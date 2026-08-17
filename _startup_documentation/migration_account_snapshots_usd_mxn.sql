-- ============================================================================
-- Supabase SQL Migration Script: account_snapshots dual currency adjustment
-- Project: budget_app_v2
-- ============================================================================

-- 1. Rename existing 'balance' column to 'balance_mxn'
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name='account_snapshots' AND column_name='balance'
    ) THEN
        ALTER TABLE account_snapshots RENAME COLUMN balance TO balance_mxn;
    END IF;
END $$;

-- 2. Add 'balance_usd' column if it does not exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name='account_snapshots' AND column_name='balance_usd'
    ) THEN
        ALTER TABLE account_snapshots ADD COLUMN balance_usd FLOAT8 NOT NULL DEFAULT 0.0;
    END IF;
END $$;

-- Verify table schema
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'account_snapshots';
