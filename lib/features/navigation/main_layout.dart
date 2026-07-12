import 'package:flutter/material.dart';
import 'package:budget_app_v2/core/config/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../dashboard/dashboard_page.dart';
import '../accounts/accounts_page.dart';
import '../transactions/transactions_page.dart';
import '../transactions/add_transaction_bottom_sheet.dart';
import '../assets/assets_page.dart';
import '../assets/add_asset_transaction_bottom_sheet.dart';
import '../../core/services/currency_service.dart';
import '../settings/settings_page.dart';

class MainLayout extends StatefulWidget {
  final VoidCallback onLogout;

  const MainLayout({
    super.key,
    required this.onLogout,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _isRailExpanded = true;
  bool _isMenuOpen = false;

  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  // GlobalKeys to trigger reloads in child pages
  final GlobalKey<AccountsPageState> _accountsKey = GlobalKey<AccountsPageState>();
  final GlobalKey<TransactionsPageState> _transactionsKey = GlobalKey<TransactionsPageState>();
  final GlobalKey<DashboardPageState> _dashboardKey = GlobalKey<DashboardPageState>();
  final GlobalKey<AssetsPageState> _assetsKey = GlobalKey<AssetsPageState>();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    
    // Trigger currency rates checking on login/startup
    CurrencyService().checkAndFetchRatesOnLogin();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      if (_isMenuOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _triggerRefresh() {
    _accountsKey.currentState?.loadAccounts();
    _transactionsKey.currentState?.loadTransactions(reset: true);
    _dashboardKey.currentState?.loadData();
    _assetsKey.currentState?.loadData();
  }

  Widget _getActivePage() {
    switch (_selectedIndex) {
      case 0:
        return DashboardPage(key: _dashboardKey);
      case 1:
        return AccountsPage(key: _accountsKey);
      case 2:
        return TransactionsPage(key: _transactionsKey);
      case 3:
        return AssetsPage(key: _assetsKey);
      case 4:
        return const SettingsPage();
      default:
        return const Center(child: Text('Page not found'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    final List<NavigationDestination> destinations = const [
      NavigationDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard, color: AppColors.limeMoss),
        label: 'Dashboard',
      ),
      NavigationDestination(
        icon: Icon(Icons.account_balance_wallet_outlined),
        selectedIcon: Icon(Icons.account_balance_wallet, color: AppColors.limeMoss),
        label: 'Accounts',
      ),
      NavigationDestination(
        icon: Icon(Icons.swap_horiz_outlined),
        selectedIcon: Icon(Icons.swap_horiz, color: AppColors.limeMoss),
        label: 'Transactions',
      ),
      NavigationDestination(
        icon: Icon(Icons.trending_up_outlined),
        selectedIcon: Icon(Icons.trending_up, color: AppColors.limeMoss),
        label: 'Assets',
      ),
    ];

    final List<SidebarDestination> sidebarDestinations = const [
      SidebarDestination(
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        label: 'Dashboard',
      ),
      SidebarDestination(
        icon: Icons.account_balance_wallet_outlined,
        selectedIcon: Icons.account_balance_wallet,
        label: 'Accounts',
      ),
      SidebarDestination(
        icon: Icons.swap_horiz_outlined,
        selectedIcon: Icons.swap_horiz,
        label: 'Transactions',
      ),
      SidebarDestination(
        icon: Icons.trending_up_outlined,
        selectedIcon: Icons.trending_up,
        label: 'Assets',
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: AppColors.background,
              elevation: 0,
              title: Row(
                children: [
                  const Icon(Icons.account_balance_wallet, color: AppColors.limeMoss, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'BAREN BUDGET',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    Icons.settings,
                    color: _selectedIndex == 4 ? AppColors.limeMoss : Colors.white70,
                  ),
                  tooltip: 'Settings',
                  onPressed: () {
                    setState(() {
                      _selectedIndex = 4;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white70),
                  tooltip: 'Refresh All Data',
                  onPressed: _triggerRefresh,
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: Color(0xFFFB9426)),
                  tooltip: 'Sign Out',
                  onPressed: () async {
                    await AuthService().signOut();
                    widget.onLogout();
                  },
                ),
              ],
            ),
      body: Stack(
        children: [
          Row(
            children: [
              if (isDesktop) ...[
                // Desktop Sidebar Custom Navigation Rail
                Container(
                  width: _isRailExpanded ? 240 : 72,
                  color: AppColors.background,
                  child: Column(
                    children: [
                      // Sidebar Header
                      _isRailExpanded
                          ? Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.account_balance_wallet, color: AppColors.limeMoss, size: 24),
                                      const SizedBox(width: 8),
                                      Text(
                                        'BAREN BUDGET',
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.menu_open, color: Colors.white),
                                    onPressed: () {
                                      setState(() {
                                        _isRailExpanded = false;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                              child: Center(
                                child: IconButton(
                                  icon: const Icon(Icons.menu, color: Colors.white),
                                  onPressed: () {
                                    setState(() {
                                      _isRailExpanded = true;
                                    });
                                  },
                                ),
                              ),
                            ),
                      const SizedBox(height: 8),
                      // Navigation Destinations
                      Expanded(
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: sidebarDestinations.length,
                          itemBuilder: (context, index) {
                            final dest = sidebarDestinations[index];
                            return SidebarItem(
                              icon: dest.icon,
                              selectedIcon: dest.selectedIcon,
                              label: dest.label,
                              isSelected: _selectedIndex == index,
                              isExpanded: _isRailExpanded,
                              onTap: () {
                                setState(() {
                                  _selectedIndex = index;
                                });
                              },
                            );
                          },
                        ),
                      ),
                      // Footer Actions
                      Container(
                        width: _isRailExpanded ? 240 : 72,
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.settings,
                                color: _selectedIndex == 4 ? AppColors.limeMoss : Colors.white70,
                              ),
                              tooltip: 'Settings',
                              onPressed: () {
                                setState(() {
                                  _selectedIndex = 4;
                                });
                              },
                            ),
                            const SizedBox(height: 8),
                            IconButton(
                              icon: const Icon(Icons.refresh, color: Colors.white70),
                              tooltip: 'Refresh All Data',
                              onPressed: _triggerRefresh,
                            ),
                            const SizedBox(height: 8),
                            IconButton(
                              icon: const Icon(Icons.logout, color: Color(0xFFFB9426)),
                              tooltip: 'Sign Out',
                              onPressed: () async {
                                await AuthService().signOut();
                                widget.onLogout();
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1, color: Colors.white12),
              ],
              Expanded(
                child: _getActivePage(),
              ),
            ],
          ),

          // Speed Dial Overlay scrim background
          if (_isMenuOpen)
            GestureDetector(
              onTap: _toggleMenu,
              child: Container(
                color: Colors.black.withOpacity(0.5),
              ),
            ),

          // Custom FAB with Expandable Speed Dial Menu
          Positioned(
            right: 24,
            bottom: isDesktop ? 24 : 96, // Lift if mobile bar is showing
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Sub-FAB Option 1: Add Transaction Pill Menu
                // Styled as a rounded horizontal lavender container enclosing both the icon and label text.
                SizeTransition(
                  sizeFactor: _expandAnimation,
                  child: ScaleTransition(
                    scale: _expandAnimation,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: GestureDetector(
                        onTap: () {
                          _toggleMenu();
                          _showAddTransactionDialog();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E0FF), // Lavender background
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.swap_horiz, color: Color(0xFF1E1446), size: 20),
                              SizedBox(width: 10),
                              Text(
                                'Add Transaction',
                                style: TextStyle(
                                  color: Color(0xFF1E1446),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Sub-FAB Option 2: Add Asset Operation Pill Menu
                // Styled as a rounded purple container. Triggers asset specific operations.
                SizeTransition(
                  sizeFactor: _expandAnimation,
                  child: ScaleTransition(
                    scale: _expandAnimation,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: GestureDetector(
                        onTap: () {
                          _toggleMenu();
                          _showAddAssetTransactionBottomSheet();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFCEBFFF), // Muted purple background
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.trending_up, color: Color(0xFF1C1146), size: 20),
                              SizedBox(width: 10),
                              Text(
                                'Record asset operation',
                                style: TextStyle(
                                  color: Color(0xFF1C1146),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Main Toggle FAB: Circular action button that rotates and transitions
                // background colors based on whether the speed dial is open (slate purple) or closed (volt lime).
                FloatingActionButton(
                  heroTag: 'main_fab',
                  backgroundColor: _isMenuOpen ? const Color(0xFF5D528F) : AppColors.limeMoss,
                  foregroundColor: _isMenuOpen ? Colors.white : Colors.black,
                  shape: const CircleBorder(),
                  onPressed: _toggleMenu,
                  child: RotationTransition(
                    turns: Tween<double>(begin: 0.0, end: 0.125).animate(_expandAnimation),
                    child: const Icon(Icons.add, size: 28),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: !isDesktop
          ? NavigationBar(
              backgroundColor: AppColors.card,
              indicatorColor: AppColors.limeMoss.withOpacity(0.3),
              selectedIndex: _selectedIndex,
              elevation: 8,
              onDestinationSelected: (int index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              destinations: destinations,
            )
          : null,
    );
  }

  void _showAddTransactionDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTransactionBottomSheet(
        onSaved: () {
          _triggerRefresh();
        },
      ),
    );
  }

  void _showAddAssetTransactionBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddAssetTransactionBottomSheet(
        onSaved: () {
          _triggerRefresh();
        },
      ),
    );
  }
}

class SidebarDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const SidebarDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

class SidebarItem extends StatefulWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final bool isExpanded;
  final VoidCallback onTap;

  const SidebarItem({
    super.key,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  State<SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<SidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    Color? backgroundColor;
    if (_isHovered) {
      backgroundColor = const Color(0xFF1F1F1F); // Lighter grey than background (0xFF030303)
    } else if (widget.isSelected) {
      backgroundColor = const Color(0xFF000000); // Darker than background (0xFF030303)
    } else {
      backgroundColor = Colors.transparent;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
          padding: widget.isExpanded
              ? const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0)
              : const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(28),
          ),
          child: widget.isExpanded
              ? Row(
                  children: [
                    Icon(
                      widget.isSelected ? widget.selectedIcon : widget.icon,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.label,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Icon(
                    widget.isSelected ? widget.selectedIcon : widget.icon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
        ),
      ),
    );
  }
}
