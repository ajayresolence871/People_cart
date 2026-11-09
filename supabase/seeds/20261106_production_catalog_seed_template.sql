-- Production catalog seed template only.
-- Includes example catalog rows and indicative INR pricing/stock; review these
-- business values before production use. This script never inserts orders,
-- assignments, profiles, or events.
-- Existing categories/products are left unchanged; reruns skip matching names.

BEGIN;

DO $preflight$
DECLARE
  missing_columns text;
  product_id_generated boolean;
  category_id_generated boolean;
  extra_required_columns text;
BEGIN
  SELECT string_agg(required.column_name, ', ')
  INTO missing_columns
  FROM (
    VALUES
      ('products', 'id'),
      ('products', 'name'),
      ('products', 'description'),
      ('products', 'price'),
      ('products', 'image_url'),
      ('products', 'category_id'),
      ('products', 'stock_quantity'),
      ('products', 'is_available'),
      ('categories', 'id'),
      ('categories', 'name')
  ) AS required(table_name, column_name)
  WHERE NOT EXISTS (
    SELECT 1
    FROM information_schema.columns c
    WHERE c.table_schema = 'public'
      AND c.table_name = required.table_name
      AND c.column_name = required.column_name
  );

  IF missing_columns IS NOT NULL THEN
    RAISE EXCEPTION 'Catalog seed stopped: missing columns: %', missing_columns;
  END IF;

  SELECT (c.column_default IS NOT NULL OR c.is_identity = 'YES')
  INTO product_id_generated
  FROM information_schema.columns c
  WHERE c.table_schema = 'public'
    AND c.table_name = 'products'
    AND c.column_name = 'id';

  SELECT (c.column_default IS NOT NULL OR c.is_identity = 'YES')
  INTO category_id_generated
  FROM information_schema.columns c
  WHERE c.table_schema = 'public'
    AND c.table_name = 'categories'
    AND c.column_name = 'id';

  IF NOT product_id_generated OR NOT category_id_generated THEN
    RAISE EXCEPTION
      'Catalog seed stopped: products.id and categories.id must have database-generated defaults.';
  END IF;

  SELECT string_agg(format('%I.%I', c.table_name, c.column_name), ', ')
  INTO extra_required_columns
  FROM information_schema.columns c
  WHERE c.table_schema = 'public'
    AND c.table_name IN ('products', 'categories')
    AND c.is_nullable = 'NO'
    AND c.column_default IS NULL
    AND c.is_identity <> 'YES'
    AND NOT (
      (c.table_name = 'products'
        AND c.column_name IN (
          'id', 'name', 'description', 'price', 'image_url',
          'category_id', 'stock_quantity', 'is_available'
        ))
      OR (c.table_name = 'categories'
        AND c.column_name IN ('id', 'name'))
    );

  IF extra_required_columns IS NOT NULL THEN
    RAISE EXCEPTION
      'Catalog seed stopped: required columns need values not handled by this template: %',
      extra_required_columns;
  END IF;
END;
$preflight$;

CREATE TEMP TABLE seed_categories (
  name text PRIMARY KEY
) ON COMMIT DROP;

INSERT INTO seed_categories (name) VALUES
  ('Fruits & Vegetables'),
  ('Dairy, Bread & Eggs'),
  ('Snacks & Munchies'),
  ('Cold Drinks & Juices'),
  ('Instant & Frozen Food'),
  ('Tea, Coffee & Health Drinks'),
  ('Bakery & Biscuits'),
  ('Atta, Rice & Dal'),
  ('Masala, Oil & More'),
  ('Sweet Tooth'),
  ('Personal Care'),
  ('Cleaning Essentials'),
  ('Home & Kitchen'),
  ('Baby Care'),
  ('Pet Care');

CREATE TEMP TABLE seed_products (
  name text,
  category_name text,
  description text,
  price numeric,
  stock_quantity integer,
  image_url text
) ON COMMIT DROP;

-- Prices are in INR; stock quantities are initial inventory counts.
-- Image URLs are NULL so the app can use its existing image fallback.
INSERT INTO seed_products
  (name, category_name, description, price, stock_quantity, image_url)
VALUES
  ('Banana (6 pcs)', 'Fruits & Vegetables', 'Fresh bananas, pack of 6', 45.00, 40, NULL),
  ('Potato (1 kg)', 'Fruits & Vegetables', 'Fresh potatoes, 1 kg', 40.00, 35, NULL),
  ('Tomato (1 kg)', 'Fruits & Vegetables', 'Fresh tomatoes, 1 kg', 50.00, 30, NULL),
  ('Full Cream Milk (500 ml)', 'Dairy, Bread & Eggs', 'Pasteurized full cream milk, 500 ml', 34.00, 50, NULL),
  ('Brown Bread (400 g)', 'Dairy, Bread & Eggs', 'Whole wheat brown bread, 400 g', 45.00, 20, NULL),
  ('Salted Potato Chips (52 g)', 'Snacks & Munchies', 'Classic salted potato chips, 52 g', 20.00, 60, NULL),
  ('Roasted Peanuts (200 g)', 'Snacks & Munchies', 'Roasted and salted peanuts, 200 g', 65.00, 25, NULL),
  ('Cola Soft Drink (750 ml)', 'Cold Drinks & Juices', 'Chilled cola soft drink, 750 ml', 40.00, 40, NULL),
  ('Orange Juice (1 L)', 'Cold Drinks & Juices', 'Orange fruit beverage, 1 L', 110.00, 18, NULL),
  ('Frozen Green Peas (500 g)', 'Instant & Frozen Food', 'Frozen green peas, 500 g', 75.00, 15, NULL),
  ('Assam Tea (250 g)', 'Tea, Coffee & Health Drinks', 'Assam black tea leaves, 250 g', 145.00, 22, NULL),
  ('Whole Wheat Bread (400 g)', 'Bakery & Biscuits', 'Soft whole wheat bread, 400 g', 40.00, 18, NULL),
  ('Wheat Flour (5 kg)', 'Atta, Rice & Dal', 'Whole wheat flour, 5 kg', 260.00, 20, NULL),
  ('Toor Dal (1 kg)', 'Atta, Rice & Dal', 'Unpolished toor dal, 1 kg', 180.00, 24, NULL),
  ('Sunflower Oil (1 L)', 'Masala, Oil & More', 'Refined sunflower cooking oil, 1 L', 155.00, 20, NULL),
  ('Milk Chocolate Bar (100 g)', 'Sweet Tooth', 'Milk chocolate bar, 100 g', 100.00, 30, NULL),
  ('Aloe Vera Bath Soap (3 x 100 g)', 'Personal Care', 'Aloe vera bathing soap, pack of 3', 120.00, 16, NULL),
  ('Dishwash Liquid (500 ml)', 'Cleaning Essentials', 'Lemon dishwashing liquid, 500 ml', 115.00, 18, NULL),
  ('Kitchen Storage Containers (3 pcs)', 'Home & Kitchen', 'Reusable food storage containers, set of 3', 199.00, 10, NULL),
  ('Baby Diapers (Pack of 10)', 'Baby Care', 'Disposable baby diapers, pack of 10', 249.00, 12, NULL);

DO $validate$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM seed_products
    WHERE name IS NULL
      OR btrim(name) = ''
      OR category_name IS NULL
      OR btrim(category_name) = ''
      OR price IS NULL
      OR price <= 0
      OR stock_quantity IS NULL
      OR stock_quantity < 0
  ) THEN
    RAISE EXCEPTION
      'Catalog seed stopped: every product needs a name, category, positive price, and non-negative stock quantity.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM seed_products sp
    JOIN information_schema.columns c
      ON c.table_schema = 'public'
     AND c.table_name = 'products'
     AND c.column_name IN ('description', 'image_url')
     AND c.is_nullable = 'NO'
    WHERE (c.column_name = 'description' AND sp.description IS NULL)
       OR (c.column_name = 'image_url' AND sp.image_url IS NULL)
  ) THEN
    RAISE EXCEPTION
      'Catalog seed stopped: this database requires a description or image URL for each product.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM seed_products
    GROUP BY lower(btrim(name))
    HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION
      'Catalog seed stopped: product names must be unique within the seed.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM seed_products sp
    WHERE NOT EXISTS (
      SELECT 1
      FROM seed_categories sc
      WHERE lower(btrim(sc.name)) = lower(btrim(sp.category_name))
    )
  ) THEN
    RAISE EXCEPTION
      'Catalog seed stopped: every product category must be listed in seed_categories.';
  END IF;
END;
$validate$;

INSERT INTO public.categories (name)
SELECT sc.name
FROM seed_categories sc
WHERE NOT EXISTS (
  SELECT 1
  FROM public.categories c
  WHERE lower(btrim(c.name)) = lower(btrim(sc.name))
);

DO $validate_category_map$
DECLARE
  has_active_flag boolean;
  has_inactive_category boolean := false;
BEGIN
  IF EXISTS (
    SELECT 1
    FROM seed_categories sc
    JOIN public.categories c
      ON lower(btrim(c.name)) = lower(btrim(sc.name))
    GROUP BY lower(btrim(sc.name))
    HAVING count(*) <> 1
  ) THEN
    RAISE EXCEPTION
      'Catalog seed stopped: a seed category maps to multiple existing category rows.';
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'categories'
      AND column_name = 'is_active'
  ) INTO has_active_flag;

  IF has_active_flag THEN
    EXECUTE $query$
      SELECT EXISTS (
        SELECT 1
        FROM seed_categories sc
        JOIN public.categories c
          ON lower(btrim(c.name)) = lower(btrim(sc.name))
        WHERE c.is_active IS FALSE
      )
    $query$ INTO has_inactive_category;
  END IF;

  IF has_inactive_category THEN
    RAISE EXCEPTION
      'Catalog seed stopped: a matching category is inactive. Activate it through the admin UI, then rerun.';
  END IF;
END;
$validate_category_map$;

INSERT INTO public.products
  (name, description, price, image_url, category_id, stock_quantity, is_available)
SELECT
  sp.name,
  sp.description,
  sp.price,
  sp.image_url,
  c.id,
  sp.stock_quantity,
  (sp.stock_quantity > 0)
FROM seed_products sp
JOIN public.categories c
  ON lower(btrim(c.name)) = lower(btrim(sp.category_name))
WHERE NOT EXISTS (
  SELECT 1
  FROM public.products existing
  WHERE lower(btrim(existing.name)) = lower(btrim(sp.name))
);

COMMIT;
