import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:budget_app_v2/core/config/app_colors.dart';
import 'package:budget_app_v2/core/models/models.dart';
import 'package:budget_app_v2/core/services/database_service.dart';
import '../../core/utils/currency_formatter.dart';


class DecimalTextInputFormatter extends TextInputFormatter {
  final int decimalRange;
  DecimalTextInputFormatter({this.decimalRange = 2});

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final regEx = RegExp('^\\d*\\.?\\d{0,$decimalRange}');
    final String newString = regEx.stringMatch(newValue.text) ?? '';
    return newString == newValue.text ? newValue : oldValue;
  }
}

class AddAssetTransactionBottomSheet extends StatefulWidget {
  final AssetTransaction? transaction;
  final VoidCallback onSaved;

  const AddAssetTransactionBottomSheet({
    super.key,
    this.transaction,
    required this.onSaved,
  });

  @override
  State<AddAssetTransactionBottomSheet> createState() => _AddAssetTransactionBottomSheetState();
}

class _AddAssetTransactionBottomSheetState extends State<AddAssetTransactionBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _databaseService = DatabaseService();

  // Form Fields State
  late DateTime _selectedDate;
  final _quantityController = TextEditingController();
  final _unitPriceController = TextEditingController();

  String? _accountId;
  String? _assetId;
  late String _type; // 'buy', 'sell', 'dividend_reinvest', 'split', 'reward'

  List<Account> _accounts = [];
  List<Asset> _assets = [];
  bool _isLoading = true;
  bool _isSaving = false;

  final List<String> _types = ['buy', 'sell', 'dividend_reinvest', 'split', 'reward'];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.transaction?.executedAt ?? DateTime.now();
    _type = widget.transaction?.type.toLowerCase() ?? 'buy';

    if (widget.transaction != null) {
      _quantityController.text = widget.transaction!.quantity.toString();
      _unitPriceController.text = widget.transaction!.unitPrice.toString();
      _accountId = widget.transaction!.accountId;
      _assetId = widget.transaction!.assetId;
    }

    _loadData();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _unitPriceController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final accountsList = await _databaseService.fetchAccounts();
      final assetsList = await _databaseService.fetchAssets();
      
      if (mounted) {
        setState(() {
          // Filter to show active capital, retirement or investment accounts by preference,
          // but allow any account to be selected.
          _accounts = accountsList.where((acc) => acc.status == 'active').toList();
          _assets = assetsList;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading data for asset bottom sheet: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectDate() async {
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

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_accountId == null || _assetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both an account and an asset.')),
      );
      return;
    }

    final double qty = double.parse(_quantityController.text);
    final double price = double.parse(_unitPriceController.text);

    // Client-side funds validation check
    if (_type.toLowerCase() == 'buy') {
      final selectedAsset = _assets.firstWhere((a) => a.id == _assetId);
      if (selectedAsset.type != 'fiat') {
        final selectedAccount = _accounts.firstWhere((a) => a.id == _accountId);
        double availableCash = selectedAccount.currentBalance;

        // If in edit mode, recover cash from the original buy transaction to check limit
        if (widget.transaction != null && widget.transaction!.type.toLowerCase() == 'buy') {
          availableCash += (widget.transaction!.quantity * widget.transaction!.unitPrice);
        }

        final double requiredCash = qty * price;
        if (availableCash < requiredCash) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Insufficient cash (${selectedAccount.currency}) to buy this asset. '
                'Required: ${formatCurrency(requiredCash)}, '
                'Available: ${formatCurrency(availableCash)}'
              ),
              backgroundColor: AppColors.cinnabar,
            ),
          );
          return;
        }
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final isEditMode = widget.transaction != null;
      final txId = widget.transaction?.id ?? _generateUuid();

      final newTx = AssetTransaction(
        id: txId,
        accountId: _accountId!,
        assetId: _assetId!,
        type: _type,
        quantity: qty,
        unitPrice: price,
        executedAt: _selectedDate,
      );

      await _databaseService.saveAssetTransaction(newTx, oldTx: widget.transaction);
      
      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error saving asset transaction: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving transaction: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _delete() async {
    if (widget.transaction == null) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: const Text('Are you sure you want to permanently delete this asset transaction? This will reverse holdings and cash balance changes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.cinnabar),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await _databaseService.deleteAssetTransaction(widget.transaction!);
      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error deleting asset transaction: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
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

  String _formatTypeName(String rawType) {
    switch (rawType) {
      case 'buy':
        return 'BUY';
      case 'sell':
        return 'SELL';
      case 'dividend_reinvest':
        return 'DIVIDEND REINVEST';
      case 'split':
        return 'STOCK SPLIT';
      case 'reward':
        return 'REWARD / BONUS';
      default:
        return rawType.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isEditMode = widget.transaction != null;

    if (_isLoading) {
      return Container(
        height: 300,
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.limeMoss),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header indicator
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Sheet Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditMode ? 'EDIT ASSET TRANSACTION' : 'RECORD ASSET TRANSACTION',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 1.2,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Choice chips for type
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _types.map((t) {
                    final isSelected = _type == t;
                    Color activeColor = AppColors.limeMoss;
                    if (t == 'sell') {
                      activeColor = AppColors.cinnabar;
                    } else if (t == 'dividend_reinvest' || t == 'split' || t == 'reward') {
                      activeColor = AppColors.googleBlue;
                    }

                    return ChoiceChip(
                      label: Text(_formatTypeName(t)),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _type = t;
                          });
                        }
                      },
                      selectedColor: activeColor,
                      backgroundColor: AppColors.background,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.black : Colors.white70,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 11,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isSelected ? activeColor : Colors.white10,
                          width: 1.0,
                        ),
                      ),
                      showCheckmark: false,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Account Selection
                DropdownButtonFormField<String>(
                  value: _accountId,
                  hint: const Text('Select Account', style: TextStyle(color: Colors.white30)),
                  dropdownColor: AppColors.card,
                  decoration: InputDecoration(
                    labelText: 'Custody Account',
                    labelStyle: const TextStyle(color: Colors.white70),
                    prefixIcon: const Icon(Icons.account_balance, color: AppColors.limeMoss),
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _accounts.map((acc) {
                    return DropdownMenuItem<String>(
                      value: acc.id,
                      child: Text('${acc.name} (${acc.institution})', style: const TextStyle(color: Colors.white)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _accountId = val;
                    });
                  },
                  validator: (val) => val == null ? 'Required field' : null,
                ),
                const SizedBox(height: 16),

                // Asset Selection
                DropdownButtonFormField<String>(
                  value: _assetId,
                  hint: const Text('Select Asset', style: TextStyle(color: Colors.white30)),
                  dropdownColor: AppColors.card,
                  decoration: InputDecoration(
                    labelText: 'Asset Ticker',
                    labelStyle: const TextStyle(color: Colors.white70),
                    prefixIcon: const Icon(Icons.show_chart, color: AppColors.limeMoss),
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _assets.map((asset) {
                    return DropdownMenuItem<String>(
                      value: asset.id,
                      child: Text('${asset.symbol} - ${asset.name}', style: const TextStyle(color: Colors.white)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _assetId = val;
                    });
                  },
                  validator: (val) => val == null ? 'Required field' : null,
                ),
                const SizedBox(height: 16),

                // Quantity & Unit Price inputs side by side
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantityController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [DecimalTextInputFormatter(decimalRange: 4)],
                        decoration: InputDecoration(
                          labelText: 'Quantity',
                          labelStyle: const TextStyle(color: Colors.white70),
                          prefixIcon: const Icon(Icons.pie_chart_outline, color: AppColors.limeMoss),
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Required';
                          final numVal = double.tryParse(val);
                          if (numVal == null || numVal <= 0.0) return 'Must be > 0';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _unitPriceController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [DecimalTextInputFormatter(decimalRange: 2)],
                        decoration: InputDecoration(
                          labelText: 'Unit Price',
                          labelStyle: const TextStyle(color: Colors.white70),
                          prefixIcon: const Icon(Icons.attach_money, color: AppColors.limeMoss),
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Required';
                          final numVal = double.tryParse(val);
                          if (numVal == null || numVal < 0.0) return 'Must be >= 0';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Date Picker row
                InkWell(
                  onTap: _selectDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10, width: 1.0),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.date_range, color: AppColors.limeMoss),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Execution Date', style: TextStyle(color: Colors.white38, fontSize: 10)),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('MMMM dd, yyyy').format(_selectedDate),
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // Submit and Delete action buttons
                if (_isSaving)
                  const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.limeMoss),
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(
                        onPressed: _submit,
                        child: Text(isEditMode ? 'SAVE CHANGES' : 'RECORD TRANSACTION'),
                      ),
                      if (isEditMode) ...[
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _delete,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.cinnabar,
                            side: const BorderSide(color: AppColors.cinnabar, width: 1.5),
                          ),
                          child: const Text('DELETE TRANSACTION'),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
