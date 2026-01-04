import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/app_controller.dart';
import '../../models/company.dart';
import '../../models/order.dart';
import '../../models/user_role.dart';
import '../../repositories/network_history_repository.dart';
import '../../repositories/network_notes_repository.dart';
import '../../repositories/network_orders_repository.dart';
import '../../services/network_stats_service.dart';
import '../../viewmodels/network_history_view_model.dart';
import '../../viewmodels/network_notes_view_model.dart';
import '../../viewmodels/network_orders_view_model.dart';
import '../../viewmodels/network_stats_view_model.dart';
import '../../screens/company/company_list_screen.dart';
import '../screens/network_cart_screen.dart';
import '../screens/network_order_details_screen.dart';

class OwnerSuperScreen extends StatelessWidget {
  const OwnerSuperScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final companies = app.companies;
    final isOwnerOrManager = app.isOwner || app.role == UserRole.manager;

    if (!isOwnerOrManager) {
      return Scaffold(
        appBar: AppBar(title: const Text('Owner Dashboard')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Owner/Manager access required.'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const CompanyListScreen()),
                  );
                },
                child: const Text('Back to Company Picker'),
              ),
            ],
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Owner Dashboard'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Orders', icon: Icon(Icons.shopping_cart_outlined)),
              Tab(text: 'Notes', icon: Icon(Icons.note_alt_outlined)),
              Tab(text: 'Stats', icon: Icon(Icons.insights_outlined)),
              Tab(text: 'History', icon: Icon(Icons.history)),
              Tab(text: 'Logout', icon: Icon(Icons.logout)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ChangeNotifierProvider(
              create: (_) =>
                  NetworkOrdersViewModel(NetworkOrdersRepository(), companies)..load(reset: true),
              child: _NetworkOrdersTab(companies: companies),
            ),
            ChangeNotifierProvider(
              create: (_) => NetworkNotesViewModel(
                NetworkNotesRepository(),
                companies,
                currentUserId: app.ownerUser?.uid ?? '',
              )..load(reset: true),
              child: _NetworkNotesTab(
                companies: companies,
                currentUserId: app.ownerUser?.uid ?? '',
              ),
            ),
            ChangeNotifierProvider(
              create: (_) => NetworkStatsViewModel(NetworkStatsService(), companies)..load(),
              child: _NetworkStatsTab(),
            ),
            ChangeNotifierProvider(
              create: (_) =>
                  NetworkHistoryViewModel(NetworkHistoryRepository(), companies)..load(reset: true),
              child: _NetworkHistoryTab(),
            ),
            _LogoutSection(onLogout: () async {
              await context.read<AppController>().signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const CompanyListScreen()),
                  (route) => false,
                );
              }
            }),
          ],
        ),
      ),
    );
  }
}

class _NetworkOrdersTab extends StatefulWidget {
  const _NetworkOrdersTab({required this.companies});
  final List<Company> companies;
  @override
  State<_NetworkOrdersTab> createState() => _NetworkOrdersTabState();
}

class _NetworkOrdersTabState extends State<_NetworkOrdersTab> {
  final Set<String> _collapsedSuppliers = {};

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NetworkOrdersViewModel>();
    return Column(
      children: [
        _TopFilterBar(
          companies: widget.companies,
          selectedCompanyIds: vm.activeCompanyIds.toSet(),
          onCompanyToggle: vm.toggleCompany,
          dateRange: vm.dateRange,
          onDateRangeChanged: vm.setDateRange,
          onSearchChanged: vm.setSearch,
          showSearch: true,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Supplier',
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
                onSubmitted: vm.setSupplier,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const NetworkCartScreen()),
                      );
                    },
                    icon: const Icon(Icons.shopping_cart),
                    label: const Text('Open Network Cart'),
                  ),
                  _StatusChip(label: 'Pending', status: OrderStatus.pending, vm: vm),
                  _StatusChip(label: 'Confirmed', status: OrderStatus.confirmed, vm: vm),
                  _StatusChip(label: 'Delivered', status: OrderStatus.delivered, vm: vm),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: Builder(
            builder: (_) {
              if (vm.loading && vm.orders.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (vm.error != null) {
                return _ErrorState(message: vm.error!, onRetry: () => vm.load(reset: true));
              }
              if (vm.orders.isEmpty) {
                return const _EmptyState(message: 'No orders found for selected filters.');
              }
              final grouped = _groupBySupplier(vm.orders);
              return RefreshIndicator(
                onRefresh: () => vm.load(reset: true),
                child: ListView(
                  children: [
                    ...grouped.entries.map((entry) {
                      final supplier = entry.key;
                      final orders = entry.value;
                      final isCollapsed = _collapsedSuppliers.contains(supplier);
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ExpansionTile(
                          initiallyExpanded: !isCollapsed,
                          onExpansionChanged: (expanded) {
                            setState(() {
                              if (expanded) {
                                _collapsedSuppliers.remove(supplier);
                              } else {
                                _collapsedSuppliers.add(supplier);
                              }
                            });
                          },
                          title: Text(supplier),
                          subtitle: Text('${orders.length} orders'),
                          children: orders
                              .map(
                                (order) => ListTile(
                                  title: Text(
                                      '#${order.orderNumber.toString().padLeft(4, '0')} • ${_companyName(vm.companyById, order.companyId)}'),
                                  subtitle: Text(
                                      '${order.items.length} items • Updated ${_lastUpdated(order).toLocal()}'),
                                  trailing: _StatusPill(status: order.status),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => NetworkOrderDetailsScreen(
                                        order: order,
                                        company: vm.companyById[order.companyId],
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      );
                    }),
                    if (vm.hasMore)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: ElevatedButton(
                            onPressed: vm.loading ? null : () => vm.load(),
                            child: vm.loading
                                ? const SizedBox(
                                    width: 16, height: 16, child: CircularProgressIndicator())
                                : const Text('Load more'),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Map<String, List<OrderModel>> _groupBySupplier(List<OrderModel> orders) {
    final map = <String, List<OrderModel>>{};
    for (final order in orders) {
      final key = order.supplier?.isNotEmpty == true ? order.supplier! : 'No supplier';
      map.putIfAbsent(key, () => []).add(order);
    }
    return map;
  }

  String _companyName(Map<String, Company> companies, String id) =>
      companies[id]?.name ?? 'Unknown company';

  DateTime _lastUpdated(OrderModel order) {
    return order.deliveredAt ?? order.confirmedAt ?? order.createdAt;
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.status, required this.vm});
  final String label;
  final OrderStatus status;
  final NetworkOrdersViewModel vm;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: vm.isStatusSelected(status),
      onSelected: (_) => vm.toggleStatus(status),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case OrderStatus.pending:
        color = Colors.amber;
        break;
      case OrderStatus.confirmed:
        color = Colors.blue;
        break;
      case OrderStatus.delivered:
        color = Colors.green;
        break;
      case OrderStatus.canceled:
        color = Colors.grey;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(status.name, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _NetworkNotesTab extends StatefulWidget {
  const _NetworkNotesTab({required this.companies, required this.currentUserId});
  final List<Company> companies;
  final String currentUserId;
  @override
  State<_NetworkNotesTab> createState() => _NetworkNotesTabState();
}

class _NetworkNotesTabState extends State<_NetworkNotesTab> {
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NetworkNotesViewModel>();
    return Column(
      children: [
        _TopFilterBar(
          companies: widget.companies,
          selectedCompanyIds: vm.activeCompanyIds.toSet(),
          onCompanyToggle: vm.toggleCompany,
          dateRange: vm.dateRange,
          onDateRangeChanged: vm.setDateRange,
          onSearchChanged: vm.setSearch,
          showSearch: true,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ChoiceChip(label: const Text('All tags'), selected: vm.tagFilter == 'all', onSelected: (_) => vm.setTag('all')),
              ChoiceChip(label: const Text('TODO'), selected: vm.tagFilter.toLowerCase() == 'todo', onSelected: (_) => vm.setTag('TODO')),
              ChoiceChip(label: const Text('Info'), selected: vm.tagFilter.toLowerCase() == 'info', onSelected: (_) => vm.setTag('Info')),
              ChoiceChip(label: const Text('Alert'), selected: vm.tagFilter.toLowerCase() == 'alert', onSelected: (_) => vm.setTag('Alert')),
              FilterChip(label: const Text('Show done'), selected: vm.showDone, onSelected: (v) => vm.setShowDone(v)),
              FilterChip(label: const Text('Assigned to me'), selected: vm.assignedToMe, onSelected: vm.setAssignedToMe),
              FilterChip(label: const Text('Unread'), selected: vm.unreadOnly, onSelected: vm.setUnreadOnly),
            ],
          ),
        ),
        Expanded(
          child: Builder(builder: (_) {
            if (vm.loading && vm.notes.isEmpty) return const Center(child: CircularProgressIndicator());
            if (vm.error != null) return _ErrorState(message: vm.error!, onRetry: () => vm.load(reset: true));
            if (vm.notes.isEmpty) return const _EmptyState(message: 'No notes found for selected filters.');
            return RefreshIndicator(
              onRefresh: () => vm.load(reset: true),
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: vm.notes.length + (vm.hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == vm.notes.length) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: ElevatedButton(
                          onPressed: vm.loading ? null : () => vm.load(),
                          child: vm.loading
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator())
                              : const Text('Load more'),
                        ),
                      ),
                    );
                  }
                  final note = vm.notes[index];
                  final isUnread = !note.readBy.containsKey(widget.currentUserId);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(note.content),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            children: [
                              Chip(label: Text(note.tag)),
                              if (note.priority != null) Chip(label: Text(note.priority!)),
                              Chip(label: Text(vm.companyName(note.companyId))),
                              if (isUnread) const Chip(label: Text('Unread')),
                            ],
                          ),
                          Text('${note.authorName} • ${note.timestamp.toLocal()}',
                              style: Theme.of(context).textTheme.bodySmall),
                          if (note.assigneeIds.isNotEmpty)
                            Wrap(
                              spacing: 6,
                              children: note.assigneeIds
                                  .map((a) => Chip(
                                        label: Text('Assigned: $a'),
                                        backgroundColor: Colors.blue.withValues(alpha: 0.12),
                                      ))
                                  .toList(),
                            ),
                        ],
                      ),
                      trailing: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!note.isDone)
                            IconButton(
                              icon: const Icon(Icons.check_circle_outline),
                              tooltip: 'Mark done',
                              onPressed: () => vm.markDone(note),
                            ),
                          IconButton(
                            icon: const Icon(Icons.mark_email_read_outlined),
                            tooltip: 'Mark read',
                            onPressed: () => vm.markRead(note),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _NetworkStatsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NetworkStatsViewModel>();
    final companies = vm.allCompanies;
    return Column(
      children: [
        _TopFilterBar(
          companies: companies,
          selectedCompanyIds: vm.companies.map((c) => c.id).toSet(),
          onCompanyToggle: vm.toggleCompany,
          dateRange: vm.range,
          onDateRangeChanged: (range) {
            if (range != null) vm.setRange(range);
          },
          showSearch: false,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Supplier filter (optional)',
                    prefixIcon: Icon(Icons.storefront_outlined),
                  ),
                  onSubmitted: vm.setSupplier,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${vm.range.start.toLocal().toIso8601String().substring(0, 10)} • ${vm.range.end.toLocal().toIso8601String().substring(0, 10)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (vm.loading && vm.stats.isEmpty)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (vm.error != null)
          Expanded(child: _ErrorState(message: vm.error!, onRetry: vm.load))
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => vm.load(),
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _KpiGrid(stats: vm.stats),
                  const SizedBox(height: 12),
                  _OrdersByCompanyTable(stats: vm.stats),
                  const SizedBox(height: 16),
                  _OrdersOverTimeChart(points: vm.overTime),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.stats});
  final List<CompanyStats> stats;
  @override
  Widget build(BuildContext context) {
    final totalPending = stats.fold<int>(0, (s, c) => s + c.pendingOrders);
    final totalConfirmed = stats.fold<int>(0, (s, c) => s + c.confirmedOrders);
    final totalDelivered = stats.fold<int>(0, (s, c) => s + c.deliveredRecently);
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _KpiCard(label: 'Pending', value: totalPending.toString(), color: Colors.amber),
        _KpiCard(label: 'Confirmed', value: totalConfirmed.toString(), color: Colors.blue),
        _KpiCard(label: 'Delivered', value: totalDelivered.toString(), color: Colors.green),
        _KpiCard(
            label: 'Open notes',
            value: stats.fold<int>(0, (s, c) => s + c.openNotes).toString(),
            color: Colors.deepPurple),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersByCompanyTable extends StatelessWidget {
  const _OrdersByCompanyTable({required this.stats});
  final List<CompanyStats> stats;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Orders by Company', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...stats.map((s) => ListTile(
                  dense: true,
                  title: Text(s.companyName),
                  subtitle: Text('Code: ${s.companyCode}'),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      _miniPill('${s.pendingOrders} pending', Colors.amber),
                      _miniPill('${s.confirmedOrders} confirmed', Colors.blue),
                      _miniPill('${s.deliveredRecently} delivered', Colors.green),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _miniPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(color: color)),
    );
  }
}

class _OrdersOverTimeChart extends StatelessWidget {
  const _OrdersOverTimeChart({required this.points});
  final List<OrdersOverTimePoint> points;
  @override
  Widget build(BuildContext context) {
    final maxCount =
        points.isEmpty ? 1 : points.map((p) => p.count).reduce((a, b) => a > b ? a : b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Orders over time', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: points.isEmpty
                  ? const Center(child: Text('No data for selected range'))
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: points
                          .map(
                            (p) => Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: Container(
                                  height: (p.count / maxCount) * 120,
                                  color: Colors.blue.withValues(alpha: 0.6),
                                  child: Tooltip(
                                    message:
                                        '${p.day.toLocal().toIso8601String().substring(0, 10)}: ${p.count}',
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkHistoryTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NetworkHistoryViewModel>();
    final companies = vm.companies;
    return Column(
      children: [
        _TopFilterBar(
          companies: companies,
          selectedCompanyIds: vm.activeCompanyIds.toSet(),
          onCompanyToggle: vm.toggleCompany,
          dateRange: vm.dateRange,
          onDateRangeChanged: vm.setDateRange,
          onSearchChanged: vm.setSearch,
          showSearch: true,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: DropdownButtonFormField<String>(
            initialValue: vm.actionFilter.isEmpty ? null : vm.actionFilter,
            decoration: const InputDecoration(labelText: 'Event type'),
            items: const [
              DropdownMenuItem(value: 'order', child: Text('Order events')),
              DropdownMenuItem(value: 'note', child: Text('Note events')),
              DropdownMenuItem(value: 'inventory', child: Text('Inventory events')),
            ],
            onChanged: (v) => vm.setAction(v ?? ''),
          ),
        ),
        Expanded(
          child: Builder(builder: (_) {
            if (vm.loading && vm.entries.isEmpty) return const Center(child: CircularProgressIndicator());
            if (vm.error != null) return _ErrorState(message: vm.error!, onRetry: () => vm.load(reset: true));
            if (vm.entries.isEmpty) return const _EmptyState(message: 'No history found.');
            return RefreshIndicator(
              onRefresh: () => vm.load(reset: true),
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: vm.entries.length + (vm.hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == vm.entries.length) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: ElevatedButton(
                          onPressed: vm.loading ? null : () => vm.load(),
                          child: vm.loading
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator())
                              : const Text('Load more'),
                        ),
                      ),
                    );
                  }
                  final entry = vm.entries[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(entry.itemName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            children: [
                              Chip(label: Text(vm.companyName(entry.companyId))),
                              Chip(label: Text(entry.actionType)),
                            ],
                          ),
                          Text('${entry.performedBy} • ${entry.timestamp.toLocal()}'),
                          if (entry.description != null) Text(entry.description!),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoutSection extends StatelessWidget {
  const _LogoutSection({required this.onLogout});
  final Future<void> Function() onLogout;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton.icon(
        icon: const Icon(Icons.logout),
        label: const Text('Sign out'),
        onPressed: onLogout,
      ),
    );
  }
}

class _TopFilterBar extends StatelessWidget {
  const _TopFilterBar({
    required this.companies,
    required this.selectedCompanyIds,
    required this.onCompanyToggle,
    this.dateRange,
    this.onDateRangeChanged,
    this.onSearchChanged,
    this.showSearch = true,
  });

  final List<Company> companies;
  final Set<String> selectedCompanyIds;
  final void Function(String) onCompanyToggle;
  final DateTimeRange? dateRange;
  final void Function(DateTimeRange?)? onDateRangeChanged;
  final void Function(String)? onSearchChanged;
  final bool showSearch;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: companies
                .map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text('${c.name} (${c.companyCode})'),
                      selected: selectedCompanyIds.isEmpty || selectedCompanyIds.contains(c.id),
                      onSelected: (_) => onCompanyToggle(c.id),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              if (showSearch)
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: onSearchChanged,
                  ),
                ),
              IconButton(
                tooltip: 'Date range',
                icon: const Icon(Icons.date_range),
                onPressed: onDateRangeChanged == null
                    ? null
                    : () async {
                        final range = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 1)),
                          initialDateRange: dateRange,
                        );
                        onDateRangeChanged?.call(range);
                      },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
