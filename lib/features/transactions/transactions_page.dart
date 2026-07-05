import 'package:flutter/material.dart';
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

  DateTime? _startDate;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 15));
    loadTransactions();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

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

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    loadTransactions(reset: true);
  }

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
              primary: Color(0xFF96CC28),
              onPrimary: Colors.black,
              surface: Color(0xFF0E0E0E),
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

  void _clearDateFilter() {
    setState(() {
      _startDate = null;
    });
    loadTransactions(reset: true);
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
      backgroundColor: const Color(0xFF030303),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(130),
        child: Container(
          color: const Color(0xFF0E0E0E),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Search input
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search description, tags, amount, category...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF96CC28)),
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
                  fillColor: const Color(0xFF030303),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.0),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Filter row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Color(0xFF96CC28)),
                      const SizedBox(width: 8),
                      Text(
                        _startDate == null
                            ? 'All Transactions'
                            : 'Since: ${DateFormat.yMMMd().format(_startDate!)}',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (_startDate != null)
                        TextButton.icon(
                          onPressed: _clearDateFilter,
                          icon: const Icon(Icons.filter_alt_off, size: 16, color: Color(0xFFFB9426)),
                          label: const Text('Clear', style: TextStyle(color: Color(0xFFFB9426), fontSize: 13)),
                        ),
                      TextButton.icon(
                        onPressed: _selectStartDate,
                        icon: const Icon(Icons.date_range, size: 16, color: Color(0xFF96CC28)),
                        label: const Text('Pick Date', style: TextStyle(color: Color(0xFF96CC28), fontSize: 13)),
                      ),
                    ],
                  )
                ],
              )
            ],
          ),
        ),
      ),
      body: _transactions.isEmpty && _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF96CC28)),
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
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF96CC28)),
                          ),
                        ),
                      );
                    }

                    final tx = _transactions[index];
                    final isIncome = tx.amount > 0;

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
                              // Row 1: Category Name & Amount
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    tx.categoryName ?? 'Uncategorized',
                                    style: const TextStyle(
                                      color: Color(0xFF96CC28),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                  Text(
                                    '${isIncome ? "+" : ""}\$${tx.amount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: isIncome ? const Color(0xFF96CC28) : const Color(0xFFDB1F87),
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
                                        color: const Color(0xFF5E2CE4).withOpacity(0.15), // Purple tag accent
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFF5E2CE4).withOpacity(0.4), width: 1),
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
          color: const Color(0xFF0E0E0E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered 
                ? const Color(0xFF96CC28) // Primary Lime #96CC28 highlight on hover
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
