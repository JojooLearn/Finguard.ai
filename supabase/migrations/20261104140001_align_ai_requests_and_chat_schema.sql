-- ==============================================================================
-- Migration: Align ai_requests with PRD Section 9.14 specifications
-- ==============================================================================

ALTER TABLE public.ai_requests
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'completed' CHECK (status IN ('received', 'processing', 'needs_clarification', 'completed', 'failed')),
  ADD COLUMN IF NOT EXISTS user_message_id UUID REFERENCES public.chat_messages(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS assistant_message_id UUID REFERENCES public.chat_messages(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS schema_version TEXT DEFAULT 'v1',
  ADD COLUMN IF NOT EXISTS result_reference JSONB,
  ADD COLUMN IF NOT EXISTS error_code TEXT,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

-- Ensure client_request_id unique index for idempotency enforcement
CREATE UNIQUE INDEX IF NOT EXISTS idx_ai_requests_user_client_req 
  ON public.ai_requests(user_id, client_request_id);

-- Ensure default system categories exist
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
ON CONFLICT DO NOTHING;

