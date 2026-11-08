-- 000003_create_accounts_and_categories.sql

-- Accounts table
CREATE TABLE IF NOT EXISTS public.accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    account_type TEXT NOT NULL CHECK (account_type IN ('cash', 'bank', 'e_wallet', 'savings', 'investment')),
    currency_code CHAR(3) NOT NULL DEFAULT 'IDR',
    opening_balance NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    is_default BOOLEAN NOT NULL DEFAULT false,
    is_archived BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Categories table
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

-- Unique index to prevent duplicate system categories
CREATE UNIQUE INDEX IF NOT EXISTS idx_categories_unique_system_name_type
ON public.categories (name, transaction_type)
WHERE is_system = true;

-- Seed system categories (is_system = true, user_id = null)
INSERT INTO public.categories (name, transaction_type, allocation_type, icon_key, color_hex, is_system) VALUES
('Makan & Minum', 'expense', 'needs', 'utensils', '#E0A100', true),
('Transportasi', 'expense', 'needs', 'car', '#263202', true),
('Tagihan & Utilitas', 'expense', 'needs', 'receipt', '#D64545', true),
('Belanja Harian', 'expense', 'needs', 'shopping-cart', '#B3CA2D', true),
('Kesehatan', 'expense', 'needs', 'heart-pulse', '#4A7C10', true),
('Hiburan', 'expense', 'wants', 'ticket', '#8B5CF6', true),
('Gaya Hidup & Hobi', 'expense', 'wants', 'coffee', '#EC4899', true),
('Gaji & Upah', 'income', 'other', 'wallet', '#4A7C10', true),
('Bonus & THR', 'income', 'other', 'gift', '#B3CA2D', true),
('Penjualan & Usaha', 'income', 'other', 'store', '#3B82F6', true),
('Investasi & Dividen', 'income', 'savings_debt', 'trending-up', '#10B981', true),
('Lainnya', 'expense', 'other', 'more-horizontal', '#64748B', true)
ON CONFLICT (name, transaction_type) WHERE is_system = true DO NOTHING;
