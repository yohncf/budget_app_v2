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

