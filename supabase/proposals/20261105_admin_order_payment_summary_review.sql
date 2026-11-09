-- REVIEW-ONLY PROPOSAL. Do not apply until the deployed admin RPC, owner,
-- search_path, and grants have been captured and compared with this preflight.
--
-- Adds payment method/status to the JSON returned by the existing admin-only
-- order-details RPC. Historical Razorpay orders are shown as online/paid only
-- when a linked checkout attempt is completed and has a payment ID. Orders
-- without stored payment details or that confirmation remain unknown.
-- No customer, payment ID, or other payment credential is returned.

BEGIN;

DO $preflight$
DECLARE
  v_function oid := to_regprocedure('public.admin_get_order_details(bigint)')::oid;
BEGIN
  IF current_user <> 'postgres' THEN
    RAISE EXCEPTION 'Expected the reviewed postgres function owner';
  END IF;
  IF v_function IS NULL THEN
    RAISE EXCEPTION 'admin_get_order_details(bigint) is missing';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'orders'
      AND column_name = 'payment_method' AND data_type = 'text'
  ) OR NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'orders'
      AND column_name = 'payment_status' AND data_type = 'text'
  ) OR to_regclass('public.razorpay_checkout_attempts') IS NULL THEN
    RAISE EXCEPTION 'Expected payment columns and checkout-attempt table';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_catalog.pg_proc p
    WHERE p.oid = v_function
      AND p.proowner = (SELECT oid FROM pg_catalog.pg_roles WHERE rolname = 'postgres')
      AND p.prosecdef
      AND p.proconfig = ARRAY['search_path=""']::text[]
      AND pg_get_function_result(p.oid) = 'jsonb'
  ) THEN
    RAISE EXCEPTION 'Admin order-details RPC owner/security/result differs from the reviewed baseline';
  END IF;

  IF NOT has_function_privilege(
       'authenticated', 'public.admin_get_order_details(bigint)', 'EXECUTE'
     )
     OR has_function_privilege(
       'anon', 'public.admin_get_order_details(bigint)', 'EXECUTE'
     )
     OR NOT has_function_privilege(
       'service_role', 'public.admin_get_order_details(bigint)', 'EXECUTE'
     ) THEN
    RAISE EXCEPTION 'Admin order-details RPC grants differ from the reviewed baseline';
  END IF;
END;
$preflight$;

-- Same signature and JSONB return type. CREATE OR REPLACE preserves the
-- existing function owner and ACL; the admin role check and empty search_path
-- remain in place.
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
    'payment_method', COALESCE(o.payment_method, CASE WHEN EXISTS (
      SELECT 1
      FROM public.razorpay_checkout_attempts a
      WHERE a.order_id = o.id
        AND a.status = 'completed'
        AND a.razorpay_payment_id IS NOT NULL
    ) THEN 'razorpay'::text END),
    'payment_status', COALESCE(o.payment_status, CASE WHEN EXISTS (
      SELECT 1
      FROM public.razorpay_checkout_attempts a
      WHERE a.order_id = o.id
        AND a.status = 'completed'
        AND a.razorpay_payment_id IS NOT NULL
    ) THEN 'paid'::text END),
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

COMMIT;

-- ROLLBACK NOTES (manual): restore the captured deployed definition of
-- admin_get_order_details(bigint). This patch writes no rows; rollback removes
-- the payment summary from the RPC response while leaving checkout records
-- and payment columns intact.
