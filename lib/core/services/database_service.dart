import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../utils/currency_formatter.dart';

class DatabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  // --- CATEGORIES ---
  Future<List<Category>> fetchCategories() async {
    try {
      final response = await _client.from('categories').select().order('name');
      return (response as List).map((json) => Category.fromJson(json)).toList();
    } catch (e) {
      print('Supabase fetchCategories error: $e');
      rethrow;
    }
  }

  // --- ACCOUNTS ---
  Future<List<Account>> fetchAccounts() async {
    try {
      final response = await _client.from('accounts').select().order('name');
      return (response as List).map((json) => Account.fromJson(json)).toList();
    } catch (e) {
      print('Supabase fetchAccounts error: $e');
      rethrow;
    }
  }

  Future<Account> saveAccount(Account account) async {
    try {
      await _client.from('accounts').upsert(account.toJson());
      return account;
    } catch (e) {
      print('Supabase saveAccount error: $e');
      rethrow;
    }
  }

  Future<void> archiveAccount(String id) async {
    // Client-side rule: Verify balance is zero
    final accounts = await fetchAccounts();
    final account = accounts.firstWhere((acc) => acc.id == id);
    if (account.currentBalance != 0.0) {
      throw Exception('Cannot archive account. Current balance is not 0.0 (Actual: ${account.currentBalance})');
    }

    try {
      await _client.from('accounts').update({'status': 'archived'}).eq('id', id);
    } catch (e) {
      print('Supabase archiveAccount error: $e');
      rethrow;
    }
  }

  // --- TRANSACTIONS ---
  /// Fetches transactions from the Supabase database.
  /// Supports starting date constraint, text search queries (which can be a description, tag, or amount),
  /// and filtering by category types (expense, income, transfer).
  Future<List<Transaction>> fetchTransactions({
    DateTime? startDate,
    String? query,
    String? typeFilter,
    required int limit,
    required int offset,
  }) async {
    try {
      // Fetch transactions with inner-joined categories to facilitate filtering on category type
      var queryBuilder = _client
          .from('transactions')
          .select('*, accounts(name), categories!inner(name, type)');

      // Apply date constraint if specified
      if (startDate != null) {
        queryBuilder = queryBuilder.gte('date', startDate.toIso8601String());
      }
      
      // Handle search queries (supports description, tags, and transaction amount)
      if (query != null && query.trim().isNotEmpty) {
        final q = query.trim();
        final numericVal = double.tryParse(q);
        if (numericVal != null) {
          // If query is numeric, search in description, tags, or matching positive/negative transaction amounts
          final absVal = numericVal.abs();
          queryBuilder = queryBuilder.or('description.ilike.%$q%,tags.ilike.%$q%,amount.eq.$absVal,amount.eq.-$absVal');
        } else {
          // If query is text, search in description or tags
          queryBuilder = queryBuilder.or('description.ilike.%$q%,tags.ilike.%$q%');
        }
      }

      // Filter by category type based on chosen chip
      if (typeFilter != null) {
        if (typeFilter == 'expense') {
          queryBuilder = queryBuilder.inFilter('categories.type', ['expense', 'tax']);
        } else if (typeFilter == 'income') {
          queryBuilder = queryBuilder.inFilter('categories.type', ['income', 'reimbursement']);
        } else if (typeFilter == 'transfer') {
          queryBuilder = queryBuilder.eq('categories.type', 'transfer');
        }
      }

      // Execute paginated and ordered query
      final response = await queryBuilder
          .order('date', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List).map((json) => Transaction.fromJson(json)).toList();
    } catch (e) {
      print('Supabase fetchTransactions error: $e');
      rethrow;
    }
  }

  Future<Transaction> saveTransaction(Transaction tx) async {
    try {
      // Supabase insert/upsert
      await _client.from('transactions').upsert(tx.toJson());
      return tx;
    } catch (e) {
      print('Supabase saveTransaction error: $e');
      rethrow;
    }
  }

  // --- RECURRING BUDGETS ---
  Future<List<Map<String, dynamic>>> fetchActiveRecurringBudgets() async {
    try {
      final response = await _client
          .from('recurring_budget')
          .select('category_id, id')
          .eq('status', 'active');
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      print('Supabase fetchActiveRecurringBudgets error: $e');
      rethrow;
    }
  }

  // --- CATEGORIES WRITE ---
  Future<Category> saveCategory(Category category) async {
    try {
      await _client.from('categories').upsert(category.toJson());
      return category;
    } catch (e) {
      print('Supabase saveCategory error: $e');
      rethrow;
    }
  }

  // --- DELETIONS ---
  Future<void> deleteTransaction(Transaction tx) async {
    try {
      await _client.from('transactions').delete().eq('id', tx.id);
      await updateAccountBalance(tx.accountId, -tx.amount);
      
      if (tx.tags != null && tx.tags!.startsWith('transfer_pair:')) {
        final counterpart = await fetchTransferCounterpart(tx.id, tx.tags!);
        if (counterpart != null) {
          await _client.from('transactions').delete().eq('id', counterpart.id);
          await updateAccountBalance(counterpart.accountId, -counterpart.amount);
        }
      }
    } catch (e) {
      print('Supabase deleteTransaction error: $e');
      rethrow;
    }
  }

  // --- COUNTERPART ---
  Future<Transaction?> fetchTransferCounterpart(String txId, String tag) async {
    try {
      final response = await _client
          .from('transactions')
          .select('*, accounts(name), categories(name)')
          .eq('tags', tag)
          .neq('id', txId)
          .maybeSingle();
      if (response != null) {
        return Transaction.fromJson(response);
      }
      return null;
    } catch (e) {
      print('Supabase fetchTransferCounterpart error: $e');
      return null;
    }
  }

  // --- BALANCE UPDATES ---
  double _calculateNewBalance(Account account, double amountChange) {
    if (account.type == 'credit_card') {
      return account.currentBalance - amountChange;
    } else {
      return account.currentBalance + amountChange;
    }
  }

  Future<void> updateAccountBalance(String accountId, double amountChange) async {
    final response = await _client.from('accounts').select().eq('id', accountId).single();
    final account = Account.fromJson(response);
    final double newBalance = _calculateNewBalance(account, amountChange);
    await _client.from('accounts').update({'current_balance': newBalance}).eq('id', accountId);
    
    // Sync matching cash/fiat holding to reflect cash changes
    await syncFiatHolding(accountId);
  }

  Future<Transaction> saveTransactionWithBalanceUpdate(Transaction tx, {Transaction? oldTx}) async {
    try {
      await _client.from('transactions').upsert(tx.toJson());
      
      if (oldTx != null) {
        await updateAccountBalance(oldTx.accountId, -oldTx.amount);
      }
      await updateAccountBalance(tx.accountId, tx.amount);
      
      return tx;
    } catch (e) {
      print('Supabase saveTransactionWithBalanceUpdate error: $e');
      rethrow;
    }
  }

  Future<void> saveTransferWithBalanceUpdate(
    Transaction sourceTx, 
    Transaction destTx, {
    Transaction? oldSourceTx, 
    Transaction? oldDestTx,
  }) async {
    try {
      await _client.from('transactions').upsert(sourceTx.toJson());
      await _client.from('transactions').upsert(destTx.toJson());
      
      if (oldSourceTx != null) {
        await updateAccountBalance(oldSourceTx.accountId, -oldSourceTx.amount);
      }
      await updateAccountBalance(sourceTx.accountId, sourceTx.amount);
      
      if (oldDestTx != null) {
        await updateAccountBalance(oldDestTx.accountId, -oldDestTx.amount);
      }
      await updateAccountBalance(destTx.accountId, destTx.amount);
    } catch (e) {
      print('Supabase saveTransferWithBalanceUpdate error: $e');
      rethrow;
    }
  }

  // --- ACCOUNT SNAPSHOTS ---
  Future<void> createAccountSnapshots(List<AccountSnapshot> snapshots) async {
    try {
      final jsonList = snapshots.map((s) => s.toJson()).toList();
      await _client.from('account_snapshots').insert(jsonList);
    } catch (e) {
      print('Supabase createAccountSnapshots error: $e');
      rethrow;
    }
  }

  // --- HOLDINGS & ASSET TRANSACTIONS ---
  Future<List<Holding>> fetchHoldings() async {
    try {
      // Sync cash balances to fiat holdings before displaying them
      await syncAllFiatHoldings();

      final response = await _client
          .from('holdings')
          .select('*, accounts(name), assets(*)');
      return (response as List).map((json) => Holding.fromJson(json)).toList();
    } catch (e) {
      print('Supabase fetchHoldings error: $e');
      rethrow;
    }
  }

  Future<List<AssetTransaction>> fetchAssetTransactions() async {
    try {
      final response = await _client
          .from('asset_transactions')
          .select('*, accounts(name), assets(*)')
          .order('executed_at', ascending: false);
      return (response as List).map((json) => AssetTransaction.fromJson(json)).toList();
    } catch (e) {
      print('Supabase fetchAssetTransactions error: $e');
      rethrow;
    }
  }

  // --- ASSET TRANSACTION OPERATIONS & LEDGER DYNAMICS ---
  String _generateUuid() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40; // Set version 4
    values[8] = (values[8] & 0x3f) | 0x80; // Set variant
    final buffer = StringBuffer();
    for (int i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) buffer.write('-');
      buffer.write(values[i].toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  Future<List<Asset>> fetchAssets() async {
    try {
      final response = await _client.from('assets').select().order('symbol');
      return (response as List).map((json) => Asset.fromJson(json)).toList();
    } catch (e) {
      print('Supabase fetchAssets error: $e');
      rethrow;
    }
  }

  Future<Holding?> fetchHolding(String accountId, String assetId) async {
    try {
      final response = await _client
          .from('holdings')
          .select()
          .eq('account_id', accountId)
          .eq('asset_id', assetId)
          .maybeSingle();
      if (response != null) {
        return Holding.fromJson(response);
      }
      return null;
    } catch (e) {
      print('Supabase fetchHolding error: $e');
      return null;
    }
  }

  /// Saves or updates a Holding record in the database.
  Future<void> saveHolding(Holding holding) async {
    try {
      await _client.from('holdings').upsert(holding.toJson());
    } catch (e) {
      print('Supabase saveHolding error: $e');
      rethrow;
    }
  }

  /// Writes an AssetTransaction row to Supabase and computes its cascading financial impacts.
  /// If [oldTx] is supplied, it represents an edit operation, so the previous transaction's
  /// impact is completely reversed before the new transaction's impact is applied.
  Future<void> saveAssetTransaction(AssetTransaction tx, {AssetTransaction? oldTx}) async {
    try {
      final txType = tx.type.toLowerCase();
      
      // If we are buying a non-fiat asset, verify that there is enough cash (fiat holding) in the account
      if (txType == 'buy') {
        // Fetch the asset info to make sure it's not a fiat asset we're buying
        final assetResponse = await _client.from('assets').select().eq('id', tx.assetId).single();
        final asset = Asset.fromJson(assetResponse);
        
        if (asset.type != 'fiat') {
          // Fetch the account to get currency
          final accountResponse = await _client.from('accounts').select().eq('id', tx.accountId).single();
          final account = Account.fromJson(accountResponse);
          
          final fiatAsset = await fetchFiatAssetForCurrency(account.currency);
          if (fiatAsset != null) {
            final fiatHolding = await fetchHolding(tx.accountId, fiatAsset.id);
            double availableCash = fiatHolding?.quantity ?? 0.0;
            
            // If editing, add back the cash from the old transaction since we will reverse it
            if (oldTx != null && oldTx.type.toLowerCase() == 'buy') {
              availableCash += (oldTx.quantity * oldTx.unitPrice);
            }
            
            final double requiredCash = tx.quantity * tx.unitPrice;
            if (availableCash < requiredCash) {
              throw Exception(
                'Insufficient cash (${account.currency}) to buy this asset. '
                'Required: ${formatCurrency(requiredCash)}, '
                'Available: ${formatCurrency(availableCash)}'
              );
            }
          }
        }
      }

      if (oldTx != null) {
        // Step 1: Revert all balance adjustments associated with the old version
        await _reverseAssetTransactionImpact(oldTx);
      }
      // Step 2: Write the transaction row to database
      await _client.from('asset_transactions').upsert(tx.toJson());
      // Step 3: Compute and apply the new ledger balance modifications
      await _applyAssetTransactionImpact(tx);
    } catch (e) {
      print('Supabase saveAssetTransaction error: $e');
      rethrow;
    }
  }

  /// Deletes an AssetTransaction row from Supabase and reverses its financial impact.
  Future<void> deleteAssetTransaction(AssetTransaction tx) async {
    try {
      // Step 1: Revert all balance adjustments first
      await _reverseAssetTransactionImpact(tx);
      // Step 2: Delete the transaction row from database
      await _client.from('asset_transactions').delete().eq('id', tx.id);
    } catch (e) {
      print('Supabase deleteAssetTransaction error: $e');
      rethrow;
    }
  }

  /// Computes and applies ledger impact updates on cash accounts and holdings tables.
  Future<void> _applyAssetTransactionImpact(AssetTransaction tx) async {
    final txType = tx.type.toLowerCase();
    
    // --- 1. Calculate Custody Account Balance Change ---
    // Asset trades are swaps inside the custody account.
    // Buying stocks turns cash into stocks, leaving total balance unchanged.
    // Selling stocks changes total balance by the realized gain/loss (proceeds - book cost).
    // Dividend reinvestments and rewards add value, increasing total balance.
    double balanceChange = 0.0;
    if (txType == 'sell') {
      final holding = await fetchHolding(tx.accountId, tx.assetId);
      final double avgPrice = holding?.avgBuyPrice ?? tx.unitPrice;
      balanceChange = tx.quantity * (tx.unitPrice - avgPrice);
    } else if (txType == 'dividend_reinvest' || txType == 'reward') {
      balanceChange = tx.quantity * tx.unitPrice;
    }

    // --- 2. Reconcile Stock/ETF/Crypto holdings quantity & cost basis ---
    final holding = await fetchHolding(tx.accountId, tx.assetId);
    if (holding == null) {
      // If position doesn't exist, create a new holding position entry.
      double qty = tx.quantity;
      if (txType == 'sell') {
        qty = -tx.quantity;
      }
      final newHolding = Holding(
        id: _generateUuid(),
        accountId: tx.accountId,
        assetId: tx.assetId,
        quantity: qty,
        avgBuyPrice: tx.unitPrice,
        updatedAt: DateTime.now(),
      );
      await saveHolding(newHolding);
    } else {
      // Re-calculate quantities and weighted cost basis for active holdings.
      double oldQty = holding.quantity;
      double oldAvg = holding.avgBuyPrice;
      double newQty = oldQty;
      double newAvg = oldAvg;

      if (txType == 'buy' || txType == 'dividend_reinvest' || txType == 'reward') {
        // Accumulate quantities and calculate new weighted cost basis
        newQty = oldQty + tx.quantity;
        if (newQty > 0) {
          newAvg = ((oldQty * oldAvg) + (tx.quantity * tx.unitPrice)) / newQty;
        } else {
          newAvg = tx.unitPrice;
        }
      } else if (txType == 'sell') {
        // Subtract quantity. Average buy price (cost basis) does not change when selling.
        newQty = oldQty - tx.quantity;
      } else if (txType == 'split') {
        // Adjust quantity by split difference
        newQty = oldQty + tx.quantity;
      }

      final updatedHolding = Holding(
        id: holding.id,
        accountId: holding.accountId,
        assetId: holding.assetId,
        quantity: newQty,
        avgBuyPrice: newAvg,
        updatedAt: DateTime.now(),
      );
      await saveHolding(updatedHolding);
    }

    // --- 3. Update account current_balance and trigger fiat cash sync ---
    // This updates the accounts table and invokes syncFiatHolding.
    // It must run after holdings are updated so syncFiatHolding sees the correct non-cash book values.
    await updateAccountBalance(tx.accountId, balanceChange);
  }

  /// Subtracts/Reverses a transaction's ledger impact on custody cash and active holdings.
  Future<void> _reverseAssetTransactionImpact(AssetTransaction tx) async {
    final txType = tx.type.toLowerCase();
    
    // --- 1. Calculate balance change reversal ---
    double balanceChange = 0.0;
    if (txType == 'sell') {
      final holding = await fetchHolding(tx.accountId, tx.assetId);
      final double avgPrice = holding?.avgBuyPrice ?? tx.unitPrice;
      balanceChange = -(tx.quantity * (tx.unitPrice - avgPrice));
    } else if (txType == 'dividend_reinvest' || txType == 'reward') {
      balanceChange = -(tx.quantity * tx.unitPrice);
    }

    // --- 2. holdings Reversal ---
    final holding = await fetchHolding(tx.accountId, tx.assetId);
    if (holding != null) {
      double oldQty = holding.quantity;
      double oldAvg = holding.avgBuyPrice;
      double newQty = oldQty;
      double newAvg = oldAvg;

      if (txType == 'buy' || txType == 'dividend_reinvest' || txType == 'reward') {
        // Reverse quantity subtraction
        newQty = oldQty - tx.quantity;
        if (newQty > 0) {
          // De-weighted cost basis calculation formula
          newAvg = ((oldQty * oldAvg) - (tx.quantity * tx.unitPrice)) / newQty;
        } else {
          newAvg = 0.0;
        }
      } else if (txType == 'sell') {
        // Add back units cleared by the sell
        newQty = oldQty + tx.quantity;
      } else if (txType == 'split') {
        newQty = oldQty - tx.quantity;
      }

      final updatedHolding = Holding(
        id: holding.id,
        accountId: holding.accountId,
        assetId: holding.assetId,
        quantity: newQty,
        avgBuyPrice: newAvg,
        updatedAt: DateTime.now(),
      );
      await saveHolding(updatedHolding);
    }

    // --- 3. Revert custody account balance and trigger fiat holding sync ---
    await updateAccountBalance(tx.accountId, balanceChange);
  }

  /// Locates the master fiat asset row corresponding to a given currency code.
  /// Used to map account currency (USD or MXN) to its respective fiat holding entry.
  Future<Asset?> fetchFiatAssetForCurrency(String currency) async {
    try {
      final response = await _client
          .from('assets')
          .select()
          .eq('symbol', currency)
          .eq('type', 'fiat')
          .maybeSingle();
      if (response != null) {
        return Asset.fromJson(response);
      }
      return null;
    } catch (e) {
      print('Supabase fetchFiatAssetForCurrency error: $e');
      return null;
    }
  }

  /// Reconciles the cash position of a capital or retirement account with the holdings table.
  /// Retrieves the current cash balance (`current_balance`) of the custody account and updates
  /// the quantity of its matching fiat asset holding (symbol matching the currency code: USD/MXN).
  /// This ensures that cash shifts from transfers, income, or stock sales are accurately reflected in holdings.
  Future<void> syncFiatHolding(String accountId) async {
    try {
      final response = await _client.from('accounts').select().eq('id', accountId).single();
      final account = Account.fromJson(response);
      
      // Sync rules only apply to capital and retirement accounts holding investment assets
      final isCapitalOrRetirement = account.accountGroup == 'capital' || account.accountGroup == 'retirement';
      if (!isCapitalOrRetirement) return;

      final fiatAsset = await fetchFiatAssetForCurrency(account.currency);
      if (fiatAsset == null) {
        print('Fiat asset metadata not found in database for currency ${account.currency}');
        return;
      }

      // Fetch all holdings for this account to calculate non-cash book value sum
      // Filter out the fiat asset itself to avoid self-reference
      final holdingsResponse = await _client
          .from('holdings')
          .select()
          .eq('account_id', accountId)
          .neq('asset_id', fiatAsset.id);
      
      final holdingsList = (holdingsResponse as List).map((json) => Holding.fromJson(json)).toList();
      
      double nonCashBookValue = 0.0;
      for (final h in holdingsList) {
        nonCashBookValue += (h.quantity * h.avgBuyPrice);
      }

      // Loose cash quantity is the total account balance minus stock/ETF/crypto positions value
      final double cashQuantity = account.currentBalance - nonCashBookValue;

      final holding = await fetchHolding(accountId, fiatAsset.id);
      if (holding == null) {
        // Create new cash/fiat asset holding position
        final newHolding = Holding(
          id: _generateUuid(),
          accountId: accountId,
          assetId: fiatAsset.id,
          quantity: cashQuantity,
          avgBuyPrice: 1.0, // Fiat book value cost basis is always 1.0
          updatedAt: DateTime.now(),
        );
        await saveHolding(newHolding);
      } else {
        // Update existing cash position quantity to match residual balance
        final updatedHolding = Holding(
          id: holding.id,
          accountId: holding.accountId,
          assetId: holding.assetId,
          quantity: cashQuantity,
          avgBuyPrice: 1.0,
          updatedAt: DateTime.now(),
        );
        await saveHolding(updatedHolding);
      }
    } catch (e) {
      print('Error in syncFiatHolding: $e');
    }
  }

  /// Scans all active accounts and synchronizes their cash balances with the holdings database.
  /// Invoked during loading/retrieving holdings, serving as a self-healing sweep of legacy balances.
  Future<void> syncAllFiatHoldings() async {
    try {
      final accounts = await fetchAccounts();
      for (final account in accounts) {
        if (account.accountGroup == 'capital' || account.accountGroup == 'retirement') {
          await syncFiatHolding(account.id);
        }
      }
    } catch (e) {
      print('Error in syncAllFiatHoldings: $e');
    }
  }
}


