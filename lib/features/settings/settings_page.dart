import 'package:flutter/material.dart';
import 'package:budget_app_v2/core/config/app_colors.dart';
import 'package:budget_app_v2/core/services/currency_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with SingleTickerProviderStateMixin {
  final _currencyService = CurrencyService();
  late TabController _tabController;
  final _currencyInputController = TextEditingController();
  bool _isFetching = false;
  String _currencyType = 'fiat'; // 'fiat' or 'crypto'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _currencyService.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    _currencyInputController.dispose();
    super.dispose();
  }

  Future<void> _addCurrency() async {
    final code = _currencyInputController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    if (code.length < 2 || code.length > 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Currency symbol must be between 2 and 6 characters.'),
          backgroundColor: AppColors.cinnabar,
        ),
      );
      return;
    }

    final success = await _currencyService.addCurrency(code);
    if (success) {
      _currencyInputController.clear();
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Currency "$code" added! It will be updated on the next login/session.'),
          backgroundColor: AppColors.limeMoss,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Currency "$code" is already in use.'),
          backgroundColor: AppColors.cinnabar,
        ),
      );
    }
  }

  Future<void> _removeCurrency(String code) async {
    if (code == 'USD') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot remove primary base currency (USD).'),
          backgroundColor: AppColors.cinnabar,
        ),
      );
      return;
    }

    final success = await _currencyService.removeCurrency(code);
    if (success) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Currency "$code" removed.'),
          backgroundColor: Colors.amber,
        ),
      );
    }
  }

  Future<void> _forceFetch() async {
    // Show a warnings dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.cinnabar, size: 28),
            SizedBox(width: 8),
            Text('Force Fetch Rates?', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'AlphaVantage has a strict usage limit per day. Force-fetching bypasses the safety limits and executes requests immediately. Only do this if necessary.\n\nDo you want to proceed?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cinnabar,
              foregroundColor: Colors.white,
            ),
            child: const Text('Force Fetch', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isFetching = true;
    });

    try {
      await _currencyService.forceFetchRates();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rates updated successfully!'),
            backgroundColor: AppColors.limeMoss,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fetch failed: $e'),
            backgroundColor: AppColors.cinnabar,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settings',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.limeMoss,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white38,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.currency_exchange_outlined),
                    text: 'Currencies',
                  ),
                  Tab(
                    icon: Icon(Icons.logo_dev_outlined),
                    text: 'API Diagnostics',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCurrenciesTab(),
                    _buildDiagnosticsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrenciesTab() {
    final activeList = _currencyService.activeCurrencies;
    final cachedRates = _currencyService.cachedRates;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add Currency Input Box
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
                    'Add New Currency',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Provide the physical (fiat) or cryptocurrency symbol to track. It will update on the next login.',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _currencyInputController,
                          textCapitalization: TextCapitalization.characters,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'E.g., EUR, BTC, BNB',
                            hintStyle: TextStyle(color: Colors.white38),
                            prefixIcon: Icon(Icons.add_card, color: AppColors.limeMoss),
                          ),
                          onSubmitted: (_) => _addCurrency(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _currencyType,
                              dropdownColor: AppColors.card,
                              items: const [
                                DropdownMenuItem(
                                  value: 'fiat',
                                  child: Text('Physical (Fiat)', style: TextStyle(color: Colors.white)),
                                ),
                                DropdownMenuItem(
                                  value: 'crypto',
                                  child: Text('Crypto', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _currencyType = val;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: _addCurrency,
                        icon: const Icon(Icons.add_circle, color: AppColors.limeMoss, size: 36),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Active Currencies List',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activeList.length,
            itemBuilder: (context, index) {
              final symbol = activeList[index];
              final rate = cachedRates[symbol];
              final rateDisplay = rate != null ? '\$ ${rate.toStringAsFixed(4)} USD' : 'Pending Fetch';

              return Card(
                color: AppColors.card,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.white10),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: symbol == 'USD'
                        ? AppColors.limeMoss.withOpacity(0.2)
                        : AppColors.googleBlue.withOpacity(0.2),
                    child: Text(
                      symbol,
                      style: TextStyle(
                        color: symbol == 'USD' ? AppColors.limeMoss : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  title: Text(
                    symbol,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    symbol == 'USD'
                        ? 'Base Currency (USD)'
                        : 'Exchange rate: $rateDisplay',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  trailing: symbol == 'USD'
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppColors.cinnabar),
                          onPressed: () => _removeCurrency(symbol),
                        ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticsTab() {
    final fetchTime = _currencyService.lastFetchTime;
    final timeStr = fetchTime != null
        ? '${fetchTime.toLocal().toString().substring(0, 19)}'
        : 'Never';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Meta details row
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Fetch Limit',
                '${_currencyService.fetchCountToday} / 2 Today',
                Icons.slow_motion_video,
                AppColors.limeMoss,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Last Successful Sync',
                timeStr,
                Icons.sync_lock,
                AppColors.googleBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'API Diagnostics Log',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            _isFetching
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.limeMoss),
                    ),
                  )
                : OutlinedButton.icon(
                    onPressed: _forceFetch,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Force Update Now'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.limeMoss,
                      side: const BorderSide(color: AppColors.limeMoss),
                    ),
                  ),
          ],
        ),
        const SizedBox(height: 12),
        // Log Terminal Output box
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: ListView.builder(
              itemCount: _currencyService.diagnosticsLog.length,
              itemBuilder: (context, index) {
                final logLine = _currencyService.diagnosticsLog[index];
                final isSuccess = logLine.toLowerCase().contains('success');
                final isFailed = logLine.toLowerCase().contains('failed') || logLine.toLowerCase().contains('error');

                Color textColor = Colors.white70;
                if (isSuccess) textColor = AppColors.limeMoss;
                if (isFailed) textColor = AppColors.cinnabar;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Text(
                    logLine,
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 12,
                      color: textColor,
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

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.white10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
