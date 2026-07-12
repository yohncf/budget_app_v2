import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:budget_app_v2/core/config/app_colors.dart';
import 'package:budget_app_v2/core/models/models.dart';
import 'package:budget_app_v2/core/services/database_service.dart';
import '../../core/utils/currency_formatter.dart';
import 'add_asset_transaction_bottom_sheet.dart';


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
  bool _isLoadingHoldings = false;
  bool _isLoadingTransactions = false;

  // Search & Filter state for Transactions tab
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedTxType; // 'buy', 'sell', or null (All)

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
      loadHoldings(),
      loadTransactions(),
    ]);
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
  double get _totalPortfolioCost {
    return _holdings.fold(0.0, (sum, holding) => sum + (holding.quantity * holding.avgBuyPrice));
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
                  const Text(
                    'TOTAL PORTFOLIO BOOK COST',
                    style: TextStyle(
                      color: Colors.white54,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatCurrency(_totalPortfolioCost),
                    style: const TextStyle(
                      color: AppColors.limeMoss,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
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
          ...groupedHoldings.entries.map((entry) {
            final accountName = entry.key;
            final accountHoldings = entry.value;
            final accountTotalCost = accountHoldings.fold<double>(
              0.0,
              (sum, h) => sum + (h.quantity * h.avgBuyPrice),
            );

            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Card(
                color: AppColors.card,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  side: const BorderSide(color: Colors.white10, width: 1.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Account Header Panel
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                      decoration: const BoxDecoration(
                        color: Color(0xFF141414),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16.0),
                          topRight: Radius.circular(16.0),
                        ),
                      ),
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
                          Text(
                            formatCurrency(accountTotalCost),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Holdings List inside Account Card
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
                        final cost = holding.quantity * holding.avgBuyPrice;

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

                              // Position details (Quantity & Average Price)
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
                                  ],
                                ),
                              ),

                              // Total position cost
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      formatCurrency(cost),
                                      style: const TextStyle(
                                        color: AppColors.limeMoss,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Book Value',
                                      style: TextStyle(
                                        color: Colors.white38,
                                        fontSize: 11,
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
