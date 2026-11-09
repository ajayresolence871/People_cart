-- REVIEW BEFORE APPLYING:
-- Prevent admins from moving orders to out_for_delivery or delivered.
-- Those transitions must use delivery_partner_update_order_status so the
-- assigned delivery partner is verified. This migration is not applied
-- automatically; review against the live orders schema and current functions.

BEGIN;

CREATE OR REPLACE FUNCTION public.guard_order_status_transitions()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_role text;
  v_is_assigned_partner boolean;
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

  IF v_role = 'admin' THEN
    IF (OLD.status::text = 'placed'
        AND NEW.status::text IN ('preparing', 'cancelled'))
      OR (OLD.status::text = 'preparing'
        AND NEW.status::text = 'cancelled') THEN
      RETURN NEW;
    END IF;

    RAISE EXCEPTION
      'Admins may prepare or cancel orders; delivery status must be updated by the assigned partner';
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

  RAISE EXCEPTION
    'Only admins or the assigned delivery partner may update order status';
END;
$function$;

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
    RAISE EXCEPTION
      'Invalid admin status transition; delivery statuses are reserved for the assigned delivery partner';
  END IF;

  UPDATE public.orders
  SET status = p_new_status
  WHERE id = p_order_id;
END;
$function$;

COMMIT;
