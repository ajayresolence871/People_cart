-- Grants authenticated admins read-only access to the order and product data
-- used by the Phase 1 dashboard. Customer policies are left unchanged.

CREATE OR REPLACE FUNCTION public.current_user_is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE id = (SELECT auth.uid())
      AND lower(btrim(role::text)) = 'admin'
  );
$function$;

REVOKE ALL ON FUNCTION public.current_user_is_admin() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.current_user_is_admin() FROM anon;
GRANT EXECUTE ON FUNCTION public.current_user_is_admin() TO authenticated;

DROP POLICY IF EXISTS "Admins can read all orders" ON public.orders;
CREATE POLICY "Admins can read all orders"
  ON public.orders
  FOR SELECT
  TO authenticated
  USING ((SELECT public.current_user_is_admin()));

DROP POLICY IF EXISTS "Admins can read all products" ON public.products;
CREATE POLICY "Admins can read all products"
  ON public.products
  FOR SELECT
  TO authenticated
  USING ((SELECT public.current_user_is_admin()));
