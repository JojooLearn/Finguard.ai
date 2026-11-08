-- ==============================================================================
-- Migration: Deduplicate categories and enforce unique constraint on system categories
-- ==============================================================================

DO $$
DECLARE
    dup RECORD;
    canonical_id UUID;
    standard_names TEXT[] := ARRAY[
        'Makan & Minum',
        'Transportasi',
        'Tagihan & Utilitas',
        'Belanja Harian',
        'Kesehatan',
        'Hiburan',
        'Gaya Hidup & Hobi',
        'Gaji & Upah',
        'Bonus & THR',
        'Penjualan & Usaha',
        'Investasi & Dividen',
        'Lainnya'
    ];
BEGIN
    -- 1. Deduplicate standard categories regardless of whether is_system is true or false
    FOR dup IN
        SELECT DISTINCT name, transaction_type
        FROM public.categories
        WHERE name = ANY(standard_names)
    LOOP
        -- Pick canonical ID (prefer is_system = true, or earliest created)
        SELECT id INTO canonical_id
        FROM public.categories
        WHERE name = dup.name
          AND transaction_type = dup.transaction_type
        ORDER BY is_system DESC, created_at ASC, id ASC
        LIMIT 1;

        IF canonical_id IS NOT NULL THEN
            -- Re-point transactions
            UPDATE public.transactions
            SET category_id = canonical_id
            WHERE category_id IN (
                SELECT id FROM public.categories
                WHERE name = dup.name
                  AND transaction_type = dup.transaction_type
                  AND id != canonical_id
            );

            -- Re-point budgets
            UPDATE public.budgets
            SET category_id = canonical_id
            WHERE category_id IN (
                SELECT id FROM public.categories
                WHERE name = dup.name
                  AND transaction_type = dup.transaction_type
                  AND id != canonical_id
            );

            -- Delete all duplicate category records
            DELETE FROM public.categories
            WHERE name = dup.name
              AND transaction_type = dup.transaction_type
              AND id != canonical_id;

            -- Elevate canonical record to official master system category
            UPDATE public.categories
            SET is_system = true,
                user_id = NULL
            WHERE id = canonical_id;
        END IF;
    END LOOP;

    -- 2. Deduplicate any remaining user-specific custom categories
    FOR dup IN
        SELECT user_id, name, transaction_type, COUNT(*) as cnt
        FROM public.categories
        WHERE user_id IS NOT NULL AND is_system = false
        GROUP BY user_id, name, transaction_type
        HAVING COUNT(*) > 1
    LOOP
        SELECT id INTO canonical_id
        FROM public.categories
        WHERE user_id = dup.user_id
          AND name = dup.name
          AND transaction_type = dup.transaction_type
        ORDER BY created_at ASC, id ASC
        LIMIT 1;

        IF canonical_id IS NOT NULL THEN
            UPDATE public.transactions
            SET category_id = canonical_id
            WHERE category_id IN (
                SELECT id FROM public.categories
                WHERE user_id = dup.user_id
                  AND name = dup.name
                  AND transaction_type = dup.transaction_type
                  AND id != canonical_id
            );

            UPDATE public.budgets
            SET category_id = canonical_id
            WHERE category_id IN (
                SELECT id FROM public.categories
                WHERE user_id = dup.user_id
                  AND name = dup.name
                  AND transaction_type = dup.transaction_type
                  AND id != canonical_id
            );

            DELETE FROM public.categories
            WHERE user_id = dup.user_id
              AND name = dup.name
              AND transaction_type = dup.transaction_type
              AND id != canonical_id;
        END IF;
    END LOOP;
END $$;

-- 3. Enforce uniqueness permanently for system categories
CREATE UNIQUE INDEX IF NOT EXISTS idx_categories_unique_system_name_type
ON public.categories (name, transaction_type)
WHERE is_system = true;

-- 4. Enforce uniqueness permanently for custom user categories
CREATE UNIQUE INDEX IF NOT EXISTS idx_categories_unique_user_name_type
ON public.categories (user_id, name, transaction_type)
WHERE user_id IS NOT NULL AND is_system = false;
