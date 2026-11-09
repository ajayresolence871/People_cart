-- REVIEW BEFORE APPLYING:
-- Checked-in migrations establish orders.id/user_id/status/created_at/total_amount,
-- order_items.order_id/product_id/product_name/quantity/unit_price, and
-- profiles.id/full_name/role. Live schema and RLS policies are not verified.
-- These admin-only functions expose only customer display names and saved order
-- item snapshots. Do not apply until reviewed and verified against the project.

BEGIN;

CREATE OR REPLACE FUNCTION public.admin_list_orders(p_status text DEFAULT NULL)
RETURNS TABLE (
  order_id bigint,
  created_at timestamptz,
  total_amount numeric,
  status text,
  customer_name text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND lower(btrim(p.role::text)) = 'admin'
  ) THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  IF p_status IS NOT NULL AND p_status NOT IN (
    'placed', 'preparing', 'out_for_delivery', 'delivered', 'cancelled'
  ) THEN
    RAISE EXCEPTION 'Invalid order status filter';
  END IF;

  RETURN QUERY
  SELECT o.id, o.created_at, o.total_amount, o.status::text,
         p.full_name::text
  FROM public.orders o
  LEFT JOIN public.profiles p ON p.id = o.user_id
  WHERE p_status IS NULL OR o.status::text = p_status
  ORDER BY o.created_at DESC NULLS LAST, o.id DESC;
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_get_order_details(p_order_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_result jsonb;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND lower(btrim(p.role::text)) = 'admin'
  ) THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  SELECT jsonb_build_object(
    'order_id', o.id,
    'created_at', o.created_at,
    'total_amount', o.total_amount,
    'status', o.status::text,
    'customer_name', p.full_name,
    'items', COALESCE((
      SELECT jsonb_agg(
        jsonb_build_object(
          'product_id', oi.product_id,
          'product_name', oi.product_name,
          'quantity', oi.quantity,
          'unit_price', oi.unit_price
        )
        ORDER BY oi.id
      )
      FROM public.order_items oi
      WHERE oi.order_id = o.id
    ), '[]'::jsonb)
  )
  INTO v_result
  FROM public.orders o
  LEFT JOIN public.profiles p ON p.id = o.user_id
  WHERE o.id = p_order_id;

  IF v_result IS NULL THEN
    RAISE EXCEPTION 'Order not found';
  END IF;

  RETURN v_result;
END;
$function$;

CREATE OR REPLACE FUNCTION public.guard_order_status_transitions()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_role text;
  v_is_assigned_partner boolean;
  v_is_valid_transition boolean;
BEGIN
  IF NEW.status::text IS NOT DISTINCT FROM OLD.status::text THEN
    RETURN NEW;
  END IF;

  IF NEW.status IS NULL THEN
    RAISE EXCEPTION 'Order status cannot be null';
  END IF;

  SELECT lower(btrim(p.role::text))
  INTO v_role
  FROM public.profiles p
  WHERE p.id = auth.uid();

  v_is_valid_transition :=
    (OLD.status::text = 'placed'
      AND NEW.status::text IN ('preparing', 'cancelled'))
    OR (OLD.status::text = 'preparing'
      AND NEW.status::text IN ('out_for_delivery', 'cancelled'))
    OR (OLD.status::text = 'out_for_delivery'
      AND NEW.status::text = 'delivered');

  IF NOT v_is_valid_transition THEN
    RAISE EXCEPTION 'Invalid order status transition';
  END IF;

  IF v_role = 'admin' THEN
    RETURN NEW;
  END IF;

  v_is_assigned_partner :=
    v_role = 'delivery_partner'
    AND to_jsonb(OLD)->>'assigned_delivery_partner_id' = auth.uid()::text
    AND to_jsonb(NEW)->>'assigned_delivery_partner_id'
      IS NOT DISTINCT FROM to_jsonb(OLD)->>'assigned_delivery_partner_id'
    AND (
      (OLD.status::text = 'preparing'
        AND NEW.status::text = 'out_for_delivery')
      OR (OLD.status::text = 'out_for_delivery'
        AND NEW.status::text = 'delivered')
    );

  IF v_is_assigned_partner THEN
    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'Only authorized admins or the assigned delivery partner may update order status';
END;
$function$;

REVOKE ALL ON FUNCTION public.guard_order_status_transitions()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS guard_order_status_transitions ON public.orders;
CREATE TRIGGER guard_order_status_transitions
  BEFORE UPDATE OF status ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_order_status_transitions();

CREATE OR REPLACE FUNCTION public.admin_update_order_status(
  p_order_id bigint,
  p_new_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_current_status text;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND lower(btrim(p.role::text)) = 'admin'
  ) THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  SELECT o.status::text
  INTO v_current_status
  FROM public.orders o
  WHERE o.id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found';
  END IF;

  IF p_new_status IS NULL OR NOT (
    (v_current_status = 'placed'
      AND p_new_status IN ('preparing', 'cancelled'))
    OR (v_current_status = 'preparing'
      AND p_new_status IN ('out_for_delivery', 'cancelled'))
    OR (v_current_status = 'out_for_delivery'
      AND p_new_status = 'delivered')
  ) THEN
    RAISE EXCEPTION 'Invalid order status transition';
  END IF;

  UPDATE public.orders
  SET status = p_new_status
  WHERE id = p_order_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_list_orders(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_get_order_details(bigint)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_update_order_status(bigint, text)
  FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.admin_list_orders(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_order_details(bigint)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_order_status(bigint, text)
  TO authenticated;

COMMIT;
