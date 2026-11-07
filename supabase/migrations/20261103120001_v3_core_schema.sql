-- ==============================================================================
-- FinGuard v3.0 Core Database Schema (PostgreSQL / Supabase)
-- Bab 4: 12 Tabel Wajib (Zero-Tolerance Strict Version)
-- ==============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Profiles (1:1 with auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT,
    locale TEXT NOT NULL DEFAULT 'id-ID',
    timezone TEXT NOT NULL DEFAULT 'Asia/Jakarta',
    currency_code CHAR(3) NOT NULL DEFAULT 'IDR',
    onboarding_completed_at TIMESTAMPTZ, -- NULL until onboarding is finished
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Financial Profiles
CREATE TABLE IF NOT EXISTS public.financial_profiles (
    user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    monthly_income NUMERIC(18,2) CHECK (monthly_income IS NULL OR monthly_income >= 0),
    dependents_count INTEGER NOT NULL DEFAULT 0 CHECK (dependents_count >= 0),
    monthly_debt_payments NUMERIC(18,2) NOT NULL DEFAULT 0 CHECK (monthly_debt_payments >= 0),
    strictness_level SMALLINT NOT NULL DEFAULT 3 CHECK (strictness_level BETWEEN 1 AND 5),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. User Preferences (Settings & Alert toggles)
CREATE TABLE IF NOT EXISTS public.user_preferences (
    user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    notifications_enabled BOOLEAN NOT NULL DEFAULT true,
    budget_alerts_enabled BOOLEAN NOT NULL DEFAULT true,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. Accounts
CREATE TABLE IF NOT EXISTS public.accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    opening_balance NUMERIC(18,2) NOT NULL DEFAULT 0.00 CHECK (opening_balance >= 0),
    account_type TEXT NOT NULL DEFAULT 'bank' CHECK (account_type IN ('cash', 'bank', 'e_wallet', 'savings', 'investment')),
    currency_code CHAR(3) NOT NULL DEFAULT 'IDR',
    is_default BOOLEAN NOT NULL DEFAULT false,
    is_archived BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 5. Categories
CREATE TABLE IF NOT EXISTS public.categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE, -- NULL for system categories
    name TEXT NOT NULL,
    transaction_type TEXT NOT NULL CHECK (transaction_type IN ('income', 'expense')),
    allocation_type TEXT CHECK (allocation_type IS NULL OR allocation_type IN ('needs', 'wants', 'savings_debt', 'other')),
    icon_key TEXT,
    color_hex TEXT,
    is_system BOOLEAN NOT NULL DEFAULT false,
    is_archived BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 6. Transactions
CREATE TABLE IF NOT EXISTS public.transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    account_id UUID NOT NULL REFERENCES public.accounts(id) ON DELETE RESTRICT,
    category_id UUID NOT NULL REFERENCES public.categories(id) ON DELETE RESTRICT,
    amount NUMERIC(18,2) NOT NULL CHECK (amount > 0),
    transaction_type TEXT NOT NULL CHECK (transaction_type IN ('income', 'expense')),
    transaction_date DATE NOT NULL DEFAULT CURRENT_DATE,
    note TEXT,
    source TEXT NOT NULL DEFAULT 'manual' CHECK (source IN ('manual', 'chat_extracted', 'csv_import', 'recurring')),
    client_request_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ -- Soft delete
);

-- 7. Budgets
CREATE TABLE IF NOT EXISTS public.budgets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    category_id UUID NOT NULL REFERENCES public.categories(id) ON DELETE CASCADE,
    limit_amount NUMERIC(18,2) NOT NULL CHECK (limit_amount > 0),
    period_start DATE NOT NULL,
    period_end DATE NOT NULL CHECK (period_end >= period_start),
    currency_code CHAR(3) NOT NULL DEFAULT 'IDR',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_user_category_period UNIQUE (user_id, category_id, period_start, period_end)
);

-- 8. Financial Goals
CREATE TABLE IF NOT EXISTS public.financial_goals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    target_amount NUMERIC(18,2) NOT NULL CHECK (target_amount > 0),
    current_amount NUMERIC(18,2) NOT NULL DEFAULT 0.00 CHECK (current_amount >= 0),
    target_date DATE,
    description TEXT,
    priority SMALLINT NOT NULL DEFAULT 3 CHECK (priority BETWEEN 1 AND 5),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'paused', 'cancelled')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 9. Goal Contributions
CREATE TABLE IF NOT EXISTS public.goal_contributions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    goal_id UUID NOT NULL REFERENCES public.financial_goals(id) ON DELETE CASCADE,
    amount NUMERIC(18,2) NOT NULL CHECK (amount > 0),
    contribution_date DATE NOT NULL DEFAULT CURRENT_DATE,
    note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 10. Chat Conversations
CREATE TABLE IF NOT EXISTS public.chat_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 11. Chat Messages
CREATE TABLE IF NOT EXISTS public.chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES public.chat_conversations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system_event')),
    content TEXT NOT NULL,
    message_status TEXT NOT NULL DEFAULT 'completed' CHECK (message_status IN ('sent', 'processing', 'completed', 'failed')),
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 12. AI Requests & Monthly Reviews
CREATE TABLE IF NOT EXISTS public.ai_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    client_request_id UUID NOT NULL,
    conversation_id UUID REFERENCES public.chat_conversations(id) ON DELETE SET NULL,
    request_type TEXT NOT NULL,
    prompt_summary TEXT,
    response_summary TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.monthly_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL CHECK (period_end >= period_start),
    currency_code CHAR(3) NOT NULL DEFAULT 'IDR',
    metrics_snapshot JSONB NOT NULL,
    narrative TEXT NOT NULL,
    calculation_version TEXT NOT NULL DEFAULT 'v1',
    generated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_user_period_review UNIQUE (user_id, period_start, period_end)
);

-- ==============================================================================
-- Row Level Security (RLS) Policies (100% Tabel Wajib Terproteksi)
-- ==============================================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.financial_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.budgets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.financial_goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.goal_contributions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.monthly_reviews ENABLE ROW LEVEL SECURITY;

-- 1. profiles
DROP POLICY IF EXISTS "Users can manage own profile" ON public.profiles;
CREATE POLICY "Users can manage own profile" ON public.profiles
    FOR ALL USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- 2. financial_profiles
DROP POLICY IF EXISTS "Users can manage own financial profile" ON public.financial_profiles;
CREATE POLICY "Users can manage own financial profile" ON public.financial_profiles
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 3. user_preferences
DROP POLICY IF EXISTS "Users can manage own preferences" ON public.user_preferences;
CREATE POLICY "Users can manage own preferences" ON public.user_preferences
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 4. accounts
DROP POLICY IF EXISTS "Users can manage own accounts" ON public.accounts;
CREATE POLICY "Users can manage own accounts" ON public.accounts
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 5. categories: System categories read-only for all, custom categories managed by owner
DROP POLICY IF EXISTS "Users can view system or own categories" ON public.categories;
CREATE POLICY "Users can view system or own categories" ON public.categories
    FOR SELECT USING (is_system = true OR auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own custom categories" ON public.categories;
CREATE POLICY "Users can insert own custom categories" ON public.categories
    FOR INSERT WITH CHECK (auth.uid() = user_id AND is_system = false);

DROP POLICY IF EXISTS "Users can update own custom categories" ON public.categories;
CREATE POLICY "Users can update own custom categories" ON public.categories
    FOR UPDATE USING (auth.uid() = user_id AND is_system = false);

DROP POLICY IF EXISTS "Users can delete own custom categories" ON public.categories;
CREATE POLICY "Users can delete own custom categories" ON public.categories
    FOR DELETE USING (auth.uid() = user_id AND is_system = false);

-- 6. transactions
DROP POLICY IF EXISTS "Users can manage own transactions" ON public.transactions;
CREATE POLICY "Users can manage own transactions" ON public.transactions
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 7. budgets
DROP POLICY IF EXISTS "Users can manage own budgets" ON public.budgets;
CREATE POLICY "Users can manage own budgets" ON public.budgets
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 8. financial_goals
DROP POLICY IF EXISTS "Users can manage own goals" ON public.financial_goals;
CREATE POLICY "Users can manage own goals" ON public.financial_goals
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 9. goal_contributions
DROP POLICY IF EXISTS "Users can manage own goal contributions" ON public.goal_contributions;
CREATE POLICY "Users can manage own goal contributions" ON public.goal_contributions
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 10. chat_conversations
DROP POLICY IF EXISTS "Users can manage own conversations" ON public.chat_conversations;
CREATE POLICY "Users can manage own conversations" ON public.chat_conversations
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 11. chat_messages
DROP POLICY IF EXISTS "Users can manage own chat messages" ON public.chat_messages;
CREATE POLICY "Users can manage own chat messages" ON public.chat_messages
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 12. ai_requests & monthly_reviews
DROP POLICY IF EXISTS "Users can manage own ai requests" ON public.ai_requests;
CREATE POLICY "Users can manage own ai requests" ON public.ai_requests
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can manage own monthly reviews" ON public.monthly_reviews;
CREATE POLICY "Users can manage own monthly reviews" ON public.monthly_reviews
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

