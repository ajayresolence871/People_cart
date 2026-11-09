-- REVIEW-ONLY PATCH. Do not apply until the deployed summary RPC and its
-- permissions have been captured and compared with this preflight.
--
-- The initial payment-summary migration intentionally left historical order
-- columns NULL. This patch lets the assigned partner see legacy Razorpay
-- orders as online/paid only when a linked checkout attempt is completed and
-- has a payment ID. It does not infer COD for orders without such evidence.
--
-- A read-only check on 2026-11-05 found order #12 has that completed attempt,
-- while its two orders payment columns are NULL.

BEGIN;

DO $preflight$
DECLARE
  v_function oid := to_regprocedure(
    'public.delivery_partner_list_my_order_payment_summary()'
  )::oid;
BEGIN
  IF current_user <> 'postgres' THEN
    RAISE EXCEPTION 'Expected the reviewed postgres function owner';
  END IF;
  IF v_function IS NULL THEN
    RAISE EXCEPTION 'Payment summary RPC is missing; inspect current schema first';
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
      AND pg_get_function_result(p.oid) =
        'TABLE(order_id bigint, payment_method text, payment_status text)'
  ) THEN
    RAISE EXCEPTION 'Payment summary RPC definition/security differs from the reviewed baseline';
  END IF;

  IF NOT has_function_privilege(
       'authenticated', 'public.delivery_partner_list_my_order_payment_summary()', 'EXECUTE'
     )
     OR has_function_privilege(
       'anon', 'public.delivery_partner_list_my_order_payment_summary()', 'EXECUTE'
     ) THEN
    RAISE EXCEPTION 'Payment summary RPC grants differ from the reviewed baseline';
  END IF;
END;
$preflight$;

-- Same signature and result type. CREATE OR REPLACE preserves the existing
-- owner and ACL; SECURITY DEFINER and the empty search_path are reaffirmed.
CREATE OR REPLACE FUNCTION public.delivery_partner_list_my_order_payment_summary()
RETURNS TABLE (
  order_id bigint,
  payment_method text,
  payment_status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid()
      AND lower(btrim(p.role::text)) = 'delivery_partner'
  ) THEN
    RAISE EXCEPTION 'Delivery partner access required';
  END IF;

  RETURN QUERY
  SELECT
    o.id,
    COALESCE(o.payment_method, CASE WHEN EXISTS (
      SELECT 1
      FROM public.razorpay_checkout_attempts a
      WHERE a.order_id = o.id
        AND a.status = 'completed'
        AND a.razorpay_payment_id IS NOT NULL
    ) THEN 'razorpay'::text END),
    COALESCE(o.payment_status, CASE WHEN EXISTS (
      SELECT 1
      FROM public.razorpay_checkout_attempts a
      WHERE a.order_id = o.id
        AND a.status = 'completed'
        AND a.razorpay_payment_id IS NOT NULL
    ) THEN 'paid'::text END)
  FROM public.orders o
  WHERE o.assigned_delivery_partner_id = auth.uid()
  ORDER BY o.created_at DESC NULLS LAST, o.id DESC;
END;
$function$;

COMMIT;

-- ROLLBACK NOTES (manual): restore the deployed definition captured before
-- this patch. That restores the previous behavior where historical orders
-- with NULL payment columns show as unavailable. This patch writes no rows.
