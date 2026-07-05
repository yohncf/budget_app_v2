import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

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
  Future<List<Transaction>> fetchTransactions({
    DateTime? startDate,
    String? query,
    required int limit,
    required int offset,
  }) async {
    try {
      var queryBuilder = _client
          .from('transactions')
          .select('*, accounts(name), categories(name)');

      if (startDate != null) {
        queryBuilder = queryBuilder.gte('date', startDate.toIso8601String());
      }
      if (query != null && query.trim().isNotEmpty) {
        final q = query.trim();
        // Supabase Postgres full text search or simple custom or filter
        queryBuilder = queryBuilder.or('description.ilike.%$q%,tags.ilike.%$q%');
      }

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
}
