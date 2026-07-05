// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:budget_app_v2/core/models/models.dart';

void main() {
  test('Account categorization logic', () {
    final accounts = [
      Account(
        id: '1',
        name: 'Checking',
        type: 'checking',
        institution: 'Bank',
        currency: 'USD',
        currentBalance: 100.0,
        limit: 0.0,
        accountGroup: 'liquid_assets',
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Account(
        id: '2',
        name: 'Credit Card',
        type: 'credit_card',
        institution: 'Bank',
        currency: 'USD',
        currentBalance: -50.0,
        limit: 1000.0,
        accountGroup: 'credit',
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Account(
        id: '3',
        name: 'Investment',
        type: 'investment',
        institution: 'Broker',
        currency: 'USD',
        currentBalance: 500.0,
        limit: 0.0,
        accountGroup: 'capital',
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Account(
        id: '4',
        name: 'IRA',
        type: 'investment',
        institution: 'Broker',
        currency: 'USD',
        currentBalance: 1000.0,
        limit: 0.0,
        accountGroup: 'retirement',
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Account(
        id: '5',
        name: 'Old Wallet',
        type: 'cash',
        institution: 'Wallet',
        currency: 'USD',
        currentBalance: 0.0,
        limit: 0.0,
        accountGroup: 'liquid_assets',
        status: 'archived',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    // Filter 1: Cash and Credit (non-archived liquid_assets, credit)
    final cashAndCredit = accounts.where((acc) =>
        acc.status != 'archived' &&
        (acc.accountGroup == 'liquid_assets' || acc.accountGroup == 'credit' || acc.accountGroup == 'credits')).toList();
    
    // Filter 2: Capital and Retirement (non-archived capital, retirement)
    final capitalAndRetirement = accounts.where((acc) =>
        acc.status != 'archived' &&
        (acc.accountGroup == 'capital' || acc.accountGroup == 'retirement')).toList();

    // Filter 3: Archived
    final archived = accounts.where((acc) => acc.status == 'archived').toList();

    expect(cashAndCredit.length, 2);
    expect(cashAndCredit[0].name, 'Checking');
    expect(cashAndCredit[1].name, 'Credit Card');

    expect(capitalAndRetirement.length, 2);
    expect(capitalAndRetirement[0].name, 'Investment');
    expect(capitalAndRetirement[1].name, 'IRA');

    expect(archived.length, 1);
    expect(archived[0].name, 'Old Wallet');
  });
}
