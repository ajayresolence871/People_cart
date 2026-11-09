-- REVIEW-ONLY PROPOSAL. Do not apply until the target database's deployed
-- function definitions, trigger attachments, grants, RLS policies, and
-- products/order_items schema have been captured and reviewed.
--
-- This version is compatible with the admin delivery-status authorization
-- proposal: admins retain preparation/cancellation transitions, only the
-- assigned delivery partner advances delivery, and an order's authenticated
-- owner may cancel it only while placed. Both status guards enforce the
-- customer cancellation rule. No direct table grants or RLS policies change.
--
-- The cancellation function locks the owned order row, changes placed to
-- cancelled once, and restores the saved item quantities to stock in the same
-- transaction. It does not issue a payment refund.

BEGIN;

CREATE OR REPLACE FUNCTION public.guard_order_status_transitions()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_role text;
  v_is_customer_cancellation boolean;
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
      AND NEW.status::text IN ('cancelled', 'out_for_delivery'))
    OR (OLD.status::text = 'out_for_delivery'
      AND NEW.status::text = 'delivered');

  IF NOT v_is_valid_transition THEN
    RAISE EXCEPTION 'Invalid order status transition';
  END IF;

  v_is_customer_cancellation :=
    v_role = 'customer'
    AND OLD.user_id = auth.uid()
    AND NEW.user_id IS NOT DISTINCT FROM OLD.user_id
    AND OLD.status::text = 'placed'
    AND NEW.status::text = 'cancelled'
    AND (to_jsonb(NEW) - 'status' - 'updated_at')
      IS NOT DISTINCT FROM
        (to_jsonb(OLD) - 'status' - 'updated_at');

  IF v_is_customer_cancellation THEN
    RETURN NEW;
  END IF;

  IF v_role = 'admin'
      AND (
        (OLD.status::text = 'placed'
          AND NEW.status::text IN ('preparing', 'cancelled'))
        OR (OLD.status::text = 'preparing'
          AND NEW.status::text = 'cancelled')
      ) THEN
    RETURN NEW;
  END IF;

  v_is_assigned_partner :=
    v_role = 'delivery_partner'
    AND to_jsonb(OLD)->>'assigned_delivery_partner_id' = auth.uid()::text
    AND to_jsonb(NEW)->>'assigned_delivery_partner_id'
      IS NOT DISTINCT FROM
        to_jsonb(OLD)->>'assigned_delivery_partner_id'
    AND (
      (OLD.status::text = 'preparing'
        AND NEW.status::text = 'out_for_delivery')
      OR (OLD.status::text = 'out_for_delivery'
        AND NEW.status::text = 'delivered')
    );

  IF v_is_assigned_partner THEN
    RETURN NEW;
  END IF;

  RAISE EXCEPTION
    'Only an order owner may cancel a placed order; delivery progress requires the assigned partner';
END;
$function$;

REVOKE ALL ON FUNCTION public.guard_order_status_transitions()
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.guard_delivery_order_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_is_admin boolean;
  v_is_customer boolean;
  v_is_delivery_partner boolean;
  v_is_customer_cancellation boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND lower(btrim(p.role::text)) = 'admin'
  ) INTO v_is_admin;

  SELECT EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND lower(btrim(p.role::text)) = 'customer'
  ) INTO v_is_customer;

  SELECT EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND lower(btrim(p.role::text)) = 'delivery_partner'
  ) INTO v_is_delivery_partner;

  IF v_is_delivery_partner
      AND NOT v_is_admin
      AND (to_jsonb(NEW) - 'status' - 'updated_at')
        IS DISTINCT FROM (to_jsonb(OLD) - 'status' - 'updated_at') THEN
    RAISE EXCEPTION 'Delivery partners may only update order status';
  END IF;

  IF NEW.assigned_delivery_partner_id
      IS DISTINCT FROM OLD.assigned_delivery_partner_id
      AND NOT v_is_admin THEN
    RAISE EXCEPTION 'Only admins can change delivery assignments';
  END IF;

  IF NEW.status::text IS DISTINCT FROM OLD.status::text THEN
    IF v_is_admin
        AND (
          (OLD.status::text = 'placed'
            AND NEW.status::text IN ('preparing', 'cancelled'))
          OR (OLD.status::text = 'preparing'
            AND NEW.status::text = 'cancelled')
        ) THEN
      NULL;
    ELSIF v_is_customer
        AND OLD.user_id = auth.uid()
        AND NEW.user_id IS NOT DISTINCT FROM OLD.user_id
        AND OLD.status::text = 'placed'
        AND NEW.status::text = 'cancelled'
        AND (to_jsonb(NEW) - 'status' - 'updated_at')
          IS NOT DISTINCT FROM
            (to_jsonb(OLD) - 'status' - 'updated_at') THEN
      NULL;
    ELSIF v_is_delivery_partner
        AND NOT v_is_admin
        AND OLD.assigned_delivery_partner_id = auth.uid()
        AND NEW.assigned_delivery_partner_id
          IS NOT DISTINCT FROM OLD.assigned_delivery_partner_id
        AND (
          (OLD.status::text = 'preparing'
            AND NEW.status::text = 'out_for_delivery')
          OR (OLD.status::text = 'out_for_delivery'
            AND NEW.status::text = 'delivered')
        ) THEN
      NULL;
    ELSE
      RAISE EXCEPTION 'Not authorized for this order status change';
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.guard_delivery_order_fields()
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.customer_cancel_order(p_order_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_status text;
  v_item record;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT o.status::text
  INTO v_status
  FROM public.orders o
  WHERE o.id = p_order_id
    AND o.user_id = v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found for this account';
  END IF;

  IF v_status <> 'placed' THEN
    RAISE EXCEPTION 'Only placed orders can be cancelled';
  END IF;

  UPDATE public.orders
  SET status = 'cancelled'
  WHERE id = p_order_id
    AND user_id = v_user_id
    AND status::text = 'placed';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order status changed; refresh and try again';
  END IF;

  FOR v_item IN
    SELECT oi.product_id, sum(oi.quantity)::bigint AS quantity
    FROM public.order_items oi
    WHERE oi.order_id = p_order_id
      AND oi.product_id IS NOT NULL
    GROUP BY oi.product_id
    ORDER BY oi.product_id
  LOOP
    UPDATE public.products p
    SET stock_quantity = p.stock_quantity + v_item.quantity
    WHERE p.id = v_item.product_id;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'order_id', p_order_id,
    'status', 'cancelled'
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.customer_cancel_order(bigint)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.customer_cancel_order(bigint)
  TO authenticated;

COMMIT;

-- ROLLBACK NOTES (manual): restore both guard functions and the customer RPC
-- ACL/definition from the captured target-environment baseline. If the RPC did
-- not exist before this change, revoke its grants and drop it. Restoring an
-- older guard_order_status_transitions definition may reopen admin delivery
-- advancement; coordinate rollback with the delivery-status fix. No automatic
-- rollback is included.
