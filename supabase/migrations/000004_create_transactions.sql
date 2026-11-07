-- 000004_create_transactions.sql

-- Transactions table
CREATE TABLE IF NOT EXISTS public.transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    account_id UUID REFERENCES public.accounts(id) ON DELETE SET NULL,
    category_id UUID REFERENCES public.categories(id) ON DELETE SET NULL,
    transaction_type TEXT NOT NULL CHECK (transaction_type IN ('income', 'expense')),
    amount NUMERIC(18,2) NOT NULL CHECK (amount > 0),
    currency_code CHAR(3) NOT NULL DEFAULT 'IDR',
    transaction_date DATE NOT NULL,
    note TEXT,
    source TEXT NOT NULL DEFAULT 'manual' CHECK (source IN ('manual', 'chat', 'import')),
    status TEXT NOT NULL DEFAULT 'confirmed' CHECK (status IN ('confirmed', 'voided')),
    ai_intent TEXT,
    ai_category_confidence NUMERIC(4,3) CHECK (ai_category_confidence IS NULL OR (ai_category_confidence >= 0 AND ai_category_confidence <= 1)),
    client_request_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

COMMENT ON TABLE public.transactions IS 'Canonical transactions table for personal finance tracking';
