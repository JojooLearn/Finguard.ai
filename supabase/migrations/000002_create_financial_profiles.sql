-- 000002_create_financial_profiles.sql
-- Financial Profiles table: 1:1 with profiles
CREATE TABLE IF NOT EXISTS public.financial_profiles (
    user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    monthly_income NUMERIC(18,2) CHECK (monthly_income IS NULL OR monthly_income >= 0),
    income_frequency TEXT CHECK (income_frequency IS NULL OR income_frequency IN ('monthly', 'weekly', 'biweekly', 'irregular')),
    dependents_count INTEGER NOT NULL DEFAULT 0 CHECK (dependents_count >= 0),
    essential_monthly_expenses NUMERIC(18,2) CHECK (essential_monthly_expenses IS NULL OR essential_monthly_expenses >= 0),
    monthly_debt_payments NUMERIC(18,2) CHECK (monthly_debt_payments IS NULL OR monthly_debt_payments >= 0),
    current_emergency_fund NUMERIC(18,2) CHECK (current_emergency_fund IS NULL OR current_emergency_fund >= 0),
    primary_goal_summary TEXT,
    risk_profile TEXT CHECK (risk_profile IS NULL OR risk_profile IN ('conservative', 'moderate', 'aggressive')),
    strictness_level SMALLINT NOT NULL DEFAULT 3 CHECK (strictness_level BETWEEN 1 AND 5),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.financial_profiles IS 'User financial background and coaching parameters';
