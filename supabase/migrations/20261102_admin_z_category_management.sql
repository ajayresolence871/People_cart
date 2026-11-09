-- REVIEW BEFORE APPLYING:
-- This migration assumes the existing categories table has id and name columns
-- and depends on current_user_is_admin() from
-- 20261102_admin_dashboard_read_policies.sql.
-- Inspect live categories RLS, grants, existing restrictive policies, and
-- normalized duplicate/blank names before applying. This file is not applied
-- to the live Supabase project by the app or this development workflow.

BEGIN;

ALTER TABLE public.categories
  ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true;

UPDATE public.categories
SET is_active = true
WHERE is_active IS NULL;

ALTER TABLE public.categories
  ALTER COLUMN is_active SET DEFAULT true,
  ALTER COLUMN is_active SET NOT NULL;

DO $preflight$
DECLARE
  duplicate_names text;
  blank_names bigint;
  existing_permissive_policies text;
  existing_restrictive_policies text;
BEGIN
  SELECT string_agg(name_group, ', ')
  INTO duplicate_names
  FROM (
    SELECT lower(btrim(name)) AS name_group
    FROM public.categories
    GROUP BY lower(btrim(name))
    HAVING count(*) > 1
  ) duplicates;

  IF duplicate_names IS NOT NULL THEN
    RAISE EXCEPTION
      'Cannot add normalized category-name uniqueness; resolve duplicate names first: %',
      duplicate_names;
  END IF;

  SELECT count(*)
  INTO blank_names
  FROM public.categories
  WHERE name IS NULL OR btrim(name) = '';

  IF blank_names > 0 THEN
    RAISE EXCEPTION
      'Cannot require non-empty category names; resolve % blank category names first.',
      blank_names;
  END IF;

  SELECT string_agg(policyname, ', ')
  INTO existing_permissive_policies
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename = 'categories'
    AND permissive = 'PERMISSIVE';

  IF existing_permissive_policies IS NOT NULL THEN
    RAISE NOTICE
      'Existing permissive categories policies will be constrained by the new restrictive policies; review them: %',
      existing_permissive_policies;
  END IF;

  SELECT string_agg(policyname, ', ')
  INTO existing_restrictive_policies
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename = 'categories'
    AND permissive = 'RESTRICTIVE'
    AND policyname NOT IN (
      'Category visibility is limited to active categories or admins',
      'Category inserts require admin role',
      'Category updates require admin role'
    );

  IF existing_restrictive_policies IS NOT NULL THEN
    RAISE EXCEPTION
      'Review existing restrictive categories policies before applying this migration: %',
      existing_restrictive_policies;
  END IF;
END;
$preflight$;

CREATE UNIQUE INDEX IF NOT EXISTS categories_name_normalized_unique
  ON public.categories (lower(btrim(name)));

DO $constraint$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.categories'::regclass
      AND conname = 'categories_name_nonempty'
  ) THEN
    ALTER TABLE public.categories
      ADD CONSTRAINT categories_name_nonempty
      CHECK (name IS NOT NULL AND btrim(name) <> '') NOT VALID;
  END IF;
END;
$constraint$;

ALTER TABLE public.categories
  VALIDATE CONSTRAINT categories_name_nonempty;

ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

GRANT SELECT ON public.categories TO anon, authenticated;
GRANT INSERT, UPDATE ON public.categories TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_is_admin()
  TO anon, authenticated;

DROP POLICY IF EXISTS "Active categories are readable" ON public.categories;
CREATE POLICY "Active categories are readable"
  ON public.categories
  FOR SELECT
  TO anon, authenticated
  USING (is_active);

DROP POLICY IF EXISTS "Admins can read all categories" ON public.categories;
CREATE POLICY "Admins can read all categories"
  ON public.categories
  FOR SELECT
  TO authenticated
  USING ((SELECT public.current_user_is_admin()));

DROP POLICY IF EXISTS
  "Category visibility is limited to active categories or admins"
  ON public.categories;
CREATE POLICY
  "Category visibility is limited to active categories or admins"
  ON public.categories
  AS RESTRICTIVE
  FOR SELECT
  TO public
  USING (
    is_active OR (SELECT public.current_user_is_admin())
  );

DROP POLICY IF EXISTS "Admins can insert categories" ON public.categories;
CREATE POLICY "Admins can insert categories"
  ON public.categories
  FOR INSERT
  TO authenticated
  WITH CHECK ((SELECT public.current_user_is_admin()));

DROP POLICY IF EXISTS "Category inserts require admin role" ON public.categories;
CREATE POLICY "Category inserts require admin role"
  ON public.categories
  AS RESTRICTIVE
  FOR INSERT
  TO authenticated
  WITH CHECK ((SELECT public.current_user_is_admin()));

DROP POLICY IF EXISTS "Admins can update categories" ON public.categories;
CREATE POLICY "Admins can update categories"
  ON public.categories
  FOR UPDATE
  TO authenticated
  USING ((SELECT public.current_user_is_admin()))
  WITH CHECK ((SELECT public.current_user_is_admin()));

DROP POLICY IF EXISTS "Category updates require admin role" ON public.categories;
CREATE POLICY "Category updates require admin role"
  ON public.categories
  AS RESTRICTIVE
  FOR UPDATE
  TO authenticated
  USING ((SELECT public.current_user_is_admin()))
  WITH CHECK ((SELECT public.current_user_is_admin()));

COMMIT;
