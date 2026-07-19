# Budget Application Database Documentation (V2 - Clean Architecture)
This document outlines the architecture, relationships, constraints, and operational integrity rules for your **Supabase (PostgreSQL)** database. All legacy IDs (`fire_id`, `old_id`) have been successfully removed for a clean slate.

---

## Architectural Integrity & Business Logic Enhancements

1. **Clean Slate Primary Keys**: All records now exclusively rely on `UUID` identifiers.
2. **Account Deletion Safeguard (Trigger)**: A PostgreSQL `BEFORE DELETE` trigger is attached to the `accounts` table. If you attempt to delete an account whose `current_balance` is not exactly `0.0`, the database will automatically abort the transaction and throw an error (`Cannot delete account. Current balance is not 0.0`).
3. **Account Archive Safeguard (Check Constraint)**: The `accounts` table has a strict multi-conditional rule on archiving: `(status != 'archived') OR (status = 'archived' AND current_balance = 0.0)`. You cannot set an account's status to `archived` if there are still active funds in it.

---

## Detailed Table Schemas & Data Constraints

### 1. `categories`
| Column | Data Type | Constraint | Explanation / Rules |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY` | Unique node identifier. |
| `name` | `TEXT` | `NOT NULL` | The readable label of the category. |
| `type` | `TEXT` | `NOT NULL`, `CHECK` | Restricted to exactly: `'income'`, `'expense'`, or `'transfer'`. |
| `parent_id` | `UUID` | `REFERENCES` | Maps sub-categories to parent classes (`ON DELETE SET NULL`). |
| `icon` | `TEXT` | `NULL` allowed | System string pointer for front-end iconography. |
| `color_hex` | `TEXT` | `CHECK` | Strict alphanumeric regex match for standard hexadecimal values (`#FFFFFF`). |
| `created_at` | `TIMESTAMPTZ`| `NOT NULL` | Defaults to server execution time. |

### 2. `accounts`
| Column | Data Type | Constraint | Explanation / Rules |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY` | Unique ledger node identifier. |
| `name` | `TEXT` | `NOT NULL` | Descriptive name (e.g., 'Emergency Fund'). |
| `type` | `TEXT` | `NOT NULL`, `CHECK` | `checking`, `savings`, `credit_card`, `investment`, `crypto_wallet`, `cash`. |
| `institution` | `TEXT` | `NOT NULL` | Financial institution provider name. |
| `currency` | `VARCHAR(3)`| `NOT NULL`, `CHECK` | 3-character ISO identifier validation string (e.g., `MXN`). |
| `current_balance`| `FLOAT8` | `NOT NULL` | Total clear valuation. |
| `limit` | `FLOAT8` | `NOT NULL`, `CHECK` | Maximum credit threshold (`>= 0.0`). |
| `account_group` | `TEXT` | `NOT NULL`, `CHECK` | `liquid_assets`, `credit`, or `capital`. |
| `status` | `TEXT` | `NOT NULL`, `CHECK` | `active`, `inactive`, or `archived`. |
| `created_at` | `TIMESTAMPTZ`| `NOT NULL` | Inception timestamp. |
| `updated_at` | `TIMESTAMPTZ`| `NOT NULL` | Automatically maintained by triggers. |

**Multi-Conditional Table Constraints:**
- **`check_archived_zero_balance`**: Validates `status` against `current_balance`. An account can only be flagged as `archived` if the balance has been reconciled to `0.0`.
- **`check_account_zero_balance_before_delete`** (Trigger): Completely blocks `DELETE` operations on any row unless the balance is zero.

### 3. `assets`
| Column | Data Type | Constraint | Explanation / Rules |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY` | Unique identity. |
| `symbol` | `TEXT` | `NOT NULL`, `UNIQUE`| Unique ticker or tracking acronym (`VOO`, `NVDA`). |
| `name` | `TEXT` | `NOT NULL` | Full corporate or asset denomination. |
| `type` | `TEXT` | `NOT NULL`, `CHECK` | `'stock'`, `'etf'`, `'crypto'`, `'fiat'`, or `'commodity'`. |

### 4. `recurring_budget`
| Column | Data Type | Constraint | Explanation / Rules |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY` | Unique automation entity key. |
| `category_id` | `UUID` | `NOT NULL`, `REF` | Maps target constraints to standard categories (`ON DELETE CASCADE`). |
| `amount` | `FLOAT8` | `NOT NULL`, `CHECK` | Financial value threshold (`>= 0.0`). |
| `frequency` | `TEXT` | `NOT NULL`, `CHECK` | Operational run interval. |
| `interval` | `INTEGER` | `NOT NULL`, `CHECK` | Period step counts (`> 0`). |
| `start_date` | `DATE` | `NOT NULL` | Horizon initiation date (Y-M-D). |
| `end_date` | `DATE` | `NULL` allowed | Terminating threshold date. |
| `next_due_date` | `DATE` | `NULL` allowed | System automated execution state pointer. |
| `budget` | `FLOAT8` | `NOT NULL`, `CHECK` | Designated maximum budget allocation amount (`>= 0.0`). |
| `running_amount` | `FLOAT8` | `NOT NULL`, `CHECK` | Accumulated spent amount in active cycle (`>= 0.0`). Resets on cycle rollover. |
| `budget_period` | `TEXT` | `NOT NULL`, `CHECK` | Frequency grouping mapping. |
| `budget_end_date`| `DATE` | `NULL` allowed | Target final date bounds. |
| `status` | `TEXT` | `NOT NULL`, `CHECK` | `'active'` or `'inactive'`. |
| `description` | `TEXT` | `NULL` allowed | Metadata and contextual descriptions. |
| `created_at` | `TIMESTAMPTZ`| `NOT NULL` | Engine record compilation date. |

**Multi-Conditional Table Constraints:**
- **`check_budget_dates`**: Prevents chronological corruption where `end_date` occurs before `start_date`.

### 5. `transactions`
| Column | Data Type | Constraint | Explanation / Rules |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY` | Unique transaction fingerprint string. |
| `account_id` | `UUID` | `NOT NULL`, `REF` | Account boundary origin (`ON DELETE CASCADE`). |
| `category_id` | `UUID` | `NOT NULL`, `REF` | Relational reference (`ON DELETE RESTRICT`). |
| `amount` | `FLOAT8` | `NOT NULL` | Signed ledger line total. Outflows are negative; inflows are positive. |
| `currency` | `VARCHAR(3)`| `NOT NULL`, `CHECK` | Standard three-letter transactional ISO code. |
| `exchange_rate` | `FLOAT8` | `NOT NULL`, `CHECK` | Numerical scaling scalar for foreign calculations (`> 0`). |
| `date` | `TIMESTAMPTZ`| `NOT NULL` | System transactional action timeline node. |
| `description` | `TEXT` | `NULL` allowed | Detail memo lines. |
| `status` | `TEXT` | `NOT NULL`, `CHECK` | Cleared state machine: `'pending'`, `'cleared'`, or `'reconciled'`. |
| `is_recurring` | `BOOLEAN` | `NOT NULL` | Logic flag tracking structural scheduling status. |
| `recurring_id` | `UUID` | `NULL` allowed | Connects execution to parent budget schedules (`ON DELETE SET NULL`). |
| `tags` | `TEXT` | `NULL` allowed | Freeform text parsing tags. |
| `sheets_row_id` | `INTEGER` | `NULL` allowed | Legacy spreadsheet mapping ID logic. |
| `created_at` | `TIMESTAMPTZ`| `NOT NULL` | Ledger ingestion execution time. |

**Multi-Conditional Table Constraints:**
- **`check_recurring_conditional`**: Enforces strict state tracking: if `is_recurring` is `TRUE`, it is physically impossible to save it without a direct link to the `recurring_id`.

### 6. `account_snapshots`
| Column | Data Type | Constraint | Explanation / Rules |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY` | Unique log identity token. |
| `account_id` | `UUID` | `NOT NULL`, `REF` | Target account (`ON DELETE CASCADE`). |
| `snapshot_date` | `TIMESTAMPTZ`| `NOT NULL` | Historical moment node representing balances. |
| `balance` | `FLOAT8` | `NOT NULL` | Exact balance on target date. |

### 7. `holdings`
| Column | Data Type | Constraint | Explanation / Rules |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY` | Unique balance tracking record key. |
| `account_id` | `UUID` | `NOT NULL`, `REF` | Destination investment custody link (`ON DELETE CASCADE`). |
| `asset_id` | `UUID` | `NOT NULL`, `REF` | Target asset directory link (`ON DELETE CASCADE`). |
| `quantity` | `FLOAT8` | `NOT NULL` | Fractional asset unit count. |
| `avg_buy_price` | `FLOAT8` | `NOT NULL`, `CHECK` | Dollar/Peso cost basis index marker (`>= 0.0`). |
| `updated_at` | `TIMESTAMPTZ`| `NOT NULL` | Triggered mutation tracking marker. |

**Relational Unique Identity Rules:**
- **`UNIQUE(account_id, asset_id)`**: An account cannot maintain duplicate holding row entries for the exact same asset. 

### 8. `asset_transactions`
| Column | Data Type | Constraint | Explanation / Rules |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY` | Unique tracking identification token. |
| `account_id` | `UUID` | `NOT NULL`, `REF` | Active account executing the transaction (`ON DELETE CASCADE`). |
| `asset_id` | `UUID` | `NOT NULL`, `REF` | Target asset record (`ON DELETE CASCADE`). |
| `type` | `TEXT` | `NOT NULL`, `CHECK` | `'buy'`, `'sell'`, `'dividend_reinvest'`, `'split'`, or `'reward'`. |
| `quantity` | `FLOAT8` | `NOT NULL`, `CHECK` | Order unit quantity size (`>= 0.0`). |
| `unit_price` | `FLOAT8` | `NOT NULL`, `CHECK` | Transaction execution clearing price point (`>= 0.0`). |
| `executed_at` | `TIMESTAMPTZ`| `NOT NULL` | Exact execution clock time. |
