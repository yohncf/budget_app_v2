import 'package:flutter_test/flutter_test.dart';
import 'package:budget_app_v2/core/models/models.dart';

void main() {
  group('Transactions sorting logic', () {
    test('sorts transactions by date and time with newest at top', () {
      final txOlderDay = Transaction(
        id: '1',
        accountId: 'acc1',
        categoryId: 'cat1',
        amount: -50.0,
        currency: 'MXN',
        exchangeRate: 1.0,
        date: DateTime(2026, 10, 15, 14, 30),
        status: 'cleared',
        isRecurring: false,
        createdAt: DateTime(2026, 10, 15, 14, 30),
      );

      final txSameDayEarlier = Transaction(
        id: '2',
        accountId: 'acc1',
        categoryId: 'cat1',
        amount: -20.0,
        currency: 'MXN',
        exchangeRate: 1.0,
        date: DateTime(2026, 10, 17, 9, 15),
        status: 'cleared',
        isRecurring: false,
        createdAt: DateTime(2026, 10, 17, 9, 15),
      );

      final txSameDayLater = Transaction(
        id: '3',
        accountId: 'acc1',
        categoryId: 'cat1',
        amount: -100.0,
        currency: 'MXN',
        exchangeRate: 1.0,
        date: DateTime(2026, 10, 17, 18, 45),
        status: 'cleared',
        isRecurring: false,
        createdAt: DateTime(2026, 10, 17, 18, 45),
      );

      final transactions = [txOlderDay, txSameDayEarlier, txSameDayLater];

      // Sort with newest date and time first
      transactions.sort((a, b) {
        final dateCmp = b.date.compareTo(a.date);
        if (dateCmp != 0) return dateCmp;
        return b.createdAt.compareTo(a.createdAt);
      });

      expect(transactions[0].id, '3'); // Oct 17 18:45
      expect(transactions[1].id, '2'); // Oct 17 09:15
      expect(transactions[2].id, '1'); // Oct 15 14:30
    });

    test('breaks tie using createdAt descending if date and time are identical', () {
      final sameDateTime = DateTime(2026, 10, 17, 12, 0);

      final txCreatedFirst = Transaction(
        id: 'first_created',
        accountId: 'acc1',
        categoryId: 'cat1',
        amount: -10.0,
        currency: 'MXN',
        exchangeRate: 1.0,
        date: sameDateTime,
        status: 'cleared',
        isRecurring: false,
        createdAt: DateTime(2026, 10, 17, 12, 1, 10),
      );

      final txCreatedLater = Transaction(
        id: 'later_created',
        accountId: 'acc1',
        categoryId: 'cat1',
        amount: -30.0,
        currency: 'MXN',
        exchangeRate: 1.0,
        date: sameDateTime,
        status: 'cleared',
        isRecurring: false,
        createdAt: DateTime(2026, 10, 17, 12, 5, 45),
      );

      final transactions = [txCreatedFirst, txCreatedLater];

      transactions.sort((a, b) {
        final dateCmp = b.date.compareTo(a.date);
        if (dateCmp != 0) return dateCmp;
        return b.createdAt.compareTo(a.createdAt);
      });

      expect(transactions[0].id, 'later_created');
      expect(transactions[1].id, 'first_created');
    });

    test('Transaction.fromJson parses UTC dates to local timezone correctly', () {
      final json = {
        'id': 'test-utc-id',
        'account_id': 'acc-1',
        'category_id': 'cat-1',
        'amount': -15.5,
        'currency': 'MXN',
        'exchange_rate': 1.0,
        'date': '2026-10-18T03:00:00Z',
        'status': 'cleared',
        'created_at': '2026-10-18T03:00:00Z',
      };

      final tx = Transaction.fromJson(json);
      expect(tx.date.isUtc, false);
      expect(tx.createdAt.isUtc, false);
    });
  });
}
