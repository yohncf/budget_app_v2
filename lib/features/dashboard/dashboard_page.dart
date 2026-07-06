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
