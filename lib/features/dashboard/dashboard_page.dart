import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:budget_app_v2/core/config/app_colors.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/models/models.dart';
import '../../core/services/database_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage> {
  final _databaseService = DatabaseService();
  
  List<Account> _accounts = [];
  List<Transaction> _transactions = [];
  List<Transaction> _chartTransactions = [];
  String _chartMode = 'cumulative'; // 'cumulative' or 'daily'
  String _chartRange = '60days'; // '60days' or 'currentMonth'
  bool _isLoading = true;
  bool _showHoldingInChecking = false;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final accounts = await _databaseService.fetchAccounts();
      final transactions = await _databaseService.fetchTransactions(limit: 30, offset: 0);
      
      final sixtyDaysAgo = DateTime.now().subtract(const Duration(days: 60));
      final chartTransactions = await _databaseService.fetchTransactions(
        startDate: sixtyDaysAgo,
        limit: 1000,
        offset: 0,
      );

      setState(() {
        _accounts = accounts.where((acc) => acc.status != 'archived').toList();
        _transactions = transactions;
        _chartTransactions = chartTransactions;
      });
    } catch (e) {
      print('Error loading dashboard data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Formats a double amount into standard currency notation with commas: e.g., "$1,234,567.89".
  String _formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'en_US', symbol: '\$').format(amount);
  }

  /// Determines the card title for the checking account summary, dynamically adding "+ Holding" if toggled.
  /// This provides clear visual feedback to the user about which accounts are currently included in the total.
  String get _checkingCardTitle => _showHoldingInChecking ? 'Checking + Holding' : 'Total Checking';

  /// Calculates the total balance of all active accounts of type 'checking'.
  /// 
  /// NOTE: We explicitly exclude any account named 'Holding' (case-insensitive) by default.
  /// This is because we want the card to show checking-only accounts initially, and ONLY
  /// include the 'Holding' account balance when the user explicitly clicks the card to
  /// toggle its state (`_showHoldingInChecking == true`).
  double get _totalChecking {
    double sum = _accounts
        .where((acc) => acc.type == 'checking' && acc.name.toLowerCase() != 'holding')
        .fold(0.0, (sum, acc) => sum + acc.currentBalance);

    // If toggled, we find and add the balance of the 'Holding' account to the total.
    if (_showHoldingInChecking) {
      final holdingAcc = _accounts.firstWhere(
        (acc) => acc.name.toLowerCase() == 'holding',
        orElse: () => Account(
          id: '',
          name: '',
          type: '',
          institution: '',
          currency: '',
          currentBalance: 0.0,
          limit: 0.0,
          accountGroup: '',
          status: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      sum += holdingAcc.currentBalance;
    }
    return sum;
  }

  /// Calculates the total balance of all active accounts of type 'credit_card'.
  double get _totalCreditCard {
    return _accounts
        .where((acc) => acc.type == 'credit_card')
        .fold(0.0, (sum, acc) => sum + acc.currentBalance);
  }

  /// Calculates the difference between checking account totals and credit card totals.
  /// 
  /// NOTE: Because this getter references `_totalChecking`, it dynamically updates to
  /// include or exclude the 'Holding' account's balance whenever Card 1 is clicked.
  /// This satisfies the requirement that the third card uses Card 1's active value vs credit card total.
  double get _checkingMinusCreditCard {
    return _totalChecking - _totalCreditCard;
  }

  /// Calculates the total balance of all active accounts in the 'retirement' account group.
  double get _totalRetirement {
    return _accounts
        .where((acc) => acc.accountGroup == 'retirement')
        .fold(0.0, (sum, acc) => sum + acc.currentBalance);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.limeMoss),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Text(
              'Dashboard',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // Financial Summary Cards Row
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 600;
                return GridView.count(
                  crossAxisCount: isWide ? 4 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: isWide ? 1.9 : 1.4,
                  children: [
                    // Card 1: Sum of checking accounts (toggles to include 'Holding' account on tap)
                    HoverSummaryCard(
                      title: _checkingCardTitle,
                      value: _formatCurrency(_totalChecking),
                      icon: Icons.account_balance_wallet,
                      color: AppColors.limeMoss, // Lime Moss #7DAC20
                      onTap: () {
                        setState(() {
                          _showHoldingInChecking = !_showHoldingInChecking;
                        });
                      },
                    ),
                    // Card 2: Sum of credit card accounts
                    HoverSummaryCard(
                      title: 'Credit Card Debt',
                      value: _formatCurrency(_totalCreditCard),
                      icon: Icons.credit_card,
                      color: AppColors.cinnabar, // Cinnabar #CB2549
                    ),
                    // Card 3: Checking minus credit card
                    HoverSummaryCard(
                      title: 'Net Checking vs Credit',
                      value: _formatCurrency(_checkingMinusCreditCard),
                      icon: Icons.balance,
                      color: _checkingMinusCreditCard >= 0 
                          ? AppColors.limeMoss 
                          : AppColors.cinnabar, // Dynamically changes color based on positive/negative net worth
                    ),
                    // Card 4: Sum of retirement accounts
                    HoverSummaryCard(
                      title: 'Retirement Savings',
                      value: _formatCurrency(_totalRetirement),
                      icon: Icons.trending_up,
                      color: AppColors.googleBlue, // Google Blue #9272BF
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),

            // Premium Line Chart Card
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(24.0),
                border: Border.all(color: Colors.transparent, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 600;
                      
                      final dynamic rawRange = _chartRange;
                      final String range = rawRange == null ? '60days' : rawRange as String;

                      final titleColumn = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cash Flow Overview',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            range == 'currentMonth'
                                ? 'Checking Income vs Credit Card Expenses (Current Month)'
                                : 'Checking Income vs Credit Card Expenses (Last 60 Days)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      );

                      final rangeWidget = _buildRangeChips();

                      final controlsRow = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildToggle(),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLegendIndicator('Checking Income', AppColors.limeMoss),
                              const SizedBox(height: 6),
                              _buildLegendIndicator('CC Expenses', AppColors.lavenderPurple),
                            ],
                          ),
                        ],
                      );

                      if (isWide) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(child: titleColumn),
                                  const SizedBox(width: 16),
                                  rangeWidget,
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            controlsRow,
                          ],
                        );
                      } else {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            titleColumn,
                            const SizedBox(height: 12),
                            rangeWidget,
                            const SizedBox(height: 16),
                            controlsRow,
                          ],
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 240,
                    child: LineChart(
                      _getMainChartData(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Recent activity header
            Text(
              'Recent Transactions',
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Short Transaction List
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(24.0),
                border: Border.all(color: Colors.transparent, width: 1),
              ),
              child: _transactions.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(
                        child: Text(
                          'No recent transactions found.',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _transactions.take(5).length,
                      separatorBuilder: (context, index) => const Divider(color: Colors.white12, height: 1),
                      itemBuilder: (context, index) {
                        final tx = _transactions[index];
                        final isIncome = tx.amount > 0;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.background,
                            child: Icon(
                              isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                              color: isIncome ? AppColors.limeMoss : AppColors.cinnabar,
                            ),
                          ),
                          title: Text(
                            tx.description ?? 'Unlabeled Transaction',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${tx.accountName ?? "Account"} • ${tx.categoryName ?? "Category"}',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          trailing: Text(
                            '${isIncome ? "+" : ""}\$${tx.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: isIncome ? AppColors.limeMoss : AppColors.cinnabar,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Deleted old static _buildSummaryCard helper. HoverSummaryCard is defined below as a stateful widget.

  Widget _buildLegendIndicator(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleOption('cumulative', 'Cumulative'),
          _buildToggleOption('daily', 'Daily'),
        ],
      ),
    );
  }

  Widget _buildToggleOption(String mode, String label) {
    final isSelected = _chartMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _chartMode = mode;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.limeMoss : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildRangeChips() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRangeChipOption('60days', '60 Days'),
          _buildRangeChipOption('currentMonth', 'This Month'),
        ],
      ),
    );
  }

  Widget _buildRangeChipOption(String range, String label) {
    final dynamic rawRange = _chartRange;
    final String currentRange = rawRange == null ? '60days' : rawRange as String;
    final isSelected = currentRange == range;
    return GestureDetector(
      onTap: () {
        setState(() {
          _chartRange = range;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.googleBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  LineChartData _getMainChartData() {
    final today = DateTime.now();
    
    final dynamic rawRange = _chartRange;
    final String range = rawRange == null ? '60days' : rawRange as String;

    DateTime startDate;
    int daysCount;

    if (range == 'currentMonth') {
      startDate = DateTime(today.year, today.month, 1);
      daysCount = DateTime(today.year, today.month + 1, 0).day;
    } else {
      startDate = DateTime(today.year, today.month, today.day).subtract(const Duration(days: 59));
      daysCount = 60;
    }

    List<double> dailyIncome = List.filled(daysCount, 0.0);
    List<double> dailyExpenses = List.filled(daysCount, 0.0);

    // Use dynamic to satisfy the analyzer while maintaining runtime safety during web hot reload
    final dynamic rawTxList = _chartTransactions;
    final List<Transaction> txList = rawTxList == null ? <Transaction>[] : List<Transaction>.from(rawTxList as Iterable);
    for (final tx in txList) {
      final account = _accounts.firstWhere(
        (a) => a.id == tx.accountId,
        orElse: () => Account(
          id: '',
          name: '',
          type: '',
          institution: '',
          currency: '',
          currentBalance: 0,
          limit: 0,
          accountGroup: '',
          status: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      if (account.id.isEmpty) continue;

      final txNormalized = DateTime(tx.date.year, tx.date.month, tx.date.day);
      final dayIndex = txNormalized.difference(startDate).inDays;

      if (dayIndex >= 0 && dayIndex < daysCount) {
        if (account.type == 'checking') {
          if (tx.categoryType == 'income' || tx.categoryType == 'reimbursement' || (tx.amount > 0 && tx.categoryType != 'transfer')) {
            dailyIncome[dayIndex] += tx.amount;
          }
        } else if (account.type == 'credit_card') {
          if (tx.categoryType == 'expense' || tx.categoryType == 'tax' || (tx.amount < 0 && tx.categoryType != 'transfer')) {
            dailyExpenses[dayIndex] += tx.amount.abs();
          }
        }
      }
    }

    List<double> incomePoints = List.filled(daysCount, 0.0);
    List<double> expensePoints = List.filled(daysCount, 0.0);

    // Use dynamic to satisfy the analyzer while maintaining runtime safety during web hot reload
    final dynamic rawMode = _chartMode;
    final String mode = rawMode == null ? 'cumulative' : rawMode as String;
    if (mode == 'cumulative') {
      double runningIncome = 0.0;
      double runningExpense = 0.0;
      for (int i = 0; i < daysCount; i++) {
        runningIncome += dailyIncome[i];
        runningExpense += dailyExpenses[i];
        incomePoints[i] = runningIncome;
        expensePoints[i] = runningExpense;
      }
    } else {
      incomePoints = dailyIncome;
      expensePoints = dailyExpenses;
    }

    List<FlSpot> incomeSpots = [];
    List<FlSpot> expenseSpots = [];

    for (int i = 0; i < daysCount; i++) {
      incomeSpots.add(FlSpot(i.toDouble(), incomePoints[i]));
      expenseSpots.add(FlSpot(i.toDouble(), expensePoints[i]));
    }

    double maxIncome = incomePoints.isEmpty ? 0.0 : incomePoints.reduce(math.max);
    double maxExpense = expensePoints.isEmpty ? 0.0 : expensePoints.reduce(math.max);
    double maxVal = math.max(maxIncome, maxExpense);
    if (maxVal < 100) maxVal = 100;

    double maxY;
    if (maxVal > 10000) {
      maxY = (maxVal / 5000).ceil() * 5000.0;
    } else if (maxVal > 2000) {
      maxY = (maxVal / 1000).ceil() * 1000.0;
    } else if (maxVal > 500) {
      maxY = (maxVal / 500).ceil() * 500.0;
    } else {
      maxY = (maxVal / 100).ceil() * 100.0;
    }

    double interval = maxY / 4;
    if (interval < 1) interval = 1;

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: interval,
        getDrawingHorizontalLine: (value) {
          return const FlLine(
            color: Colors.white10,
            strokeWidth: 1,
          );
        },
      ),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (touchedSpot) => AppColors.card,
          tooltipBorder: const BorderSide(color: Colors.white12, width: 1),
          tooltipBorderRadius: const BorderRadius.all(Radius.circular(8)),
          getTooltipItems: (List<LineBarSpot> touchedSpots) {
            return touchedSpots.map((barSpot) {
              final isIncome = barSpot.barIndex == 0;
              final dayIndex = barSpot.x.toInt();
              final date = startDate.add(Duration(days: dayIndex));
              final dateStr = DateFormat('MMM dd').format(date);
              final valStr = _formatCurrency(barSpot.y);
              final prefix = barSpot == touchedSpots.first ? '$dateStr\n' : '';
              
              if (isIncome) {
                return LineTooltipItem(
                  '${prefix}Income: $valStr',
                  const TextStyle(
                    color: AppColors.limeMoss,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              } else {
                return LineTooltipItem(
                  '${prefix}Expenses: $valStr',
                  const TextStyle(
                    color: AppColors.lavenderPurple,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }
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
              final int dayIndex = value.toInt();
              if (dayIndex >= 0 && dayIndex < daysCount) {
                bool shouldShow = false;
                if (daysCount == 60) {
                  shouldShow = (dayIndex == 0 || dayIndex == 15 || dayIndex == 30 || dayIndex == 45 || dayIndex == 59);
                } else {
                  shouldShow = (dayIndex == 0 || dayIndex == 9 || dayIndex == 19 || dayIndex == daysCount - 1);
                }

                if (shouldShow) {
                  final date = startDate.add(Duration(days: dayIndex));
                  return SideTitleWidget(
                    meta: meta,
                    space: 8,
                    child: Text(
                      DateFormat('MM/dd').format(date),
                      style: const TextStyle(color: Colors.white54, fontSize: 10),
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
            interval: interval,
            getTitlesWidget: (value, meta) {
              if (value < 0 || value > maxY) return const SizedBox.shrink();
              String text;
              if (value >= 1000) {
                final kVal = value / 1000;
                if (kVal == kVal.toInt()) {
                  text = '\$${kVal.toInt()}k';
                } else {
                  text = '\$${kVal.toStringAsFixed(1)}k';
                }
              } else {
                text = '\$${value.toInt()}';
              }
              return SideTitleWidget(
                meta: meta,
                space: 8,
                child: Text(
                  text,
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                  textAlign: TextAlign.left,
                ),
              );
            },
            reservedSize: 48,
          ),
        ),
      ),
      borderData: FlBorderData(
        show: false,
      ),
      minX: 0,
      maxX: (daysCount - 1).toDouble(),
      minY: 0,
      maxY: maxY,
      lineBarsData: [
        LineChartBarData(
          spots: incomeSpots,
          isCurved: true,
          color: AppColors.limeMoss,
          barWidth: 3.5,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: AppColors.limeMoss.withOpacity(0.08),
          ),
        ),
        LineChartBarData(
          spots: expenseSpots,
          isCurved: true,
          color: AppColors.lavenderPurple,
          barWidth: 3.5,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: AppColors.lavenderPurple.withOpacity(0.08),
          ),
        ),
      ],
    );
  }
}

/// A premium, animated hover summary card widget conforming to Material 3 card specs.
///
/// **Why it exists**: Animates scale, shadow, and borders when the mouse hovers
/// over it, giving the dashboard a highly interactive and state-of-the-art SaaS feel.
class HoverSummaryCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const HoverSummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  State<HoverSummaryCard> createState() => _HoverSummaryCardState();
}

class _HoverSummaryCardState extends State<HoverSummaryCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: _isHovered 
              ? Matrix4.translationValues(0.0, -4.0, 0.0) 
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered 
                  ? AppColors.limeMoss // Lime Moss #7DAC20 highlight on hover
                  : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered 
                    ? const Color(0x26C2FE0B) // 15% opacity Volt Green glow on hover
                    : Colors.black.withOpacity(0.2),
                blurRadius: _isHovered ? 12 : 6,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0), // Margins upscaled to balance larger sizes
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header/Headline & Subhead text column on the left side
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, // Align text to the top-left corner
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      widget.title, // Shown as "Headline" text (visually bold & prominent) in the top-left corner
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18, // Upscaled from 16 to maximize legibility and presence
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.start,
                    ),
                    const SizedBox(height: 6), // Adjusted gap to balance larger text elements
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.value, // Shown as "Subhead" text (less prominent format) just below the Headline
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16, // Upscaled from 14 to maximize readability
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.start,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Icon wrapped in a circle on the right side
              Container(
                width: 42, // Upscaled from 36 to match larger layout
                height: 42, // Upscaled from 36 to match larger layout
                decoration: const BoxDecoration(
                  color: AppColors.background, // Circular badge matched to app canvas background
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.icon,
                  color: widget.color,
                  size: 22, // Upscaled from 18 to match larger circle container
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
