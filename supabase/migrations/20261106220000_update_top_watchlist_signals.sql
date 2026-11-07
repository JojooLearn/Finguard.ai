-- Migration: 20261106220000_update_top_watchlist_signals.sql
-- Purpose: Set the 5 top watchlist stocks (BBCA, BBRI, BMRI, TLKM, ASII)

DELETE FROM public.stock_signals WHERE ticker = 'GOTO';

-- Clean existing to have exact 5 top watchlist
DELETE FROM public.stock_signals WHERE ticker IN ('BBCA', 'BBRI', 'BMRI', 'TLKM', 'ASII');

INSERT INTO public.stock_signals (ticker, signal_type, price_at_signal, timeframe, analysis_notes, valid_until)
VALUES
  ('BBCA', 'BUY', 5200.00, '1D', 'Akumulasi di support MA20, RSI netral-bullish', now() + interval '30 days'),
  ('BBRI', 'BUY', 2810.00, '1D', 'Rebound dari support kuat, volume naik', now() + interval '30 days'),
  ('BMRI', 'BUY', 3700.00, '1D', 'Breakout resisten minor, tren uptrend', now() + interval '30 days'),
  ('TLKM', 'HOLD', 2850.00, '1D', 'Konsolidasi di area support kunci', now() + interval '30 days'),
  ('ASII', 'BUY', 5000.00, '1D', 'Uji resisten 5.000, momentum positif', now() + interval '30 days');

