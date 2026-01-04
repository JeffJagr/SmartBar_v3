import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../controllers/app_controller.dart';
import '../../models/order.dart';
import '../../viewmodels/inventory_view_model.dart';
import '../../viewmodels/orders_view_model.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  String _search = '';
  String _range = '7d';
  String _supplierFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final inventoryVm = context.watch<InventoryViewModel>();
    final ordersVm = context.watch<OrdersViewModel?>();
    final app = context.watch<AppController>();
    final orders = ordersVm?.orders ?? [];
    final supplierOptions = _collectSuppliers(inventoryVm, orders);

    final periodDays = _range == 'today'
        ? 1
        : _range == '30d'
            ? 30
            : _range == 'all'
                ? null
                : 7;
    final now = DateTime.now();
    final start = periodDays == null ? null : now.subtract(Duration(days: periodDays));
    final prevStart = periodDays == null ? null : now.subtract(Duration(days: periodDays * 2));
    final prevEnd = start;

    List<OrderModel> inRange = orders;
    List<OrderModel> prevRange = [];
    if (start != null) {
      inRange = orders.where((o) => o.createdAt.isAfter(start)).toList();
      if (prevStart != null && prevEnd != null) {
        prevRange = orders
            .where((o) => o.createdAt.isAfter(prevStart) && o.createdAt.isBefore(prevEnd))
            .toList();
      }
    }
    if (_supplierFilter != 'All') {
      final filter = _supplierFilter.toLowerCase();
      inRange = inRange.where((o) => (o.supplier ?? '').toLowerCase().contains(filter)).toList();
      prevRange =
          prevRange.where((o) => (o.supplier ?? '').toLowerCase().contains(filter)).toList();
    }

    final totalProducts = inventoryVm.products.length;
    final lowCount = inventoryVm.products
        .where((p) {
          final threshold = p.minimalStockThreshold ?? 0;
          final lowBar = threshold > 0 ? p.barQuantity < threshold : p.barQuantity < p.barMax;
          final lowWh = threshold > 0
              ? p.warehouseQuantity < threshold
              : p.warehouseQuantity < p.warehouseTarget;
          return lowBar || lowWh;
        })
        .length;
    final hintCount = inventoryVm.products.where((p) => (p.restockHint ?? 0) > 0).length;
    final pendingOrders = inRange.where((o) => o.status == OrderStatus.pending).length;
    final confirmedOrders = inRange.where((o) => o.status == OrderStatus.confirmed).length;
    final deliveredOrders = inRange.where((o) => o.status == OrderStatus.delivered).length;
    final lastCount = inRange.length;
    final prevCount = prevRange.isEmpty ? 0 : prevRange.length;
    final orderTrend = prevCount == 0 ? lastCount : (((lastCount - prevCount) / prevCount) * 100).round();

    final filteredProducts = _search.isEmpty
        ? inventoryVm.products
        : inventoryVm.products
            .where((p) => p.name.toLowerCase().contains(_search.toLowerCase()))
            .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                app.activeCompany != null ? 'Stats for ${app.activeCompany!.name}' : 'Statistics',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            DropdownButton<String>(
              value: _supplierFilter,
              items: [
                const DropdownMenuItem(value: 'All', child: Text('All suppliers')),
                ...supplierOptions.map(
                  (s) => DropdownMenuItem(value: s, child: Text(s)),
                ),
              ],
              onChanged: (v) => setState(() => _supplierFilter = v ?? 'All'),
            ),
            DropdownButton<String>(
              value: _range,
              items: const [
                DropdownMenuItem(value: 'today', child: Text('Today')),
                DropdownMenuItem(value: '7d', child: Text('Last 7 days')),
                DropdownMenuItem(value: '30d', child: Text('Last 30 days')),
                DropdownMenuItem(value: 'all', child: Text('All time')),
              ],
              onChanged: (v) => setState(() => _range = v ?? '7d'),
            ),
            IconButton(
              tooltip: 'Copy summary',
              icon: const Icon(Icons.copy_all),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final csv = _exportSummaryCsv(
                  totalProducts: totalProducts,
                  low: lowCount,
                  hint: hintCount,
                  pending: pendingOrders,
                  confirmed: confirmedOrders,
                  delivered: deliveredOrders,
                  periodLabel: _rangeLabel(),
                  ordersCurrent: lastCount,
                  ordersPrev: prevCount,
                );
                await Clipboard.setData(ClipboardData(text: csv));
                if (!mounted) return;
                messenger.showSnackBar(const SnackBar(content: Text('Summary copied')));
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _statCard(context, 'Products', '$totalProducts', Icons.inventory_2_outlined),
            _statCard(context, 'Low stock', '$lowCount', Icons.report_problem_outlined),
            _statCard(context, 'Hints set', '$hintCount', Icons.lightbulb_outline),
            _statCard(context, 'Orders pending', '$pendingOrders', Icons.shopping_cart_outlined),
            _statCard(context, 'Orders confirmed', '$confirmedOrders', Icons.verified_outlined),
            _statCard(context, 'Orders delivered', '$deliveredOrders', Icons.done_all),
            _statCard(
              context,
              'Orders (${_rangeLabel()})',
              '$lastCount (${orderTrend >= 0 ? '+' : ''}$orderTrend% vs prev)',
              Icons.trending_up,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Products', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search products',
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            IconButton(
              tooltip: 'Copy product stats CSV',
              icon: const Icon(Icons.copy_all),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final csv = _exportProductsCsv(filteredProducts, orders);
                await Clipboard.setData(ClipboardData(text: csv));
                if (!mounted) return;
                messenger.showSnackBar(const SnackBar(content: Text('Stats copied to clipboard')));
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...filteredProducts.map((p) {
          if (_supplierFilter != 'All' &&
              !(p.supplierName ?? '').toLowerCase().contains(_supplierFilter.toLowerCase())) {
            return const SizedBox.shrink();
          }
          final ordered = orders
              .where((o) => o.status != OrderStatus.delivered)
              .expand((o) => o.items)
              .where((i) => i.productId == p.id)
              .fold<int>(0, (sum, i) => sum + i.quantityOrdered);
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              title: Text(p.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Bar ${p.barQuantity}/${p.barMax} | WH ${p.warehouseQuantity}/${p.warehouseTarget} | Ordered $ordered'),
                  if ((p.supplierName ?? '').isNotEmpty)
                    Text('Supplier: ${p.supplierName}',
                        style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              trailing: (p.restockHint ?? 0) > 0
                  ? Text('Hint ${p.restockHint}', style: const TextStyle(color: Colors.orange))
                  : null,
            ),
          );
        }),
      ],
    );
  }

  Widget _statCard(BuildContext context, String label, String value, IconData icon) {
    return SizedBox(
      width: 170,
      child: Card(
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              Text(
                value,
                style:
                    Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _rangeLabel() {
    switch (_range) {
      case 'today':
        return 'today';
      case '30d':
        return '30d';
      case 'all':
        return 'all time';
      case '7d':
      default:
        return '7d';
    }
  }

  String _exportProductsCsv(List filtered, List<OrderModel> orders) {
    final buffer = StringBuffer();
    buffer.writeln('Product,Bar,Warehouse,Ordered,Hint,Supplier');
    for (final p in filtered) {
      if (_supplierFilter != 'All' &&
          !(p.supplierName ?? '').toLowerCase().contains(_supplierFilter.toLowerCase())) {
        continue;
      }
      final ordered = orders
          .where((o) => o.status != OrderStatus.delivered)
          .expand((o) => o.items)
          .where((i) => i.productId == p.id)
          .fold<int>(0, (sum, i) => sum + i.quantityOrdered);
      buffer.writeln(
          '${p.name},${p.barQuantity}/${p.barMax},${p.warehouseQuantity}/${p.warehouseTarget},$ordered,${p.restockHint ?? 0},${p.supplierName ?? ''}');
    }
    return buffer.toString();
  }

  String _exportSummaryCsv({
    required int totalProducts,
    required int low,
    required int hint,
    required int pending,
    required int confirmed,
    required int delivered,
    required String periodLabel,
    required int ordersCurrent,
    required int ordersPrev,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('Metric,Value');
    buffer.writeln('Products,$totalProducts');
    buffer.writeln('Low stock,$low');
    buffer.writeln('Hints,$hint');
    buffer.writeln('Orders pending,$pending');
    buffer.writeln('Orders confirmed,$confirmed');
    buffer.writeln('Orders delivered,$delivered');
    buffer.writeln('Orders ($periodLabel),$ordersCurrent');
    buffer.writeln('Orders previous period,$ordersPrev');
    return buffer.toString();
  }

  List<String> _collectSuppliers(InventoryViewModel inventoryVm, List<OrderModel> orders) {
    final set = <String>{};
    for (final p in inventoryVm.products) {
      final name = p.supplierName ?? '';
      if (name.isNotEmpty) set.add(name);
    }
    for (final o in orders) {
      final name = o.supplier ?? '';
      if (name.isNotEmpty) set.add(name);
    }
    final list = set.toList()..sort();
    return list;
  }
}
