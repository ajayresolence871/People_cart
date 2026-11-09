-- ==============================================================================
-- Migration: 20261030_secure_checkout_rpc.sql
-- Description: Creates the atomic `create_order_secure` stored procedure in Postgres
--              that prevents price tampering and concurrency overselling:
--              1. Locks stock rows with `FOR UPDATE`
--              2. Validates availability and stock limits
--              3. Recalculates total from authoritative database prices
--              4. Decrements inventory atomically
--              5. Inserts into orders and order_items in a single ACID transaction
-- ==============================================================================

-- 1. Allow guest/anonymous checkouts by making user_id optional in orders
ALTER TABLE public.orders ALTER COLUMN user_id DROP NOT NULL;

-- 2. Drop previous function signature if exists
DROP FUNCTION IF EXISTS public.create_order_secure(jsonb, text);
DROP FUNCTION IF EXISTS public.create_order_secure(jsonb, text, uuid);

-- 3. Create the secure atomic checkout function
CREATE OR REPLACE FUNCTION public.create_order_secure(
    p_items JSONB,
    p_payment_method TEXT DEFAULT 'cash_on_delivery',
    p_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_item JSONB;
    v_product_id INT;
    v_qty INT;
    v_prod_name TEXT;
    v_prod_price NUMERIC;
    v_prod_stock INT;
    v_prod_avail BOOLEAN;
    v_authoritative_total NUMERIC := 0.00;
    v_order_id BIGINT;
    v_user_id UUID;
    v_delivery_fee NUMERIC := 0.00;
BEGIN
    -- Resolve user ID: authenticated session > passed user_id > first registered user > NULL
    v_user_id := COALESCE(
        auth.uid(),
        p_user_id,
        (SELECT id FROM auth.users LIMIT 1)
    );

    IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'Order cannot be empty';
    END IF;

    -- 1. Pass 1: Row Locking, Stock Validation, and Authoritative Price Calculation
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_product_id := (v_item->>'product_id')::INT;
        v_qty := (v_item->>'quantity')::INT;

        IF v_qty <= 0 THEN
            RAISE EXCEPTION 'Invalid quantity % for product ID %', v_qty, v_product_id;
        END IF;

        -- Lock the row for update so no concurrent transaction can modify stock
        SELECT name, price, stock_quantity, is_available
        INTO v_prod_name, v_prod_price, v_prod_stock, v_prod_avail
        FROM public.products
        WHERE id = v_product_id
        FOR UPDATE;

        IF v_prod_name IS NULL THEN
            RAISE EXCEPTION 'Product with ID % does not exist', v_product_id;
        END IF;

        IF NOT v_prod_avail THEN
            RAISE EXCEPTION 'Product "%" is currently unavailable', v_prod_name;
        END IF;

        IF v_prod_stock < v_qty THEN
            RAISE EXCEPTION 'Insufficient stock for "%". Requested: %, Available: %',
                v_prod_name, v_qty, v_prod_stock;
        END IF;

        -- Calculate total directly from database price
        v_authoritative_total := v_authoritative_total + (v_prod_price * v_qty);
    END LOOP;

    -- Free delivery threshold check (₹49 threshold)
    IF v_authoritative_total < 49.00 THEN
        v_delivery_fee := 30.00;
    ELSE
        v_delivery_fee := 0.00;
    END IF;

    -- 2. Pass 2: Deduct Stock
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_product_id := (v_item->>'product_id')::INT;
        v_qty := (v_item->>'quantity')::INT;

        UPDATE public.products
        SET stock_quantity = stock_quantity - v_qty
        WHERE id = v_product_id;
    END LOOP;

    -- 3. Insert into orders table
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

    -- 4. Insert into order_items table
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_product_id := (v_item->>'product_id')::INT;
        v_qty := (v_item->>'quantity')::INT;

        SELECT name, price
        INTO v_prod_name, v_prod_price
        FROM public.products
        WHERE id = v_product_id;

        INSERT INTO public.order_items (
            order_id,
            product_id,
            product_name,
            quantity,
            unit_price
        ) VALUES (
            v_order_id,
            v_product_id,
            v_prod_name,
            v_qty,
            v_prod_price
        );
    END LOOP;

    -- Return JSON result to the client
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
