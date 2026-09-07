import 'package:flutter_test/flutter_test.dart';
import 'package:budget_app_v2/core/models/models.dart';

double calculateAccountStockValue({
  required Account account,
  required List<Holding> holdings,
  required double Function(String symbol) getPriceInUSD,
}) {
  double totalValueInAccountCurrency = 0.0;
  final accountCurrency = account.currency.trim().toUpperCase();
  final accountCurrencyPriceInUSD = getPriceInUSD(accountCurrency);

  for (final holding in holdings) {
    if (holding.accountId == account.id && holding.quantity > 0) {
      if (holding.asset?.type == 'fiat') continue;

      final symbol = holding.asset?.symbol ?? '';
      final currentPriceInUSD = getPriceInUSD(symbol);
      final currentPriceInAccountCurrency = currentPriceInUSD / (accountCurrencyPriceInUSD > 0 ? accountCurrencyPriceInUSD : 1.0);
      totalValueInAccountCurrency += holding.quantity * currentPriceInAccountCurrency;
    }
  }
  return totalValueInAccountCurrency;
}

double calculateAccountTotalValue({
  required Account account,
  required List<Holding> holdings,
  required double Function(String symbol) getPriceInUSD,
}) {
  if (account.accountGroup == 'capital' || account.accountGroup == 'retirement') {
    return account.currentBalance +
        calculateAccountStockValue(
          account: account,
          holdings: holdings,
          getPriceInUSD: getPriceInUSD,
        );
  }
  return account.currentBalance;
}

void main() {
  group('Capital and retirement accounts value calculation', () {
    final mockPrices = <String, double>{
      'USD': 1.0,
      'MXN': 0.05, // 1 MXN = 0.05 USD (i.e. 20 MXN per USD)
      'AAPL': 200.0,
      'VOO': 500.0,
      'BTC': 60000.0,
    };

    double getPriceInUSD(String symbol) {
      final sym = symbol.trim().toUpperCase();
      return mockPrices[sym] ?? 1.0;
    }

    test('calculates total value for capital account with USD cash + multiple stocks', () {
      final fidelityAccount = Account(
        id: 'acc-fidelity',
        name: 'Fidelity Brokerage',
        type: 'investment',
        institution: 'Fidelity',
        currency: 'USD',
        currentBalance: 500.0, // $500 cash in USD
        limit: 0.0,
        accountGroup: 'capital',
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final holdings = [
        Holding(
          id: 'h1',
          accountId: 'acc-fidelity',
          assetId: 'asset-aapl',
          quantity: 10.0, // 10 shares * $200 = $2000
          avgBuyPrice: 150.0,
          updatedAt: DateTime.now(),
          asset: Asset(id: 'asset-aapl', symbol: 'AAPL', name: 'Apple Inc.', type: 'stock'),
        ),
        Holding(
          id: 'h2',
          accountId: 'acc-fidelity',
          assetId: 'asset-voo',
          quantity: 4.0, // 4 shares * $500 = $2000
          avgBuyPrice: 400.0,
          updatedAt: DateTime.now(),
          asset: Asset(id: 'asset-voo', symbol: 'VOO', name: 'Vanguard S&P 500 ETF', type: 'etf'),
        ),
      ];

      final stockValue = calculateAccountStockValue(
        account: fidelityAccount,
        holdings: holdings,
        getPriceInUSD: getPriceInUSD,
      );
      final totalValue = calculateAccountTotalValue(
        account: fidelityAccount,
        holdings: holdings,
        getPriceInUSD: getPriceInUSD,
      );

      // Stock value: 10 * 200 + 4 * 500 = 2000 + 2000 = 4000
      expect(stockValue, 4000.0);
      // Total value: 500 cash + 4000 stocks = 4500
      expect(totalValue, 4500.0);
    });

    test('calculates total value for retirement account', () {
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

      final holdings = [
        Holding(
          id: 'h3',
          accountId: 'acc-ira',
          assetId: 'asset-voo',
          quantity: 10.0, // 10 * $500 = $5000
          avgBuyPrice: 450.0,
          updatedAt: DateTime.now(),
          asset: Asset(id: 'asset-voo', symbol: 'VOO', name: 'Vanguard S&P 500 ETF', type: 'etf'),
        ),
      ];

      final totalValue = calculateAccountTotalValue(
        account: iraAccount,
        holdings: holdings,
        getPriceInUSD: getPriceInUSD,
      );

      // Total value: 1200 + 5000 = 6200
      expect(totalValue, 6200.0);
    });

    test('ignores fiat type holdings to avoid double-counting cash', () {
      final account = Account(
        id: 'acc-cap',
        name: 'GBM',
        type: 'investment',
        institution: 'GBM',
        currency: 'USD',
        currentBalance: 1000.0,
        limit: 0.0,
        accountGroup: 'capital',
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final holdings = [
        Holding(
          id: 'h-fiat',
          accountId: 'acc-cap',
          assetId: 'asset-usd',
          quantity: 1000.0,
          avgBuyPrice: 1.0,
          updatedAt: DateTime.now(),
          asset: Asset(id: 'asset-usd', symbol: 'USD', name: 'US Dollar', type: 'fiat'),
        ),
        Holding(
          id: 'h-stock',
          accountId: 'acc-cap',
          assetId: 'asset-aapl',
          quantity: 5.0, // 5 * 200 = 1000
          avgBuyPrice: 180.0,
          updatedAt: DateTime.now(),
          asset: Asset(id: 'asset-aapl', symbol: 'AAPL', name: 'Apple Inc.', type: 'stock'),
        ),
      ];

      final totalValue = calculateAccountTotalValue(
        account: account,
        holdings: holdings,
        getPriceInUSD: getPriceInUSD,
      );

      // Total value should be 1000 (cash balance) + 1000 (AAPL), NOT + 1000 for fiat holding
      expect(totalValue, 2000.0);
    });

    test('does not add stock value to liquid_assets or credit accounts', () {
      final checkingAccount = Account(
        id: 'acc-checking',
        name: 'Checking Account',
        type: 'checking',
        institution: 'Chase',
        currency: 'USD',
        currentBalance: 3500.0,
        limit: 0.0,
        accountGroup: 'liquid_assets',
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final holdings = [
        Holding(
          id: 'h-orphan',
          accountId: 'acc-checking',
          assetId: 'asset-aapl',
          quantity: 10.0,
          avgBuyPrice: 200.0,
          updatedAt: DateTime.now(),
          asset: Asset(id: 'asset-aapl', symbol: 'AAPL', name: 'Apple Inc.', type: 'stock'),
        ),
      ];

      final totalValue = calculateAccountTotalValue(
        account: checkingAccount,
        holdings: holdings,
        getPriceInUSD: getPriceInUSD,
      );

      expect(totalValue, 3500.0);
    });
  });
}
