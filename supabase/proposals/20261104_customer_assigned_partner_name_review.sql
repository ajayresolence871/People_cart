-- REVIEW-ONLY PROPOSAL. Do not apply until this definition, target schema,
-- function owner, and grants have been reviewed for the target project.
--
-- The deployed profiles SELECT policy shown during review lets users read only
-- their own profile. This function lets an authenticated customer read only
-- the assigned partner's display name for an order owned by that customer.
-- It does not grant general profiles access or expose phone/private fields.
-- The checked-in schema evidence confirms profiles.id, profiles.full_name,
-- orders.id, orders.user_id, and orders.assigned_delivery_partner_id.

BEGIN;

CREATE OR REPLACE FUNCTION public.customer_get_assigned_delivery_partner(
  p_order_id bigint
)
RETURNS TABLE (partner_name text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  RETURN QUERY
  SELECT p.full_name::text
  FROM public.orders o
  JOIN public.profiles p
    ON p.id = o.assigned_delivery_partner_id
  WHERE o.id = p_order_id
    AND o.user_id = auth.uid()
    AND o.assigned_delivery_partner_id IS NOT NULL;
END;
$function$;

REVOKE ALL ON FUNCTION public.customer_get_assigned_delivery_partner(bigint)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.customer_get_assigned_delivery_partner(bigint)
  TO authenticated;

COMMIT;

-- ROLLBACK NOTES (manual): if preflight confirms this function did not exist,
-- revoke its grants and DROP FUNCTION public.customer_get_assigned_delivery_partner(bigint).
-- If it did exist, restore its captured definition and ACL instead. No
-- automatic rollback is included.
