-- Migration: 20261107120000_allow_stock_signals_auto_seed.sql
-- Purpose: Allow authenticated users to auto-seed core stock signals if database was reset or empty

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'stock_signals' 
    AND policyname = 'stock_signals_authenticated_insert'
  ) THEN
    CREATE POLICY "stock_signals_authenticated_insert"
      ON public.stock_signals
      FOR INSERT
      TO authenticated
      WITH CHECK (true);
  END IF;
END $$;

