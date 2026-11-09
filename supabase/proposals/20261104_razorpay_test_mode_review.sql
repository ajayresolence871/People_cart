-- REVIEW-ONLY PROPOSAL. Do not apply before confirming the deployed orders,
-- order_items, products, customer_addresses schemas, constraints, and grants.
-- No live database operation is performed by this file.
--
-- Razorpay flow: reserve stock and save trusted checkout snapshots; create no
-- grocery order until a server function confirms a captured Razorpay payment.
-- COD remains on create_order_secure. A reservation is restored only by the
-- service-only release RPC after the server confirms that no payable payment
-- exists for its Razorpay order.

BEGIN;

-- Prerequisite: the reviewed address-aware
-- public.create_order_secure(jsonb, text, text) implementation must exist.
-- Remove direct client access to its legacy online_simulated option. The
-- application switches COD to the constrained wrapper below; Razorpay uses
-- reserve_razorpay_checkout/finalize_razorpay_checkout instead.
DO $preflight$
BEGIN
  IF to_regprocedure('public.create_order_secure(jsonb,text,text)') IS NULL THEN
    RAISE EXCEPTION 'Expected address-aware create_order_secure(jsonb,text,text); inspect deployed function signatures before applying';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'create_order_secure'
      AND pg_get_function_identity_arguments(p.oid) = 'p_items jsonb, p_delivery_address_id text, p_payment_method text'
      AND pg_get_userbyid(p.proowner) = current_user
  ) THEN
    RAISE EXCEPTION 'Run as the reviewed create_order_secure owner and verify its argument names before applying';
  END IF;
  IF to_regclass('public.customer_addresses') IS NULL
     OR to_regclass('public.products') IS NULL
     OR to_regclass('public.order_items') IS NULL
     OR to_regclass('public.orders') IS NULL THEN
    RAISE EXCEPTION 'Expected orders, order_items, products, and customer_addresses tables';
  END IF;
  IF EXISTS (
    SELECT 1 FROM (VALUES
      ('public.orders', 'id'), ('public.orders', 'user_id'),
      ('public.orders', 'status'), ('public.orders', 'total_amount'),
      ('public.order_items', 'order_id'), ('public.order_items', 'product_id'),
      ('public.order_items', 'product_name'), ('public.order_items', 'quantity'),
      ('public.order_items', 'unit_price'), ('public.products', 'id'),
      ('public.products', 'name'), ('public.products', 'price'),
      ('public.products', 'stock_quantity'), ('public.products', 'is_available'),
      ('public.customer_addresses', 'id'), ('public.customer_addresses', 'user_id'),
      ('public.customer_addresses', 'tag'), ('public.customer_addresses', 'house_no'),
      ('public.customer_addresses', 'area'), ('public.customer_addresses', 'landmark')
    ) AS required(table_name, column_name)
    WHERE NOT EXISTS (
      SELECT 1 FROM information_schema.columns c
       WHERE c.table_schema || '.' || c.table_name = required.table_name
         AND c.column_name = required.column_name
    )
  ) THEN RAISE EXCEPTION 'Required checkout columns are missing; compare the live schema before applying';
  END IF;
END;
$preflight$;

DO $revoke_legacy$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure AS signature
      FROM pg_catalog.pg_proc p
      JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.proname = 'create_order_secure'
  LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated', r.signature);
  END LOOP;
END;
$revoke_legacy$;

CREATE OR REPLACE FUNCTION public.create_order_cash_secure(
  p_items jsonb,
  p_delivery_address_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  RETURN public.create_order_secure(p_items, p_delivery_address_id, 'cash_on_delivery');
END;
$function$;

REVOKE ALL ON FUNCTION public.create_order_cash_secure(jsonb, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_order_cash_secure(jsonb, text) TO authenticated;

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS delivery_address_snapshot jsonb;

CREATE TABLE IF NOT EXISTS public.razorpay_checkout_attempts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  idempotency_key uuid NOT NULL,
  razorpay_order_id text UNIQUE,
  razorpay_payment_id text UNIQUE,
  items_snapshot jsonb NOT NULL,
  address_snapshot jsonb NOT NULL,
  total_amount numeric(12,2) NOT NULL CHECK (total_amount >= 1),
  amount_paise bigint NOT NULL CHECK (amount_paise >= 100),
  status text NOT NULL CHECK (status IN ('reserved', 'completed', 'released')),
  order_id bigint UNIQUE REFERENCES public.orders(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '30 minutes'),
  UNIQUE (user_id, idempotency_key)
);

ALTER TABLE public.razorpay_checkout_attempts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.razorpay_checkout_attempts FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.razorpay_checkout_attempts TO service_role;

CREATE OR REPLACE FUNCTION public.reserve_razorpay_checkout(
  p_items jsonb,
  p_delivery_address_id text,
  p_idempotency_key uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_user uuid := auth.uid();
  v_attempt public.razorpay_checkout_attempts%ROWTYPE;
  v_address jsonb;
  v_total numeric(12,2) := 0;
  v_fee numeric(12,2) := 0;
  v_line record;
  v_name text;
  v_price numeric;
  v_stock integer;
  v_available boolean;
  v_snapshot jsonb := '[]'::jsonb;
  v_attempt_id uuid;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  IF p_idempotency_key IS NULL OR p_delivery_address_id IS NULL
     OR p_items IS NULL OR jsonb_typeof(p_items) IS DISTINCT FROM 'array'
     OR jsonb_array_length(p_items) = 0
     OR jsonb_array_length(p_items) > 100 THEN
    RAISE EXCEPTION 'Invalid checkout request';
  END IF;

  SELECT jsonb_build_object('tag', a.tag, 'house_no', a.house_no,
                            'area', a.area, 'landmark', a.landmark)
    INTO v_address
    FROM public.customer_addresses a
   WHERE a.user_id = v_user AND a.id = p_delivery_address_id
   FOR SHARE;
  IF v_address IS NULL THEN RAISE EXCEPTION 'Delivery address unavailable'; END IF;

  INSERT INTO public.razorpay_checkout_attempts
    (user_id, idempotency_key, items_snapshot, address_snapshot,
     total_amount, amount_paise, status)
  VALUES (v_user, p_idempotency_key, '[]'::jsonb, v_address, 1, 100, 'reserved')
  ON CONFLICT (user_id, idempotency_key) DO NOTHING;
  SELECT * INTO STRICT v_attempt FROM public.razorpay_checkout_attempts
   WHERE user_id = v_user AND idempotency_key = p_idempotency_key FOR UPDATE;
  IF v_attempt.razorpay_order_id IS NOT NULL THEN
    RETURN jsonb_build_object('attempt_id', v_attempt.id,
      'razorpay_order_id', v_attempt.razorpay_order_id,
      'amount_paise', v_attempt.amount_paise, 'currency', 'INR');
  END IF;
  IF v_attempt.items_snapshot <> '[]'::jsonb THEN
    RETURN jsonb_build_object('attempt_id', v_attempt.id,
      'razorpay_order_id', v_attempt.razorpay_order_id,
      'amount_paise', v_attempt.amount_paise, 'currency', 'INR');
  END IF;
  IF v_attempt.status <> 'reserved' THEN
    RAISE EXCEPTION 'Checkout attempt cannot be reused';
  END IF;

  IF EXISTS (
    SELECT 1 FROM jsonb_array_elements(p_items) x
     WHERE jsonb_typeof(x) <> 'object'
        OR coalesce(x->>'product_id', '') !~ '^\d+$'
        OR coalesce(x->>'quantity', '') !~ '^\d+$'
  ) THEN RAISE EXCEPTION 'Invalid cart item'; END IF;

  FOR v_line IN
    SELECT (x->>'product_id')::integer AS product_id,
           sum((x->>'quantity')::integer)::integer AS quantity
      FROM jsonb_array_elements(p_items) x
     WHERE x->>'product_id' ~ '^\d+$' AND x->>'quantity' ~ '^\d+$'
     GROUP BY (x->>'product_id')::integer
     ORDER BY (x->>'product_id')::integer
  LOOP
    IF v_line.product_id <= 0 OR v_line.quantity <= 0 OR v_line.quantity > 9999 THEN
      RAISE EXCEPTION 'Invalid product or quantity';
    END IF;
    SELECT p.name, p.price, p.stock_quantity, p.is_available
      INTO v_name, v_price, v_stock, v_available
      FROM public.products p WHERE p.id = v_line.product_id FOR UPDATE;
    IF NOT FOUND OR NOT coalesce(v_available, false) THEN RAISE EXCEPTION 'Product unavailable'; END IF;
    IF v_price IS NULL OR v_price < 0 OR v_stock IS NULL OR v_stock < 0 THEN
      RAISE EXCEPTION 'Product price or stock data is invalid';
    END IF;
    IF v_stock < v_line.quantity THEN RAISE EXCEPTION 'Insufficient stock for %', v_name; END IF;
    v_total := v_total + v_price * v_line.quantity;
    v_snapshot := v_snapshot || jsonb_build_array(jsonb_build_object(
      'product_id', v_line.product_id, 'product_name', v_name,
      'quantity', v_line.quantity, 'unit_price', v_price));
  END LOOP;
  IF jsonb_array_length(v_snapshot) = 0 THEN RAISE EXCEPTION 'Invalid cart items'; END IF;
  IF v_total < 49 THEN v_fee := 30; END IF;
  v_total := v_total + v_fee;
  IF round(v_total * 100)::bigint < 100 THEN RAISE EXCEPTION 'Minimum payment is INR 1.00'; END IF;

  FOR v_line IN SELECT (x->>'product_id')::integer product_id,
                       (x->>'quantity')::integer quantity
                  FROM jsonb_array_elements(v_snapshot) x
                 ORDER BY (x->>'product_id')::integer
  LOOP
    UPDATE public.products SET stock_quantity = stock_quantity - v_line.quantity
     WHERE id = v_line.product_id;
  END LOOP;

  UPDATE public.razorpay_checkout_attempts
     SET items_snapshot = v_snapshot, address_snapshot = v_address,
         total_amount = v_total, amount_paise = round(v_total * 100)::bigint
   WHERE id = v_attempt.id RETURNING * INTO v_attempt;
  RETURN jsonb_build_object('attempt_id', v_attempt.id,
    'amount_paise', v_attempt.amount_paise, 'currency', 'INR');
END;
$function$;

CREATE OR REPLACE FUNCTION public.attach_razorpay_order(
  p_attempt_id uuid, p_razorpay_order_id text
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
BEGIN
  IF auth.role() <> 'service_role' OR p_razorpay_order_id IS NULL THEN
    RAISE EXCEPTION 'Service role required';
  END IF;
  UPDATE public.razorpay_checkout_attempts
     SET razorpay_order_id = p_razorpay_order_id
   WHERE id = p_attempt_id AND status = 'reserved'
     AND razorpay_order_id IS NULL;
  IF NOT FOUND AND NOT EXISTS (SELECT 1 FROM public.razorpay_checkout_attempts
      WHERE id = p_attempt_id AND razorpay_order_id = p_razorpay_order_id) THEN
    RAISE EXCEPTION 'Unable to attach payment order';
  END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION public.finalize_razorpay_checkout(
  p_attempt_id uuid, p_razorpay_order_id text, p_razorpay_payment_id text
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
DECLARE
  v_attempt public.razorpay_checkout_attempts%ROWTYPE;
  v_order_id bigint;
  v_line jsonb;
BEGIN
  IF auth.role() <> 'service_role' THEN RAISE EXCEPTION 'Service role required'; END IF;
  SELECT * INTO STRICT v_attempt FROM public.razorpay_checkout_attempts
   WHERE id = p_attempt_id FOR UPDATE;
  IF v_attempt.status = 'completed' THEN
    IF v_attempt.razorpay_order_id IS DISTINCT FROM p_razorpay_order_id
       OR v_attempt.razorpay_payment_id IS DISTINCT FROM p_razorpay_payment_id THEN
      RAISE EXCEPTION 'A different payment already completed this attempt';
    END IF;
    RETURN jsonb_build_object('success', true, 'order_id', v_attempt.order_id,
                              'total_amount', v_attempt.total_amount);
  END IF;
  IF v_attempt.status <> 'reserved'
     OR v_attempt.razorpay_order_id IS DISTINCT FROM p_razorpay_order_id
     OR p_razorpay_payment_id IS NULL THEN
    RAISE EXCEPTION 'Payment attempt does not match';
  END IF;
  INSERT INTO public.orders (total_amount, status, user_id, delivery_address_snapshot)
  VALUES (v_attempt.total_amount, 'placed', v_attempt.user_id, v_attempt.address_snapshot)
  RETURNING id INTO v_order_id;
  FOR v_line IN SELECT value FROM jsonb_array_elements(v_attempt.items_snapshot)
  LOOP
    INSERT INTO public.order_items
      (order_id, product_id, product_name, quantity, unit_price)
    VALUES (v_order_id, (v_line->>'product_id')::integer,
      v_line->>'product_name', (v_line->>'quantity')::integer,
      (v_line->>'unit_price')::numeric);
  END LOOP;
  UPDATE public.razorpay_checkout_attempts
     SET status = 'completed', order_id = v_order_id,
         razorpay_payment_id = p_razorpay_payment_id
   WHERE id = p_attempt_id;
  RETURN jsonb_build_object('success', true, 'order_id', v_order_id,
                            'total_amount', v_attempt.total_amount);
END;
$function$;

CREATE OR REPLACE FUNCTION public.release_razorpay_checkout(p_attempt_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
DECLARE v_attempt public.razorpay_checkout_attempts%ROWTYPE; v_line jsonb;
BEGIN
  IF auth.role() <> 'service_role' THEN RAISE EXCEPTION 'Service role required'; END IF;
  SELECT * INTO STRICT v_attempt FROM public.razorpay_checkout_attempts
   WHERE id = p_attempt_id FOR UPDATE;
  IF v_attempt.status <> 'reserved' THEN RETURN; END IF;
  FOR v_line IN SELECT value FROM jsonb_array_elements(v_attempt.items_snapshot)
  LOOP
    UPDATE public.products SET stock_quantity = stock_quantity + (v_line->>'quantity')::integer
     WHERE id = (v_line->>'product_id')::integer;
  END LOOP;
  UPDATE public.razorpay_checkout_attempts SET status = 'released' WHERE id = p_attempt_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.reserve_razorpay_checkout(jsonb, text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reserve_razorpay_checkout(jsonb, text, uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.attach_razorpay_order(uuid, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.attach_razorpay_order(uuid, text) TO service_role;
REVOKE ALL ON FUNCTION public.finalize_razorpay_checkout(uuid, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.finalize_razorpay_checkout(uuid, text, text) TO service_role;
REVOKE ALL ON FUNCTION public.release_razorpay_checkout(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.release_razorpay_checkout(uuid) TO service_role;

COMMIT;

-- ROLLBACK (manual, after pausing checkout and reconciling attempts): first
-- complete/refund captured payments and release only holds confirmed unpaid by
-- Razorpay. Restore the exact captured create_order_secure definitions and ACLs,
-- drop create_order_cash_secure and its grants, then remove attempt functions
-- and table. Drop delivery_address_snapshot only if it did not pre-exist and
-- no app version uses it. Keep completed orders. Re-granting authenticated
-- EXECUTE on a legacy create_order_secure that accepts online_simulated
-- explicitly reopens the unpaid-order security gap; do not restore that grant
-- unless deliberately accepting the risk. Preserve COD through the cash-only
-- wrapper until the old app version is retired.
