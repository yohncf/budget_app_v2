import 'dart:math';
import 'package:flutter/material.dart';
import 'package:budget_app_v2/core/config/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/models/models.dart';
import '../../core/services/database_service.dart';

/// Custom input formatter to restrict values to floats with max 2 decimal places.
class DecimalTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final regEx = RegExp(r'^\d*\.?\d{0,2}');
    final String newString = regEx.stringMatch(newValue.text) ?? '';
    return newString == newValue.text ? newValue : oldValue;
  }
}

class AddTransactionBottomSheet extends StatefulWidget {
  final Transaction? transaction;
  final VoidCallback onSaved;

  const AddTransactionBottomSheet({
    super.key,
    this.transaction,
    required this.onSaved,
  });

  @override
  State<AddTransactionBottomSheet> createState() => _AddTransactionBottomSheetState();
}

class _AddTransactionBottomSheetState extends State<AddTransactionBottomSheet> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _databaseService = DatabaseService();
  late TabController _tabController;

  // Form Fields State
  late DateTime _selectedDate;
  final _amountController = TextEditingController();
  late String _currency;
  String? _categoryId;
  final _descriptionController = TextEditingController();
  
  // Searchable Autocomplete Category Fields
  final _categorySearchController = TextEditingController();
  final _categoryFocusNode = FocusNode();

  // Searchable Autocomplete Account Fields (Source)
  String? _accountId;
  final _accountSearchController = TextEditingController();
  final _accountFocusNode = FocusNode();

  // Searchable Autocomplete Account Fields (Destination)
  String? _destAccountId;
  final _destAccountSearchController = TextEditingController();
  final _destAccountFocusNode = FocusNode();

  // Loaded database lists
  List<Account> _accounts = [];
  List<Category> _categories = [];
  List<Map<String, dynamic>> _recurringBudgets = [];

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isRecurring = false;
  String? _recurringId;
  bool _isFirstLoad = true;

  // For Edit Mode
  Transaction? _counterpartTx;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Default form states
    _selectedDate = widget.transaction?.date ?? DateTime.now();
    if (widget.transaction != null) {
      _amountController.text = widget.transaction!.amount.abs().toString();
      _currency = widget.transaction!.currency;
      _categoryId = widget.transaction!.categoryId;
      _descriptionController.text = widget.transaction!.description ?? '';
      _accountId = widget.transaction!.accountId;
      _isRecurring = widget.transaction!.isRecurring;
      _recurringId = widget.transaction!.recurringId;
    } else {
      _currency = 'MXN'; // Default currency
    }

    _loadData();

    // Listen to tab changes to adjust default selected category and validation
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _onTabChanged();
      }
    });

    // Listen to search controller inputs to automatically map search selections to IDs.
    // Skips if lookup database lists are not loaded yet to avoid early clears.
    _categorySearchController.addListener(() {
      if (_categories.isEmpty) return;
      final text = _categorySearchController.text.trim();
      final match = _categories.firstWhere(
        (c) => c.name.toLowerCase() == text.toLowerCase(),
        orElse: () => Category(id: '', name: '', type: '', createdAt: DateTime.now()),
      );
      setState(() {
        if (match.id.isNotEmpty) {
          _categoryId = match.id;
          _checkIfRecurring();
        } else {
          _categoryId = null;
          _isRecurring = false;
          _recurringId = null;
        }
      });
    });

    _accountSearchController.addListener(() {
      if (_accounts.isEmpty) return;
      final text = _accountSearchController.text.trim();
      final match = _accounts.firstWhere(
        (acc) => acc.name.toLowerCase() == text.toLowerCase(),
        orElse: () => Account(id: '', name: '', type: '', institution: '', currency: '', currentBalance: 0, limit: 0, accountGroup: '', status: '', createdAt: DateTime.now(), updatedAt: DateTime.now()),
      );
      setState(() {
        if (match.id.isNotEmpty) {
          _accountId = match.id;
        } else {
          _accountId = null;
        }
      });
    });

    _destAccountSearchController.addListener(() {
      if (_accounts.isEmpty) return;
      final text = _destAccountSearchController.text.trim();
      final match = _accounts.firstWhere(
        (acc) => acc.name.toLowerCase() == text.toLowerCase(),
        orElse: () => Account(id: '', name: '', type: '', institution: '', currency: '', currentBalance: 0, limit: 0, accountGroup: '', status: '', createdAt: DateTime.now(), updatedAt: DateTime.now()),
      );
      setState(() {
        if (match.id.isNotEmpty) {
          _destAccountId = match.id;
        } else {
          _destAccountId = null;
        }
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _categorySearchController.dispose();
    _categoryFocusNode.dispose();
    _accountSearchController.dispose();
    _accountFocusNode.dispose();
    _destAccountSearchController.dispose();
    _destAccountFocusNode.dispose();
    super.dispose();
  }

  Account? _getDefaultDebitAccount(List<Account> accounts) {
    if (accounts.isEmpty) return null;
    final debitAcc = accounts.where((acc) => acc.name.toLowerCase().contains('debit')).toList();
    if (debitAcc.isNotEmpty) return debitAcc.first;
    final checkingAcc = accounts.where((acc) => acc.type == 'checking').toList();
    if (checkingAcc.isNotEmpty) return checkingAcc.first;
    return accounts.first;
  }

  Future<void> _loadData() async {
    try {
      final accounts = await _databaseService.fetchAccounts();
      final categories = await _databaseService.fetchCategories();
      final recurring = await _databaseService.fetchActiveRecurringBudgets();

      setState(() {
        // FILTER: DONT show archived accounts (status != 'archived')
        _accounts = accounts.where((acc) => acc.status != 'archived').toList();
        // SORT: Accounts sorted alphabetically
        _accounts.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

        _categories = categories;
        // SORT: Categories sorted alphabetically
        _categories.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

        _recurringBudgets = recurring;
      });

      // If in edit mode, fetch counterpart if it's a transfer
      if (widget.transaction != null) {
        final tx = widget.transaction!;
        
        final selectedCat = _categories.firstWhere((c) => c.id == tx.categoryId, 
          orElse: () => Category(id: '', name: '', type: 'expense', createdAt: DateTime.now()));
        
        _categoryId = tx.categoryId;
        _categorySearchController.text = selectedCat.name;

        final selectedAcc = _accounts.firstWhere((a) => a.id == tx.accountId,
          orElse: () => Account(id: '', name: '', type: '', institution: '', currency: '', currentBalance: 0, limit: 0, accountGroup: '', status: '', createdAt: DateTime.now(), updatedAt: DateTime.now()));
        
        _accountId = tx.accountId;
        _accountSearchController.text = selectedAcc.name;

        if (selectedCat.type == 'transfer') {
          _tabController.index = 2; // Transfer Tab
          
          if (tx.tags != null && tx.tags!.startsWith('transfer_pair:')) {
            final counterpart = await _databaseService.fetchTransferCounterpart(tx.id, tx.tags!);
            if (counterpart != null) {
              final counterpartAcc = _accounts.firstWhere((a) => a.id == counterpart.accountId,
                orElse: () => Account(id: '', name: '', type: '', institution: '', currency: '', currentBalance: 0, limit: 0, accountGroup: '', status: '', createdAt: DateTime.now(), updatedAt: DateTime.now()));
              
              setState(() {
                _counterpartTx = counterpart;
                if (tx.amount < 0) {
                  _accountId = tx.accountId;
                  _accountSearchController.text = selectedAcc.name;
                  
                  _destAccountId = counterpart.accountId;
                  _destAccountSearchController.text = counterpartAcc.name;
                } else {
                  _accountId = counterpart.accountId;
                  _accountSearchController.text = counterpartAcc.name;
                  
                  _destAccountId = tx.accountId;
                  _destAccountSearchController.text = selectedAcc.name;
                }
              });
            }
          }
        } else if (tx.amount < 0) {
          _tabController.index = 0; // Expense Tab
        } else {
          _tabController.index = 1; // Route to Income Tab
        }
      } else {
        _onTabChanged();
      }
    } catch (e) {
      print('Error loading bottom sheet data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
      // After first load completes, set _isFirstLoad to false
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _isFirstLoad = false;
      });
    }
  }

  /// Reset/Clear fields on tab changes.
  void _onTabChanged() {
    if (_isFirstLoad && widget.transaction != null) {
      // Keep edit values on initial load
      return;
    }

    final tabIndex = _tabController.index;
    
    final filteredAccs = _getFilteredAccounts(tabIndex);

    setState(() {
      // CLEAR all inputs on tab switch
      _amountController.clear();
      _descriptionController.clear();
      
      _categoryId = null;
      _categorySearchController.clear();
      
      _accountId = null;
      _accountSearchController.clear();
      
      _destAccountId = null;
      _destAccountSearchController.clear();

      _isRecurring = false;

      // Transfer tab category prefilled by category with name "Transfer"
      if (tabIndex == 2) {
        final transferCat = _categories.firstWhere(
          (c) => c.type == 'transfer' || c.name.toLowerCase() == 'transfer',
          orElse: () => Category(id: '', name: 'Transfer', type: 'transfer', createdAt: DateTime.now()),
        );
        _categoryId = transferCat.id;
        _categorySearchController.text = transferCat.name;
      }

      // Account should ONLY be prefilled for the Income tab (tabIndex 1).
      // Expense (tabIndex 0) and Transfer (tabIndex 2) accounts start empty.
      if (tabIndex == 1) {
        if (filteredAccs.isNotEmpty) {
          final defaultAcc = _getDefaultDebitAccount(filteredAccs);
          if (defaultAcc != null) {
            _accountId = defaultAcc.id;
            _accountSearchController.text = defaultAcc.name;
          } else {
            _accountId = filteredAccs.first.id;
            _accountSearchController.text = filteredAccs.first.name;
          }
        }
      }

      _checkIfRecurring();
    });
  }

  List<Category> _getFilteredCategories(int tabIndex) {
    if (tabIndex == 0) {
      return _categories.where((c) => c.type == 'expense' || c.type == 'tax').toList();
    } else if (tabIndex == 1) {
      return _categories.where((c) => c.type == 'income' || c.type == 'reimbursement').toList();
    } else {
      return _categories.where((c) => c.type == 'transfer').toList();
    }
  }

  List<Account> _getFilteredAccounts(int tabIndex) {
    if (tabIndex == 0 || tabIndex == 1) {
      return _accounts.where((acc) => acc.accountGroup == 'credit' || acc.type == 'checking').toList();
    } else {
      return _accounts;
    }
  }

  void _checkIfRecurring() {
    if (_categoryId == null) {
      _isRecurring = false;
      _recurringId = null;
      return;
    }
    final match = _recurringBudgets.firstWhere(
      (r) => r['category_id'] == _categoryId,
      orElse: () => <String, dynamic>{},
    );
    setState(() {
      if (match.isNotEmpty) {
        _isRecurring = true;
        _recurringId = match['id'] as String?;
      } else {
        _isRecurring = false;
        _recurringId = null;
      }
    });
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
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

    if (picked != null) {
      setState(() {
        final now = DateTime.now();
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          now.hour,
          now.minute,
          now.second,
          now.millisecond,
        );
      });
    }
  }

  String _generateUuid() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40; // Set version 4
    values[8] = (values[8] & 0x3f) | 0x80; // Set variant
    final buffer = StringBuffer();
    for (int i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) buffer.write('-');
      buffer.write(values[i].toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  void _clearFields() {
    setState(() {
      _amountController.clear();
      _descriptionController.clear();
      _categoryId = null;
      _categorySearchController.clear();
      _isRecurring = false;
      _recurringId = null;
      if (_tabController.index == 2) {
        _destAccountId = null;
        _destAccountSearchController.clear();
      }
    });
  }

  Future<void> _submit({bool closeSheet = true}) async {
    if (!_formKey.currentState!.validate()) return;
    if (_accountId == null) return;

    final tabIndex = _tabController.index;
    
    if (tabIndex == 2 && _accountId == _destAccountId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Source and destination accounts must be different.'),
          backgroundColor: AppColors.cinnabar,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final double enteredAmount = double.parse(_amountController.text);
      final double exchangeRate = 1.0;

      String finalCategoryId = '';
      if (tabIndex == 2) {
        if (_categoryId == null) throw Exception('Please select a category');
        finalCategoryId = _categoryId!;
      } else {
        if (_categoryId == null) throw Exception('Please select a category');
        finalCategoryId = _categoryId!;
      }

      // Safe check: Only push changes for the selected tab
      if (tabIndex == 2) {
        final pairTag = widget.transaction?.tags?.startsWith('transfer_pair:') == true
            ? widget.transaction!.tags!
            : 'transfer_pair:${_generateUuid()}';

        final sourceTx = Transaction(
          id: widget.transaction?.amount != null && widget.transaction!.amount < 0 
              ? widget.transaction!.id 
              : (_counterpartTx?.amount != null && _counterpartTx!.amount < 0 ? _counterpartTx!.id : _generateUuid()),
          accountId: _accountId!,
          categoryId: finalCategoryId,
          amount: -enteredAmount,
          currency: _currency,
          exchangeRate: exchangeRate,
          date: _selectedDate,
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          status: widget.transaction?.status ?? 'cleared',
          isRecurring: _isRecurring,
          recurringId: _recurringId,
          tags: pairTag,
          createdAt: widget.transaction?.createdAt ?? DateTime.now(),
        );

        final destTx = Transaction(
          id: widget.transaction?.amount != null && widget.transaction!.amount > 0 
              ? widget.transaction!.id 
              : (_counterpartTx?.amount != null && _counterpartTx!.amount > 0 ? _counterpartTx!.id : _generateUuid()),
          accountId: _destAccountId!,
          categoryId: finalCategoryId,
          amount: enteredAmount,
          currency: _currency,
          exchangeRate: exchangeRate,
          date: _selectedDate,
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          status: widget.transaction?.status ?? 'cleared',
          isRecurring: _isRecurring,
          recurringId: _recurringId,
          tags: pairTag,
          createdAt: widget.transaction?.createdAt ?? DateTime.now(),
        );

        Transaction? oldSourceTx;
        Transaction? oldDestTx;
        
        if (widget.transaction != null) {
          if (widget.transaction!.amount < 0) {
            oldSourceTx = widget.transaction;
            oldDestTx = _counterpartTx;
          } else {
            oldSourceTx = _counterpartTx;
            oldDestTx = widget.transaction;
          }
        }

        await _databaseService.saveTransferWithBalanceUpdate(
          sourceTx, 
          destTx, 
          oldSourceTx: oldSourceTx, 
          oldDestTx: oldDestTx,
        );

      } else if (tabIndex == 0 || tabIndex == 1) {
        final double finalAmount = tabIndex == 0 ? -enteredAmount : enteredAmount;

        final txToSave = Transaction(
          id: widget.transaction?.id ?? _generateUuid(),
          accountId: _accountId!,
          categoryId: finalCategoryId,
          amount: finalAmount,
          currency: _currency,
          exchangeRate: exchangeRate,
          date: _selectedDate,
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          status: widget.transaction?.status ?? 'cleared',
          isRecurring: _isRecurring,
          recurringId: _recurringId,
          tags: widget.transaction?.tags,
          createdAt: widget.transaction?.createdAt ?? DateTime.now(),
        );

        if (widget.transaction != null && _counterpartTx != null) {
          await _databaseService.deleteTransaction(_counterpartTx!);
        }

        await _databaseService.saveTransactionWithBalanceUpdate(txToSave, oldTx: widget.transaction);
      }

      widget.onSaved();
      if (closeSheet) {
        Navigator.of(context).pop();
      } else {
        _clearFields();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction saved successfully!'),
            backgroundColor: AppColors.limeMoss,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _showErrorDialog(_getFriendlyErrorMessage(e.toString().replaceFirst('Exception: ', '')));
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _delete() async {
    if (widget.transaction == null) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Delete Transaction', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to delete this transaction? This will also revert the balance updates on the associated account(s).', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.cinnabar),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await _databaseService.deleteTransaction(widget.transaction!);
      widget.onSaved();
      Navigator.of(context).pop();
    } catch (e) {
      _showErrorDialog(_getFriendlyErrorMessage(e.toString().replaceFirst('Exception: ', '')));
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  String _getFriendlyErrorMessage(String rawMessage) {
    if (rawMessage.contains('check_recurring_conditional') || rawMessage.contains('23514')) {
      return 'This transaction is marked as recurring but is not properly linked to an active recurring budget. Please verify the category has a valid active recurring budget.';
    }
    return rawMessage;
  }

  void _showErrorDialog(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Error', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK', style: TextStyle(color: AppColors.limeMoss)),
          ),
        ],
      ),
    );
  }

  Color _getHighlightColor() {
    if (_tabController.index == 0) {
      return AppColors.cinnabar;
    } else if (_tabController.index == 1) {
      return AppColors.limeMoss;
    } else {
      return AppColors.googleBlue;
    }
  }

  InputDecoration _buildInputDecoration({
    required String labelText,
    required bool hasContent,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? prefixText,
  }) {
    final highlightColor = _getHighlightColor();
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Colors.white24, width: 1.5),
    );
    final focusBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: highlightColor, width: 2),
    );
    final errBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.cinnabar, width: 1.5),
    );
    final focusErrBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.cinnabar, width: 2),
    );

    if (hasContent) {
      // Outlined text field style
      return InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        prefixText: prefixText,
        prefixStyle: TextStyle(color: highlightColor, fontWeight: FontWeight.bold),
        filled: false,
        enabledBorder: border,
        focusedBorder: focusBorder,
        errorBorder: errBorder,
        focusedErrorBorder: focusErrBorder,
      );
    } else {
      // Filled text field style
      return InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        prefixText: prefixText,
        prefixStyle: TextStyle(color: highlightColor, fontWeight: FontWeight.bold),
        filled: true,
        fillColor: AppColors.background,
        enabledBorder: UnderlineInputBorder(
          borderSide: const BorderSide(color: Colors.white10),
          borderRadius: BorderRadius.circular(16),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: highlightColor, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        errorBorder: UnderlineInputBorder(
          borderSide: const BorderSide(color: AppColors.cinnabar, width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        focusedErrorBorder: UnderlineInputBorder(
          borderSide: const BorderSide(color: AppColors.cinnabar, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.transaction != null;
    final highlightColor = _getHighlightColor();

    if (_isLoading) {
      return Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.limeMoss),
          ),
        ),
      );
    }

    final filteredCategories = _getFilteredCategories(_tabController.index);
    final filteredAccounts = _getFilteredAccounts(_tabController.index);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(28.0), topRight: Radius.circular(28.0)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min, // Wrap content height dynamically
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEdit ? 'Edit Transaction' : 'New Transaction',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    if (isEdit)
                      IconButton(
                        icon: const Icon(Icons.delete, color: AppColors.cinnabar),
                        tooltip: 'Delete Transaction',
                        onPressed: _isSaving ? null : _delete,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              TabBar(
                controller: _tabController,
                indicatorColor: highlightColor,
                labelColor: highlightColor,
                unselectedLabelColor: Colors.white54,
                dividerColor: Colors.white10,
                tabs: const [
                  Tab(icon: Icon(Icons.call_made), text: 'Expense'),
                  Tab(icon: Icon(Icons.call_received), text: 'Income'),
                  Tab(icon: Icon(Icons.swap_horiz), text: 'Transfer'),
                ],
              ),
              
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. DATE PICKER (First Element - Date only, time auto-set to now())
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('DATE', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                                  const SizedBox(height: 6),
                                  Text(
                                    DateFormat('EEEE, MMM dd, yyyy').format(_selectedDate),
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              Icon(Icons.calendar_month, color: highlightColor),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 2. CATEGORY (Second Element - Autocomplete text field, works with arrow keys)
                      RawAutocomplete<Category>(
                        textEditingController: _categorySearchController,
                        focusNode: _categoryFocusNode,
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return filteredCategories;
                          }
                          return filteredCategories.where((c) => c.name.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                        },
                        displayStringForOption: (cat) => cat.name,
                        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            style: const TextStyle(color: Colors.white),
                            decoration: _buildInputDecoration(
                              labelText: 'Category',
                              hasContent: _categoryId != null,
                              prefixIcon: Icon(Icons.search, size: 20, color: highlightColor),
                              suffixIcon: _categoryId != null
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18, color: Colors.white54),
                                      onPressed: () {
                                        setState(() {
                                          _categoryId = null;
                                          _categorySearchController.clear();
                                          _isRecurring = false;
                                        });
                                      },
                                    )
                                  : null,
                            ),
                            onFieldSubmitted: (val) {
                              onFieldSubmitted();
                            },
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Please select a category';
                              }
                              final valid = filteredCategories.any((c) => c.name.toLowerCase() == val.trim().toLowerCase());
                              if (!valid) {
                                  return 'Select a category from suggestions';
                              }
                              return null;
                            },
                          );
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              color: Colors.transparent,
                              child: Container(
                                margin: const EdgeInsets.only(top: 4),
                                constraints: const BoxConstraints(maxHeight: 180),
                                width: MediaQuery.of(context).size.width - 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF161616),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  itemCount: options.length,
                                  itemBuilder: (context, index) {
                                    final cat = options.elementAt(index);
                                    final highlightedIndex = AutocompleteHighlightedOption.of(context);
                                    final isHighlighted = highlightedIndex == index;
                                    return Material(
                                      color: isHighlighted ? Colors.white10 : Colors.transparent,
                                      child: ListTile(
                                        visualDensity: VisualDensity.compact,
                                        title: Text(cat.name, style: const TextStyle(color: Colors.white, fontSize: 14)),
                                        onTap: () => onSelected(cat),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      // 3. AMOUNT & CURRENCY (Third Element - Side-by-Side in Row, curved dropdown)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _amountController,
                              style: const TextStyle(color: Colors.white, fontSize: 16),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                DecimalTextInputFormatter(),
                              ],
                              decoration: _buildInputDecoration(
                                labelText: 'Amount',
                                hasContent: _amountController.text.isNotEmpty,
                                prefixText: '\$ ',
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Enter amount';
                                }
                                final num = double.tryParse(val);
                                if (num == null) {
                                  return 'Letters not allowed';
                                }
                                if (num <= 0) {
                                  return 'Must be > 0';
                                }
                                return null;
                              },
                              onChanged: (val) {
                                setState(() {});
                              },
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              value: _currency,
                              dropdownColor: AppColors.card,
                              borderRadius: BorderRadius.circular(16),
                              style: TextStyle(color: highlightColor, fontWeight: FontWeight.bold, fontSize: 16),
                              decoration: _buildInputDecoration(
                                labelText: 'Currency',
                                hasContent: true,
                              ),
                              items: const [
                                DropdownMenuItem(value: 'MXN', child: Text('MXN')),
                                DropdownMenuItem(value: 'USD', child: Text('USD')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _currency = val;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // 4. ACCOUNT (Fourth Element - Searchable autocomplete input, works with arrow keys)
                      RawAutocomplete<Account>(
                        textEditingController: _accountSearchController,
                        focusNode: _accountFocusNode,
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return filteredAccounts;
                          }
                          return filteredAccounts.where((acc) => acc.name.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                        },
                        displayStringForOption: (acc) => acc.name,
                        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            style: const TextStyle(color: Colors.white),
                            decoration: _buildInputDecoration(
                              labelText: _tabController.index == 2 ? 'Source Account' : 'Account',
                              hasContent: _accountId != null,
                              prefixIcon: Icon(Icons.search, size: 20, color: highlightColor),
                              suffixIcon: _accountId != null
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18, color: Colors.white54),
                                      onPressed: () {
                                        setState(() {
                                          _accountId = null;
                                          _accountSearchController.clear();
                                        });
                                      },
                                    )
                                  : null,
                            ),
                            onFieldSubmitted: (val) {
                              onFieldSubmitted();
                            },
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Please select an account';
                              }
                              final valid = filteredAccounts.any((acc) => acc.name.toLowerCase() == val.trim().toLowerCase());
                              if (!valid) {
                                return 'Select an account from suggestions';
                              }
                              return null;
                            },
                          );
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              color: Colors.transparent,
                              child: Container(
                                margin: const EdgeInsets.only(top: 4),
                                constraints: const BoxConstraints(maxHeight: 180),
                                width: MediaQuery.of(context).size.width - 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF161616),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  itemCount: options.length,
                                  itemBuilder: (context, index) {
                                    final acc = options.elementAt(index);
                                    final highlightedIndex = AutocompleteHighlightedOption.of(context);
                                    final isHighlighted = highlightedIndex == index;
                                    return Material(
                                      color: isHighlighted ? Colors.white10 : Colors.transparent,
                                      child: ListTile(
                                        visualDensity: VisualDensity.compact,
                                        title: Text('${acc.name} (${acc.type.toUpperCase()})', style: const TextStyle(color: Colors.white, fontSize: 14)),
                                        onTap: () => onSelected(acc),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      
                      if (_tabController.index == 2) ...[
                        const SizedBox(height: 20),
                        // Destination Account: Searchable autocomplete input (NOT prefilled, works with arrow keys)
                        RawAutocomplete<Account>(
                          textEditingController: _destAccountSearchController,
                          focusNode: _destAccountFocusNode,
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            final filteredDestAccounts = _getFilteredAccounts(2);
                            if (textEditingValue.text.isEmpty) {
                              return filteredDestAccounts;
                            }
                            return filteredDestAccounts.where((acc) => acc.name.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                          },
                          displayStringForOption: (acc) => acc.name,
                          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              style: const TextStyle(color: Colors.white),
                              decoration: _buildInputDecoration(
                                labelText: 'Destination Account',
                                hasContent: _destAccountId != null,
                                prefixIcon: Icon(Icons.search, size: 20, color: highlightColor),
                                suffixIcon: _destAccountId != null
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18, color: Colors.white54),
                                        onPressed: () {
                                          setState(() {
                                            _destAccountId = null;
                                            _destAccountSearchController.clear();
                                          });
                                        },
                                      )
                                    : null,
                              ),
                              onFieldSubmitted: (val) {
                                onFieldSubmitted();
                              },
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Please select a destination account';
                                }
                                final valid = _getFilteredAccounts(2).any((acc) => acc.name.toLowerCase() == val.trim().toLowerCase());
                                if (!valid) {
                                  return 'Select destination account from suggestions';
                                }
                                return null;
                              },
                            );
                          },
                          optionsViewBuilder: (context, onSelected, options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                color: Colors.transparent,
                                child: Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  constraints: const BoxConstraints(maxHeight: 180),
                                  width: MediaQuery.of(context).size.width - 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF161616),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    padding: EdgeInsets.zero,
                                    itemCount: options.length,
                                    itemBuilder: (context, index) {
                                      final acc = options.elementAt(index);
                                      final highlightedIndex = AutocompleteHighlightedOption.of(context);
                                      final isHighlighted = highlightedIndex == index;
                                      return Material(
                                        color: isHighlighted ? Colors.white10 : Colors.transparent,
                                        child: ListTile(
                                          visualDensity: VisualDensity.compact,
                                          title: Text('${acc.name} (${acc.type.toUpperCase()})', style: const TextStyle(color: Colors.white, fontSize: 14)),
                                          onTap: () => onSelected(acc),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 20),

                      // 5. DESCRIPTION (Fifth Element)
                      TextFormField(
                        controller: _descriptionController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _buildInputDecoration(
                          labelText: 'Description',
                          hasContent: _descriptionController.text.isNotEmpty,
                        ),
                        onChanged: (val) {
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: 24),

                      // Recurring Chip
                      if (_tabController.index != 2 && _isRecurring) ...[
                        Row(
                          children: [
                            ChoiceChip(
                              label: const Text('Recurring Budget Category'),
                              selected: true,
                              onSelected: (_) {},
                              selectedColor: highlightColor.withOpacity(0.2),
                              labelStyle: TextStyle(color: highlightColor, fontWeight: FontWeight.bold, fontSize: 11),
                              shape: RoundedRectangleBorder(
                                side: BorderSide(color: highlightColor),
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Cancel & Save Buttons (LARGE buttons with height 54)
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 54,
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white70,
                                  side: const BorderSide(color: Colors.white24, width: 1.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: const Text('Cancel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                          if (!isEdit) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 54,
                                child: OutlinedButton(
                                  onPressed: _isSaving ? null : () => _submit(closeSheet: false),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: highlightColor,
                                    side: BorderSide(color: highlightColor, width: 1.5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: _isSaving
                                      ? const SizedBox(
                                          width: 20, 
                                          height: 20, 
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                        )
                                      : const Text('Save & New', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : () => _submit(closeSheet: true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: highlightColor,
                                  foregroundColor: Colors.black,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: _isSaving
                                    ? const SizedBox(
                                        width: 20, 
                                        height: 20, 
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                      )
                                    : const Text('Save', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
