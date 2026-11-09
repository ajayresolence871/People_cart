-- ==============================================================================
-- Migration: 20261030_fix_checkout_authorization.sql
-- Description: Hardens create_order_secure to enforce mandatory authenticated checkout:
--              1. Rejects unauthenticated callers immediately (auth.uid() IS NULL).
--              2. Removes any concept or code supporting guest checkout.
--              3. Strictly assigns v_user_id := auth.uid().
--              4. Revokes execution from PUBLIC and anon; grants exclusively to authenticated.
--              5. Drops old overloaded signatures (including insecure p_user_id variants).
--              6. Pins function search_path to empty string (search_path = '') for maximum security.
--              7. Aggregates duplicate product IDs in p_items before validation.
--              8. Sorts row locks (ORDER BY product_id ASC) to eliminate deadlocks.
--              9. Enforces strict input validation and numeric bounds:
--                 - Array max 100 items
--                 - product_id between 1 and 2147483647
--                 - Item quantity between 1 and 999
--                 - Aggregated quantity between 1 and 9999 (BIGINT safe against overflow)
--              10. Validates payment method parameter.
--              11. Checks orders.user_id data integrity before enforcing NOT NULL.
-- ==============================================================================

-- 1. Inspect existing orders and enforce NOT NULL on user_id safely
DO $$
BEGIN
    -- Check if legacy orders exist with a NULL user_id
    IF EXISTS (SELECT 1 FROM public.orders WHERE user_id IS NULL) THEN
        RAISE NOTICE 'Notice: public.orders contains existing rows with user_id IS NULL. These should be archived or assigned before adding a NOT NULL constraint.';
    ELSE
        -- If no NULL rows exist, enforce NOT NULL constraint at table level
        ALTER TABLE public.orders ALTER COLUMN user_id SET NOT NULL;
    END IF;
END $$;

-- 2. Drop all previous overloaded function signatures
DROP FUNCTION IF EXISTS public.create_order_secure(jsonb, text, uuid);
DROP FUNCTION IF EXISTS public.create_order_secure(jsonb, text);
DROP FUNCTION IF EXISTS public.create_order_secure(jsonb);

-- 3. Create hardened secure checkout function requiring authentication
CREATE OR REPLACE FUNCTION public.create_order_secure(
    p_items JSONB,
    p_payment_method TEXT DEFAULT 'cash_on_delivery'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id UUID;
    v_elem JSONB;
    v_raw_pid TEXT;
    v_raw_qty TEXT;
    v_prod_name TEXT;
    v_prod_price NUMERIC;
    v_prod_stock INT;
    v_prod_avail BOOLEAN;
    v_authoritative_total NUMERIC := 0.00;
    v_order_id BIGINT;
    v_delivery_fee NUMERIC := 0.00;
    v_agg_item RECORD;
BEGIN
    -- 1. MANDATORY AUTHENTICATION CHECK:
    -- Guest checkout is strictly forbidden. The caller must be authenticated with a verified Supabase JWT.
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required: You must be signed in to place an order.'
            USING ERRCODE = 'P0001';
    END IF;

    -- 2. Payment method parameter validation
    -- Note: public.orders currently records status = 'placed'. Real payment gateway
    -- processing (Razorpay, Stripe, UPI) is not yet integrated.
    IF p_payment_method IS NULL OR p_payment_method NOT IN ('cash_on_delivery', 'online_simulated') THEN
        RAISE EXCEPTION 'Invalid or missing payment method: "%". Supported methods: cash_on_delivery, online_simulated', p_payment_method;
    END IF;

    -- 3. Payload structure & length validation
    IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'Order cannot be empty and items must be a valid JSON array';
    END IF;

    IF jsonb_array_length(p_items) > 100 THEN
        RAISE EXCEPTION 'Order exceeds maximum allowed item count (100 items per order)';
    END IF;

    -- 4. Individual element format & numeric range validation
    FOR v_elem IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        IF jsonb_typeof(v_elem) <> 'object' THEN
            RAISE EXCEPTION 'Invalid item format: each item in p_items must be a JSON object';
        END IF;

        v_raw_pid := v_elem->>'product_id';
        v_raw_qty := v_elem->>'quantity';

        -- Validate product_id is a positive integer within 32-bit INT range
        IF v_raw_pid IS NULL OR v_raw_pid !~ '^\d+$' OR v_raw_pid::BIGINT <= 0 OR v_raw_pid::BIGINT > 2147483647 THEN
            RAISE EXCEPTION 'Invalid product_id: "%". Product ID must be a positive integer between 1 and 2147483647', v_raw_pid;
        END IF;

        -- Validate individual item quantity is a reasonable positive integer
        IF v_raw_qty IS NULL OR v_raw_qty !~ '^\d+$' OR v_raw_qty::BIGINT <= 0 OR v_raw_qty::BIGINT > 999 THEN
            RAISE EXCEPTION 'Invalid quantity: "%" for product ID %. Quantity per item must be between 1 and 999', v_raw_qty, v_raw_pid;
        END IF;
    END LOOP;

    -- 5. Pass 1: Aggregate duplicate product IDs & lock rows in deterministic order
    -- Sorting by product_id ASC guarantees concurrent checkout transactions acquire locks in identical order, eliminating deadlocks
    FOR v_agg_item IN
        SELECT 
            (elem->>'product_id')::INT AS product_id,
            SUM((elem->>'quantity')::BIGINT)::BIGINT AS aggregated_qty
        FROM jsonb_array_elements(p_items) AS elem
        GROUP BY (elem->>'product_id')::INT
        ORDER BY (elem->>'product_id')::INT ASC
    LOOP
        -- Enforce aggregated quantity upper limit per product
        IF v_agg_item.aggregated_qty <= 0 OR v_agg_item.aggregated_qty > 9999 THEN
            RAISE EXCEPTION 'Combined quantity % for product ID % exceeds maximum allowed per order (9999)',
                v_agg_item.aggregated_qty, v_agg_item.product_id;
        END IF;

        -- Lock product row for update so no concurrent transaction can alter stock
        SELECT name, price, stock_quantity, is_available
        INTO v_prod_name, v_prod_price, v_prod_stock, v_prod_avail
        FROM public.products
        WHERE id = v_agg_item.product_id
        FOR UPDATE;

        IF v_prod_name IS NULL THEN
            RAISE EXCEPTION 'Product with ID % does not exist', v_agg_item.product_id;
        END IF;

        IF NOT v_prod_avail THEN
            RAISE EXCEPTION 'Product "%" is currently unavailable', v_prod_name;
        END IF;

        IF v_prod_stock < v_agg_item.aggregated_qty THEN
            RAISE EXCEPTION 'Insufficient stock for "%". Requested: %, Available: %',
                v_prod_name, v_agg_item.aggregated_qty, v_prod_stock;
        END IF;

        -- Authoritative price calculation directly from database table
        v_authoritative_total := v_authoritative_total + (v_prod_price * v_agg_item.aggregated_qty);
    END LOOP;

    -- Free delivery threshold check (₹49 threshold)
    IF v_authoritative_total < 49.00 THEN
        v_delivery_fee := 30.00;
    ELSE
        v_delivery_fee := 0.00;
    END IF;

    -- 6. Pass 2: Deduct Stock Atomically for aggregated quantities
    FOR v_agg_item IN
        SELECT 
            (elem->>'product_id')::INT AS product_id,
            SUM((elem->>'quantity')::BIGINT)::INT AS aggregated_qty
        FROM jsonb_array_elements(p_items) AS elem
        GROUP BY (elem->>'product_id')::INT
    LOOP
        UPDATE public.products
        SET stock_quantity = stock_quantity - v_agg_item.aggregated_qty
        WHERE id = v_agg_item.product_id;
    END LOOP;

    -- 7. Pass 3: Insert into orders table with authoritative total & authenticated user_id
    INSERT INTO public.orders (
        total_amount,
        status,
        user_id
    ) VALUES (
        v_authoritative_total + v_delivery_fee,
        'placed',
        v_user_id
    )
    RETURNING id INTO v_order_id;

    -- 8. Pass 4: Insert consolidated line items into order_items table
    FOR v_agg_item IN
        SELECT 
            (elem->>'product_id')::INT AS product_id,
            SUM((elem->>'quantity')::BIGINT)::INT AS aggregated_qty
        FROM jsonb_array_elements(p_items) AS elem
        GROUP BY (elem->>'product_id')::INT
        ORDER BY (elem->>'product_id')::INT ASC
    LOOP
        SELECT name, price
        INTO v_prod_name, v_prod_price
        FROM public.products
        WHERE id = v_agg_item.product_id;

        INSERT INTO public.order_items (
            order_id,
            product_id,
            product_name,
            quantity,
            unit_price
        ) VALUES (
            v_order_id,
            v_agg_item.product_id,
            v_prod_name,
            v_agg_item.aggregated_qty,
            v_prod_price
        );
    END LOOP;

    -- 9. Return JSON result to the client
    RETURN jsonb_build_object(
        'success', TRUE,
        'order_id', v_order_id,
        'subtotal', v_authoritative_total,
        'delivery_fee', v_delivery_fee,
        'total_amount', v_authoritative_total + v_delivery_fee,
        'status', 'placed'
    );
END;
$$;

-- 4. Set permissions: Revoke from PUBLIC and anon; grant exclusively to authenticated
REVOKE ALL ON FUNCTION public.create_order_secure(JSONB, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.create_order_secure(JSONB, TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION public.create_order_secure(JSONB, TEXT) TO authenticated;
