-- ==============================================================================
-- FinGuard v3.0 Master System Categories (Zero-Tolerance: Hanya is_system = true)
-- ==============================================================================

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

