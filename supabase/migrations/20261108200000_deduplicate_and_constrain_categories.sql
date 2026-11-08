-- ==============================================================================
-- Migration: Deduplicate categories and enforce unique constraint on system categories
-- ==============================================================================

DO $$
DECLARE
    dup RECORD;
    canonical_id UUID;
BEGIN
    -- Loop over all system category names & types
    FOR dup IN
        SELECT DISTINCT name, transaction_type
        FROM public.categories
        WHERE is_system = true
    LOOP
        -- Choose the earliest created category ID as the canonical one
        SELECT id INTO canonical_id
        FROM public.categories
        WHERE name = dup.name
          AND transaction_type = dup.transaction_type
          AND is_system = true
        ORDER BY created_at ASC, id ASC
        LIMIT 1;

        IF canonical_id IS NOT NULL THEN
            -- Re-point any transactions linked to duplicate category IDs
            UPDATE public.transactions
            SET category_id = canonical_id
            WHERE category_id IN (
                SELECT id FROM public.categories
                WHERE name = dup.name
                  AND transaction_type = dup.transaction_type
                  AND is_system = true
                  AND id != canonical_id
            );

            -- Re-point any budgets linked to duplicate category IDs
            UPDATE public.budgets
            SET category_id = canonical_id
            WHERE category_id IN (
                SELECT id FROM public.categories
                WHERE name = dup.name
                  AND transaction_type = dup.transaction_type
                  AND is_system = true
                  AND id != canonical_id
            );

            -- Delete duplicate category records
            DELETE FROM public.categories
            WHERE name = dup.name
              AND transaction_type = dup.transaction_type
              AND is_system = true
              AND id != canonical_id;
        END IF;
    END LOOP;
END $$;

-- Enforce uniqueness for system categories permanently
CREATE UNIQUE INDEX IF NOT EXISTS idx_categories_unique_system_name_type
ON public.categories (name, transaction_type)
WHERE is_system = true;

-- Enforce uniqueness for custom user categories
CREATE UNIQUE INDEX IF NOT EXISTS idx_categories_unique_user_name_type
ON public.categories (user_id, name, transaction_type)
WHERE user_id IS NOT NULL AND is_system = false;

