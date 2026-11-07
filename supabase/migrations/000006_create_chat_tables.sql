-- 000006_create_chat_tables.sql

-- Chat conversations table
CREATE TABLE IF NOT EXISTS public.chat_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT,
    conversation_type TEXT NOT NULL CHECK (conversation_type IN ('coach', 'purchase_consultation', 'monthly_review')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    archived_at TIMESTAMPTZ
);

-- Chat messages table
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
