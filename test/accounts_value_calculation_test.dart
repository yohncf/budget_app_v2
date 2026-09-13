import 'package:flutter_test/flutter_test.dart';
import 'package:budget_app_v2/core/models/models.dart';

double calculateAccountTotalValue(Account account) {
  return account.currentBalance;
}

void main() {
  group('Accounts value calculation', () {
    test('calculates total value for cash accounts based on currentBalance', () {
      final checkingAccount = Account(
        id: 'acc-checking',
        name: 'Chase Checking',
        type: 'checking',
        institution: 'Chase',
        currency: 'USD',
        currentBalance: 1500.0,
        limit: 0.0,
        accountGroup: 'liquid_assets',
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final totalValue = calculateAccountTotalValue(checkingAccount);
      expect(totalValue, 1500.0);
    });

    test('calculates total value for retirement accounts based on currentBalance', () {
      final iraAccount = Account(
        id: 'acc-ira',
        name: 'Traditional IRA',
        type: 'investment',
        institution: 'Schwab',
        currency: 'USD',
        currentBalance: 1200.0,
        limit: 0.0,
        accountGroup: 'retirement',
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final totalValue = calculateAccountTotalValue(iraAccount);
      expect(totalValue, 1200.0);
    });

    test('calculates total value for credit card accounts based on currentBalance', () {
      final creditCard = Account(
        id: 'acc-cc',
        name: 'Amex Gold',
        type: 'credit_card',
        institution: 'American Express',
        currency: 'USD',
        currentBalance: -250.0,
        limit: 5000.0,
        accountGroup: 'credit',
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final totalValue = calculateAccountTotalValue(creditCard);
      expect(totalValue, -250.0);
    });
  });
}
