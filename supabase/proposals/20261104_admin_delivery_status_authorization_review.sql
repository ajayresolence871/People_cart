-- REVIEW-ONLY PROPOSAL. Do not apply until the deployed schema, function
-- definitions, grants, row-level security policies, and trigger inventory have
-- been inspected and this change is explicitly approved.
--
-- The checked-in admin order-management migration allows admins to move orders
-- into out_for_delivery and delivered through admin_update_order_status. Its
-- guard_order_status_transitions trigger also allows those transitions, and the
-- separate guard_delivery_order_fields trigger allows admins to change status
-- without restricting which valid transition they make. Thus fixing only the
-- RPC would leave a direct authenticated UPDATE path if table grants/RLS allow
-- it. This proposal restricts both trigger paths as well as the admin RPC.
--
-- Admin cancellation transitions from the existing migration are preserved.
-- Customer cancellation is not implemented or changed here. The separate
-- customer cancellation review proposal replaces guard_order_status_transitions
-- but does not update guard_delivery_order_fields; as written, that second
-- trigger rejects its customer_cancel_order status update. Coordinate both
-- trigger definitions and the table UPDATE grants before adopting cancellation.
--
-- The partner RPC is intentionally unchanged: it validates the caller's role,
-- scopes its row lock to orders assigned to auth.uid(), and accepts only
-- preparing -> out_for_delivery or out_for_delivery -> delivered. Assignment
-- remains a separate field update and does not change status.
--
-- This proposal does not add/change statuses, constraints, RLS, payment logic,
-- inventory, assignment behavior, or any live database state.

BEGIN;

-- Shared status trigger: admins may prepare/cancel according to the existing
-- admin rules, while only the assigned delivery partner may advance delivery.
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
      AND NEW.status::text = 'cancelled')
    OR (OLD.status::text = 'preparing'
      AND NEW.status::text = 'out_for_delivery')
    OR (OLD.status::text = 'out_for_delivery'
      AND NEW.status::text = 'delivered');

  IF NOT v_is_valid_transition THEN
    RAISE EXCEPTION 'Invalid order status transition';
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
    'Only admins may prepare/cancel orders and only the assigned delivery partner may advance delivery';
END;
$function$;

REVOKE ALL ON FUNCTION public.guard_order_status_transitions()
  FROM PUBLIC, anon, authenticated;

-- Separate delivery/assignment guard. Admin status changes are limited to
-- preparing/cancellation; partner status changes remain assignment-scoped.
CREATE OR REPLACE FUNCTION public.guard_delivery_order_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_is_admin boolean;
  v_is_delivery_partner boolean;
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

-- Recheck the admin role, lock the order row, and retain only existing admin
-- preparation/cancellation transitions. Delivery progress is partner-only.
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
      AND p_new_status = 'cancelled')
  ) THEN
    RAISE EXCEPTION 'Invalid admin order status transition';
  END IF;

  UPDATE public.orders
  SET status = p_new_status
  WHERE id = p_order_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_update_order_status(bigint, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_update_order_status(bigint, text)
  TO authenticated;

COMMIT;

-- ROLLBACK NOTES (manual, after review): restore the previous definitions of
-- guard_order_status_transitions(), guard_delivery_order_fields(), and
-- admin_update_order_status(bigint, text) from the verified deployed baseline.
-- Restoring the checked-in 20261102 definitions reopens admin delivery-status
-- advancement, so rollback should only be used to recover from a deployment
-- failure and must be followed by a security review. This file intentionally
-- contains no automatic rollback script.
