-- 000008_add_constraints_indexes_and_triggers.sql

-- Performance and Idempotency Indexes
CREATE INDEX IF NOT EXISTS idx_transactions_user_date ON public.transactions(user_id, transaction_date DESC, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_user_category ON public.transactions(user_id, category_id, transaction_date DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_user_type ON public.transactions(user_id, transaction_type, transaction_date DESC);
CREATE UNIQUE INDEX IF NOT EXISTS uq_transactions_user_client_request ON public.transactions(user_id, client_request_id) WHERE client_request_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_budgets_user_period ON public.budgets(user_id, period_start, period_end);
CREATE INDEX IF NOT EXISTS idx_budgets_user_category ON public.budgets(user_id, category_id, period_start);

CREATE INDEX IF NOT EXISTS idx_goals_user_status_priority ON public.financial_goals(user_id, status, priority);
CREATE INDEX IF NOT EXISTS idx_goal_contribs_user_goal ON public.goal_contributions(user_id, goal_id, contribution_date DESC);

CREATE INDEX IF NOT EXISTS idx_chat_conversations_user ON public.chat_conversations(user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_messages_conversation ON public.chat_messages(conversation_id, created_at ASC);

CREATE INDEX IF NOT EXISTS idx_monthly_reviews_user_period ON public.monthly_reviews(user_id, period_start DESC);

-- Trigger: update updated_at automatically
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_profiles_updated_at
BEFORE UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_financial_profiles_updated_at
BEFORE UPDATE ON public.financial_profiles
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_accounts_updated_at
BEFORE UPDATE ON public.accounts
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_categories_updated_at
BEFORE UPDATE ON public.categories
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_transactions_updated_at
BEFORE UPDATE ON public.transactions
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_budgets_updated_at
BEFORE UPDATE ON public.budgets
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_financial_goals_updated_at
BEFORE UPDATE ON public.financial_goals
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_chat_conversations_updated_at
BEFORE UPDATE ON public.chat_conversations
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_ai_requests_updated_at
BEFORE UPDATE ON public.ai_requests
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Trigger: create profile on user registration in auth.users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, display_name)
    VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)))
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.financial_profiles (user_id)
    VALUES (NEW.id)
    ON CONFLICT (user_id) DO NOTHING;

    -- Create default cash account
    INSERT INTO public.accounts (user_id, name, account_type, is_default)
    VALUES (NEW.id, 'Dompet Utama', 'cash', true)
    ON CONFLICT DO NOTHING;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop trigger if already exists and recreate
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Trigger: maintain goal current_amount from contributions
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
    SET current_amount = total_amount
    WHERE id = target_goal_id;

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_goal_contribution_change
AFTER INSERT OR UPDATE OR DELETE ON public.goal_contributions
FOR EACH ROW EXECUTE FUNCTION public.update_goal_current_amount();
