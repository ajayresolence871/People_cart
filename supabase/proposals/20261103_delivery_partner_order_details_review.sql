-- REVIEW-ONLY PROPOSAL. Do not apply until the live schema, function owner,
-- grants, deployed RPC definition, and existing RLS policies are verified.
--
-- Replaces the assigned-partner listing RPC with an assignment-scoped response
-- that includes saved order-item snapshots and, when present, the immutable
-- delivery address snapshot. It deliberately excludes customer profile/contact
-- data, payment data, and delivery instructions.
--
-- delivery_address_snapshot is read through to_jsonb(o) so this function can
-- still be installed if the address proposal has not been deployed; it returns
-- SQL NULL for orders/schema without that field. Existing orders without a
-- saved snapshot cannot be given a truthful delivery address retroactively.

BEGIN;

DROP FUNCTION IF EXISTS public.delivery_partner_list_my_orders();

CREATE FUNCTION public.delivery_partner_list_my_orders()
RETURNS TABLE (
  order_id bigint,
  created_at timestamptz,
  total_amount numeric,
  status text,
  assigned_delivery_partner_id uuid,
  item_count bigint,
  items jsonb,
  delivery_address_snapshot jsonb
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
  SELECT
    o.id,
    o.created_at,
    o.total_amount,
    o.status::text,
    o.assigned_delivery_partner_id,
    COALESCE((
      SELECT sum(oi.quantity)::bigint
      FROM public.order_items oi
      WHERE oi.order_id = o.id
    ), 0::bigint),
    COALESCE((
      SELECT jsonb_agg(
        jsonb_build_object(
          'product_id', oi.product_id,
          'product_name', oi.product_name,
          'quantity', oi.quantity,
          'unit_price', oi.unit_price
        )
        ORDER BY oi.id
      )
      FROM public.order_items oi
      WHERE oi.order_id = o.id
    ), '[]'::jsonb),
    to_jsonb(o)->'delivery_address_snapshot'
  FROM public.orders o
  WHERE o.assigned_delivery_partner_id = auth.uid()
  ORDER BY o.created_at DESC NULLS LAST, o.id DESC;
END;
$function$;

REVOKE ALL ON FUNCTION public.delivery_partner_list_my_orders()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delivery_partner_list_my_orders()
  TO authenticated;

COMMIT;
