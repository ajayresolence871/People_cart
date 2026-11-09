-- REVIEW BEFORE APPLYING:
-- Checked-in checkout migrations establish orders.id as BIGINT and orders.user_id,
-- but the base orders/profiles definitions and live RLS policies are unavailable.
-- Confirm profiles.id is UUID and orders.status supports the existing statuses.
-- This migration is a proposal and must not be applied until reviewed.

BEGIN;

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS assigned_delivery_partner_id uuid;

DO $block$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'orders_assigned_delivery_partner_id_fkey'
      AND conrelid = 'public.orders'::regclass
  ) THEN
    ALTER TABLE public.orders
      ADD CONSTRAINT orders_assigned_delivery_partner_id_fkey
      FOREIGN KEY (assigned_delivery_partner_id)
      REFERENCES public.profiles(id)
      ON DELETE SET NULL;
  END IF;
END;
$block$;

CREATE INDEX IF NOT EXISTS orders_assigned_delivery_partner_status_idx
  ON public.orders (assigned_delivery_partner_id, status, created_at DESC)
  WHERE assigned_delivery_partner_id IS NOT NULL;

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
    IF v_is_admin THEN
      NULL;
    ELSIF v_is_delivery_partner
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

DROP TRIGGER IF EXISTS guard_delivery_order_fields
  ON public.orders;
CREATE TRIGGER guard_delivery_order_fields
  BEFORE UPDATE OF assigned_delivery_partner_id, status
  ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_delivery_order_fields();

DROP FUNCTION IF EXISTS public.admin_list_delivery_orders();
CREATE FUNCTION public.admin_list_delivery_orders()
RETURNS TABLE (
  order_id bigint,
  created_at timestamptz,
  total_amount numeric,
  status text,
  assigned_delivery_partner_id uuid,
  assigned_partner_name text,
  item_count bigint
)
LANGUAGE plpgsql
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

  RETURN QUERY
  SELECT o.id, o.created_at, o.total_amount, o.status::text,
         o.assigned_delivery_partner_id, p.full_name::text,
         COALESCE(SUM(oi.quantity), 0)::bigint
  FROM public.orders o
  LEFT JOIN public.profiles p
    ON p.id = o.assigned_delivery_partner_id
  LEFT JOIN public.order_items oi
    ON oi.order_id = o.id
  GROUP BY o.id, p.full_name
  ORDER BY o.created_at DESC;
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_list_delivery_partners()
RETURNS TABLE (partner_id uuid, full_name text)
LANGUAGE plpgsql
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

  RETURN QUERY
  SELECT p.id, p.full_name::text
  FROM public.profiles p
  WHERE lower(btrim(p.role::text)) = 'delivery_partner'
  ORDER BY p.full_name NULLS LAST, p.id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_assign_delivery_partner(
  p_order_id bigint,
  p_delivery_partner_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_status text;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND lower(btrim(p.role::text)) = 'admin'
  ) THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  IF p_delivery_partner_id IS NOT NULL AND NOT EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = p_delivery_partner_id
      AND lower(btrim(p.role::text)) = 'delivery_partner'
  ) THEN
    RAISE EXCEPTION 'The selected account is not a delivery partner';
  END IF;

  SELECT o.status::text
  INTO v_status
  FROM public.orders o
  WHERE o.id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found';
  END IF;
  IF v_status IN ('delivered', 'cancelled') THEN
    RAISE EXCEPTION 'Completed or cancelled orders cannot be reassigned';
  END IF;

  UPDATE public.orders
  SET assigned_delivery_partner_id = p_delivery_partner_id
  WHERE id = p_order_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.delivery_partner_list_my_orders()
RETURNS TABLE (
  order_id bigint,
  created_at timestamptz,
  total_amount numeric,
  status text,
  assigned_delivery_partner_id uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND lower(btrim(p.role::text)) = 'delivery_partner'
  ) THEN
    RAISE EXCEPTION 'Delivery partner access required';
  END IF;

  RETURN QUERY
  SELECT o.id, o.created_at, o.total_amount, o.status::text,
         o.assigned_delivery_partner_id
  FROM public.orders o
  WHERE o.assigned_delivery_partner_id = auth.uid()
  ORDER BY o.created_at DESC;
END;
$function$;

CREATE OR REPLACE FUNCTION public.delivery_partner_update_order_status(
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
      AND lower(btrim(p.role::text)) = 'delivery_partner'
  ) THEN
    RAISE EXCEPTION 'Delivery partner access required';
  END IF;

  SELECT o.status::text
  INTO v_current_status
  FROM public.orders o
  WHERE o.id = p_order_id
    AND o.assigned_delivery_partner_id = auth.uid()
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order is not assigned to this delivery partner';
  END IF;

  IF NOT (
    (v_current_status = 'preparing' AND p_new_status = 'out_for_delivery')
    OR (v_current_status = 'out_for_delivery' AND p_new_status = 'delivered')
  ) THEN
    RAISE EXCEPTION 'Invalid delivery status transition';
  END IF;

  UPDATE public.orders
  SET status = p_new_status
  WHERE id = p_order_id
    AND assigned_delivery_partner_id = auth.uid();
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_list_delivery_orders() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_list_delivery_partners() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_assign_delivery_partner(bigint, uuid)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.delivery_partner_list_my_orders()
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.delivery_partner_update_order_status(bigint, text)
  FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.admin_list_delivery_orders() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_delivery_partners() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_assign_delivery_partner(bigint, uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.delivery_partner_list_my_orders()
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.delivery_partner_update_order_status(bigint, text)
  TO authenticated;

COMMIT;
