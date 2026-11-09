-- Restricts catalog creation and editing to authenticated admins.
-- Depends on current_user_is_admin() from
-- 20261102_admin_dashboard_read_policies.sql.

DROP POLICY IF EXISTS "Admins can insert products" ON public.products;
CREATE POLICY "Admins can insert products"
  ON public.products
  FOR INSERT
  TO authenticated
  WITH CHECK ((SELECT public.current_user_is_admin()));

DROP POLICY IF EXISTS "Admin role required for product inserts" ON public.products;
CREATE POLICY "Admin role required for product inserts"
  ON public.products
  AS RESTRICTIVE
  FOR INSERT
  TO authenticated
  WITH CHECK ((SELECT public.current_user_is_admin()));

DROP POLICY IF EXISTS "Admins can update products" ON public.products;
CREATE POLICY "Admins can update products"
  ON public.products
  FOR UPDATE
  TO authenticated
  USING ((SELECT public.current_user_is_admin()))
  WITH CHECK ((SELECT public.current_user_is_admin()));

DROP POLICY IF EXISTS "Admin role required for product updates" ON public.products;
CREATE POLICY "Admin role required for product updates"
  ON public.products
  AS RESTRICTIVE
  FOR UPDATE
  TO authenticated
  USING ((SELECT public.current_user_is_admin()))
  WITH CHECK ((SELECT public.current_user_is_admin()));

DO $migration$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.products'::regclass
      AND conname = 'products_price_positive'
  ) THEN
    ALTER TABLE public.products
      ADD CONSTRAINT products_price_positive CHECK (price > 0) NOT VALID;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.products'::regclass
      AND conname = 'products_stock_nonnegative'
  ) THEN
    ALTER TABLE public.products
      ADD CONSTRAINT products_stock_nonnegative
      CHECK (stock_quantity >= 0) NOT VALID;
  END IF;
END;
$migration$;

ALTER TABLE public.products
  VALIDATE CONSTRAINT products_price_positive;
ALTER TABLE public.products
  VALIDATE CONSTRAINT products_stock_nonnegative;
