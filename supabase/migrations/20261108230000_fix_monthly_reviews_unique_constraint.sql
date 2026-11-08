-- ==============================================================================
-- Migration: Add unique constraint on (user_id, period_start, period_end) for monthly_reviews
-- ==============================================================================

-- 1. Deduplicate any existing duplicate reviews for the same user and period
DO $$
DECLARE
    dup RECORD;
    canonical_id UUID;
BEGIN
    FOR dup IN
        SELECT user_id, period_start, period_end, COUNT(*) as cnt
        FROM public.monthly_reviews
        GROUP BY user_id, period_start, period_end
        HAVING COUNT(*) > 1
    LOOP
        SELECT id INTO canonical_id
        FROM public.monthly_reviews
        WHERE user_id = dup.user_id
          AND period_start = dup.period_start
          AND period_end = dup.period_end
        ORDER BY created_at DESC, id DESC
        LIMIT 1;

        IF canonical_id IS NOT NULL THEN
            DELETE FROM public.monthly_reviews
            WHERE user_id = dup.user_id
              AND period_start = dup.period_start
              AND period_end = dup.period_end
              AND id != canonical_id;
        END IF;
    END LOOP;
END $$;

-- 2. Create unique index matching the application's upsert onConflict: user_id,period_start,period_end
CREATE UNIQUE INDEX IF NOT EXISTS idx_monthly_reviews_user_period_unique
ON public.monthly_reviews (user_id, period_start, period_end);
