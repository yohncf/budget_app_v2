import 'package:flutter/material.dart';
import 'package:budget_app_v2/core/config/app_colors.dart';
import 'package:fl_chart/fl_chart.dart';
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
  bool _isLoading = true;

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
      setState(() {
        _accounts = accounts.where((acc) => acc.status != 'archived').toList();
        _transactions = transactions;
      });
    } catch (e) {
      print('Error loading dashboard data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  double get _totalNetWorth {
    double total = 0.0;
    for (var acc in _accounts) {
      total += acc.currentBalance;
    }
    return total;
  }

  double get _totalLiquidAssets {
    return _accounts
        .where((acc) => acc.accountGroup == 'liquid_assets')
        .fold(0.0, (sum, acc) => sum + acc.currentBalance);
  }

  double get _totalCreditDebt {
    return _accounts
        .where((acc) => acc.accountGroup == 'credit')
        .fold(0.0, (sum, acc) => sum + acc.currentBalance);
  }

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
                  childAspectRatio: isWide ? 1.6 : 1.3,
                  children: [
                    HoverSummaryCard(
                      title: 'Net Worth',
                      value: '\$${_totalNetWorth.toStringAsFixed(2)}',
                      icon: Icons.account_balance,
                      color: AppColors.limeMoss, // Lime Moss #7DAC20
                    ),
                    HoverSummaryCard(
                      title: 'Liquid Assets',
                      value: '\$${_totalLiquidAssets.toStringAsFixed(2)}',
                      icon: Icons.money,
                      color: AppColors.limeMoss, // Lime Moss #7DAC20
                    ),
                    HoverSummaryCard(
                      title: 'Credit Debt',
                      value: '\$${_totalCreditDebt.toStringAsFixed(2)}',
                      icon: Icons.credit_card,
                      color: AppColors.cinnabar, // Cinnabar #CB2549
                    ),
                    HoverSummaryCard(
                      title: 'Retirement Savings',
                      value: '\$${_totalRetirement.toStringAsFixed(2)}',
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
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
                            'Monthly comparison of Income vs Expenses',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                      // Legend Row
                      Row(
                        children: [
                          _buildLegendIndicator('Income', AppColors.limeMoss),
                          const SizedBox(width: 16),
                          _buildLegendIndicator('Expenses', AppColors.lavenderPurple),
                        ],
                      )
                    ],
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

  LineChartData _getMainChartData() {
    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 1000,
        getDrawingHorizontalLine: (value) {
          return const FlLine(
            color: Colors.white10,
            strokeWidth: 1,
          );
        },
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
              String text = '';
              switch (value.toInt()) {
                case 1:
                  text = 'Jan';
                  break;
                case 3:
                  text = 'Mar';
                  break;
                case 5:
                  text = 'May';
                  break;
                case 7:
                  text = 'Jul';
                  break;
                case 9:
                  text = 'Sep';
                  break;
                case 11:
                  text = 'Nov';
                  break;
              }
              return SideTitleWidget(
                meta: meta,
                space: 8,
                child: Text(text, style: const TextStyle(color: Colors.white54, fontSize: 11)),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1000,
            getTitlesWidget: (value, meta) {
              return Text(
                '\$${(value.toInt() ~/ 1000)}k',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
                textAlign: TextAlign.left,
              );
            },
            reservedSize: 42,
          ),
        ),
      ),
      borderData: FlBorderData(
        show: false,
      ),
      minX: 0,
      maxX: 11,
      minY: 0,
      maxY: 4000,
      lineBarsData: [
        // Income Line (Green)
        LineChartBarData(
          spots: const [
            FlSpot(0, 2000),
            FlSpot(2, 2300),
            FlSpot(4, 2500),
            FlSpot(6, 2500),
            FlSpot(8, 2700),
            FlSpot(10, 3100),
            FlSpot(11, 3500),
          ],
          isCurved: true,
          color: AppColors.limeMoss, // Lime Moss #7DAC20
          barWidth: 4,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: false,
          ),
        ),
        // Expenses Line (Lavender purple #4285F4)
        LineChartBarData(
          spots: const [
            FlSpot(0, 1500),
            FlSpot(2, 1800),
            FlSpot(4, 1400),
            FlSpot(6, 1900),
            FlSpot(8, 2100),
            FlSpot(10, 2300),
            FlSpot(11, 2000),
          ],
          isCurved: true,
          color: AppColors.lavenderPurple, // Lavender purple #4285F4
          barWidth: 4,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: false,
          ),
        ),
      ],
    );
  }
}

/// A premium, animated hover summary card widget.
///
/// **Why it exists**: Animates scale, shadow, and borders when the mouse hovers
/// over it, giving the dashboard a highly interactive and state-of-the-art SaaS feel.
class HoverSummaryCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const HoverSummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
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
        padding: const EdgeInsets.all(16.0),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Icon(
                widget.icon,
                color: widget.color.withOpacity(0.85),
                size: 22,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
