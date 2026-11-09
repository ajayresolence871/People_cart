-- REVIEW-ONLY PROPOSAL. Do not apply until the deployed definitions, grants,
-- and table constraints have been captured and compared with this file.
--
-- Gives an assigned delivery partner only the payment method and collection
-- state needed to complete delivery. Historical orders remain NULL/unknown;
-- this proposal does not guess payment details for old orders.
--
-- Razorpay orders are created only by finalize_razorpay_checkout after the
-- Edge Function verifies a captured payment. COD continues through the
-- existing trusted create_order_secure RPC, with its returned order marked
-- as cash-on-delivery in the same transaction.

BEGIN;

DO $preflight$
BEGIN
  IF current_user <> 'postgres' THEN
    RAISE EXCEPTION 'Review this proposal for the deployed function owner before applying';
  END IF;
  IF to_regprocedure('public.create_order_cash_secure(jsonb,text)') IS NULL
     OR to_regprocedure('public.finalize_razorpay_checkout(uuid,text,text)') IS NULL
     OR to_regprocedure('public.create_order_secure(jsonb,text,text)') IS NULL THEN
    RAISE EXCEPTION 'Expected checkout RPC signatures are missing';
  END IF;
  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_proc p
    WHERE (
      p.oid = to_regprocedure(
        'public.create_order_cash_secure(jsonb,text)'
      )::oid
      OR p.oid = to_regprocedure(
        'public.finalize_razorpay_checkout(uuid,text,text)'
      )::oid
    )
      AND (
        p.proowner <> (SELECT oid FROM pg_catalog.pg_roles WHERE rolname = 'postgres')
        OR NOT p.prosecdef
        OR p.proconfig IS NULL
        OR NOT ('search_path=""' = ANY (p.proconfig))
      )
  ) THEN
    RAISE EXCEPTION 'Checkout RPC owner or security settings differ from the reviewed baseline';
  END IF;
  IF NOT has_function_privilege(
       'authenticated', 'public.create_order_cash_secure(jsonb,text)', 'EXECUTE'
     )
     OR has_function_privilege(
       'anon', 'public.create_order_cash_secure(jsonb,text)', 'EXECUTE'
     )
     OR NOT has_function_privilege(
       'service_role', 'public.finalize_razorpay_checkout(uuid,text,text)', 'EXECUTE'
     )
     OR has_function_privilege(
       'authenticated', 'public.finalize_razorpay_checkout(uuid,text,text)', 'EXECUTE'
     ) THEN
    RAISE EXCEPTION 'Checkout RPC grants differ from the reviewed baseline';
  END IF;
  IF to_regprocedure('public.delivery_partner_list_my_order_payment_summary()') IS NOT NULL THEN
    RAISE EXCEPTION 'Payment summary RPC already exists; inspect it instead of replacing it';
  END IF;
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'orders'
      AND column_name IN ('payment_method', 'payment_status')
  ) THEN
    RAISE EXCEPTION 'Payment columns already exist; compare their types and constraints before proceeding';
  END IF;
  IF (SELECT count(*) FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public' AND c.relname = 'razorpay_checkout_attempts'
        AND c.relkind = 'r') <> 1 THEN
    RAISE EXCEPTION 'Expected public.razorpay_checkout_attempts table';
  END IF;
END;
$preflight$;

ALTER TABLE public.orders
  ADD COLUMN payment_method text,
  ADD COLUMN payment_status text,
  ADD CONSTRAINT orders_payment_summary_check CHECK (
    (payment_method IS NULL AND payment_status IS NULL)
    OR (
      payment_method IS NOT NULL AND payment_status IS NOT NULL
      AND (
        (payment_method = 'cash_on_delivery'
          AND payment_status IN ('pending', 'paid'))
        OR (payment_method = 'razorpay' AND payment_status = 'paid')
      )
    )
  );

-- CREATE OR REPLACE keeps the deployed function signature and ACL. Preserve
-- the trusted checkout RPC's price, address, stock, and item calculations.
CREATE OR REPLACE FUNCTION public.create_order_cash_secure(
  p_items jsonb,
  p_delivery_address_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_result jsonb;
  v_order_id bigint;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  v_result := public.create_order_secure(
    p_items, p_delivery_address_id, 'cash_on_delivery'
  );
  v_order_id := (v_result->>'order_id')::bigint;
  IF v_order_id IS NULL THEN
    RAISE EXCEPTION 'Secure checkout did not return an order ID';
  END IF;

  UPDATE public.orders
  SET payment_method = 'cash_on_delivery', payment_status = 'pending'
  WHERE id = v_order_id AND user_id = auth.uid();
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Could not save COD payment details for the new order';
  END IF;

  RETURN v_result;
END;
$function$;

-- Preserve the existing signature, SECURITY DEFINER owner, search path,
-- idempotency behavior, order-item snapshots, and attempt updates. The only
-- order insertion change is recording the already-verified payment summary.
CREATE OR REPLACE FUNCTION public.finalize_razorpay_checkout(
  p_attempt_id uuid,
  p_razorpay_order_id text,
  p_razorpay_payment_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_attempt public.razorpay_checkout_attempts%ROWTYPE;
  v_order_id bigint;
  v_line jsonb;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'Service role required';
  END IF;

  SELECT * INTO STRICT v_attempt
  FROM public.razorpay_checkout_attempts
  WHERE id = p_attempt_id
  FOR UPDATE;

  IF v_attempt.status = 'completed' THEN
    IF v_attempt.razorpay_order_id IS DISTINCT FROM p_razorpay_order_id
       OR v_attempt.razorpay_payment_id IS DISTINCT FROM p_razorpay_payment_id THEN
      RAISE EXCEPTION 'A different payment already completed this attempt';
    END IF;
    RETURN jsonb_build_object(
      'success', true, 'order_id', v_attempt.order_id,
      'total_amount', v_attempt.total_amount
    );
  END IF;

  IF v_attempt.status <> 'reserved'
     OR v_attempt.razorpay_order_id IS DISTINCT FROM p_razorpay_order_id
     OR p_razorpay_payment_id IS NULL THEN
    RAISE EXCEPTION 'Payment attempt does not match';
  END IF;

  INSERT INTO public.orders (
    total_amount, status, user_id, delivery_address_snapshot,
    payment_method, payment_status
  ) VALUES (
    v_attempt.total_amount, 'placed', v_attempt.user_id,
    v_attempt.address_snapshot, 'razorpay', 'paid'
  )
  RETURNING id INTO v_order_id;

  FOR v_line IN
    SELECT value FROM jsonb_array_elements(v_attempt.items_snapshot)
  LOOP
    INSERT INTO public.order_items (
      order_id, product_id, product_name, quantity, unit_price
    ) VALUES (
      v_order_id,
      (v_line->>'product_id')::integer,
      v_line->>'product_name',
      (v_line->>'quantity')::integer,
      (v_line->>'unit_price')::numeric
    );
  END LOOP;

  UPDATE public.razorpay_checkout_attempts
  SET status = 'completed', order_id = v_order_id,
      razorpay_payment_id = p_razorpay_payment_id
  WHERE id = p_attempt_id;

  RETURN jsonb_build_object(
    'success', true, 'order_id', v_order_id,
    'total_amount', v_attempt.total_amount
  );
END;
$function$;

-- Return payment summary only for the caller's currently assigned orders.
-- This avoids changing the existing delivery-list RPC's return type.
CREATE FUNCTION public.delivery_partner_list_my_order_payment_summary()
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
  SELECT o.id, o.payment_method, o.payment_status
  FROM public.orders o
  WHERE o.assigned_delivery_partner_id = auth.uid()
  ORDER BY o.created_at DESC NULLS LAST, o.id DESC;
END;
$function$;

REVOKE ALL ON FUNCTION public.delivery_partner_list_my_order_payment_summary()
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.delivery_partner_list_my_order_payment_summary()
  TO authenticated;

COMMIT;

-- ROLLBACK NOTES (manual): restore the captured deployed definitions of
-- create_order_cash_secure(jsonb,text) and
-- finalize_razorpay_checkout(uuid,text,text); revoke/drop the newly created
-- delivery_partner_list_my_order_payment_summary() RPC. Remove the check
-- constraint if reverting the column behavior. Keep payment_method and
-- payment_status columns unless their data has been backed up and removal is
-- explicitly intended. Rollback loses new UI payment details; it does not
-- alter order status, stock, or payment attempts.
