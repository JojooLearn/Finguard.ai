-- Migration: 20261106200000_create_stock_signals.sql
-- Purpose: Table and RLS for TradingView stock signals

CREATE TABLE IF NOT EXISTS public.stock_signals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticker text NOT NULL,
  signal_type text NOT NULL CHECK (signal_type IN ('BUY', 'SELL', 'HOLD', 'STRONG_BUY', 'STRONG_SELL')),
  price_at_signal numeric(18,2) NOT NULL CHECK (price_at_signal >= 0),
  timeframe text NOT NULL DEFAULT '1D',
  analysis_notes text,
  valid_until timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Ensure ticker is always stored uppercase
CREATE OR REPLACE FUNCTION public.fn_normalize_stock_signal_ticker()
RETURNS trigger AS $$
BEGIN
  NEW.ticker := upper(trim(NEW.ticker));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_normalize_stock_signal_ticker ON public.stock_signals;
CREATE TRIGGER trg_normalize_stock_signal_ticker
BEFORE INSERT OR UPDATE ON public.stock_signals
FOR EACH ROW
EXECUTE FUNCTION public.fn_normalize_stock_signal_ticker();

-- Indexes for performant lookup
CREATE INDEX IF NOT EXISTS idx_stock_signals_ticker_created_at
  ON public.stock_signals(ticker, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_stock_signals_valid_until
  ON public.stock_signals(valid_until DESC);

-- Enable RLS
ALTER TABLE public.stock_signals ENABLE ROW LEVEL SECURITY;

-- Read policy: Anyone authenticated or anon can read signals
CREATE POLICY "stock_signals_authenticated_read"
  ON public.stock_signals
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "stock_signals_anon_read"
  ON public.stock_signals
  FOR SELECT
  TO anon
  USING (true);

-- No insert/update/delete policy for regular clients.
-- Only service_role (used by Edge Functions webhook) bypasses RLS to insert/update.

