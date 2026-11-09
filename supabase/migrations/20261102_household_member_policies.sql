-- Migration: 20261102_household_member_policies.sql
-- Enables authenticated users to find households by join_code and join them safely.

-- 1. Ensure authenticated users can look up a household by its unique join_code
DROP POLICY IF EXISTS "Allow authenticated users to find households by join_code" ON public.households;
CREATE POLICY "Allow authenticated users to find households by join_code"
  ON public.households
  FOR SELECT
  TO authenticated
  USING (true);

-- 2. Allow authenticated users to insert themselves into household_members
DROP POLICY IF EXISTS "Allow authenticated users to join households" ON public.household_members;
CREATE POLICY "Allow authenticated users to join households"
  ON public.household_members
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);
