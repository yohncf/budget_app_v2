import 'package:flutter/material.dart';
import 'package:budget_app_v2/core/config/app_colors.dart';
import 'package:intl/intl.dart';
import '../../core/models/models.dart';
import '../../core/services/database_service.dart';
import 'add_transaction_bottom_sheet.dart';
class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => TransactionsPageState();
}

class TransactionsPageState extends State<TransactionsPage> {
  final _databaseService = DatabaseService();
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  List<Transaction> _transactions = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 30;

  // Filters and search query state variables
  DateTime? _startDate;
  DateTime? _presetDate; // Default preset date (15 days ago) to revert to on clearing filters
  String _searchQuery = '';
  String? _selectedTypeFilter; // Tracks category type filter selection ('expense', 'income', 'transfer', or null)

  /// Returns the default date preset of 15 days ago
  DateTime _getDefaultPresetDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 15));
  }

  @override
  void initState() {
    super.initState();
    // Initialize filter date preset and start date
    _presetDate = _getDefaultPresetDate();
    _startDate = _presetDate;
    loadTransactions();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Fetches transactions from backend using active filters (date range, query, type)
  Future<void> loadTransactions({bool reset = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (reset) {
        _transactions.clear();
        _offset = 0;
        _hasMore = true;
      }
    });

    try {
      final list = await _databaseService.fetchTransactions(
        startDate: _startDate,
        query: _searchQuery.isEmpty ? null : _searchQuery,
        typeFilter: _selectedTypeFilter,
        limit: _limit,
        offset: _offset,
      );

      setState(() {
        _transactions.addAll(list);
        _offset += list.length;
        if (list.length < _limit) {
          _hasMore = false;
        }
      });
    } catch (e) {
      print('Error loading transactions: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (_hasMore && !_isLoading) {
        loadTransactions();
      }
    }
  }

  /// Triggers a reset reload when the search term is updated
  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    loadTransactions(reset: true);
  }

  /// Opens the system date picker dialog with custom dark styling mapping to design guidelines
  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.limeMoss,
              onPrimary: Colors.black,
              surface: AppColors.card,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
      loadTransactions(reset: true);
    }
  }

  /// Clears the search field, type filter, and reverts the start date back to the initial preset
  void _clearAllFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _startDate = _presetDate;
      _selectedTypeFilter = null;
    });
    loadTransactions(reset: true);
  }

  bool get _hasActiveFilters {
    return _searchQuery.isNotEmpty || _startDate != _presetDate || _selectedTypeFilter != null;
  }

  Widget _buildTypeChip(String label, String? typeValue) {
    final isSelected = _selectedTypeFilter == typeValue;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedTypeFilter = typeValue;
          });
          loadTransactions(reset: true);
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

  void _editTransaction(Transaction tx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTransactionBottomSheet(
        transaction: tx,
        onSaved: () => loadTransactions(reset: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(140),
        child: Container(
          color: AppColors.card,
          padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search input and Date Picker row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search description, tags, amount, category...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(Icons.search, color: AppColors.limeMoss),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.white54),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
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
                  const SizedBox(width: 10),
                  // Date picker next to search bar
                  InkWell(
                    onTap: _selectStartDate,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white10, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.date_range, size: 18, color: AppColors.limeMoss),
                          const SizedBox(width: 8),
                          Text(
                            _startDate == null
                                ? 'All Time'
                                : DateFormat('MMM dd').format(_startDate!),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Chips & Clear Filters Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildTypeChip('All', null),
                          const SizedBox(width: 8),
                          _buildTypeChip('Expense', 'expense'),
                          const SizedBox(width: 8),
                          _buildTypeChip('Income', 'income'),
                          const SizedBox(width: 8),
                          _buildTypeChip('Transfer', 'transfer'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_hasActiveFilters)
                    TextButton.icon(
                      onPressed: _clearAllFilters,
                      icon: const Icon(Icons.filter_alt_off, size: 16, color: Colors.white),
                      label: const Text('Clear Filters', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: _transactions.isEmpty && _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.limeMoss),
              ),
            )
          : _transactions.isEmpty
              ? const Center(
                  child: Text('No transactions found matching the filter.', style: TextStyle(color: Colors.white)),
                )
              : ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _transactions.length + (_hasMore ? 1 : 0),
                  separatorBuilder: (context, index) => const SizedBox(height: 12.0),
                  itemBuilder: (context, index) {
                    if (index == _transactions.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.0),
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.limeMoss),
                          ),
                        ),
                      );
                    }

                    // Extract transaction model attributes
                    final tx = _transactions[index];
                    final isIncome = tx.amount > 0;
                    
                    // Check if the transaction represents a transfer (either by category type or tag prefix)
                    final isTransfer = tx.categoryType == 'transfer' || 
                        (tx.tags != null && tx.tags!.startsWith('transfer_pair:'));

                    return HoverTransactionCard(
                      isIncome: isIncome,
                      child: InkWell(
                        onTap: () => _editTransaction(tx),
                        borderRadius: BorderRadius.circular(16.0),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Row 1: Category Name & Amount (Color-coded)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    tx.categoryName ?? 'Uncategorized',
                                    style: const TextStyle(
                                      color: AppColors.limeMoss,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                  Text(
                                    '${isIncome ? "+" : ""}\$${tx.amount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      // Transactions of type transfer should be colored Google Blue,
                                      // other transactions are green (inflow/income) or red (outflow/expense)
                                      color: isTransfer 
                                          ? AppColors.googleBlue 
                                          : (isIncome ? AppColors.limeMoss : AppColors.cinnabar),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),

                              // Row 2: Description
                              Text(
                                tx.description ?? 'No Description',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),

                              // Row 3: Meta (Account Name & Date)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${tx.accountName ?? "Unknown Account"} • ${tx.currency}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    DateFormat('MMM dd, yyyy - hh:mm a').format(tx.date),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),

                              // Row 4: Tag Chips
                              if (tx.tags != null && tx.tags!.trim().isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: tx.tags!.split(',').map((tag) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.googleBlue.withOpacity(0.15), // Purple tag accent
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppColors.googleBlue.withOpacity(0.4), width: 1),
                                      ),
                                      child: Text(
                                        tag.trim(),
                                        style: const TextStyle(
                                          color: Color(0xFFB22CE4),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                )
                              ]
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}



/// A premium, animated hover transaction card widget.
///
/// **Why it exists**: Translates horizontally and scales borders/shadows smoothly
/// on hover, making the transactions page feel alive and reactive.
class HoverTransactionCard extends StatefulWidget {
  final bool isIncome;
  final Widget child;

  const HoverTransactionCard({
    super.key,
    required this.isIncome,
    required this.child,
  });

  @override
  State<HoverTransactionCard> createState() => _HoverTransactionCardState();
}

class _HoverTransactionCardState extends State<HoverTransactionCard> {
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
                ? AppColors.limeMoss // Lime Moss #7DAC20 highlight on hover
                : Colors.transparent,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered 
                  ? const Color(0x26C2FE0B) // 15% opacity Volt Green glow on hover
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
