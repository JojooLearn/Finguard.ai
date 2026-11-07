-- ==============================================================================
-- FinGuard v3.0 Automatic User Setup Trigger & Helpers
-- ==============================================================================

-- 0. Auto-confirm users on signup to prevent email confirmation blocking mobile testing
CREATE OR REPLACE FUNCTION public.handle_auto_confirm_user()
RETURNS TRIGGER AS $$
BEGIN
    NEW.email_confirmed_at := COALESCE(NEW.email_confirmed_at, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_auto_confirm ON auth.users;
CREATE TRIGGER on_auth_user_auto_confirm
BEFORE INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_auto_confirm_user();

-- Auto-confirm any existing users
UPDATE auth.users
SET email_confirmed_at = COALESCE(email_confirmed_at, now())
WHERE email_confirmed_at IS NULL;

-- 1. Trigger handle_new_user: Executed automatically when a user registers in auth.users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    -- 1. Create initial profile with onboarding_completed_at = NULL
    INSERT INTO public.profiles (id, display_name, onboarding_completed_at)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
        NULL
    )
    ON CONFLICT (id) DO NOTHING;

    -- 2. Create financial profile with default strictness level
    INSERT INTO public.financial_profiles (user_id, strictness_level)
    VALUES (NEW.id, 3)
    ON CONFLICT (user_id) DO NOTHING;

    -- 3. Create initial user preferences
    INSERT INTO public.user_preferences (user_id, notifications_enabled, budget_alerts_enabled)
    VALUES (NEW.id, true, true)
    ON CONFLICT (user_id) DO NOTHING;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 2. Trigger to automatically update goal current_amount when contributions are added/updated/deleted
CREATE OR REPLACE FUNCTION public.update_goal_current_amount()
RETURNS TRIGGER AS $$
DECLARE
    target_goal_id UUID;
    total_amount NUMERIC(18,2);
BEGIN
    target_goal_id := COALESCE(NEW.goal_id, OLD.goal_id);
    SELECT COALESCE(SUM(amount), 0.00) INTO total_amount
    FROM public.goal_contributions
    WHERE goal_id = target_goal_id;

    UPDATE public.financial_goals
    SET current_amount = total_amount,
        updated_at = now()
    WHERE id = target_goal_id;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_goal_contributions_update_amount ON public.goal_contributions;
CREATE TRIGGER trg_goal_contributions_update_amount
AFTER INSERT OR UPDATE OR DELETE ON public.goal_contributions
FOR EACH ROW EXECUTE FUNCTION public.update_goal_current_amount();

