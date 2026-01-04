import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../controllers/app_controller.dart';
import '../../../models/company.dart';
import '../../../viewmodels/inventory_view_model.dart';
import '../../../viewmodels/notes_view_model.dart';
import '../../../viewmodels/orders_view_model.dart';
import '../../../models/order.dart';
import '../../sections/bar_screen.dart';
import '../../sections/company_settings_screen.dart';
import '../../sections/history_section_screen.dart';
import '../../sections/orders_screen.dart';
import '../../sections/print_export_screen.dart';
import '../../sections/restock_screen.dart';
import '../../sections/statistics_screen.dart';
import '../../sections/users_screen.dart';
import '../../sections/warehouse_screen.dart';
import 'package:smart_bar_app_v3/ui/sections/notes_screen.dart';
import '../../sections/inventory_list_screen.dart';
import '../../widgets/product_form_sheet.dart';
import '../../sections/notifications_screen.dart';
import 'package:smart_bar_app_v3/screens/auth/role_selection_screen.dart';
import 'package:smart_bar_app_v3/screens/company/company_list_screen.dart';

enum _HomeSection {
  bar,
  warehouse,
  inventory,
  restock,
  orders,
  history,
  statistics,
  users,
  companySettings,
  printExport,
  syncRefresh,
  notes,
  notifications,
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _HomeSection _selected = _HomeSection.bar;
  StreamSubscription<RemoteMessage>? _messageSubscription;

  @override
  void initState() {
    super.initState();
    // Listen for foreground notifications to show a quick Snackbar.
    _messageSubscription = FirebaseMessaging.onMessage.listen((message) {
      if (!mounted) return;
      final notif = message.notification;
      final title = notif?.title ?? 'Notification';
      final body = notif?.body ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$title${body.isNotEmpty ? ': $body' : ''}')),
      );
    });
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }

  void _selectSection(_HomeSection section, {bool closeDrawer = true}) {
    setState(() => _selected = section);
    if (closeDrawer) {
      Navigator.of(context).pop(); // close drawer
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final company = app.activeCompany;
    final permSnapshot = app.currentPermissionSnapshot;
    final canManageProducts = app.permissions.canEditProducts(permSnapshot);
    final isOwner = app.isOwner;
    // Keep VMs in sync with current permission snapshot instead of owner-only.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final invVm = context.read<InventoryViewModel>();
      invVm.applyPermissionContext(
        snapshot: permSnapshot,
        service: app.permissions,
      );
      context.read<NotesViewModel>().setPermissions(isOwner: isOwner);
    });
    if (company == null) {
      // No active company; redirect to company selection/creation flow.
      return const CompanyListScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(company.name),
            Text(
              'Code: ${company.companyCode}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              app.themeMode == ThemeMode.dark
                  ? Icons.dark_mode
                  : app.themeMode == ThemeMode.light
                      ? Icons.light_mode
                      : Icons.brightness_6_outlined,
            ),
            onPressed: app.toggleThemeMode,
            tooltip: 'Toggle theme',
          ),
          Consumer<OrdersViewModel?>(
            builder: (context, vm, _) {
              final pendingCount =
                  vm?.orders.where((o) => o.status == OrderStatus.pending).length ?? 0;
              final activeCount = vm?.orders
                      .where((o) =>
                          o.status == OrderStatus.pending || o.status == OrderStatus.confirmed)
                      .length ??
                  0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    tooltip: 'Orders',
                    onPressed: () => _selectSection(_HomeSection.orders, closeDrawer: false),
                    icon: const Icon(Icons.shopping_cart_outlined),
                  ),
                  if (pendingCount > 0)
                    Positioned(
                      right: 6,
                      top: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  if (activeCount > 0)
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          activeCount.toString(),
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      drawer: _buildDrawer(app, company, isOwner),
      body: _buildBody(),
      floatingActionButton: _buildFab(canManageProducts),
    );
  }

  Widget _buildBody() {
    switch (_selected) {
      case _HomeSection.bar:
        return const BarScreen();
      case _HomeSection.warehouse:
        return const WarehouseScreen();
      case _HomeSection.inventory:
        return const InventoryListScreen();
      case _HomeSection.restock:
        return const RestockScreen();
      case _HomeSection.orders:
        return const OrdersScreen();
      case _HomeSection.history:
        return const HistorySectionScreen();
      case _HomeSection.statistics:
        return const StatisticsScreen();
      case _HomeSection.users:
        return const UsersScreen();
      case _HomeSection.companySettings:
        return const CompanySettingsScreen();
      case _HomeSection.printExport:
        return const PrintExportScreen();
      case _HomeSection.syncRefresh:
        final app = context.watch<AppController>();
        return Center(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh data'),
            onPressed: () => app.refreshActiveCompany(),
          ),
        );
      case _HomeSection.notes:
        return const NotesScreen();
      case _HomeSection.notifications:
        return const NotificationsScreen();
    }
  }

  Widget? _buildFab(bool canManageProducts) {
    if (!canManageProducts) return null;
    if (_selected != _HomeSection.bar &&
        _selected != _HomeSection.warehouse &&
        _selected != _HomeSection.inventory) {
      return null;
    }
    return FloatingActionButton.extended(
      icon: const Icon(Icons.add),
      label: const Text('Add product'),
      onPressed: () {
        showModalBottomSheet(
          isScrollControlled: true,
          context: context,
          builder: (_) => const ProductFormSheet(),
        );
      },
    );
  }

  Drawer _buildDrawer(AppController app, Company? company, bool isOwner) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(app.displayName),
              accountEmail: Text(isOwner ? 'Owner/Manager' : 'Staff'),
              currentAccountPicture: CircleAvatar(
                child: Text(app.displayName.isNotEmpty
                    ? app.displayName.substring(0, 1).toUpperCase()
                    : '?'),
              ),
            ),
            _sectionLabel('Company'),
            if (isOwner)
              _drawerItem(
                icon: Icons.settings_outlined,
                label: 'Company Settings',
                onTap: () => _selectSection(_HomeSection.companySettings),
              ),
            if (isOwner)
              _drawerItem(
                icon: Icons.swap_horiz,
                label: 'Switch Company',
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const CompanyListScreen(),
                    ),
                  );
                },
              ),
            if (isOwner)
              _drawerItem(
                icon: Icons.group_add_outlined,
                label: 'Invite Partner Owner',
                onTap: () {
                  // TODO: implement invite partner flow.
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invite flow coming soon')),
                  );
                },
              ),
            _sectionLabel('Operations'),
            _drawerItem(
              icon: Icons.local_bar_outlined,
              label: 'Bar',
              onTap: () => _selectSection(_HomeSection.bar),
            ),
            _drawerItem(
              icon: Icons.warehouse_outlined,
              label: 'Warehouse',
              onTap: () => _selectSection(_HomeSection.warehouse),
            ),
            _drawerItem(
              icon: Icons.list_alt_outlined,
              label: 'Inventory (combined)',
              onTap: () => _selectSection(_HomeSection.inventory),
            ),
            _drawerItem(
              icon: Icons.swap_vert,
              label: 'Restock',
              onTap: () => _selectSection(_HomeSection.restock),
            ),
            _drawerItem(
              icon: Icons.local_shipping_outlined,
              label: 'Orders',
              onTap: () => _selectSection(_HomeSection.orders),
            ),
            _sectionLabel('Analytics'),
            _drawerItem(
              icon: Icons.insights_outlined,
              label: 'Statistics',
              onTap: () => _selectSection(_HomeSection.statistics),
            ),
            _drawerItem(
              icon: Icons.history_toggle_off_outlined,
              label: 'History',
              onTap: () => _selectSection(_HomeSection.history),
            ),
            _sectionLabel('Tools'),
            _drawerItem(
              icon: Icons.print_outlined,
              label: 'Print / Export',
              onTap: () => _selectSection(_HomeSection.printExport),
            ),
            _drawerItem(
              icon: Icons.note_alt_outlined,
              label: 'Notes',
              onTap: () => _selectSection(_HomeSection.notes),
            ),
            _drawerItem(
              icon: Icons.notifications,
              label: 'Notifications',
              onTap: () => _selectSection(_HomeSection.notifications),
            ),
            _drawerItem(
              icon: Icons.refresh_outlined,
              label: 'Sync / Refresh',
              onTap: () {
                _selectSection(_HomeSection.syncRefresh);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Refreshing soon...')),
                );
              },
            ),
            _sectionLabel('Account'),
            if (isOwner)
              _drawerItem(
                icon: Icons.badge_outlined,
                label: 'User Management',
                onTap: () => _selectSection(_HomeSection.users),
              ),
            _drawerItem(
              icon: Icons.logout,
              label: 'Logout',
              onTap: () async {
                await app.signOut();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => const RoleSelectionScreen(),
                    ),
                    (_) => false,
                  );
                }
              },
            ),
            const SizedBox(height: 16),
            if (company != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Active: ${company.name}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: onTap,
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }
}

