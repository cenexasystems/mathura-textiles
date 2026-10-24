-- Migration: 20261024_0028_sync_cost_price_and_low_stock_alert.sql
-- Description: Ensure single purchase_price (cost price) and low_stock_alert columns exist on products and variants.

-- 1. Ensure purchase_price and low_stock_alert exist on products
ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS purchase_price NUMERIC(12,2) NOT NULL DEFAULT 0;

ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS low_stock_alert NUMERIC(12,3) NOT NULL DEFAULT 5;

-- 2. Ensure purchase_price exists on product_variants
ALTER TABLE public.product_variants
ADD COLUMN IF NOT EXISTS purchase_price NUMERIC(12,2) DEFAULT 0;

-- 3. If an old/separate cost_price column exists from earlier experiments, merge it into purchase_price and drop it
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'products' AND column_name = 'cost_price'
  ) THEN
    UPDATE public.products 
    SET purchase_price = cost_price 
    WHERE (purchase_price IS NULL OR purchase_price = 0) AND cost_price > 0;

    ALTER TABLE public.products DROP COLUMN IF EXISTS cost_price;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'product_variants' AND column_name = 'cost_price'
  ) THEN
    UPDATE public.product_variants 
    SET purchase_price = cost_price 
    WHERE (purchase_price IS NULL OR purchase_price = 0) AND cost_price > 0;

    ALTER TABLE public.product_variants DROP COLUMN IF EXISTS cost_price;
  END IF;
END $$;

-- 4. Clean up any existing NULL or zero threshold values
UPDATE public.products
SET purchase_price = 0
WHERE purchase_price IS NULL;

UPDATE public.products
SET low_stock_alert = 5
WHERE low_stock_alert IS NULL OR low_stock_alert <= 0;

UPDATE public.product_variants
SET purchase_price = 0
WHERE purchase_price IS NULL;

-- 5. Instruct Supabase PostgREST to reload schema cache
NOTIFY pgrst, 'reload schema';
