-- ==============================================================================
-- Migration: Ensure all 12 standard system categories are fully seeded with icons & colors
-- ==============================================================================

-- 1. Upsert or enrich the 12 standard categories with proper icon_key and color_hex
INSERT INTO public.categories (name, transaction_type, allocation_type, icon_key, color_hex, is_system, user_id)
VALUES
    ('Makan & Minum', 'expense', 'needs', 'utensils', '#E0A100', true, NULL),
    ('Transportasi', 'expense', 'needs', 'car', '#283202', true, NULL),
    ('Tagihan & Utilitas', 'expense', 'needs', 'receipt', '#D64545', true, NULL),
    ('Belanja Harian', 'expense', 'needs', 'shopping-cart', '#83CA2D', true, NULL),
    ('Kesehatan', 'expense', 'needs', 'heart-pulse', '#4A7C10', true, NULL),
    ('Hiburan', 'expense', 'wants', 'ticket', '#885CF6', true, NULL),
    ('Gaya Hidup & Hobi', 'expense', 'wants', 'coffee', '#EC4899', true, NULL),
    ('Lainnya', 'expense', 'other', 'more-horizontal', '#64748B', true, NULL),
    ('Gaji & Upah', 'income', 'other', 'wallet', '#4A7C10', true, NULL),
    ('Bonus & THR', 'income', 'other', 'gift', '#83CA2D', true, NULL),
    ('Penjualan & Usaha', 'income', 'other', 'store', '#3882F6', true, NULL),
    ('Investasi & Dividen', 'income', 'other', 'trend-up', '#885CF6', true, NULL)
ON CONFLICT (name, transaction_type) WHERE is_system = true
DO UPDATE SET
    allocation_type = EXCLUDED.allocation_type,
    icon_key = EXCLUDED.icon_key,
    color_hex = EXCLUDED.color_hex,
    is_system = true,
    user_id = NULL;

-- 2. If any rows exist with user_id NOT NULL that match standard names, merge them into the system categories
DO $$
DECLARE
    rec RECORD;
    sys_id UUID;
BEGIN
    FOR rec IN
        SELECT id, name, transaction_type, user_id
        FROM public.categories
        WHERE user_id IS NOT NULL
          AND name IN (
            'Makan & Minum', 'Transportasi', 'Tagihan & Utilitas', 'Belanja Harian',
            'Kesehatan', 'Hiburan', 'Gaya Hidup & Hobi', 'Lainnya',
            'Gaji & Upah', 'Bonus & THR', 'Penjualan & Usaha', 'Investasi & Dividen'
          )
    LOOP
        -- Find the system category ID
        SELECT id INTO sys_id
        FROM public.categories
        WHERE name = rec.name
          AND transaction_type = rec.transaction_type
          AND is_system = true
        LIMIT 1;

        IF sys_id IS NOT NULL AND sys_id != rec.id THEN
            -- Re-point transactions
            UPDATE public.transactions
            SET category_id = sys_id
            WHERE category_id = rec.id;

            -- Re-point budgets
            UPDATE public.budgets
            SET category_id = sys_id
            WHERE category_id = rec.id;

            -- Delete duplicate user row
            DELETE FROM public.categories
            WHERE id = rec.id;
        END IF;
    END LOOP;
END $$;

