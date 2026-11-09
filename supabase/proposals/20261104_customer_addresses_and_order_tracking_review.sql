-- REVIEW-ONLY PROPOSAL. This file is intentionally outside supabase/migrations
-- and must not be applied until the live schema, grants, and RLS policies are
-- reviewed and the customer approves deployment.
--
-- Adds customer-owned addresses, makes the address mandatory for secure
-- checkout, snapshots the server-verified address on the order, and allows
-- customers to read only their own orders and saved order items.
-- Before adoption, confirm public.current_user_is_admin() exists and review
-- all existing policies; the restrictive owner/admin guards below prevent
-- unrelated permissive policies from widening customer visibility.
--
-- Preserve the existing create_order_secure product, price, stock, payment,
-- delivery-fee, and transaction logic when adopting this proposal.

BEGIN;

CREATE TABLE public.customer_addresses (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  id text NOT NULL,
  tag text NOT NULL,
  house_no text NOT NULL,
  area text NOT NULL,
  landmark text NOT NULL DEFAULT '',
  recipient_name text NOT NULL,
  phone_number text NOT NULL,
  is_default boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, id),
  CHECK (btrim(id) <> ''),
  CHECK (btrim(tag) <> ''),
  CHECK (btrim(house_no) <> ''),
  CHECK (btrim(area) <> ''),
  CHECK (btrim(recipient_name) <> ''),
  CHECK (btrim(phone_number) <> '')
);

ALTER TABLE public.customer_addresses ENABLE ROW LEVEL SECURITY;

CREATE POLICY customer_addresses_select_own
  ON public.customer_addresses
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = user_id);

CREATE POLICY customer_addresses_insert_own
  ON public.customer_addresses
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY customer_addresses_update_own
  ON public.customer_addresses
  FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY customer_addresses_delete_own
  ON public.customer_addresses
  FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) = user_id);

GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.customer_addresses TO authenticated;

ALTER TABLE public.orders
  ADD COLUMN delivery_address_snapshot jsonb;

-- RLS is necessary because the app requests order rows and their saved items
-- directly. The user_id predicates in Flutter are defense in depth, not auth.
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY customers_read_own_orders
  ON public.orders
  FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));

CREATE POLICY orders_customer_scope_guard
  ON public.orders
  AS RESTRICTIVE
  FOR SELECT TO authenticated
  USING (
    user_id = (SELECT auth.uid())
    OR (SELECT public.current_user_is_admin())
  );

CREATE POLICY customers_read_own_order_items
  ON public.order_items
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.orders o
      WHERE o.id = order_items.order_id
        AND o.user_id = (SELECT auth.uid())
    )
  );

CREATE POLICY admins_read_order_items
  ON public.order_items
  FOR SELECT TO authenticated
  USING ((SELECT public.current_user_is_admin()));

CREATE POLICY order_items_customer_scope_guard
  ON public.order_items
  AS RESTRICTIVE
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.orders o
      WHERE o.id = order_items.order_id
        AND (
          o.user_id = (SELECT auth.uid())
          OR (SELECT public.current_user_is_admin())
        )
    )
  );

GRANT SELECT ON public.orders, public.order_items TO authenticated;

CREATE OR REPLACE FUNCTION public.prevent_order_address_snapshot_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF NEW.delivery_address_snapshot IS DISTINCT FROM OLD.delivery_address_snapshot THEN
    RAISE EXCEPTION 'A saved order delivery address cannot be changed';
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.prevent_order_address_snapshot_change()
  FROM PUBLIC, anon, authenticated;

CREATE TRIGGER prevent_order_address_snapshot_change
  BEFORE UPDATE OF delivery_address_snapshot ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_order_address_snapshot_change();

-- Remove address-less RPC signatures so clients cannot bypass the required
-- address argument through an older overload.
DROP FUNCTION IF EXISTS public.create_order_secure(jsonb, text, uuid);
DROP FUNCTION IF EXISTS public.create_order_secure(jsonb, text);
DROP FUNCTION IF EXISTS public.create_order_secure(jsonb);

CREATE FUNCTION public.create_order_secure(
  p_items jsonb,
  p_delivery_address_id text,
  p_payment_method text DEFAULT 'cash_on_delivery'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_user_id uuid;
  v_elem jsonb;
  v_raw_pid text;
  v_raw_qty text;
  v_prod_name text;
  v_prod_price numeric;
  v_prod_stock int;
  v_prod_avail boolean;
  v_authoritative_total numeric := 0.00;
  v_order_id bigint;
  v_delivery_fee numeric := 0.00;
  v_agg_item record;
  v_address_snapshot jsonb;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required: You must be signed in to place an order.'
      USING ERRCODE = 'P0001';
  END IF;

  IF p_delivery_address_id IS NULL OR btrim(p_delivery_address_id) = '' THEN
    RAISE EXCEPTION 'A delivery address is required.'
      USING ERRCODE = 'P0001';
  END IF;

  -- The supplied ID is only a lookup key. Ownership and all persisted address
  -- fields are resolved from the authenticated user's address row.
  SELECT jsonb_build_object(
    'tag', a.tag,
    'house_no', a.house_no,
    'area', a.area,
    'landmark', a.landmark
  )
  INTO v_address_snapshot
  FROM public.customer_addresses a
  WHERE a.user_id = v_user_id
    AND a.id = p_delivery_address_id
  FOR SHARE;

  IF v_address_snapshot IS NULL THEN
    RAISE EXCEPTION 'The selected delivery address is unavailable for this account.'
      USING ERRCODE = 'P0001';
  END IF;

  IF p_payment_method IS NULL OR p_payment_method NOT IN (
    'cash_on_delivery', 'online_simulated'
  ) THEN
    RAISE EXCEPTION 'Invalid or missing payment method: "%". Supported methods: cash_on_delivery, online_simulated',
      p_payment_method;
  END IF;

  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array'
     OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'Order cannot be empty and items must be a valid JSON array';
  END IF;

  IF jsonb_array_length(p_items) > 100 THEN
    RAISE EXCEPTION 'Order exceeds maximum allowed item count (100 items per order)';
  END IF;

  FOR v_elem IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    IF jsonb_typeof(v_elem) <> 'object' THEN
      RAISE EXCEPTION 'Invalid item format: each item in p_items must be a JSON object';
    END IF;

    v_raw_pid := v_elem->>'product_id';
    v_raw_qty := v_elem->>'quantity';

    IF v_raw_pid IS NULL OR v_raw_pid !~ '^\d+$'
       OR v_raw_pid::bigint <= 0 OR v_raw_pid::bigint > 2147483647 THEN
      RAISE EXCEPTION 'Invalid product_id: "%". Product ID must be a positive integer between 1 and 2147483647',
        v_raw_pid;
    END IF;

    IF v_raw_qty IS NULL OR v_raw_qty !~ '^\d+$'
       OR v_raw_qty::bigint <= 0 OR v_raw_qty::bigint > 999 THEN
      RAISE EXCEPTION 'Invalid quantity: "%" for product ID %. Quantity per item must be between 1 and 999',
        v_raw_qty, v_raw_pid;
    END IF;
  END LOOP;

  FOR v_agg_item IN
    SELECT (elem->>'product_id')::int AS product_id,
           sum((elem->>'quantity')::bigint)::bigint AS aggregated_qty
    FROM jsonb_array_elements(p_items) AS elem
    GROUP BY (elem->>'product_id')::int
    ORDER BY (elem->>'product_id')::int ASC
  LOOP
    IF v_agg_item.aggregated_qty <= 0 OR v_agg_item.aggregated_qty > 9999 THEN
      RAISE EXCEPTION 'Combined quantity % for product ID % exceeds maximum allowed per order (9999)',
        v_agg_item.aggregated_qty, v_agg_item.product_id;
    END IF;

    SELECT name, price, stock_quantity, is_available
    INTO v_prod_name, v_prod_price, v_prod_stock, v_prod_avail
    FROM public.products
    WHERE id = v_agg_item.product_id
    FOR UPDATE;

    IF v_prod_name IS NULL THEN
      RAISE EXCEPTION 'Product with ID % does not exist', v_agg_item.product_id;
    END IF;
    IF NOT v_prod_avail THEN
      RAISE EXCEPTION 'Product "%" is currently unavailable', v_prod_name;
    END IF;
    IF v_prod_stock < v_agg_item.aggregated_qty THEN
      RAISE EXCEPTION 'Insufficient stock for "%". Requested: %, Available: %',
        v_prod_name, v_agg_item.aggregated_qty, v_prod_stock;
    END IF;
    v_authoritative_total :=
      v_authoritative_total + (v_prod_price * v_agg_item.aggregated_qty);
  END LOOP;

  IF v_authoritative_total < 49.00 THEN
    v_delivery_fee := 30.00;
  END IF;

  FOR v_agg_item IN
    SELECT (elem->>'product_id')::int AS product_id,
           sum((elem->>'quantity')::bigint)::int AS aggregated_qty
    FROM jsonb_array_elements(p_items) AS elem
    GROUP BY (elem->>'product_id')::int
  LOOP
    UPDATE public.products
    SET stock_quantity = stock_quantity - v_agg_item.aggregated_qty
    WHERE id = v_agg_item.product_id;
  END LOOP;

  INSERT INTO public.orders (
    total_amount,
    status,
    user_id,
    delivery_address_snapshot
  ) VALUES (
    v_authoritative_total + v_delivery_fee,
    'placed',
    v_user_id,
    v_address_snapshot
  )
  RETURNING id INTO v_order_id;

  FOR v_agg_item IN
    SELECT (elem->>'product_id')::int AS product_id,
           sum((elem->>'quantity')::bigint)::int AS aggregated_qty
    FROM jsonb_array_elements(p_items) AS elem
    GROUP BY (elem->>'product_id')::int
  LOOP
    SELECT name, price
    INTO v_prod_name, v_prod_price
    FROM public.products
    WHERE id = v_agg_item.product_id;

    INSERT INTO public.order_items (
      order_id, product_id, product_name, quantity, unit_price
    ) VALUES (
      v_order_id,
      v_agg_item.product_id,
      v_prod_name,
      v_agg_item.aggregated_qty,
      v_prod_price
    );
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order_id,
    'subtotal', v_authoritative_total,
    'delivery_fee', v_delivery_fee,
    'total_amount', v_authoritative_total + v_delivery_fee,
    'status', 'placed'
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.create_order_secure(jsonb, text, text)
  FROM PUBLIC;
REVOKE ALL ON FUNCTION public.create_order_secure(jsonb, text, text)
  FROM anon;
GRANT EXECUTE ON FUNCTION public.create_order_secure(jsonb, text, text)
  TO authenticated;

COMMIT;
