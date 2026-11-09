-- REVIEW BEFORE APPLYING:
-- This migration creates customer-owned wishlist rows. Verify that no
-- wishlist table already exists and review deployed grants/RLS first.
-- product_id is created with the exact type of public.products.id.
-- This file is a proposal only; it is not applied by the Flutter app.

BEGIN;

DO $migration$
DECLARE
  product_id_type text;
BEGIN
  IF to_regclass('public.customer_wishlist') IS NOT NULL THEN
    RAISE EXCEPTION
      'public.customer_wishlist already exists; inspect its schema and policies before applying this migration';
  END IF;

  IF to_regclass('public.products') IS NULL THEN
    RAISE EXCEPTION
      'public.products does not exist; verify the live catalog schema';
  END IF;

  SELECT format_type(attribute.atttypid, attribute.atttypmod)
  INTO product_id_type
  FROM pg_attribute AS attribute
  WHERE attribute.attrelid = 'public.products'::regclass
    AND attribute.attname = 'id'
    AND NOT attribute.attisdropped;

  IF product_id_type IS NULL THEN
    RAISE EXCEPTION
      'Could not determine public.products.id type; verify the live products schema';
  END IF;

  EXECUTE format(
    'CREATE TABLE public.customer_wishlist (
      user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
      product_id %s NOT NULL REFERENCES public.products (id) ON DELETE CASCADE,
      created_at timestamptz NOT NULL DEFAULT now(),
      CONSTRAINT customer_wishlist_user_product_key UNIQUE (user_id, product_id)
    )',
    product_id_type
  );
END;
$migration$;

ALTER TABLE public.customer_wishlist ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.customer_wishlist FROM PUBLIC, anon;
GRANT SELECT, INSERT, DELETE ON TABLE public.customer_wishlist TO authenticated;

CREATE POLICY "Customers can read their own wishlist"
  ON public.customer_wishlist
  FOR SELECT
  TO authenticated
  USING (user_id = (SELECT auth.uid()));

CREATE POLICY "Customers can add to their own wishlist"
  ON public.customer_wishlist
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY "Customers can remove from their own wishlist"
  ON public.customer_wishlist
  FOR DELETE
  TO authenticated
  USING (user_id = (SELECT auth.uid()));

COMMIT;
