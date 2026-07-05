-- Supabase PostgreSQL Database Schema
-- Optimized with UUID Primary Keys, Check Constraints, Relational Integrity, and Automatic Triggers

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. CATEGORIES TABLE
CREATE TABLE categories (
    id UUID PRIMARY KEY,
    name TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('income', 'expense', 'transfer', 'tax', 'reimbursement')),
    parent_id UUID REFERENCES categories(id) ON DELETE SET NULL,
    icon TEXT,
    color_hex TEXT CHECK (color_hex SIMILAR TO '#[0-9a-fA-F]{6}' OR color_hex IS NULL),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. ACCOUNTS TABLE
CREATE TABLE accounts (
    id UUID PRIMARY KEY,
    name TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('checking', 'savings', 'credit_card', 'investment', 'crypto_wallet', 'cash')),
    institution TEXT NOT NULL,
    currency VARCHAR(3) NOT NULL CHECK (length(currency) = 3),
    current_balance FLOAT8 NOT NULL DEFAULT 0.0,
    "limit" FLOAT8 NOT NULL DEFAULT 0.0 CHECK ("limit" >= 0.0),
    account_group TEXT NOT NULL CHECK (account_group IN ('liquid_assets', 'credit', 'capital','retirement')),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'archived')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    -- Multi-conditional rule: Cannot archive an account if balance is not zero
    CONSTRAINT check_archived_zero_balance CHECK (
        (status != 'archived') OR (status = 'archived' AND current_balance = 0.0)
    )
);

-- 3. ASSETS TABLE
CREATE TABLE assets (
    id UUID PRIMARY KEY,
    symbol TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('stock', 'etf', 'crypto', 'fiat', 'commodity'))
);

-- 4. RECURRING_BUDGET TABLE
CREATE TABLE recurring_budget (
    id UUID PRIMARY KEY,
    category_id UUID NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    amount FLOAT8 NOT NULL CHECK (amount >= 0.0),
    frequency TEXT NOT NULL CHECK (frequency IN ('daily', 'weekly', 'monthly', 'yearly')),
    interval INTEGER NOT NULL DEFAULT 1 CHECK (interval > 0),
    start_date DATE NOT NULL,
    end_date DATE,
    next_due_date DATE,
    budget FLOAT8 NOT NULL CHECK (budget >= 0.0),
    budget_period TEXT NOT NULL CHECK (budget_period IN ('daily', 'weekly', 'monthly', 'yearly')),
    budget_end_date DATE,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    -- Multi-conditional rule: End date must be after or equal to start date if present
    CONSTRAINT check_budget_dates CHECK (end_date IS NULL OR end_date >= start_date)
);

-- 5. TRANSACTIONS TABLE
CREATE TABLE transactions (
    id UUID PRIMARY KEY,
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    category_id UUID NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
    amount FLOAT8 NOT NULL,
    currency VARCHAR(3) NOT NULL CHECK (length(currency) = 3),
    exchange_rate FLOAT8 NOT NULL DEFAULT 1.0 CHECK (exchange_rate > 0),
    date TIMESTAMPTZ NOT NULL,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'cleared' CHECK (status IN ('pending', 'cleared', 'reconciled')),
    is_recurring BOOLEAN NOT NULL DEFAULT FALSE,
    recurring_id UUID REFERENCES recurring_budget(id) ON DELETE SET NULL,
    tags TEXT,
    sheets_row_id INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    -- Multi-conditional rule: If is_recurring is TRUE, recurring_id must NOT be NULL
    CONSTRAINT check_recurring_conditional CHECK (
        (is_recurring = FALSE) OR (is_recurring = TRUE AND recurring_id IS NOT NULL)
    )
);

-- 6. ACCOUNT_SNAPSHOTS TABLE
CREATE TABLE account_snapshots (
    id UUID PRIMARY KEY,
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    snapshot_date TIMESTAMPTZ NOT NULL,
    balance FLOAT8 NOT NULL
);

-- 7. HOLDINGS TABLE
CREATE TABLE holdings (
    id UUID PRIMARY KEY,
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    asset_id UUID NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
    quantity FLOAT8 NOT NULL DEFAULT 0.0,
    avg_buy_price FLOAT8 NOT NULL DEFAULT 0.0 CHECK (avg_buy_price >= 0.0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(account_id, asset_id)
);

-- 8. ASSET_TRANSACTIONS TABLE
CREATE TABLE asset_transactions (
    id UUID PRIMARY KEY,
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    asset_id UUID NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('buy', 'sell', 'dividend_reinvest', 'split', 'reward')),
    quantity FLOAT8 NOT NULL CHECK (quantity >= 0.0),
    unit_price FLOAT8 NOT NULL CHECK (unit_price >= 0.0),
    executed_at TIMESTAMPTZ NOT NULL
);

-- TRIGGERS
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_accounts_modtime BEFORE UPDATE ON accounts FOR EACH ROW EXECUTE PROCEDURE update_modified_column();
CREATE TRIGGER update_holdings_modtime BEFORE UPDATE ON holdings FOR EACH ROW EXECUTE PROCEDURE update_modified_column();

-- ACCOUNT DELETION SAFEGUARD (Cannot delete account if balance != 0.0)
CREATE OR REPLACE FUNCTION prevent_non_zero_account_deletion()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.current_balance != 0.0 THEN
        RAISE EXCEPTION 'Cannot delete account (%). Current balance is not 0.0', OLD.name;
    END IF;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_account_zero_balance_before_delete
BEFORE DELETE ON accounts
FOR EACH ROW
EXECUTE PROCEDURE prevent_non_zero_account_deletion();
