class Category {
  final String id;
  final String name;
  final String type; // 'income', 'expense', 'transfer', 'tax', 'reimbursement'
  final String? parentId;
  final String? icon;
  final String? colorHex;
  final DateTime createdAt;

  Category({
    required this.id,
    required this.name,
    required this.type,
    this.parentId,
    this.icon,
    this.colorHex,
    required this.createdAt,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      parentId: json['parent_id'] as String?,
      icon: json['icon'] as String?,
      colorHex: json['color_hex'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'parent_id': parentId,
      'icon': icon,
      'color_hex': colorHex,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class Account {
  final String id;
  final String name;
  final String type; // 'checking', 'savings', 'credit_card', 'investment', 'crypto_wallet', 'cash'
  final String institution;
  final String currency;
  final double currentBalance;
  final double limit;
  final String accountGroup; // 'liquid_assets', 'credit', 'capital', 'retirement'
  final String status; // 'active', 'inactive', 'archived'
  final DateTime createdAt;
  final DateTime updatedAt;

  Account({
    required this.id,
    required this.name,
    required this.type,
    required this.institution,
    required this.currency,
    required this.currentBalance,
    required this.limit,
    required this.accountGroup,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      institution: json['institution'] as String,
      currency: json['currency'] as String,
      currentBalance: (json['current_balance'] as num).toDouble(),
      limit: (json['limit'] as num).toDouble(),
      accountGroup: json['account_group'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'institution': institution,
      'currency': currency,
      'current_balance': currentBalance,
      'limit': limit,
      'account_group': accountGroup,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Account copyWith({
    String? name,
    String? type,
    String? institution,
    String? currency,
    double? currentBalance,
    double? limit,
    String? accountGroup,
    String? status,
  }) {
    return Account(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      institution: institution ?? this.institution,
      currency: currency ?? this.currency,
      currentBalance: currentBalance ?? this.currentBalance,
      limit: limit ?? this.limit,
      accountGroup: accountGroup ?? this.accountGroup,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

class Transaction {
  final String id;
  final String accountId;
  final String categoryId;
  final double amount;
  final String currency;
  final double exchangeRate;
  final DateTime date;
  final String? description;
  final String status; // 'pending', 'cleared', 'reconciled'
  final bool isRecurring;
  final String? recurringId;
  final String? tags;
  final int? sheetsRowId;
  final DateTime createdAt;

  // UI presentation helper properties (joined from DB)
  final String? accountName;
  final String? categoryName;
  final String? categoryType;

  Transaction({
    required this.id,
    required this.accountId,
    required this.categoryId,
    required this.amount,
    required this.currency,
    required this.exchangeRate,
    required this.date,
    this.description,
    required this.status,
    required this.isRecurring,
    this.recurringId,
    this.tags,
    this.sheetsRowId,
    required this.createdAt,
    this.accountName,
    this.categoryName,
    this.categoryType,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    // Check if account / category tables are joined under keys
    final accountData = json['accounts'] as Map<String, dynamic>?;
    final categoryData = json['categories'] as Map<String, dynamic>?;

    return Transaction(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      categoryId: json['category_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String,
      exchangeRate: (json['exchange_rate'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      description: json['description'] as String?,
      status: json['status'] as String,
      isRecurring: json['is_recurring'] as bool? ?? false,
      recurringId: json['recurring_id'] as String?,
      tags: json['tags'] as String?,
      sheetsRowId: json['sheets_row_id'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      accountName: accountData != null ? accountData['name'] as String? : json['account_name'] as String?,
      categoryName: categoryData != null ? categoryData['name'] as String? : json['category_name'] as String?,
      categoryType: categoryData != null ? categoryData['type'] as String? : json['category_type'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_id': accountId,
      'category_id': categoryId,
      'amount': amount,
      'currency': currency,
      'exchange_rate': exchangeRate,
      'date': date.toIso8601String(),
      'description': description,
      'status': status,
      'is_recurring': isRecurring,
      'recurring_id': recurringId,
      'tags': tags,
      'sheets_row_id': sheetsRowId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Transaction copyWith({
    String? accountId,
    String? categoryId,
    double? amount,
    String? currency,
    double? exchangeRate,
    DateTime? date,
    String? description,
    String? status,
    bool? isRecurring,
    String? recurringId,
    String? tags,
    String? accountName,
    String? categoryName,
  }) {
    return Transaction(
      id: id,
      accountId: accountId ?? this.accountId,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      date: date ?? this.date,
      description: description ?? this.description,
      status: status ?? this.status,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringId: recurringId ?? this.recurringId,
      tags: tags ?? this.tags,
      sheetsRowId: sheetsRowId,
      createdAt: createdAt,
      accountName: accountName ?? this.accountName,
      categoryName: categoryName ?? this.categoryName,
    );
  }
}

class AccountSnapshot {
  final String id;
  final String accountId;
  final DateTime snapshotDate;
  final double balance;

  AccountSnapshot({
    required this.id,
    required this.accountId,
    required this.snapshotDate,
    required this.balance,
  });

  factory AccountSnapshot.fromJson(Map<String, dynamic> json) {
    return AccountSnapshot(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      snapshotDate: DateTime.parse(json['snapshot_date'] as String),
      balance: (json['balance'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_id': accountId,
      'snapshot_date': snapshotDate.toIso8601String(),
      'balance': balance,
    };
  }
}

/// Represents an investable asset (e.g. stock ticker, ETF, crypto, fiat currency, or commodity)
/// mapped to the `assets` table in Supabase.
class Asset {
  final String id;
  final String symbol; // E.g., 'VOO', 'MSFT', 'BTC'
  final String name;   // E.g., 'Vanguard S&P 500 ETF'
  final String type;   // E.g., 'etf', 'stock', 'crypto', 'fiat', 'commodity'

  Asset({
    required this.id,
    required this.symbol,
    required this.name,
    required this.type,
  });

  factory Asset.fromJson(Map<String, dynamic> json) {
    return Asset(
      id: json['id'] as String,
      symbol: json['symbol'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'symbol': symbol,
      'name': name,
      'type': type,
    };
  }
}

/// Represents the net accumulated position of a specific asset within a custody account.
/// Summarizes transaction history in the `holdings` table, supporting cost basis calculations.
class Holding {
  final String id;
  final String accountId;    // The custody account holding the asset (referencing the accounts table)
  final String assetId;      // The target asset (referencing the assets table)
  final double quantity;     // Fractional units held (can be negative if shorted/empty)
  final double avgBuyPrice;  // The calculated cost basis/weighted average acquisition price
  final DateTime updatedAt;  // Timestamp of the last applied transaction adjustment

  // UI presentation fields populated via database joins
  final String? accountName;
  final Asset? asset;

  Holding({
    required this.id,
    required this.accountId,
    required this.assetId,
    required this.quantity,
    required this.avgBuyPrice,
    required this.updatedAt,
    this.accountName,
    this.asset,
  });

  factory Holding.fromJson(Map<String, dynamic> json) {
    final accountData = json['accounts'] as Map<String, dynamic>?;
    final assetData = json['assets'] as Map<String, dynamic>?;

    return Holding(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      assetId: json['asset_id'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      avgBuyPrice: (json['avg_buy_price'] as num).toDouble(),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      accountName: accountData != null ? accountData['name'] as String? : null,
      asset: assetData != null ? Asset.fromJson(assetData) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_id': accountId,
      'asset_id': assetId,
      'quantity': quantity,
      'avg_buy_price': avgBuyPrice,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Logs individual buy, sell, or adjustment operations for an asset in a specific account.
/// Mapped directly to the `asset_transactions` table in Supabase.
class AssetTransaction {
  final String id;
  final String accountId;   // The account execution cash flow and custody (referencing accounts)
  final String assetId;     // The target asset (referencing assets)
  final String type;        // 'buy', 'sell', 'dividend_reinvest', 'split', 'reward'
  final double quantity;    // Count of units cleared in the operation
  final double unitPrice;   // Transaction execution clearing price point
  final DateTime executedAt;// Exact timestamp of the operation

  // UI presentation fields populated via database joins
  final String? accountName;
  final Asset? asset;

  AssetTransaction({
    required this.id,
    required this.accountId,
    required this.assetId,
    required this.type,
    required this.quantity,
    required this.unitPrice,
    required this.executedAt,
    this.accountName,
    this.asset,
  });

  factory AssetTransaction.fromJson(Map<String, dynamic> json) {
    final accountData = json['accounts'] as Map<String, dynamic>?;
    final assetData = json['assets'] as Map<String, dynamic>?;

    return AssetTransaction(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      assetId: json['asset_id'] as String,
      type: json['type'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unitPrice: (json['unit_price'] as num).toDouble(),
      executedAt: DateTime.parse(json['executed_at'] as String),
      accountName: accountData != null ? accountData['name'] as String? : null,
      asset: assetData != null ? Asset.fromJson(assetData) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_id': accountId,
      'asset_id': assetId,
      'type': type,
      'quantity': quantity,
      'unit_price': unitPrice,
      'executed_at': executedAt.toIso8601String(),
    };
  }
}

/// Represents a recurring budget schedule and spending limit configuration
/// mapped directly to the `recurring_budget` table in Supabase.
class RecurringBudget {
  final String id;
  final String categoryId;
  final double amount;
  final String frequency; // 'daily', 'weekly', 'monthly', 'yearly'
  final int interval; // Period step multiplier (e.g. interval: 2 + frequency: 'monthly' = every 2 months)
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime? nextDueDate;
  final double budget; // Designated maximum budget ceiling for this period
  final double runningAmount; // Accumulated expenses in the current period cycle (resets on rollover)
  final String budgetPeriod; // Frequency grouping mapping
  final DateTime? budgetEndDate;
  final String status; // 'active', 'inactive'
  final String? description;
  final DateTime createdAt;

  // Joined UI presentation properties (fetched via database relational joins)
  final String? categoryName;
  final String? categoryIcon;
  final String? categoryColorHex;

  RecurringBudget({
    required this.id,
    required this.categoryId,
    required this.amount,
    required this.frequency,
    required this.interval,
    required this.startDate,
    this.endDate,
    this.nextDueDate,
    required this.budget,
    this.runningAmount = 0.0,
    required this.budgetPeriod,
    this.budgetEndDate,
    required this.status,
    this.description,
    required this.createdAt,
    this.categoryName,
    this.categoryIcon,
    this.categoryColorHex,
  });

  /// Factory constructor to deserialize json from Supabase query response
  factory RecurringBudget.fromJson(Map<String, dynamic> json) {
    final categoryData = json['categories'] as Map<String, dynamic>?;

    return RecurringBudget(
      id: json['id'] as String,
      categoryId: json['category_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      frequency: json['frequency'] as String,
      interval: (json['interval'] as num?)?.toInt() ?? 1,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date'] as String) : null,
      nextDueDate: json['next_due_date'] != null ? DateTime.parse(json['next_due_date'] as String) : null,
      budget: (json['budget'] as num).toDouble(),
      runningAmount: (json['running_amount'] as num?)?.toDouble() ?? 0.0,
      budgetPeriod: json['budget_period'] as String,
      budgetEndDate: json['budget_end_date'] != null ? DateTime.parse(json['budget_end_date'] as String) : null,
      status: json['status'] as String,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      categoryName: categoryData != null ? categoryData['name'] as String? : json['category_name'] as String?,
      categoryIcon: categoryData != null ? categoryData['icon'] as String? : json['category_icon'] as String?,
      categoryColorHex: categoryData != null ? categoryData['color_hex'] as String? : json['category_color_hex'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category_id': categoryId,
      'amount': amount,
      'frequency': frequency,
      'interval': interval,
      'start_date': startDate.toIso8601String().split('T').first,
      'end_date': endDate?.toIso8601String().split('T').first,
      'next_due_date': nextDueDate?.toIso8601String().split('T').first,
      'budget': budget,
      'running_amount': runningAmount,
      'budget_period': budgetPeriod,
      'budget_end_date': budgetEndDate?.toIso8601String().split('T').first,
      'status': status,
      'description': description,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Formatted user-facing description of frequency and interval.
  /// E.g., interval: 1, frequency: 'monthly' -> "Every Month"
  /// E.g., interval: 2, frequency: 'monthly' -> "Every 2 Months"
  String get formattedFrequencyInterval {
    final freqStr = frequency.toLowerCase();
    if (interval == 1) {
      if (freqStr == 'monthly') return 'Every Month';
      if (freqStr == 'weekly') return 'Every Week';
      if (freqStr == 'daily') return 'Every Day';
      if (freqStr == 'yearly') return 'Every Year';
      return 'Every $frequency';
    } else {
      if (freqStr == 'monthly') return 'Every $interval Months';
      if (freqStr == 'weekly') return 'Every $interval Weeks';
      if (freqStr == 'daily') return 'Every $interval Days';
      if (freqStr == 'yearly') return 'Every $interval Years';
      return 'Every $interval $frequency';
    }
  }

  /// Returns true if next_due_date matches the specified year and month.
  bool isDueInMonth(DateTime targetMonth) {
    if (nextDueDate == null) return false;
    return nextDueDate!.year == targetMonth.year && nextDueDate!.month == targetMonth.month;
  }

  /// Calculates ratio of running_amount spent relative to budget limit.
  double get budgetProgressRatio {
    if (budget <= 0) return 0.0;
    return runningAmount / budget;
  }
}



