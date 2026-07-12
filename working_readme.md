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

### Residual Cash & Currency Sync
Rather than tracking loose cash as an independent variable, the system defines it as the residual cash of the account's total value after subtracting the book value of all non-cash holdings:
$$\text{Loose Cash (Fiat Holding Quantity)} = \text{Account current\_balance} - \sum_{\text{non-cash holdings}} (\text{Quantity} \times \text{Average Buy Price})$$
The symbol of the fiat holding matches the account's currency (`USD` or `MXN`).

### Transaction Application (`_applyAssetTransactionImpact`)
When an asset transaction is logged, it changes the holdings and custody account total balance (`current_balance`) according to these rules:
1. **Custody Account Balance (`current_balance`)**:
   - **BUY** & **SPLIT**: Net balance change is `0.0`. Cash is swapped for stock value, leaving total value unchanged.
   - **SELL**: Realized profit/loss is added/subtracted: `quantity * (unitPrice - avgBuyPrice)`.
   - **DIVIDEND REINVEST** & **REWARD**: The total value is increased by the incoming asset amount: `quantity * unitPrice`.
2. **Holdings Quantity**:
   - `buy`, `dividend_reinvest`, `reward`, `split`: Increases quantity (`+ quantity`).
   - `sell`: Decreases quantity (`- quantity`).
3. **Cost Basis (Average Buy Price)**:
   - **Acquisition** (`buy`, `dividend_reinvest`, `reward`): Re-calculates a new weighted average buy price:
     $$\text{New Avg Price} = \frac{(\text{Old Qty} \times \text{Old Avg Price}) + (\text{Tx Qty} \times \text{Tx Price})}{\text{Old Qty} + \text{Tx Qty}}$$
   - **Disposition** (`sell`): Quantity decreases but cost basis remains unchanged.
4. **Fiat Holding Sync**:
   - After updating the target stock holding and custody account balance, `syncFiatHolding` is invoked. It recalculates the loose cash using the residual formula and updates the matching `USD` or `MXN` holding in the database.

### Transaction Reversal (`_reverseAssetTransactionImpact`)
When a transaction is updated or deleted:
1. **Reverses Account Balance**: Reverts the balance change (e.g. SELL subtracts the realized gain; DIVIDEND reinvest subtracts its value).
2. **Reverses Stock Holdings**: Subtracts/adds back transacted stock units and de-weights the cost basis.
3. **Reverses Fiat Holding**: Recalculates loose cash residual.

### Edit Operations (`saveAssetTransaction`)
An edit is processed atomically by first reversing the old transaction’s impact and then applying the new transaction's impact.

### Advanced Cash Validation

To maintain high data integrity, the system implements the following advanced restrictions:
1. **Purchase Cash Validation**:
   - Assets of type stock, ETF, or crypto can only be purchased if the custody account has sufficient available cash (represented by the matching `fiat` holding).
   - Validation occurs both on the client side (before submitting the form, showing a warning snackbar) and on the service layer (raising a runtime exception to abort illegal saves).
2. **Inflows/Transfers Auto-Sync**:
   - When a transfer is made to a capital/retirement account, or any other income occurs, the account balance changes, which immediately triggers the fiat holdings sync. This automatically reflects the cash inflow in the holdings table without double-charging the account.

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

