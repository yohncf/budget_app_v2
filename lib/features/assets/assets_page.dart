import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:budget_app_v2/core/config/app_colors.dart';
import 'package:budget_app_v2/core/models/models.dart';
import 'package:budget_app_v2/core/services/database_service.dart';
import '../../core/utils/currency_formatter.dart';
import 'add_asset_transaction_bottom_sheet.dart';
import '../../core/services/currency_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;


class AssetsPage extends StatefulWidget {
  const AssetsPage({super.key});

  @override
  State<AssetsPage> createState() => AssetsPageState();
}

class AssetsPageState extends State<AssetsPage> with SingleTickerProviderStateMixin {
  final _databaseService = DatabaseService();
  late TabController _tabController;

  List<Holding> _holdings = [];
  List<AssetTransaction> _transactions = [];
  List<Account> _accounts = [];
  bool _isLoadingHoldings = false;
  bool _isLoadingTransactions = false;
  bool _isLoadingAccounts = false;
  String _portfolioCurrency = 'USD';

  // Timeline chart state
  bool _isLoadingTimeline = false;
  List<FlSpot> _timelineSpots = [];
  List<DateTime> _timelineDates = [];
  String _timelineRange = 'ALL'; // '6M', '3Y', 'ALL'

  // Search & Filter state for Transactions tab
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedTxType; // 'buy', 'sell', or null (All)
  final Set<String> _collapsedAccounts = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    await Future.wait([
      loadAccounts(),
      loadHoldings(),
      loadTransactions(),
    ]);
    await loadTimelineData();
  }

  Future<void> loadAccounts() async {
    if (mounted) {
      setState(() {
        _isLoadingAccounts = true;
      });
    }
    try {
      final list = await _databaseService.fetchAccounts();
      if (mounted) {
        setState(() {
          _accounts = list;
        });
      }
    } catch (e) {
      print('Error loading accounts: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAccounts = false;
        });
      }
    }
  }

  Future<void> loadHoldings() async {
    if (mounted) {
      setState(() {
        _isLoadingHoldings = true;
      });
    }
    try {
      final list = await _databaseService.fetchHoldings();
      if (mounted) {
        setState(() {
          // Filter to show only active holdings (quantity > 0)
          _holdings = list.where((h) => h.quantity > 0).toList();
        });
      }
    } catch (e) {
      print('Error loading holdings: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingHoldings = false;
        });
      }
    }
  }

  Future<void> loadTransactions() async {
    if (mounted) {
      setState(() {
        _isLoadingTransactions = true;
      });
    }
    try {
      final list = await _databaseService.fetchAssetTransactions();
      if (mounted) {
        setState(() {
          _transactions = list;
        });
      }
    } catch (e) {
      print('Error loading asset transactions: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingTransactions = false;
        });
      }
    }
  }

  void _editTransaction(AssetTransaction tx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddAssetTransactionBottomSheet(
        transaction: tx,
        onSaved: () => loadData(),
      ),
    );
  }

  // --- Calculations ---

  double get _totalPortfolioCostInUSD {
    double total = 0.0;
    for (var holding in _holdings) {
      final account = _getAccountById(holding.accountId);
      final accountCurrency = account?.currency ?? 'USD';
      final accountCurrencyPriceInUSD = CurrencyService().getPrice(accountCurrency) ?? 1.0;
      
      final avgBuyPriceInUSD = holding.avgBuyPrice * accountCurrencyPriceInUSD;
      total += (holding.quantity * avgBuyPriceInUSD);
    }
    return total;
  }

  Future<void> loadTimelineData() async {
    if (mounted) {
      setState(() {
        _isLoadingTimeline = true;
      });
    }
    try {
      final targetAccounts = _accounts
          .where((a) => a.accountGroup == 'capital' || a.accountGroup == 'retirement')
          .toList();
      if (targetAccounts.isEmpty) {
        if (mounted) {
          setState(() {
            _timelineSpots = [];
            _timelineDates = [];
            _isLoadingTimeline = false;
          });
        }
        return;
      }
      final targetAccountIds = targetAccounts.map((a) => a.id).toList();
      final regularTx = await _databaseService.fetchAllTransactionsForAccounts(targetAccountIds);

      _computeTimeline(targetAccounts, regularTx);
    } catch (e) {
      print('Error loading timeline data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingTimeline = false;
        });
      }
    }
  }

  void _computeTimeline(List<Account> targetAccounts, List<Transaction> regularTx) {
    if (_transactions.isEmpty && regularTx.isEmpty) {
      if (mounted) {
        setState(() {
          _timelineSpots = [];
          _timelineDates = [];
        });
      }
      return;
    }

    final List<dynamic> allEvents = [];
    allEvents.addAll(regularTx);
    allEvents.addAll(_transactions);
    allEvents.sort((a, b) {
      final dateA = a is Transaction ? a.date : (a as AssetTransaction).executedAt;
      final dateB = b is Transaction ? b.date : (b as AssetTransaction).executedAt;
      return dateA.compareTo(dateB);
    });

    if (allEvents.isEmpty) {
      if (mounted) {
        setState(() {
          _timelineSpots = [];
          _timelineDates = [];
        });
      }
      return;
    }

    final firstEvent = allEvents.first;
    final firstDate = firstEvent is Transaction ? firstEvent.date : (firstEvent as AssetTransaction).executedAt;
    final today = DateTime.now();

    final List<DateTime> months = [];
    DateTime current = DateTime(firstDate.year, firstDate.month, 1);
    while (current.isBefore(today) || (current.year == today.year && current.month == today.month)) {
      final lastDay = DateTime(current.year, current.month + 1, 0);
      months.add(lastDay);
      current = DateTime(current.year, current.month + 1, 1);
    }

    if (months.length == 1) {
      final prevMonth = DateTime(months.first.year, months.first.month - 1, 1);
      months.insert(0, DateTime(prevMonth.year, prevMonth.month + 1, 0));
    }

    final Map<String, List<MapEntry<DateTime, double>>> assetPriceHistory = {};
    for (var ev in allEvents) {
      if (ev is AssetTransaction) {
        final symbol = ev.asset?.symbol.toUpperCase() ?? '';
        if (symbol.isNotEmpty) {
          assetPriceHistory.putIfAbsent(symbol, () => []);
          assetPriceHistory[symbol]!.add(MapEntry(ev.executedAt, ev.unitPrice));
        }
      }
    }

    for (var entries in assetPriceHistory.values) {
      entries.sort((a, b) => a.key.compareTo(b.key));
    }

    // Initialize states to today's actual current values
    final Map<String, Map<String, double>> holdingsState = {};
    final Map<String, double> cashState = {};

    for (var acc in targetAccounts) {
      holdingsState[acc.id] = {};
      
      double cashToday = 0.0;
      final fiatHolding = _holdings.firstWhere(
        (h) => h.accountId == acc.id && h.asset?.type == 'fiat',
        orElse: () => Holding(id: '', accountId: '', assetId: '', quantity: -1, avgBuyPrice: 0, updatedAt: DateTime.now()),
      );
      if (fiatHolding.quantity >= 0) {
        cashToday = fiatHolding.quantity;
      } else {
        double nonCashBook = 0.0;
        for (var h in _holdings) {
          if (h.accountId == acc.id && h.asset?.type != 'fiat') {
            nonCashBook += h.quantity * h.avgBuyPrice;
          }
        }
        cashToday = acc.currentBalance - nonCashBook;
      }
      cashState[acc.id] = cashToday;

      for (var h in _holdings) {
        if (h.accountId == acc.id && h.asset?.type != 'fiat') {
          holdingsState[acc.id]![h.assetId] = h.quantity;
        }
      }
    }

    final List<double> monthlyValuesInUSD = List.filled(months.length, 0.0);

    // Populate for the last month (today's month) first using current state
    monthlyValuesInUSD[months.length - 1] = _calculateTotalValueInUSD(
      targetAccounts,
      cashState,
      holdingsState,
      months.last,
      assetPriceHistory,
    );

    // Now go backwards from months.length - 1 down to 1
    for (int i = months.length - 1; i >= 1; i--) {
      final monthEnd = months[i];
      final prevMonthEnd = months[i - 1];

      // Find all events that occurred in this month (date > prevMonthEnd and date <= monthEnd)
      for (var ev in allEvents) {
        final evDate = ev is Transaction ? ev.date : (ev as AssetTransaction).executedAt;
        if (evDate.isAfter(prevMonthEnd) && (evDate.isBefore(monthEnd) || evDate.isAtSameMomentAs(monthEnd))) {
          if (ev is Transaction) {
            final accId = ev.accountId;
            if (cashState.containsKey(accId)) {
              cashState[accId] = cashState[accId]! - ev.amount;
            }
          } else if (ev is AssetTransaction) {
            final accId = ev.accountId;
            final assetId = ev.assetId;
            final txType = ev.type.toLowerCase();

            if (holdingsState.containsKey(accId)) {
              final accHoldings = holdingsState[accId]!;
              
              double qtyChange = 0.0;
              if (txType == 'buy' || txType == 'dividend_reinvest' || txType == 'reward' || txType == 'split') {
                qtyChange = ev.quantity;
              } else if (txType == 'sell') {
                qtyChange = -ev.quantity;
              }
              accHoldings[assetId] = (accHoldings[assetId] ?? 0.0) - qtyChange;

              double cashChange = 0.0;
              if (txType == 'buy') {
                cashChange = -ev.quantity * ev.unitPrice;
              } else if (txType == 'sell') {
                cashChange = ev.quantity * ev.unitPrice;
              }
              cashState[accId] = cashState[accId]! - cashChange;
            }
          }
        }
      }

      // Safeguard: Ensure no negative quantities or cash balances due to ledger anomalies
      for (var accId in cashState.keys) {
        cashState[accId] = math.max(0.0, cashState[accId]!);
      }
      for (var accHoldings in holdingsState.values) {
        for (var assetId in accHoldings.keys) {
          accHoldings[assetId] = math.max(0.0, accHoldings[assetId]!);
        }
      }

      monthlyValuesInUSD[i - 1] = _calculateTotalValueInUSD(
        targetAccounts,
        cashState,
        holdingsState,
        prevMonthEnd,
        assetPriceHistory,
      );
    }

    final List<FlSpot> spots = [];
    for (int i = 0; i < months.length; i++) {
      spots.add(FlSpot(i.toDouble(), monthlyValuesInUSD[i]));
    }

    if (mounted) {
      setState(() {
        _timelineSpots = spots;
        _timelineDates = months;
      });
    }
  }

  double _calculateTotalValueInUSD(
    List<Account> targetAccounts,
    Map<String, double> cashState,
    Map<String, Map<String, double>> holdingsState,
    DateTime date,
    Map<String, List<MapEntry<DateTime, double>>> assetPriceHistory,
  ) {
    double totalUSD = 0.0;
    for (var acc in targetAccounts) {
      final accId = acc.id;
      final accCurrency = acc.currency;
      final accCurrencyPriceInUSD = CurrencyService().getPrice(accCurrency) ?? 1.0;

      final accCash = cashState[accId] ?? 0.0;
      totalUSD += accCash * accCurrencyPriceInUSD;

      final accHoldings = holdingsState[accId] ?? {};
      for (var entry in accHoldings.entries) {
        final assetId = entry.key;
        final quantity = entry.value;
        if (quantity <= 0) continue;

        final asset = _findAssetById(assetId);
        if (asset == null || asset.type == 'fiat') continue;

        final symbol = asset.symbol.toUpperCase();
        final priceInUSD = _getHistoricalPriceInUSD(symbol, date, assetPriceHistory);

        totalUSD += quantity * priceInUSD;
      }
    }
    return totalUSD;
  }

  Asset? _findAssetById(String id) {
    for (var holding in _holdings) {
      if (holding.assetId == id) return holding.asset;
    }
    for (var tx in _transactions) {
      if (tx.assetId == id) return tx.asset;
    }
    return null;
  }

  double _getHistoricalPriceInUSD(
    String symbol,
    DateTime date,
    Map<String, List<MapEntry<DateTime, double>>> priceHistory,
  ) {
    if (symbol == 'USD') return 1.0;

    final history = priceHistory[symbol];
    final currentPrice = CurrencyService().getPrice(symbol);

    if (history == null || history.isEmpty) {
      return currentPrice ?? 1.0;
    }

    MapEntry<DateTime, double>? lastTx;
    MapEntry<DateTime, double>? nextTx;

    for (var entry in history) {
      if (entry.key.isBefore(date) || entry.key.isAtSameMomentAs(date)) {
        lastTx = entry;
      } else {
        nextTx = entry;
        break;
      }
    }

    if (lastTx == null) {
      return history.first.value;
    }

    if (nextTx == null) {
      if (currentPrice != null) {
        final today = DateTime.now();
        final totalDays = today.difference(lastTx.key).inDays;
        if (totalDays <= 0) return currentPrice;

        final daysPassed = date.difference(lastTx.key).inDays;
        final fraction = daysPassed / totalDays;
        return lastTx.value + (currentPrice - lastTx.value) * fraction;
      }
      return lastTx.value;
    }

    final totalDays = nextTx.key.difference(lastTx.key).inDays;
    if (totalDays <= 0) return lastTx.value;

    final daysPassed = date.difference(lastTx.key).inDays;
    final fraction = daysPassed / totalDays;
    return lastTx.value + (nextTx.value - lastTx.value) * fraction;
  }

  List<FlSpot> _getFilteredSpots(double mxnRate) {
    if (_timelineSpots.isEmpty) return [];

    int startIndex = 0;
    if (_timelineRange == '6M') {
      startIndex = math.max(0, _timelineSpots.length - 6);
    } else if (_timelineRange == '3Y') {
      startIndex = math.max(0, _timelineSpots.length - 36);
    }

    final filtered = <FlSpot>[];
    for (int i = startIndex; i < _timelineSpots.length; i++) {
      final spot = _timelineSpots[i];
      final yVal = _portfolioCurrency == 'MXN' ? spot.y / mxnRate : spot.y;
      filtered.add(FlSpot((i - startIndex).toDouble(), yVal));
    }
    return filtered;
  }

  List<DateTime> _getFilteredDates() {
    if (_timelineDates.isEmpty) return [];

    int startIndex = 0;
    if (_timelineRange == '6M') {
      startIndex = math.max(0, _timelineDates.length - 6);
    } else if (_timelineRange == '3Y') {
      startIndex = math.max(0, _timelineDates.length - 36);
    }

    return _timelineDates.sublist(startIndex);
  }

  Widget _buildTimelineChartCard() {
    if (_isLoadingTimeline) {
      return Card(
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: const BorderSide(color: Colors.white10, width: 1.0),
        ),
        child: const SizedBox(
          height: 300,
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.limeMoss),
            ),
          ),
        ),
      );
    }

    final mxnRate = CurrencyService().getPrice('MXN') ?? 0.053;
    final spots = _getFilteredSpots(mxnRate);
    final dates = _getFilteredDates();

    if (spots.length < 2) {
      return Card(
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: const BorderSide(color: Colors.white10, width: 1.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PORTFOLIO HISTORICAL PERFORMANCE',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 40),
              const Center(
                child: Text(
                  'Not enough historical transaction data to generate timeline.',
                  style: TextStyle(color: Colors.white38, fontSize: 14),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      );
    }

    // Dynamic Y-axis scaling
    final yValues = spots.map((s) => s.y).toList();
    final double minYVal = yValues.reduce(math.min);
    final double maxYVal = yValues.reduce(math.max);
    final double padding = (maxYVal - minYVal) * 0.15;
    final double minY = math.max(0.0, minYVal - padding);
    final double maxY = maxYVal + (padding > 0 ? padding : 100.0);
    final double yRange = maxY - minY;

    double yInterval = yRange / 4;
    if (yInterval < 1) yInterval = 1;

    return Card(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: const BorderSide(color: Colors.white10, width: 1.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'PORTFOLIO HISTORICAL PERFORMANCE',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
                Row(
                  children: [
                    _buildTimelineRangeChip('6M', '6M'),
                    const SizedBox(width: 8),
                    _buildTimelineRangeChip('3Y', '3Y'),
                    const SizedBox(width: 8),
                    _buildTimelineRangeChip('ALL', 'ALL'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minY: minY,
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: yInterval,
                    getDrawingHorizontalLine: (value) {
                      return const FlLine(
                        color: Colors.white10,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (touchedSpot) => const Color(0xFF1E1E1E),
                      tooltipBorder: const BorderSide(color: Colors.white10, width: 1),
                      tooltipBorderRadius: const BorderRadius.all(Radius.circular(8)),
                      getTooltipItems: (List<LineBarSpot> touchedSpots) {
                        return touchedSpots.map((barSpot) {
                          final index = barSpot.x.toInt();
                          if (index < 0 || index >= dates.length) return null;
                          final date = dates[index];
                          final dateStr = DateFormat('MMMM yyyy').format(date);
                          final valStr = formatCurrency(barSpot.y);
                          return LineTooltipItem(
                            '$dateStr\n',
                            const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            children: [
                              TextSpan(
                                text: '$valStr $_portfolioCurrency',
                                style: const TextStyle(
                                  color: AppColors.limeMoss,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          );
                        }).toList();
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final int index = value.toInt();
                          if (index >= 0 && index < dates.length) {
                            final totalPoints = dates.length;
                            int showInterval = 1;
                            if (totalPoints > 12) {
                              showInterval = (totalPoints / 6).ceil();
                            } else if (totalPoints > 6) {
                              showInterval = 2;
                            }

                            if (index % showInterval == 0 || index == totalPoints - 1) {
                              final date = dates[index];
                              return SideTitleWidget(
                                meta: meta,
                                space: 8,
                                child: Text(
                                  DateFormat('MMM yy').format(date),
                                  style: const TextStyle(color: Colors.white38, fontSize: 9),
                                ),
                              );
                            }
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: yInterval,
                        reservedSize: 55,
                        getTitlesWidget: (value, meta) {
                          if (value < minY || value > maxY) return const SizedBox.shrink();
                          return SideTitleWidget(
                            meta: meta,
                            space: 8,
                            child: Text(
                              _formatCompactCurrency(value),
                              style: const TextStyle(color: Colors.white38, fontSize: 9),
                              textAlign: TextAlign.right,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: AppColors.limeMoss,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.limeMoss.withOpacity(0.2),
                            AppColors.limeMoss.withOpacity(0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineRangeChip(String range, String label) {
    final isSelected = _timelineRange == range;
    return GestureDetector(
      onTap: () {
        setState(() {
          _timelineRange = range;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.limeMoss : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.limeMoss : Colors.white10,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 10,
          ),
        ),
      ),
    );
  }

  String _formatCompactCurrency(double value) {
    final prefix = '\$';
    if (value >= 1000000) {
      return '$prefix${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '$prefix${(value / 1000).toStringAsFixed(0)}k';
    } else {
      return '$prefix${value.toStringAsFixed(0)}';
    }
  }

  double get _totalPortfolioMarketValue {
    double total = 0.0;
    for (var holding in _holdings) {
      final symbol = holding.asset?.symbol ?? '';
      final currentPriceInUSD = CurrencyService().getPrice(symbol) ?? holding.avgBuyPrice;
      total += (holding.quantity * currentPriceInUSD);
    }
    return total;
  }

  Account? _getAccountById(String id) {
    for (var account in _accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  Widget _buildPortfolioProfitLossWidget() {
    final costUSD = _totalPortfolioCostInUSD;
    final marketUSD = _totalPortfolioMarketValue;
    final diffUSD = marketUSD - costUSD;
    
    double displayDiff = diffUSD;
    if (_portfolioCurrency == 'MXN') {
      final mxnRate = CurrencyService().getPrice('MXN') ?? 0.053;
      displayDiff = diffUSD / mxnRate;
    }
    
    final pct = costUSD > 0 ? (diffUSD / costUSD) * 100 : 0.0;

    final isProfit = diffUSD >= 0;
    final color = isProfit ? AppColors.limeMoss : AppColors.cinnabar;
    final icon = isProfit ? Icons.trending_up : Icons.trending_down;
    final sign = isProfit ? '+' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text(
                '$sign${pct.toStringAsFixed(2)}%',
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '$sign${formatCurrency(displayDiff)} $_portfolioCurrency',
            style: TextStyle(color: color, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyToggleBtn(String currency) {
    final isSelected = _portfolioCurrency == currency;
    return GestureDetector(
      onTap: () {
        setState(() {
          _portfolioCurrency = currency;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.limeMoss : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          currency,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
      ),
    );
  }

  Map<String, List<Holding>> get _holdingsByAccount {
    final Map<String, List<Holding>> grouped = {};
    for (var holding in _holdings) {
      final accountName = holding.accountName ?? 'Unknown Account';
      if (!grouped.containsKey(accountName)) {
        grouped[accountName] = [];
      }
      grouped[accountName]!.add(holding);
    }
    return grouped;
  }

  List<MapEntry<String, List<Holding>>> get _sortedHoldingsByAccount {
    final grouped = _holdingsByAccount;
    final entries = grouped.entries.toList();
    entries.sort((a, b) {
      final aTotalUSD = a.value.fold<double>(
        0.0,
        (sum, h) {
          final symbol = h.asset?.symbol ?? '';
          final currentPriceInUSD = CurrencyService().getPrice(symbol) ?? h.avgBuyPrice;
          return sum + (h.quantity * currentPriceInUSD);
        },
      );
      final bTotalUSD = b.value.fold<double>(
        0.0,
        (sum, h) {
          final symbol = h.asset?.symbol ?? '';
          final currentPriceInUSD = CurrencyService().getPrice(symbol) ?? h.avgBuyPrice;
          return sum + (h.quantity * currentPriceInUSD);
        },
      );
      return bTotalUSD.compareTo(aTotalUSD); // Descending order
    });
    return entries;
  }

  List<AssetTransaction> get _filteredTransactions {
    return _transactions.where((tx) {
      final matchesSearch = _searchQuery.isEmpty ||
          (tx.asset?.symbol.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          (tx.asset?.name.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          (tx.accountName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);

      final matchesType = _selectedTxType == null || tx.type.toLowerCase() == _selectedTxType;

      return matchesSearch && matchesType;
    }).toList();
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedTxType = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Container(
          color: AppColors.card,
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const SizedBox(height: 8),
                Text(
                  'CAPITAL & RETIREMENT PORTFOLIO',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                ),
                TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.limeMoss,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white38,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
                  tabs: const [
                    Tab(text: 'Holdings Summary'),
                    Tab(text: 'Asset Transactions'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildHoldingsTab(),
          _buildTransactionsTab(),
        ],
      ),
    );
  }

  // --- Tab 1: Holdings Tab ---
  Widget _buildHoldingsTab() {
    if (_isLoadingHoldings) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.limeMoss),
        ),
      );
    }

    if (_holdings.isEmpty) {
      return RefreshIndicator(
        onRefresh: loadHoldings,
        color: AppColors.limeMoss,
        backgroundColor: AppColors.card,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 100),
            Center(
              child: Text(
                'No active asset holdings found.',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            ),
          ],
        ),
      );
    }

    final groupedHoldings = _holdingsByAccount;

    final double marketValueUSD = _totalPortfolioMarketValue;
    final double costBasisUSD = _totalPortfolioCostInUSD;
    
    double displayMarket = marketValueUSD;
    double displayCost = costBasisUSD;
    if (_portfolioCurrency == 'MXN') {
      final mxnRate = CurrencyService().getPrice('MXN') ?? 0.053;
      displayMarket = marketValueUSD / mxnRate;
      displayCost = costBasisUSD / mxnRate;
    }

    return RefreshIndicator(
      onRefresh: loadHoldings,
      color: AppColors.limeMoss,
      backgroundColor: AppColors.card,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        children: [
          // KPI Portfolio Header Card
          Card(
            color: AppColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
              side: const BorderSide(color: Colors.white10, width: 1.0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'TOTAL PORTFOLIO VALUE (MARKET)',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.all(2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildCurrencyToggleBtn('USD'),
                                    _buildCurrencyToggleBtn('MXN'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${formatCurrency(displayMarket)} $_portfolioCurrency',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Cost Basis: ${formatCurrency(displayCost)} $_portfolioCurrency',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      _buildPortfolioProfitLossWidget(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSummaryItem('Accounts', groupedHoldings.keys.length.toString()),
                      _buildSummaryItem('Unique Assets', _holdings.map((h) => h.assetId).toSet().length.toString()),
                      _buildSummaryItem('Total Quantity', _holdings.fold<double>(0, (sum, h) => sum + h.quantity).toStringAsFixed(2)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          _buildTimelineChartCard(),
          const SizedBox(height: 20),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
            child: Text(
              'Asset Allocation by Account',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Grouped Accounts & Holdings
          ..._sortedHoldingsByAccount.map((entry) {
            final accountName = entry.key;
            final accountHoldings = entry.value;
            final accountTotalCost = accountHoldings.fold<double>(
              0.0,
              (sum, h) => sum + (h.quantity * h.avgBuyPrice),
            );
            
            final accountTotalMarket = accountHoldings.fold<double>(
              0.0,
              (sum, h) {
                final symbol = h.asset?.symbol ?? '';
                final currentPriceInUSD = CurrencyService().getPrice(symbol) ?? h.avgBuyPrice;
                final account = _getAccountById(h.accountId);
                final accountCurrency = account?.currency ?? 'USD';
                final accountCurrencyPriceInUSD = CurrencyService().getPrice(accountCurrency) ?? 1.0;
                final currentPriceInAccountCurrency = currentPriceInUSD / accountCurrencyPriceInUSD;
                return sum + (h.quantity * currentPriceInAccountCurrency);
              },
            );

            final isCollapsed = _collapsedAccounts.contains(accountName);

            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Card(
                color: AppColors.card,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  side: const BorderSide(color: Colors.white10, width: 1.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Account Header Panel
                    Material(
                      color: const Color(0xFF141414),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            if (isCollapsed) {
                              _collapsedAccounts.remove(accountName);
                            } else {
                              _collapsedAccounts.add(accountName);
                            }
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.account_balance_outlined, color: AppColors.limeMoss, size: 20),
                                  const SizedBox(width: 10),
                                  Text(
                                    accountName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        formatCurrency(accountTotalMarket),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Book: ${formatCurrency(accountTotalCost)}',
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 10),
                                  Icon(
                                    isCollapsed ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                                    color: Colors.white54,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Holdings List inside Account Card
                    if (!isCollapsed)
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: accountHoldings.length,
                        separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1.0),
                        itemBuilder: (context, index) {
                          final holding = accountHoldings[index];
                          final assetName = holding.asset?.name ?? 'Unknown Asset';
                          final symbol = holding.asset?.symbol ?? 'ASSET';
                          final type = holding.asset?.type ?? 'other';
                          
                          // Current price in account currency
                          final currentPriceInUSD = CurrencyService().getPrice(symbol) ?? holding.avgBuyPrice;
                          final account = _getAccountById(holding.accountId);
                          final accountCurrency = account?.currency ?? 'USD';
                          final accountCurrencyPriceInUSD = CurrencyService().getPrice(accountCurrency) ?? 1.0;
                          final currentPriceInAccountCurrency = currentPriceInUSD / accountCurrencyPriceInUSD;

                          final bookValue = holding.quantity * holding.avgBuyPrice;
                          final marketValue = holding.quantity * currentPriceInAccountCurrency;
                          final gainLoss = marketValue - bookValue;
                          final gainLossPercent = bookValue > 0 ? (gainLoss / bookValue) * 100 : 0.0;

                          final isProfit = gainLoss >= 0;
                          final trendColor = isProfit ? AppColors.limeMoss : AppColors.cinnabar;
                          final trendSign = isProfit ? '+' : '';

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                            child: Row(
                              children: [
                                // Asset Identifiers
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            symbol,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          _buildTypeBadge(type),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        assetName,
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),

                                // Position details (Quantity, Average Price, Current Price)
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${holding.quantity.toStringAsFixed(3)} units',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Avg: ${formatCurrency(holding.avgBuyPrice)}',
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Price: ${formatCurrency(currentPriceInAccountCurrency)}',
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Financial value details (Market value, Book cost, Profit/Loss)
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        formatCurrency(marketValue),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Book: ${formatCurrency(bookValue)}',
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$trendSign${formatCurrency(gainLoss)} ($trendSign${gainLossPercent.toStringAsFixed(1)}%)',
                                        style: TextStyle(
                                          color: trendColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // --- Tab 2: Transactions Tab ---
  Widget _buildTransactionsTab() {
    final filteredList = _filteredTransactions;

    return Column(
      children: [
        // Search & Filter header bar
        Container(
          color: AppColors.card,
          padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 12.0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search asset symbol, name, or account...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(Icons.search, color: AppColors.limeMoss),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.white54),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24.0),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildTypeChoiceChip('All', null),
                  const SizedBox(width: 8),
                  _buildTypeChoiceChip('Buy', 'buy'),
                  const SizedBox(width: 8),
                  _buildTypeChoiceChip('Sell', 'sell'),
                  const Spacer(),
                  if (_searchQuery.isNotEmpty || _selectedTxType != null)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _clearFilters();
                        });
                      },
                      icon: const Icon(Icons.filter_alt_off, size: 16, color: Colors.white),
                      label: const Text('Clear', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                ],
              ),
            ],
          ),
        ),

        // Transactions list view
        Expanded(
          child: _isLoadingTransactions
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.limeMoss),
                  ),
                )
              : filteredList.isEmpty
                  ? RefreshIndicator(
                      onRefresh: loadTransactions,
                      color: AppColors.limeMoss,
                      backgroundColor: AppColors.card,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 100),
                          Center(
                            child: Text(
                              'No asset transactions found.',
                              style: TextStyle(color: Colors.white54, fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: loadTransactions,
                      color: AppColors.limeMoss,
                      backgroundColor: AppColors.card,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: filteredList.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12.0),
                        itemBuilder: (context, index) {
                          final tx = filteredList[index];
                          final isBuy = tx.type.toLowerCase() == 'buy';
                          final totalValue = tx.quantity * tx.unitPrice;
                          final symbol = tx.asset?.symbol ?? 'ASSET';
                          final assetName = tx.asset?.name ?? 'Unknown Asset';

                          return HoverAssetTransactionCard(
                            isBuy: isBuy,
                            child: InkWell(
                              onTap: () => _editTransaction(tx),
                              borderRadius: BorderRadius.circular(16.0),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Row 1: Action (Buy/Sell) & Net Value
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: isBuy
                                                    ? AppColors.limeMoss.withOpacity(0.15)
                                                    : AppColors.cinnabar.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: isBuy ? AppColors.limeMoss : AppColors.cinnabar,
                                                  width: 1,
                                                ),
                                              ),
                                              child: Text(
                                                tx.type.toUpperCase(),
                                                style: TextStyle(
                                                  color: isBuy ? AppColors.limeMoss : AppColors.cinnabar,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 1.1,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              symbol,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          '${isBuy ? "- " : "+ "}${formatCurrency(totalValue)}',
                                          style: TextStyle(
                                            color: isBuy ? AppColors.limeMoss : AppColors.googleBlue,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // Row 2: Asset Details
                                    Text(
                                      assetName,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // Row 3: Meta details
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${tx.accountName ?? "Unknown Account"} • ${tx.quantity.toStringAsFixed(3)} units @ ${formatCurrency(tx.unitPrice)}',
                                          style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 11,
                                          ),
                                        ),
                                        Text(
                                          DateFormat('MMM dd, yyyy').format(tx.executedAt),
                                          style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  // --- Sub-widgets helper ---
  Widget _buildSummaryItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildTypeBadge(String type) {
    final cleanType = type.trim().toLowerCase();
    Color badgeColor = AppColors.googleBlue;
    if (cleanType == 'stock') {
      badgeColor = AppColors.lavenderPurple;
    } else if (cleanType == 'crypto') {
      badgeColor = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: badgeColor.withOpacity(0.5), width: 0.8),
      ),
      child: Text(
        cleanType.toUpperCase(),
        style: TextStyle(
          color: badgeColor,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTypeChoiceChip(String label, String? typeValue) {
    final isSelected = _selectedTxType == typeValue;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedTxType = typeValue;
          });
        }
      },
      selectedColor: AppColors.limeMoss,
      backgroundColor: AppColors.background,
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : Colors.white,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? AppColors.limeMoss : Colors.white10,
          width: 1,
        ),
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    );
  }
}

class HoverAssetTransactionCard extends StatefulWidget {
  final bool isBuy;
  final Widget child;

  const HoverAssetTransactionCard({
    super.key,
    required this.isBuy,
    required this.child,
  });

  @override
  State<HoverAssetTransactionCard> createState() => _HoverAssetTransactionCardState();
}

class _HoverAssetTransactionCardState extends State<HoverAssetTransactionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        transform: _isHovered
            ? Matrix4.translationValues(2.0, 0.0, 0.0)
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered
                ? AppColors.limeMoss
                : Colors.transparent,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? const Color(0x26C2FE0B)
                  : Colors.black.withOpacity(0.15),
              blurRadius: _isHovered ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}
