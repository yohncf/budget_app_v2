import 'dart:math';
import 'package:flutter/material.dart';
import 'package:budget_app_v2/core/config/app_colors.dart';
import '../../core/models/models.dart';
import '../../core/services/database_service.dart';

// Generates RFC4122 version 4 compliant UUIDs
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

Color _getColorForAccountType(String type) {
  switch (type) {
    case 'checking':
      return AppColors.limeMoss; // Lime Moss #7DAC20
    case 'savings':
      return AppColors.limeMoss; // Lime Moss #7DAC20
    case 'credit_card':
      return AppColors.cinnabar; // Cinnabar #CB2549
    case 'investment':
      return AppColors.lavenderPurple; // Lavender purple #4285F4
    case 'crypto_wallet':
      return AppColors.googleBlue; // Google Blue #9272BF
    case 'cash':
    default:
      return AppColors.limeMoss; // Lime Moss
  }
}

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  State<AccountsPage> createState() => AccountsPageState();
}

class AccountsPageState extends State<AccountsPage> with SingleTickerProviderStateMixin {
  final _databaseService = DatabaseService();
  late TabController _tabController;

  List<Account> _accounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    loadAccounts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> loadAccounts() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final list = await _databaseService.fetchAccounts();
      setState(() {
        _accounts = list;
      });
    } catch (e) {
      print('Error loading accounts: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _archive(Account account) async {
    // Client-side rule validation: balance must be 0.0
    if (account.currentBalance != 0.0) {
      _showErrorDialog(
        'Cannot Archive Account',
        'Account "${account.name}" cannot be archived because it has a non-zero balance (\$${account.currentBalance.toStringAsFixed(2)}).\n\nPlease reconcile the balance to \$0.0 before archiving.',
      );
      return;
    }

    try {
      await _databaseService.archiveAccount(account.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Account "${account.name}" has been archived successfully.'),
          backgroundColor: const Color(0xFF04E07B),
        ),
      );
      loadAccounts();
    } catch (e) {
      _showErrorDialog('Archiving Failed', e.toString());
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.cinnabar, size: 28),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK', style: TextStyle(color: AppColors.limeMoss, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _editAccount(Account account) {
    showDialog(
      context: context,
      builder: (context) => AddAccountDialog(
        account: account,
        onSaved: loadAccounts,
      ),
    );
  }

  List<Account> get _cashAndCreditAccounts {
    return _accounts
        .where((acc) =>
            acc.status != 'archived' &&
            (acc.accountGroup == 'liquid_assets' || acc.accountGroup == 'credit' || acc.accountGroup == 'credits'))
        .toList();
  }

  List<Account> get _capitalAndRetirementAccounts {
    return _accounts
        .where((acc) =>
            acc.status != 'archived' &&
            (acc.accountGroup == 'capital' || acc.accountGroup == 'retirement'))
        .toList();
  }

  List<Account> get _archivedAccounts {
    return _accounts.where((acc) => acc.status == 'archived').toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.limeMoss),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          color: AppColors.card,
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.limeMoss,
            labelColor: AppColors.limeMoss,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(text: 'Cash and Credit'),
              Tab(text: 'Capital and retirement'),
              Tab(text: 'Archived'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAccountList(_cashAndCreditAccounts),
          _buildAccountList(_capitalAndRetirementAccounts),
          _buildAccountList(_archivedAccounts, isArchivedTab: true),
        ],
      ),
    );
  }

  Widget _buildAccountList(List<Account> list, {bool isArchivedTab = false}) {
    if (list.isEmpty) {
      return const Center(
        child: Text(
          'No accounts found in this section.',
          style: TextStyle(color: Colors.white, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final acc = list[index];
        final typeColor = _getColorForAccountType(acc.type);
        
        return HoverAccountCard(
          typeColor: typeColor,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                // Account Icon with dynamic colored indicator border
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getIconForAccountType(acc.type),
                    color: typeColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),

                // Name & Institution details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        acc.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${acc.institution} • ${acc.type.toUpperCase()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // Currency & Balances
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${acc.currentBalance.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: acc.currentBalance >= 0 ? AppColors.limeMoss : AppColors.cinnabar,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      acc.limit > 0 
                          ? 'Limit: \$${acc.limit.toStringAsFixed(0)} ${acc.currency}' 
                          : acc.currency,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 8),

                // Menu items
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  color: AppColors.card,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editAccount(acc);
                    } else if (value == 'archive') {
                      _archive(acc);
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: AppColors.limeMoss, size: 20),
                          SizedBox(width: 8),
                          Text('Edit', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    if (!isArchivedTab)
                      const PopupMenuItem<String>(
                        value: 'archive',
                        child: Row(
                          children: [
                            Icon(Icons.archive, color: AppColors.cinnabar, size: 20),
                            SizedBox(width: 8),
                            Text('Archive', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getIconForAccountType(String type) {
    switch (type) {
      case 'checking':
        return Icons.account_balance;
      case 'savings':
        return Icons.savings;
      case 'credit_card':
        return Icons.credit_card;
      case 'investment':
        return Icons.trending_up;
      case 'crypto_wallet':
        return Icons.currency_bitcoin;
      case 'cash':
      default:
        return Icons.wallet;
    }
  }
}

// Add / Edit Account Dialog
class AddAccountDialog extends StatefulWidget {
  final Account? account; // If provided, we are editing
  final VoidCallback onSaved;

  const AddAccountDialog({
    super.key,
    this.account,
    required this.onSaved,
  });

  @override
  State<AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends State<AddAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _databaseService = DatabaseService();

  late String _name;
  late String _type;
  late String _institution;
  late String _currency;
  late double _balance;
  late double _limit;
  late String _accountGroup;
  late String _status;

  bool _isSaving = false;

  final List<String> _types = ['checking', 'savings', 'credit_card', 'investment', 'crypto_wallet', 'cash'];
  final List<String> _groups = ['liquid_assets', 'credit', 'capital', 'retirement'];
  final List<String> _statuses = ['active', 'inactive', 'archived'];

  @override
  void initState() {
    super.initState();
    final acc = widget.account;
    _name = acc?.name ?? '';
    _type = (acc?.type ?? 'checking').trim().toLowerCase();
    _institution = acc?.institution ?? '';
    _currency = acc?.currency ?? 'USD';
    _balance = acc?.currentBalance ?? 0.0;
    _limit = acc?.limit ?? 0.0;
    _accountGroup = (acc?.accountGroup ?? 'liquid_assets').trim().toLowerCase();
    _status = (acc?.status ?? 'active').trim().toLowerCase();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() {
      _isSaving = true;
    });

    try {
      final accountToSave = Account(
        id: widget.account?.id ?? _generateUuid(),
        name: _name,
        type: _type,
        institution: _institution,
        currency: _currency,
        currentBalance: _balance,
        limit: _limit,
        accountGroup: _accountGroup,
        status: _status,
        createdAt: widget.account?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Backend trigger or check condition constraint check:
      if (_status == 'archived' && _balance != 0.0) {
        throw Exception('Cannot archive account if current balance is not exactly 0.0.');
      }

      await _databaseService.saveAccount(accountToSave);
      widget.onSaved();
      Navigator.of(context).pop();
    } catch (e) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Error Saving Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text(e.toString().replaceFirst('Exception: ', ''), style: const TextStyle(color: Colors.white)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK', style: TextStyle(color: AppColors.limeMoss)),
            ),
          ],
        ),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.account != null;

    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24.0), // Rounded corners M3
      ),
      title: Text(
        isEdit ? 'Edit Account' : 'New Account',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Name
              TextFormField(
                initialValue: _name,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Account Name',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.limeMoss)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Name is required' : null,
                onSaved: (val) => _name = val!.trim(),
              ),
              const SizedBox(height: 16),

              // Institution
              TextFormField(
                initialValue: _institution,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Institution',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.limeMoss)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Institution is required' : null,
                onSaved: (val) => _institution = val!.trim(),
              ),
              const SizedBox(height: 16),

              // Currency
              TextFormField(
                initialValue: _currency,
                style: const TextStyle(color: Colors.white),
                maxLength: 3,
                decoration: const InputDecoration(
                  labelText: 'Currency (e.g., USD)',
                  labelStyle: TextStyle(color: Colors.white70),
                  counterStyle: TextStyle(color: Colors.white30),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.limeMoss)),
                ),
                validator: (val) => val == null || val.trim().length != 3 ? 'Must be exactly 3 characters' : null,
                onSaved: (val) => _currency = val!.toUpperCase().trim(),
              ),
              const SizedBox(height: 8),

              // Current Balance
              TextFormField(
                initialValue: _balance.toString(),
                style: const TextStyle(color: Colors.white),
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: const InputDecoration(
                  labelText: 'Current Balance (\$)',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.limeMoss)),
                ),
                validator: (val) => val == null || double.tryParse(val) == null ? 'Enter a valid number' : null,
                onSaved: (val) => _balance = double.parse(val!),
              ),
              const SizedBox(height: 16),

              // Limit
              TextFormField(
                initialValue: _limit.toString(),
                style: const TextStyle(color: Colors.white),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Limit / Overdraft Limit (\$)',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.limeMoss)),
                ),
                validator: (val) => val == null || double.tryParse(val) == null || double.parse(val) < 0
                    ? 'Enter a positive number'
                    : null,
                onSaved: (val) => _limit = double.parse(val!),
              ),
              const SizedBox(height: 24),

              // Type Dropdown
              DropdownButtonFormField<String>(
                value: _type,
                dropdownColor: const Color(0xFF333333),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Account Type',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                ),
                items: _types.map((t) {
                  return DropdownMenuItem(value: t, child: Text(t.toUpperCase()));
                }).toList(),
                onChanged: (val) => setState(() => _type = val!),
              ),
              const SizedBox(height: 16),

              // Account Group Dropdown
              DropdownButtonFormField<String>(
                value: _accountGroup,
                dropdownColor: AppColors.card,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Account Group',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                ),
                items: _groups.map((g) {
                  return DropdownMenuItem(value: g, child: Text(g.replaceAll('_', ' ').toUpperCase()));
                }).toList(),
                onChanged: (val) => setState(() => _accountGroup = val!),
              ),
              const SizedBox(height: 16),

              // Status Dropdown
              DropdownButtonFormField<String>(
                value: _status,
                dropdownColor: AppColors.card,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Status',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                ),
                items: _statuses.map((s) {
                  return DropdownMenuItem(value: s, child: Text(s.toUpperCase()));
                }).toList(),
                onChanged: (val) => setState(() => _status = val!),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.limeMoss,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _isSaving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
              : const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

/// A premium, animated hover account card widget.
///
/// **Why it exists**: Translates and changes border highlight smoothly on hover
/// to create a professional responsive SaaS vibe in lists.
class HoverAccountCard extends StatefulWidget {
  final Color typeColor;
  final Widget child;

  const HoverAccountCard({
    super.key,
    required this.typeColor,
    required this.child,
  });

  @override
  State<HoverAccountCard> createState() => _HoverAccountCardState();
}

class _HoverAccountCardState extends State<HoverAccountCard> {
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
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered 
                  ? AppColors.limeMoss.withOpacity(0.08) // 8% opacity Lime Moss glow on hover
                  : Colors.black.withOpacity(0.15),
              blurRadius: _isHovered ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        margin: const EdgeInsets.only(bottom: 12.0),
        child: widget.child,
      ),
    );
  }
}
