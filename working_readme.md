# Capital & Retirement Account Holdings and Transactions Documentation

This document explains the architecture, database schema, ledger dynamics, and UI implementation details of the Capital and Retirement Asset Holdings feature in **BAREN BUDGET (V2)**.

---

## 1. Feature Architecture

Capital and retirement accounts hold non-cash investment assets (e.g., stocks, ETFs, crypto). 
Instead of relying on database-level triggers, all financial calculations and position reconciliations are handled on the client side in the Dart application layer. This ensures that every creation, modification, or deletion of a transaction automatically and safely updates:
1. The **Holdings Table**: Reflecting correct quantities and acquisition cost basis.
2. The **Accounts Table**: Reconciling the cash balance of the custody account when buying or selling assets.

---

## 2. Database Schema

The feature maps to three main tables in Supabase:

### `assets`
Contains the master directory of all trackable assets.
* `id` (`UUID`, Primary Key)
* `symbol` (`TEXT`, Unique): Ticker symbol (e.g. `VOO`, `AAPL`).
* `name` (`TEXT`): Readable name (e.g. `Microsoft Corporation`).
* `type` (`TEXT`): Category constraint (`'stock'`, `'etf'`, `'crypto'`, `'fiat'`, or `'commodity'`).

### `holdings`
Maintains the current consolidated asset position.
* `id` (`UUID`, Primary Key)
* `account_id` (`UUID`, references `accounts` table): Custody account.
* `asset_id` (`UUID`, references `assets` table): Target asset.
* `quantity` (`FLOAT8`): Total shares/units held.
* `avg_buy_price` (`FLOAT8`): Weighted average purchase price (book value cost basis).
* `updated_at` (`TIMESTAMPTZ`): Timestamp of the last applied transaction.
* *Constraint*: `UNIQUE(account_id, asset_id)` prevents duplicate records.

### `asset_transactions`
Logs the chronological history of asset purchases, sales, and adjustments.
* `id` (`UUID`, Primary Key)
* `account_id` (`UUID`, references `accounts` table)
* `asset_id` (`UUID`, references `assets` table)
* `type` (`TEXT`): `'buy'`, `'sell'`, `'dividend_reinvest'`, `'split'`, or `'reward'`.
* `quantity` (`FLOAT8`): Count of units transacted.
* `unit_price` (`FLOAT8`): Transaction price per unit.
* `executed_at` (`TIMESTAMPTZ`): Execution date/time.

---

## 3. Ledger Dynamics and Calculations

The business logic resides in `DatabaseService` (`lib/core/services/database_service.dart`).

### Asset-Only Capital Accounts
Capital accounts hold investment assets only (e.g., stocks, ETFs, crypto) and **do not hold cash**. Across the entire application, a capital account's total value is computed strictly as the sum of the values of its asset holdings at that time based on the last cached price of each asset:
$$\text{Capital Account Total Value} = \sum_{\text{holdings}} (\text{Quantity} \times \text{Cached Price in Account Currency})$$

### Transaction Application (`_applyAssetTransactionImpact`)
When an asset transaction is logged, it updates the `holdings` table directly without impacting cash balances:
1. **Holdings Quantity**:
   - `buy`, `dividend_reinvest`, `reward`, `split`: Increases quantity (`+ quantity`).
   - `sell`: Decreases quantity (`- quantity`).
2. **Cost Basis (Average Buy Price)**:
   - **Acquisition** (`buy`, `dividend_reinvest`, `reward`): Re-calculates a new weighted average buy price:
     $$\text{New Avg Price} = \frac{(\text{Old Qty} \times \text{Old Avg Price}) + (\text{Tx Qty} \times \text{Tx Price})}{\text{Old Qty} + \text{Tx Qty}}$$
   - **Disposition** (`sell`): Quantity decreases while the unit cost basis remains unchanged.
3. **No Cash Dependency**:
   - Buying assets does not require cash in the custody account.
   - Selling assets decrements holding units without modifying custody cash balances.

### Transaction Reversal (`_reverseAssetTransactionImpact`)
When a transaction is updated or deleted:
1. **Reverses Stock Holdings**: Subtracts/adds back transacted units and recalculates or reverts the weighted cost basis.
2. **No Account Balance Mutation**: Custody accounts maintain a non-cash profile.

### Edit Operations (`saveAssetTransaction`)
An edit is processed atomically by first reversing the old transaction’s holdings impact and then applying the new transaction's impact.

---

## 4. UI Layout and User Flows

* **Assets View** (`lib/features/assets/assets_page.dart`):
  * **Tab 1: Holdings Summary**: Displays total portfolio market value and book cost, and groups active holdings under expandable custody account cards.
  * **Tab 2: Asset Transactions**: Displays paginated transaction logs with hover animations. Tapping a card opens the editing form.
* **Recording Form** (`lib/features/assets/add_asset_transaction_bottom_sheet.dart`):
  * Interactive choice chips for transaction type.
  * Validation rules ensuring valid quantities and pricing.
  * An integrated **Delete** confirmation flow (reversing all ledger balances automatically).

---

## 5. Currency API Integration and Live Valuations

To provide real-time valuation of investment assets and foreign cash, the application integrates with external API endpoints to fetch exchange rates and stock prices.

### API Routing Specifications
1. **AlphaVantage API**:
   - Primary data provider for physical/fiat currency pairs, crypto assets, and public stocks/ETFs.
   - Endpoint for physical/crypto exchange rates: `CURRENCY_EXCHANGE_RATE`
     `https://www.alphavantage.co/query?function=CURRENCY_EXCHANGE_RATE&from_currency={symbol}&to_currency=USD&apikey={apiKey}`
   - Endpoint for stocks/ETFs: `GLOBAL_QUOTE`
     `https://www.alphavantage.co/query?function=GLOBAL_QUOTE&symbol={symbol}&apikey={apiKey}`
2. **CoinMarketCap Public API**:
   - Specialized routing for **KMNO** (Kamino Finance token) via the simple price endpoint:
     `https://pro-api.coinmarketcap.com/public-api/v1/simple/price?ids=30986&convert=USD`
   - Bypasses AlphaVantage for this token to guarantee availability, parsed dynamically.

### Rate Limit and Local Cache Enforcement
To stay within free-tier limits, rates are checked **maximum twice per day**:
1. **First sync**: Automatically triggered upon app startup/login for the calendar day.
2. **Second sync**: Permitted only if at least **8 hours** have elapsed since the first sync.
All values are cached locally using `SharedPreferences` (`shared_preferences: ^2.3.2`).
Any new currency typed in Settings is added to the active checklist immediately, and its price is resolved on the next session start to prevent exceeding API rate limits.

### Multi-Currency Conversion Logic
Asset prices are cached in USD. When rendering holdings on the Assets Page, prices are converted to the parent account's local currency dynamically using the formula:
$$\text{Price in Account Currency} = \frac{\text{Asset Price in USD}}{\text{Account Currency Price in USD}}$$
This dynamically supports assets in USD or MXN accounts (e.g. VOO inside a MXN capital account is automatically valued in MXN based on the current USD/MXN rate).

### Settings & Diagnostics UI
* **Currencies Tab**: Shows active physical and crypto currencies list (USD, MXN, SOL, KMNO by default), their last fetched USD values, and a text field to add new tracking symbols.
* **API Diagnostics Tab**: Displays sync stats (e.g., `1/2 fetches today`), last update time, and a scrolling live-updating mock terminal log of all network events. A developer "Force Update Now" bypasses the time limits (triggers confirmation warnings).

---

## 6. Recurring Budget Expense Tracking & Expected Monthly Expenses UI

### Overview
The `recurring_budget` system manages recurring category spending limits, execution intervals (`frequency` and `interval`), automated period cycle rollovers, and active progress tracking via the `running_amount` column.

### Database Schema Dynamics (`recurring_budget`)
* `id` (`UUID`, Primary Key): Automation record identifier.
* `category_id` (`UUID`, references `categories`): Target expense category.
* `amount` (`FLOAT8`): Expected single transaction amount threshold.
* `frequency` (`TEXT`): Cycle period (`'daily'`, `'weekly'`, `'monthly'`, `'yearly'`).
* `interval` (`INTEGER`): Step count for frequency multiplier (e.g., `frequency = 'monthly'` with `interval = 2` means every 2 months).
* `next_due_date` (`DATE`): Date pointer indicating when the next recurring expense is due. Automatically advances by `interval` step count when an expense transaction is logged in the due month.
* `budget` (`FLOAT8`): Maximum budget threshold allocated for the category period.
* `running_amount` (`FLOAT8`): Accumulated total spent in the current active cycle period. Resets to `0.0` when a new cycle period begins.
* `status` (`TEXT`): `'active'` or `'inactive'`.

### Expense Ledger Automation (`DatabaseService`)
1. **Expense Logging (`processExpenseForRecurringBudget`)**:
   - Whenever an expense transaction is created, updated, or deleted, `DatabaseService` checks if there is an active `recurring_budget` matching the category.
   - For new expenses: `running_amount` increases by the transaction amount (`running_amount += txAmount`).
   - For deleted expenses: `running_amount` decreases by the transaction amount (`running_amount = max(0, running_amount - txAmount)`).
   - For edited expenses: `running_amount` adjusts by the net delta (`running_amount += (newTxAmount - oldTxAmount)`).
   - **`next_due_date` Advancement**: When an expense is recorded for the active cycle month, `next_due_date` advances forward by `interval` period steps (`advanceDateByFrequency`).
2. **Cycle Rollover Check (`_checkAndRolloverRecurringBudgetCycle`)**:
   - When fetching recurring budgets, the service evaluates if `DateTime.now()` has advanced into a new cycle period relative to `next_due_date`.
   - If the previous cycle has expired, `running_amount` is automatically reset to `0.0` in Supabase.
3. **Manual Checkmark Verification (Mark as Paid)**:
   - When a user clicks the checkmark on a recurring expense, it is considered paid.
   - The system generates the new `next_due_date` using `DateTime.now()` as the base date, advanced by the configured interval and frequency.
   - The `running_amount` is reset to `0.0` **only** if the `budget_end_date` is due in the current calendar month. If the `budget_end_date` ends in another month, the `running_amount` is preserved.
   - The `budget_end_date` is then updated to be the last day of the month of the newly generated `next_due_date`.
   - **Background Refresh UX**: To prevent a jarring full-page reload, the dashboard only updates the specific recurring budgets list asynchronously in the background (`_refreshRecurringBudgets`) instead of querying all accounts and showing a loading spinner.
4. **Manual Due Date Editing**:
   - The user can select "Edit next due date" from the 3-dots popup menu on the card, opening a date picker to manually set a new next due date in Supabase.
   - Updates the user interface instantly using the same background refresh pipeline.

### Dashboard UI Section (`CurrentMonthRecurringExpensesCard`)
* **Location**: Positioned directly below the "Category Expenses" card (`CategoryExpenseChartCard`) on the Dashboard.
* **Filtering**: Only displays active recurring budgets where `next_due_date` matches the current calendar month and year. This ensures cards are only visible during the month of their due date.
* **UI Elements**:
  - **Two-Row Distribution Layout**:
    - **Top Row**: Contains the Category icon, Category name, and frequency description (e.g. *"Every Month"*), alongside the action buttons (green checkmark for "Mark as Paid" and 3-dots for editing options).
    - **Bottom Row**: Separated by a subtle divider, contains the next due date (e.g. *"Due Aug 15"*) on the left, and the incurred expenses vs running budget limit (e.g. *"$250.00 spent of $1,000.00"*) on the right.
  - **Budget Overrun Indicator**: If incurred expenses exceed the budget limit, the amount spent text and the receipt icon turn red (`AppColors.cinnabar`) for visual feedback.
  - *Note*: The linear progress bar has been removed in favor of this distributed text presentation.

---

## 7. Cash Flow Overview Chart Default Settings
* **Location**: The line chart container on the Dashboard (`DashboardPage`).
* **Defaults**:
  - Time Range default: **This Month** (`currentMonth`).
  - Visualization mode default: **Daily** (`daily`).

---

## 8. Annual Expenses Summary & Transactions
* **Location**: Replaces the "Recent Transactions" section at the bottom of the Dashboard page (`DashboardPage`).
* **Logic**:
  - Automatically queries all transactions matching the current calendar month that are assigned the category **"Annual Expenses"**.
  - Displays a **Summary Banner** showing:
    - **Total Spent This Month**: Sum of the absolute values of the month's matching transactions.
    - **Transaction Count**: The number of matching transactions.
  - Lists all of the matching transactions with their description, account name, date (formatted `MMM dd, yyyy`), and amount.

---

## 9. Transaction Modal Account Filtering & Credit Card Reimbursements

### Overview
In the Transaction Modal (`AddTransactionBottomSheet` in `lib/features/transactions/add_transaction_bottom_sheet.dart`), available accounts in the Account dropdown are dynamically filtered based on the active tab:
* **Expense Tab (`tabIndex == 0`)**: Displays `credit` card accounts and `checking` accounts. Amounts are stored as negative numbers (outflows).
* **Income Tab (`tabIndex == 1`)**:
  - **Default**: Displays `liquid_assets` and `retirement` accounts. Credit card accounts are hidden by default to prevent logging standard income against credit lines.
  - **Reimbursement Special Rule**: When a category of type `'reimbursement'` or matching the name `"Reimbursement"` (e.g., Cashback, refunds, expense returns) is selected or typed in the Category search box, credit card accounts (`accountGroup == 'credit'`) are dynamically enabled. This allows logging cashback credits or reimbursements directly to credit cards (which decreases the credit card debt/balance).
  - **Auto-Reset Safeguard**: If a credit card account is selected and the category is subsequently changed to a non-reimbursement income category (e.g. Salary), the account field is automatically reset to prevent invalid entries.
* **Transfer Tab (`tabIndex == 2`)**: Displays all active accounts except capital accounts (since capital accounts hold non-cash investment assets only).

---

## 10. Capital & Retirement Account Valuation

### Overview
In the Accounts page (`AccountsPage` in `lib/features/accounts/accounts_page.dart`), accounts under the **"Capital and retirement"** section display their valuation:
* **Capital Accounts**:
  - **Asset-Based Value**: Value is calculated strictly from the sum of active asset positions held in that custody account multiplied by the current cached price in the account currency:
    $$\text{Capital Account Total Value} = \sum_{\text{holdings}} (\text{Quantity} \times \text{Cached Price in Account Currency})$$
  - **No Cash**: Capital accounts do not maintain a cash balance. Subtitles show solely the account currency (e.g., `USD`) without any cash amounts.
* **Retirement Accounts**:
  - Displays combined total value (cash balance `currentBalance` plus active asset positions).
* **Dynamic Asset Pricing**: Uses real-time cached rates from `CurrencyService` (`CurrencyService().getPrice(symbol)` with fallback to `avgBuyPrice`) converted into the account's base currency.
* **Snapshots & Archiving Consistency**:
  - `Create Snapshot` records the effective total value for all accounts (purely asset-based for capital accounts) in `account_snapshots`.
  - Archiving validation ensures capital accounts with remaining asset holdings cannot be archived until fully liquidated/reconciled (`totalValue == 0.0`).
