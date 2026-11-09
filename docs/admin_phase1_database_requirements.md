# People Cart Admin Phase 1 database requirements

This note records the database access the Phase 1 dashboard needs. It does not
assert that these policies are present or deployed.

## Dashboard reads

The app reads the authenticated user's `profiles` row (`id`, `full_name`,
`role`) to choose a role-specific experience. The operations overview reads:

- `orders.id` for exact total and per-status counts.
- `orders.created_at` for local-calendar-day counts, a seven-day trend, and
  recent-order ordering.
- `orders.total_amount` and `orders.status` for recent-order summaries and
  today's non-cancelled order value.

The overview does not read customer identities, order items, or payment data.
Inventory loads products from the existing product-management service. The
overview does not query products a second time.

The `Order value today` KPI sums the `total_amount` of orders created today,
excluding rows whose status is `cancelled`. It is an order-value proxy, not
confirmed paid revenue, because the checked-in schema does not establish a
payment-confirmation field. `Needs attention` counts orders whose current
status is `placed`, shown as awaiting preparation. The seven-day trend counts
all orders by their `created_at` local calendar date, including cancelled
orders, and includes zero-count dates.

## Required authorization

- Authenticated users must be able to select their own profile row so the app
  can resolve the role from `profiles`, not from a client-editable setting.
- Authenticated admins need read-only access to the order rows required above.
  Existing customer order-read policies must remain customer-scoped.
- Authenticated admins need the existing read access required by the Inventory
  screen; inventory status counts are derived from that same loaded product
  list.
- Policies must determine admin access from the authenticated identity joined
  to `profiles.role = 'admin'`. They must not accept a role or user ID supplied
  by the client.
- Customers must not be able to update their own `profiles.role` to obtain
  admin access. Role changes must be restricted to a trusted administrative
  process.
- No dashboard operation writes to the database. Do not grant order or stock
  update privileges for this phase.

The migration `supabase/migrations/20261102_admin_dashboard_read_policies.sql`
adds a `SECURITY DEFINER` role-check helper and additive admin-only `SELECT`
policies for `orders` and `products`. It grants no write access and does not
modify existing customer or household policies. Apply it only after confirming
the live column names and policies; it has not been applied to the live
project.

## Repository evidence and unverified items

The checked-in migrations create policies for quick-order modes and household
membership and define the secure checkout RPC. They do not create the base
`profiles`, `orders`, `order_items`, or `products` tables or define their
admin-read policies. They do not establish the `profiles.role` constraint or
the profile creation trigger. The known order statuses used by the dashboard
are `placed`, `preparing`, `out_for_delivery`, `delivered`, and `cancelled`.

The screenshots show three rows in the Supabase `orders` table and one RLS
policy on that table, while the admin app sees no recent orders. This is
consistent with an existing customer-only SELECT policy filtering out the
admin's rows. The live policy definition, deployed schema, `profiles.role`
constraint, and profile policies have not been verified. Apply the migration
through Supabase SQL Editor (or the approved migration workflow) and then sign
out and back in / refresh the dashboard to verify access. The project includes
a client-side publishable key, but no privileged database credential that
would allow safe remote schema inspection or migration from this workspace.

## Product inventory writes

The proposed migration
`supabase/migrations/20261102_admin_product_write_policies.sql` depends on the
admin identity helper above. It adds admin insert/update policies and
restrictive admin-role policies so existing permissive policies cannot allow
customer API writes. It also adds database constraints for positive prices and
non-negative stock. It does not add a product trigger, preserving the existing
`create_order_secure` SECURITY DEFINER checkout stock updates.

The product form accepts a publicly reachable `http`/`https` image URL in the
existing `products.image_url` column. No Supabase Storage bucket, Storage RLS
policy, or image-picker integration exists in the checked-in project, so this
phase does not upload local images. To support uploads later, create a private
or public product-images bucket with admin-only upload/update/delete policies
and customer/admin read access as appropriate, then use an image picker and
store the resulting object URL or path in `image_url`.

Before applying these migrations, confirm `products` has the expected columns
(`id`, `name`, `description`, `price`, `image_url`, `category_id`,
`stock_quantity`, `is_available`), confirm the category table and foreign-key
type, inspect all existing product policies and triggers, check existing rows
for invalid price/stock values, and ensure RLS is enabled and the existing
dashboard migration's helper is installed. No live schema or policy changes
have been applied from this workspace.

## Dynamic category management

The app's category model currently uses `id`, `name`, optional `image_url`,
and optional `created_at`; the checked-in migrations do not create the base
`categories` table or define its RLS policies. The live schema and policies
could not be reached or verified from this workspace.

The proposed migration
`supabase/migrations/20261102_admin_z_category_management.sql` adds
`categories.is_active` (existing rows default to active), enforces unique
category names using `lower(btrim(name))`, and rejects blank names. Its
preflight aborts on existing normalized duplicates, blank names, or unexpected
restrictive category policies. It adds admin-only insert/update policies,
active-category customer reads, admin reads of inactive categories, and a
restrictive visibility policy that prevents permissive read policies from
exposing inactive categories. Category records are deactivated, never deleted.

Apply the dashboard helper migration before the category migration. Before
manual application, inspect live category columns, grants, all permissive and
restrictive policies, existing duplicates/blank names, and whether the app
needs anonymous catalog access. The migration is a proposal only and has not
been applied. The app expects the added `is_active` column for category reads;
until the migration is applied, customer and admin category requests may fail
with a missing-column error. Do not remove or bypass RLS to work around that
failure.

Customer category browsing now requests active category rows and filters
products using the selected category's database ID. Product creation offers
only active categories; editing a product preserves its existing inactive
category assignment until an admin changes it.

## Customer behavior insights

The proposed migration
`supabase/migrations/20261102_customer_behavior_insights.sql` creates
`customer_events` because no existing event table or tracking implementation
was found in checked-in sources. It stores only the authenticated user ID,
event type, optional product ID, normalized search text and result count,
optional order ID for completed checkouts, and a server timestamp. It does not
store email, passwords, payment details, or search history outside the event
table.

Customers can read only their own rows and insert only product-view,
add-to-cart, and search events with their own `auth.uid()`. They cannot insert
`checkout_completed`. The `record_checkout_completed_event` security-definer
function verifies that the supplied order ID belongs to `auth.uid()` in
`public.orders`, then records an idempotent event. The client calls it only
after `create_order_secure` returns success; that checkout RPC is not modified.
A trigger derives the event owner and timestamp server-side, rather than
trusting client-supplied values.
Admins can read events only when the existing admin role helper confirms their
profile. The admin screen aggregates events for a selectable 7/30/90-day
window. Funnel values are event counts, not unique-customer conversion rates.
The insights screen ranks products using view and add-event counts and queries
current product image URLs. Search opportunities contain normalized terms with
zero results only; no customer identity or per-customer search history is shown.

Before applying the migration, verify the live `orders.id` and `orders.user_id`
columns, the installed `current_user_is_admin()` helper, and existing grants
and RLS policies. The migration is a proposal only; no live schema or RLS
configuration has been inspected or changed from this workspace. Analytics
remain empty or show a useful query error until the migration is applied and
new genuine activity is recorded.

## Delivery partner assignment

The checked-in migrations show `orders.id` as `BIGINT`, `orders.user_id`, and
the existing order status values, but do not define the base `orders` or
`profiles` schema. No delivery assignment column or delivery-partner database
policy was found. The proposed
`supabase/migrations/20261102_delivery_partner_assignment.sql` adds the nullable
`orders.assigned_delivery_partner_id` reference to `profiles.id` and exposes
role-checked RPCs for admin order/partner lists, assignment, a partner's assigned
orders, and partner status transitions. It does not expose direct client
updates to assignment or order status and does not alter checkout.

The admin RPCs verify `profiles.role = admin`; partner RPCs verify the caller's
`delivery_partner` role and, for updates, that the order is assigned to that
authenticated user. Partner status changes are limited to
`preparing -> out_for_delivery -> delivered`; cancellation and reassignment of
delivered/cancelled orders are disallowed. A database trigger also guards
changes to assignment and status columns against pre-existing broad direct
update policies. Returned order data is limited to order ID, timestamp, total,
status, partner ID/name, and summed order-item quantities. No delivery address
column was established in checked-in migrations, so address details are not
displayed. The admin screen counts unassigned, assigned, and out-for-delivery
orders only among non-cancelled, non-delivered orders. No customer details or
GPS information are returned.

Before applying the migration, verify live `profiles.id` is UUID,
`profiles.full_name` and `profiles.role` exist, `orders.id` is BIGINT, order
timestamps and totals match the declared return types, and the `status` column
accepts the existing text values. Inspect existing RLS policies and function
ownership/grants as well. The migration is a proposal only; live Supabase
schema and permissions have not been verified or changed. The delivery screens
will show a useful RPC error until the reviewed migration is applied.
