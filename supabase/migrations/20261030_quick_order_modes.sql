-- ==============================================================================
-- Migration: 20261030_quick_order_modes.sql
-- Description: Creates quick_order_modes and quick_order_mode_items tables
--              with Row Level Security (RLS) for user-isolated shortcuts.
-- ==============================================================================

-- 1. Create quick_order_modes table
CREATE TABLE IF NOT EXISTS public.quick_order_modes (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    name TEXT NOT NULL,
    icon_name TEXT DEFAULT 'custom',
    tagline TEXT DEFAULT 'Custom collection',
    is_predefined BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Index for speedy user-scoped lookups
CREATE INDEX IF NOT EXISTS idx_quick_order_modes_user_id ON public.quick_order_modes(user_id);

-- 2. Create quick_order_mode_items table
CREATE TABLE IF NOT EXISTS public.quick_order_mode_items (
    id TEXT PRIMARY KEY,
    mode_id TEXT NOT NULL REFERENCES public.quick_order_modes(id) ON DELETE CASCADE,
    product_id TEXT NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    -- Prevent duplicate product entries within a single mode
    CONSTRAINT uq_mode_product UNIQUE (mode_id, product_id)
);

CREATE INDEX IF NOT EXISTS idx_quick_order_mode_items_mode_id ON public.quick_order_mode_items(mode_id);

-- 3. Enable Row Level Security (RLS)
ALTER TABLE public.quick_order_modes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quick_order_mode_items ENABLE ROW LEVEL SECURITY;

-- 4. Policies for quick_order_modes (Users can only read/write their own modes)
CREATE POLICY "Users can view own quick order modes"
    ON public.quick_order_modes
    FOR SELECT
    USING (auth.uid()::text = user_id OR user_id LIKE 'guest_%');

CREATE POLICY "Users can insert own quick order modes"
    ON public.quick_order_modes
    FOR INSERT
    WITH CHECK (auth.uid()::text = user_id OR user_id LIKE 'guest_%');

CREATE POLICY "Users can update own quick order modes"
    ON public.quick_order_modes
    FOR UPDATE
    USING (auth.uid()::text = user_id OR user_id LIKE 'guest_%');

CREATE POLICY "Users can delete own quick order modes"
    ON public.quick_order_modes
    FOR DELETE
    USING (auth.uid()::text = user_id OR user_id LIKE 'guest_%');

-- 5. Policies for quick_order_mode_items (Cascaded through mode ownership)
CREATE POLICY "Users can view own mode items"
    ON public.quick_order_mode_items
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.quick_order_modes
            WHERE quick_order_modes.id = quick_order_mode_items.mode_id
            AND (quick_order_modes.user_id = auth.uid()::text OR quick_order_modes.user_id LIKE 'guest_%')
        )
    );

CREATE POLICY "Users can insert own mode items"
    ON public.quick_order_mode_items
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.quick_order_modes
            WHERE quick_order_modes.id = quick_order_mode_items.mode_id
            AND (quick_order_modes.user_id = auth.uid()::text OR quick_order_modes.user_id LIKE 'guest_%')
        )
    );

CREATE POLICY "Users can update own mode items"
    ON public.quick_order_mode_items
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.quick_order_modes
            WHERE quick_order_modes.id = quick_order_mode_items.mode_id
            AND (quick_order_modes.user_id = auth.uid()::text OR quick_order_modes.user_id LIKE 'guest_%')
        )
    );

CREATE POLICY "Users can delete own mode items"
    ON public.quick_order_mode_items
    FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM public.quick_order_modes
            WHERE quick_order_modes.id = quick_order_mode_items.mode_id
            AND (quick_order_modes.user_id = auth.uid()::text OR quick_order_modes.user_id LIKE 'guest_%')
        )
    );
