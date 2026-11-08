-- Migration: 20261108211500_allow_stock_signals_full_sync.sql
-- Purpose: Enable full read/write/delete sync for real-time TradingView stock signals on stock_signals table

ALTER TABLE public.stock_signals ENABLE ROW LEVEL SECURITY;

-- 1. Read policies: Authenticated & Anon
DROP POLICY IF EXISTS "stock_signals_authenticated_read" ON public.stock_signals;
CREATE POLICY "stock_signals_authenticated_read"
  ON public.stock_signals FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "stock_signals_anon_read" ON public.stock_signals;
CREATE POLICY "stock_signals_anon_read"
  ON public.stock_signals FOR SELECT TO anon USING (true);

-- 2. Insert policies: Authenticated & Anon
DROP POLICY IF EXISTS "stock_signals_authenticated_insert" ON public.stock_signals;
CREATE POLICY "stock_signals_authenticated_insert"
  ON public.stock_signals FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "stock_signals_anon_insert" ON public.stock_signals;
CREATE POLICY "stock_signals_anon_insert"
  ON public.stock_signals FOR INSERT TO anon WITH CHECK (true);

-- 3. Update policies: Authenticated & Anon
DROP POLICY IF EXISTS "stock_signals_authenticated_update" ON public.stock_signals;
CREATE POLICY "stock_signals_authenticated_update"
  ON public.stock_signals FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "stock_signals_anon_update" ON public.stock_signals;
CREATE POLICY "stock_signals_anon_update"
  ON public.stock_signals FOR UPDATE TO anon USING (true) WITH CHECK (true);

-- 4. Delete policies: Authenticated & Anon (allows clearing old signals before syncing fresh top gainers)
DROP POLICY IF EXISTS "stock_signals_authenticated_delete" ON public.stock_signals;
CREATE POLICY "stock_signals_authenticated_delete"
  ON public.stock_signals FOR DELETE TO authenticated USING (true);

DROP POLICY IF EXISTS "stock_signals_anon_delete" ON public.stock_signals;
CREATE POLICY "stock_signals_anon_delete"
  ON public.stock_signals FOR DELETE TO anon USING (true);
