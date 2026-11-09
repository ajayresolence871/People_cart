-- REVIEW-ONLY PROPOSAL. Inspect the live household_members/profiles schema and
-- RLS policies before applying. This does not disable RLS or return private
-- profile fields such as email, phone, or auth metadata.
--
-- Returns only profile IDs and full names for members of a household that the
-- authenticated caller belongs to. The text casts avoid assuming the database
-- type used for household_members.household_id/user_id.

BEGIN;

CREATE OR REPLACE FUNCTION public.is_household_member(p_household_id text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.household_members hm
    WHERE hm.household_id::text = p_household_id
      AND hm.user_id::text = auth.uid()::text
  );
$function$;

REVOKE ALL ON FUNCTION public.is_household_member(text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_household_member(text)
  TO authenticated;

DROP POLICY IF EXISTS "Household members can read their household membership"
  ON public.household_members;
CREATE POLICY "Household members can read their household membership"
  ON public.household_members
  FOR SELECT
  TO authenticated
  USING (public.is_household_member(household_id::text));

CREATE OR REPLACE FUNCTION public.household_member_names(p_household_id text)
RETURNS TABLE (user_id text, full_name text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.household_members hm
    WHERE hm.household_id::text = p_household_id
      AND hm.user_id::text = auth.uid()::text
  ) THEN
    RAISE EXCEPTION 'Household membership required';
  END IF;

  RETURN QUERY
  SELECT p.id::text, p.full_name::text
  FROM public.household_members hm
  JOIN public.profiles p
    ON p.id::text = hm.user_id::text
  WHERE hm.household_id::text = p_household_id
    AND nullif(btrim(p.full_name::text), '') IS NOT NULL
  ORDER BY p.full_name::text;
END;
$function$;

REVOKE ALL ON FUNCTION public.household_member_names(text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.household_member_names(text)
  TO authenticated;

COMMIT;
