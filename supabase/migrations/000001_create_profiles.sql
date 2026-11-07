-- 000001_create_profiles.sql
-- Profiles table: 1:1 with auth.users
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT,
    locale TEXT NOT NULL DEFAULT 'id-ID',
    timezone TEXT NOT NULL DEFAULT 'Asia/Jakarta',
    currency_code CHAR(3) NOT NULL DEFAULT 'IDR',
    onboarding_completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.profiles IS 'User application-level identity and core locale/timezone preferences';
