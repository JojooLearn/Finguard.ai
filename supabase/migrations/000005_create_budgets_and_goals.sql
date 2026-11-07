-- 000005_create_budgets_and_goals.sql

-- Budgets table
CREATE TABLE IF NOT EXISTS public.budgets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    category_id UUID NOT NULL REFERENCES public.categories(id) ON DELETE CASCADE,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL CHECK (period_end >= period_start),
    limit_amount NUMERIC(18,2) NOT NULL CHECK (limit_amount >= 0),
    currency_code CHAR(3) NOT NULL DEFAULT 'IDR',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Financial Goals table
CREATE TABLE IF NOT EXISTS public.financial_goals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    goal_type TEXT NOT NULL CHECK (goal_type IN ('emergency_fund', 'savings', 'debt_repayment', 'other')),
    target_amount NUMERIC(18,2) NOT NULL CHECK (target_amount > 0),
    current_amount NUMERIC(18,2) NOT NULL DEFAULT 0.00 CHECK (current_amount >= 0),
    currency_code CHAR(3) NOT NULL DEFAULT 'IDR',
    target_date DATE,
    priority SMALLINT NOT NULL DEFAULT 3 CHECK (priority BETWEEN 1 AND 5),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'paused', 'cancelled')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Goal Contributions table
CREATE TABLE IF NOT EXISTS public.goal_contributions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    goal_id UUID NOT NULL REFERENCES public.financial_goals(id) ON DELETE CASCADE,
    amount NUMERIC(18,2) NOT NULL CHECK (amount > 0),
    contribution_date DATE NOT NULL,
    note TEXT,
    transaction_id UUID REFERENCES public.transactions(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
