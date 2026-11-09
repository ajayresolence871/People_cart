-- REVIEW-ONLY PROPOSAL. Do not apply until the target database's deployed
-- function, trigger, grant, and schema definitions have been captured.
--
-- Lock assignment using the status read under FOR UPDATE, so a stale admin UI
-- cannot reassign after the assigned partner has picked up the order.
-- This preserves assignment/reassignment before pickup and preserves the
-- existing function signature and all existing role/partner checks.
-- Preflight: confirm public.admin_assign_delivery_partner(bigint, uuid) exists
-- and capture its deployed owner, security settings, search_path, and EXECUTE
-- grants. CREATE OR REPLACE preserves the ACL of an existing function; do not
-- run this proposal if the target function is absent or its grants differ from
-- the reviewed baseline.

BEGIN;

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
  IF v_status = 'out_for_delivery' THEN
    RAISE EXCEPTION 'Delivery partner assignment is locked after pickup';
  END IF;
  IF v_status IN ('delivered', 'cancelled') THEN
    RAISE EXCEPTION 'Completed or cancelled orders cannot be reassigned';
  END IF;

  UPDATE public.orders
  SET assigned_delivery_partner_id = p_delivery_partner_id
  WHERE id = p_order_id;
END;
$function$;

COMMIT;

-- ROLLBACK NOTES (manual): restore admin_assign_delivery_partner(bigint,
-- uuid) from the captured target-environment baseline. The old definition
-- allows reassignment while status is out_for_delivery; restoring it reopens
-- that behavior. No automatic rollback is included.
