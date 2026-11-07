-- 000007_create_ai_requests_and_reviews.sql

-- AI Requests table (for idempotency and lifecycle tracking)
CREATE TABLE IF NOT EXISTS public.ai_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    client_request_id UUID NOT NULL,
    conversation_id UUID REFERENCES public.chat_conversations(id) ON DELETE SET NULL,
    user_message_id UUID REFERENCES public.chat_messages(id) ON DELETE SET NULL,
    assistant_message_id UUID REFERENCES public.chat_messages(id) ON DELETE SET NULL,
    request_type TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('received', 'processing', 'needs_clarification', 'completed', 'failed')),
    schema_version TEXT NOT NULL DEFAULT 'v1',
    prompt_version TEXT NOT NULL DEFAULT 'v1',
    result_reference JSONB,
    error_code TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_ai_requests_client UNIQUE (user_id, client_request_id)
);

-- Monthly Reviews table
CREATE TABLE IF NOT EXISTS public.monthly_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL CHECK (period_end >= period_start),
    currency_code CHAR(3) NOT NULL DEFAULT 'IDR',
    metrics_snapshot JSONB NOT NULL,
    narrative TEXT,
    calculation_version TEXT NOT NULL DEFAULT 'v1',
    prompt_version TEXT DEFAULT 'v1',
    status TEXT NOT NULL DEFAULT 'generated' CHECK (status IN ('generated', 'failed', 'superseded')),
    generated_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_monthly_reviews_period UNIQUE (user_id, period_start, period_end, calculation_version)
);
