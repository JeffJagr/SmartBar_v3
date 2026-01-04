import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../controllers/app_controller.dart';
import '../../models/order.dart';
import '../../models/product.dart';
import '../../viewmodels/inventory_view_model.dart';
import '../../viewmodels/orders_view_model.dart';
import '../widgets/adjust_quantity_sheet.dart';
import '../widgets/product_form_sheet.dart';
import '../widgets/restock_hint_sheet.dart';
import '../widgets/group_management_sheet.dart';
import '../../repositories/group_repository.dart';
import '../widgets/add_to_order_sheet.dart';

/// Warehouse inventory screen – list-first UI with grouped, collapsible sections.
class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  String _search = '';
  String? _groupFilter;
  bool _lowOnly = false;
  bool _hintOnly = false;
  final String _sortKey = 'name';
  bool _groupedView = true;
  final Set<String> _expandedGroups = {};
  final Set<String> _selectedIds = {};
  bool get _inSelectMode => _selectedIds.isNotEmpty;

  String _buildPrintable(List<Product> products) {
    final buffer = StringBuffer();
    buffer.writeln('WAREHOUSE INVENTORY');
    buffer.writeln('========================');
    for (final p in products) {
      buffer.writeln(
          '${p.name} | ${p.group}${p.subgroup != null ? " / ${p.subgroup}" : ""} | Supplier: ${p.supplierName ?? "n/a"}');
      buffer.writeln(
          '  Bar: ${p.barQuantity}/${p.barMax}${p.trackVolume && (p.unitVolumeMl ?? 0) > 0 ? " (${p.barVolumeMl ?? p.barQuantity * (p.unitVolumeMl ?? 0)} ml)" : ""}');
      buffer.writeln(
          '  WH: ${p.warehouseQuantity}/${p.warehouseTarget}${p.trackVolume && (p.unitVolumeMl ?? 0) > 0 ? " (${p.warehouseVolumeMl ?? p.warehouseQuantity * (p.unitVolumeMl ?? 0)} ml)" : ""}');
      if ((p.restockHint ?? 0) > 0) buffer.writeln('  Hint: ${p.restockHint}');
      buffer.writeln('------------------------');
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final perm = app.currentPermissionSnapshot;
    final canOrder = app.permissions.canCreateOrders(perm);
    final vm = context.watch<InventoryViewModel>();
    final ordersVm = context.watch<OrdersViewModel?>();

    if (vm.loading) return const Center(child: CircularProgressIndicator());
    if (vm.error != null) return Center(child: Text('Error: ${vm.error}'));
    if (vm.products.isEmpty) return const Center(child: Text('No products yet.'));

    final canAdjust = app.permissions.canAdjustQuantities(perm);
    final canManageGroups = app.permissions.canEditProducts(perm);
    final groups = vm.products.map((p) => p.group).toSet().toList()..sort();
    List<Product> filtered = vm.products.where((p) {
      final matchesSearch = _search.isEmpty ||
          p.name.toLowerCase().contains(_search.toLowerCase()) ||
          p.group.toLowerCase().contains(_search.toLowerCase());
      final matchesGroup = _groupFilter == null || p.group == _groupFilter;
      final matchesLow = !_lowOnly || p.warehouseQuantity < p.warehouseTarget;
      final matchesHint = !_hintOnly || (p.restockHint ?? 0) > 0;
      return matchesSearch && matchesGroup && matchesLow && matchesHint;
    }).toList();

    _sortProducts(filtered);

    final grouped = _groupedView ? _groupByGroup(filtered) : {'All items': filtered};
    final groupKeys = grouped.keys.toList()..sort();

    return Column(
      children: [
        _filters(context, groups, filtered, ordersVm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                FilterChip(
                  label: Text(_groupedView ? 'Grouped view' : 'Flat view'),
                  selected: _groupedView,
                  onSelected: (v) => setState(() => _groupedView = v),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.unfold_less),
                  label: const Text('Collapse all'),
                  onPressed: () => setState(() => _expandedGroups.clear()),
                ),
                if (_inSelectMode)
                  TextButton(
                    onPressed: () => setState(() => _selectedIds.clear()),
                    child: const Text('Clear selection'),
                  ),
                if (_inSelectMode)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.label),
                    label: const Text('Move to group'),
                    onPressed: () => _showMoveToGroupDialog(context, vm),
                  ),
                if (_inSelectMode)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Ungroup'),
                    onPressed: () => _clearGroupSelection(vm),
                  ),
                if (canManageGroups)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.settings),
                    label: const Text('Manage groups'),
                    onPressed: () => _openGroupManager(context),
                  ),
                PopupMenuButton<_ExportKind>(
                  tooltip: 'Export / share',
                  onSelected: (kind) async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      final text = kind == _ExportKind.csv
                          ? await context.read<InventoryViewModel>().exportCsv()
                          : _buildPrintable(filtered);
                      await Clipboard.setData(ClipboardData(text: text));
                      if (!mounted) return;
                      messenger.showSnackBar(SnackBar(
                        content: Text(kind == _ExportKind.csv
                            ? 'Warehouse CSV copied'
                            : 'Printable warehouse copied'),
                      ));
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Export failed: $e')),
                      );
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: _ExportKind.csv,
                      child: ListTile(
                        leading: Icon(Icons.copy_all),
                        title: Text('Copy CSV'),
                      ),
                    ),
                    PopupMenuItem(
                      value: _ExportKind.printable,
                      child: ListTile(
                        leading: Icon(Icons.picture_as_pdf_outlined),
                        title: Text('Copy printable (PDF-ready)'),
                      ),
                    ),
                  ],
                  icon: const Icon(Icons.ios_share),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: groupKeys.length,
            itemBuilder: (context, index) {
              final group = groupKeys[index];
              final items = grouped[group]!;
              final stats = _aggregateStatus(items, ordersVm);
              final expanded = _expandedGroups.contains(group);
              final groupColor = _groupColor(items);
              final hasCritical = stats.lowCount > 0 || stats.hintCount > 0 || stats.orderCount > 0;
              final criticalColor = stats.lowCount > 0
                  ? Theme.of(context).colorScheme.error
                  : stats.hintCount > 0
                      ? Theme.of(context).colorScheme.tertiary
                      : Theme.of(context).colorScheme.primary;
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border(
                    left: BorderSide(color: groupColor.withValues(alpha: 0.9), width: 4),
                  ),
                ),
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: Card(
                  margin: EdgeInsets.zero,
                  elevation: 0,
                  child: ExpansionTile(
                    initiallyExpanded: expanded,
                    onExpansionChanged: (v) {
                      setState(() {
                        if (v) {
                          _expandedGroups.add(group);
                        } else {
                          _expandedGroups.remove(group);
                        }
                      });
                    },
                    title: Row(
                      children: [
                        _groupTag(group, color: groupColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(group, style: Theme.of(context).textTheme.titleMedium),
                        ),
                        if (hasCritical)
                          Icon(Icons.circle, size: 10, color: criticalColor),
                      ],
                    ),
                    subtitle: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _chip(context, '${items.length} items'),
                        if (stats.lowCount > 0)
                          _chip(context, 'Low ${stats.lowCount}',
                              color: Theme.of(context).colorScheme.error),
                        if (stats.halfCount > 0)
                          _chip(context, 'Half ${stats.halfCount}', color: Colors.amber),
                        if (stats.hintCount > 0)
                          _chip(context, 'Hints ${stats.hintCount}',
                              color: Theme.of(context).colorScheme.tertiary),
                        if (stats.orderCount > 0)
                          _chip(context, 'Ordered ${stats.orderCount}',
                              color: Theme.of(context).colorScheme.primary),
                      ],
                    ),
                    children: items
                        .map(
                          (p) => _buildItemTile(
                            context: context,
                            product: p,
                            canAdjust: canAdjust,
                            canOrder: canOrder,
                            ordersVm: ordersVm,
                            vm: vm,
                          ),
                        )
                        .toList(),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _filters(
    BuildContext context,
    List<String> groups,
    List<Product> filtered,
    OrdersViewModel? ordersVm,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search name or group',
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String?>(
                value: _groupFilter,
                hint: const Text('Group'),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('All')),
                  ...groups.map(
                    (g) => DropdownMenuItem<String?>(value: g, child: Text(g)),
                  ),
                ],
                onChanged: (v) => setState(() => _groupFilter = v),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Copy CSV',
                icon: const Icon(Icons.copy_all),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final csv = _buildCsv(filtered, ordersVm);
                  await Clipboard.setData(ClipboardData(text: csv));
                  if (!mounted) return;
                  messenger.showSnackBar(const SnackBar(content: Text('Warehouse list copied')));
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Wrap(
            spacing: 12,
            children: [
              FilterChip(
                label: const Text('Low stock'),
                selected: _lowOnly,
                onSelected: (v) => setState(() => _lowOnly = v),
              ),
              FilterChip(
                label: const Text('Has restock hint'),
                selected: _hintOnly,
                onSelected: (v) => setState(() => _hintOnly = v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip(BuildContext context, String text, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? Theme.of(context).colorScheme.surfaceContainerHighest)
            .withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
      ),
    );
  }

  Widget _groupTag(String group, {Color? color}) {
    final palette = Colors.primaries;
    final resolved = color ?? palette[group.hashCode.abs() % palette.length];
    return CircleAvatar(
      radius: 12,
      backgroundColor: resolved.withValues(alpha: 0.8),
      child: Text(
        group.isNotEmpty ? group[0].toUpperCase() : '?',
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  Map<String, List<Product>> _groupByGroup(List<Product> items) {
    final map = <String, List<Product>>{};
    for (final p in items) {
      final key = p.group.isNotEmpty ? p.group : 'Ungrouped';
      map.putIfAbsent(key, () => []).add(p);
    }
    return map;
  }

  _GroupStats _aggregateStatus(List<Product> products, OrdersViewModel? ordersVm) {
    int low = 0;
    int half = 0;
    int hint = 0;
    int ordered = 0;
    for (final p in products) {
      if (_isWarehouseLow(p)) low++;
      if (_isHalf(p)) half++;
      if ((p.restockHint ?? 0) > 0) hint++;
      ordered += _activeOrderQtyForProduct(ordersVm, p.id) > 0 ? 1 : 0;
    }
    return _GroupStats(lowCount: low, halfCount: half, hintCount: hint, orderCount: ordered);
  }

  Color _groupColor(List<Product> items) {
    final explicit = items.firstWhere(
      (p) => p.groupColor != null && p.groupColor!.isNotEmpty,
      orElse: () => items.first,
    );
    if (explicit.groupColor != null && explicit.groupColor!.isNotEmpty) {
      try {
        final hex = explicit.groupColor!;
        final cleaned = hex.startsWith('#') ? hex.substring(1) : hex;
        final value = int.parse(cleaned, radix: 16);
        return Color(value <= 0xFFFFFF ? 0xFF000000 | value : value);
      } catch (_) {
        // ignore parse errors
      }
    }
    final palette = Colors.primaries;
    return palette[explicit.group.hashCode.abs() % palette.length];
  }

  void _showRestockHintSheet(
    BuildContext context, {
    required Product product,
    required int current,
    required int max,
  }) {
    showModalBottomSheet(
      context: context,
      builder: (_) => RestockHintSheet(
        productId: product.id,
        currentQuantity: current,
        maxQuantity: max,
      ),
    );
  }

  void _showAdjustSheet(
    BuildContext context,
    String productId,
    int barQuantity,
    int warehouseQuantity,
    int barMax,
    int warehouseTarget,
    {int? unitVolumeMl, bool trackVolume = false, bool trackWarehouse = true}
  ) {
    showModalBottomSheet(
      context: context,
      builder: (_) => AdjustQuantitySheet(
        productId: productId,
        barQuantity: barQuantity,
        warehouseQuantity: warehouseQuantity,
        barMax: barMax,
        warehouseTarget: warehouseTarget,
        unitVolumeMl: trackVolume ? unitVolumeMl : null,
        trackVolume: trackVolume,
        trackWarehouse: trackWarehouse,
      ),
    );
  }

  void _openProductForm(BuildContext context, Product product) {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (_) => ProductFormSheet(product: product),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String productId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete product'),
        content: const Text('Are you sure you want to delete this product?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      await context.read<InventoryViewModel>().deleteProduct(productId);
      if (context.mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('Product deleted')));
      }
    }
  }

  void _openQuickOrder({
    required BuildContext context,
    required Product product,
  }) {
    final vm = context.read<OrdersViewModel?>();
    final app = context.read<AppController>();
    if (vm == null) return;
    final defaultQty = _suggestOrderQty(product);
    showAddToOrderSheet(
      context: context,
      app: app,
      ordersVm: vm,
      inventory: context.read<InventoryViewModel>().products,
      initialProduct: product,
      defaultQuantity: defaultQty,
    );
  }

  int _activeOrderQtyForProduct(OrdersViewModel? vm, String productId) {
    if (vm == null) return 0;
    return vm.orders
        .where((o) => o.status == OrderStatus.pending || o.status == OrderStatus.confirmed)
        .expand((o) => o.items)
        .where((i) => i.productId == productId)
        .fold<int>(0, (sum, item) => sum + item.quantityOrdered);
  }

  void _sortProducts(List<Product> items) {
    switch (_sortKey) {
      case 'group':
        items.sort((a, b) {
          final g = a.group.compareTo(b.group);
          return g != 0 ? g : a.name.compareTo(b.name);
        });
        break;
      case 'bar':
        items.sort((b, a) => a.barQuantity.compareTo(b.barQuantity));
        break;
      case 'wh':
        items.sort((b, a) => a.warehouseQuantity.compareTo(b.warehouseQuantity));
        break;
      case 'name':
      default:
        items.sort((a, b) => a.name.compareTo(b.name));
    }
  }

  _Low _lowStock(Product p) {
    final thresholdMl = p.minVolumeThresholdMl;
    final unitMl = p.unitVolumeMl ?? 0;
    final barValue = (p.trackVolume && unitMl > 0)
        ? (p.barVolumeMl ?? (p.barQuantity * unitMl))
        : p.barQuantity;
    final whValue = (p.trackVolume && unitMl > 0)
        ? (p.warehouseVolumeMl ?? (p.warehouseQuantity * unitMl))
        : p.warehouseQuantity;
    final threshold = p.trackVolume && thresholdMl != null && thresholdMl > 0
        ? thresholdMl
        : (p.minimalStockThreshold ?? 0);
    final barRatio = _fillRatioBar(p);
    final whRatio = _fillRatioWarehouse(p);
    return _Low(
      bar: threshold > 0
          ? barValue <= threshold
          : (barRatio != null && barRatio < 0.5),
      warehouse: p.trackWarehouse &&
          (threshold > 0
              ? whValue <= threshold
              : (whRatio != null && whRatio < 0.5)),
    );
  }

  int _suggestOrderQty(Product p) {
    final desired = (p.restockHint != null && p.restockHint! > 0) ? p.restockHint! : p.barMax;
    final missing = desired - p.barQuantity;
    return missing > 0 ? missing : 1;
  }

  bool _isHalf(Product p) {
    // In warehouse view, measure fill against warehouse target when tracked; fallback to bar.
    final ratio = _fillRatioWarehouse(p) ?? _fillRatioBar(p);
    if (ratio == null) return false;
    return ratio >= 0.5 && ratio < 0.7;
  }

  bool _isWarehouseLow(Product p) {
    final threshold = p.minimalStockThreshold ?? 0;
    final whRatio = _fillRatioWarehouse(p);
    final barRatio = _fillRatioBar(p);
    if (threshold > 0) {
      if (p.trackWarehouse) return p.warehouseQuantity <= threshold;
      return p.barQuantity <= threshold;
    }
    if (p.trackWarehouse) {
      return whRatio != null && whRatio < 0.5;
    }
    return barRatio != null && barRatio < 0.5;
  }

  double? _fillRatioBar(Product p) {
    final unitMl = p.unitVolumeMl ?? 0;
    if (p.trackVolume && unitMl > 0 && p.barMax > 0) {
      final maxMl = p.barMax * unitMl;
      final currentMl = p.barVolumeMl ?? (p.barQuantity * unitMl);
      return maxMl > 0 ? currentMl / maxMl : null;
    }
    if (p.barMax > 0) return p.barQuantity / p.barMax;
    return null;
  }

  double? _fillRatioWarehouse(Product p) {
    final unitMl = p.unitVolumeMl ?? 0;
    if (p.trackWarehouse && p.trackVolume && unitMl > 0 && p.warehouseTarget > 0) {
      final maxMl = p.warehouseTarget * unitMl;
      final currentMl = p.warehouseVolumeMl ?? (p.warehouseQuantity * unitMl);
      return maxMl > 0 ? currentMl / maxMl : null;
    }
    if (p.trackWarehouse && p.warehouseTarget > 0) {
      return p.warehouseQuantity / p.warehouseTarget;
    }
    return null;
  }

  String _buildCsv(List<Product> items, OrdersViewModel? ordersVm) {
    final buffer = StringBuffer('Name,Group,WHQty,WHTarget,BarQty,BarMax,Hint,InOrders\\n');
    for (final p in items) {
      final active = _activeOrderQtyForProduct(ordersVm, p.id);
      buffer.writeln(
          '${p.name},${p.group},${p.warehouseQuantity},${p.warehouseTarget},${p.barQuantity},${p.barMax},${p.restockHint ?? 0},$active');
    }
    return buffer.toString();
  }

  void _openGroupManager(BuildContext context) {
    final repo = context.read<GroupRepository?>();
    final perm = context.read<AppController>().currentPermissionSnapshot;
    final canManage = context.read<AppController>().permissions.canEditProducts(perm);
    showModalBottomSheet(
      context: context,
      builder: (_) => GroupManagementSheet(repository: repo, canManage: canManage),
    );
  }

  Future<void> _showMoveToGroupDialog(BuildContext context, InventoryViewModel vm) async {
    final nameCtrl = TextEditingController();
    final colorCtrl = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move to group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Group name')),
            TextField(controller: colorCtrl, decoration: const InputDecoration(labelText: 'Color hex (optional, e.g. #7B61FF)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apply')),
        ],
      ),
    );
    if (!mounted) return;
    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      await vm.moveItemsToGroup(
        itemIds: _selectedIds.toList(),
        groupName: nameCtrl.text.trim(),
        groupColor: colorCtrl.text.trim().isNotEmpty ? colorCtrl.text.trim() : null,
      );
      if (!mounted) return;
      setState(() => _selectedIds.clear());
      messenger.showSnackBar(const SnackBar(content: Text('Items moved to group')));
    }
  }

  Future<void> _clearGroupSelection(InventoryViewModel vm) async {
    if (_selectedIds.isEmpty) return;
    await vm.clearGroupForItems(_selectedIds.toList());
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _selectedIds.clear());
    messenger.showSnackBar(const SnackBar(content: Text('Items ungrouped')));
  }

  Widget _buildItemTile({
    required BuildContext context,
    required Product product,
    required bool canAdjust,
    required bool canOrder,
    required OrdersViewModel? ordersVm,
    required InventoryViewModel vm,
  }) {
    final isSelected = _selectedIds.contains(product.id);
    void toggleSelect() {
      setState(() {
        if (isSelected) {
          _selectedIds.remove(product.id);
        } else {
          _selectedIds.add(product.id);
        }
      });
    }
    final barMl = product.trackVolume && (product.unitVolumeMl ?? 0) > 0
        ? product.barQuantity * (product.unitVolumeMl ?? 0)
        : null;
    final whMl = product.trackVolume && (product.unitVolumeMl ?? 0) > 0
        ? product.warehouseQuantity * (product.unitVolumeMl ?? 0)
        : null;
    final low = _lowStock(product);
    final isHalf = _isHalf(product);
    final activeOrderQty = _activeOrderQtyForProduct(ordersVm, product.id);
    final statusBadges = <Widget>[
      if (low.warehouse)
        _chip(context, 'Low WH', color: Theme.of(context).colorScheme.error),
      if (low.bar)
        _chip(context, 'Low bar', color: Theme.of(context).colorScheme.error),
      if ((product.restockHint ?? 0) > 0)
        _chip(context, 'Hint ${product.restockHint}', color: Theme.of(context).colorScheme.tertiary),
      if (activeOrderQty > 0)
        _chip(context, 'Ordered $activeOrderQty',
            color: Theme.of(context).colorScheme.primary),
      if (!product.trackWarehouse)
        _chip(context, 'Bar only', color: Theme.of(context).colorScheme.outline),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Card(
        margin: EdgeInsets.zero,
        child: ExpansionTile(
          title: Row(
            children: [
              if (_inSelectMode)
                Checkbox(value: isSelected, onChanged: (_) => toggleSelect())
              else
                GestureDetector(
                  onLongPress: toggleSelect,
                  child: Icon(Icons.warehouse, color: Theme.of(context).colorScheme.primary),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(product.name, style: Theme.of(context).textTheme.titleMedium),
                        ),
                        if (low.bar || low.warehouse)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Icon(Icons.circle,
                                size: 10, color: Theme.of(context).colorScheme.error),
                          )
                        else if (isHalf)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Icon(Icons.circle, size: 10, color: Colors.amber),
                          ),
                      ],
                    ),
                    Text(
                      '${product.group}${product.subgroup != null ? " - ${product.subgroup}" : ""}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (!product.trackWarehouse)
                _chip(context, 'Bar only', color: Theme.of(context).colorScheme.outline),
            ],
          ),
          subtitle: statusBadges.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(spacing: 6, runSpacing: 4, children: statusBadges),
                )
              : null,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _quantityRow(
                    context,
                    label: 'Warehouse',
                    value: product.trackWarehouse
                        ? '${product.warehouseQuantity}/${product.warehouseTarget}'
                        : '—',
                    sub: product.trackWarehouse && whMl != null ? '$whMl ml' : null,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  _quantityRow(
                    context,
                    label: 'Bar',
                    value: '${product.barQuantity}/${product.barMax}',
                    sub: barMl != null ? '$barMl ml' : null,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  if (product.minimalStockThreshold != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Min stock: ${product.minimalStockThreshold}'),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (canOrder)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.shopping_cart_outlined, size: 16),
                          label: const Text('Order'),
                          onPressed: () => _openQuickOrder(context: context, product: product),
                        ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.lightbulb, size: 16),
                        label: const Text('Restock hint'),
                        onPressed: () => _showRestockHintSheet(
                          context,
                          product: product,
                          current: product.warehouseQuantity,
                          max: product.warehouseTarget,
                        ),
                      ),
                      if (canAdjust && product.trackWarehouse)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.swap_horiz, size: 16),
                          label: const Text('Transfer to bar'),
                          onPressed: () => _showTransferDialog(
                            context: context,
                            productId: product.id,
                            available: product.warehouseQuantity,
                          ),
                        ),
                      if (canAdjust)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.tune, size: 16),
                          label: const Text('Adjust'),
                          onPressed: () => _showAdjustSheet(
                            context,
                            product.id,
                            product.barQuantity,
                            product.warehouseQuantity,
                            product.barMax,
                            product.warehouseTarget,
                            unitVolumeMl: product.unitVolumeMl,
                            trackVolume: product.trackVolume,
                            trackWarehouse: product.trackWarehouse,
                          ),
                        ),
                      if (canAdjust)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Edit'),
                          onPressed: () => _openProductForm(context, product),
                        ),
                      if (canAdjust)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: const Text('Delete'),
                          onPressed: () => _confirmDelete(context, product.id),
                        ),
                      if (_inSelectMode)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.label),
                          label: const Text('Add to selection'),
                          onPressed: toggleSelect,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quantityRow(BuildContext context,
      {required String label, required String value, String? sub, required Color color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (sub != null) ...[
            const SizedBox(width: 6),
            Text(sub, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color)),
          ],
        ],
      ),
    );
  }

  Future<void> _showTransferDialog({
    required BuildContext context,
    required String productId,
    required int available,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final inventoryVm = context.read<InventoryViewModel>();
    final controller = TextEditingController(text: available > 0 ? '1' : '0');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Transfer to Bar'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Quantity (max $available)',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Transfer')),
        ],
      ),
    );
    if (!mounted) return;
    if (ok == true) {
      final qty = int.tryParse(controller.text) ?? 0;
      if (qty <= 0 || qty > available) {
        messenger.showSnackBar(const SnackBar(content: Text('Invalid quantity')));
        return;
      }
      await inventoryVm.transferToBar(productId: productId, quantity: qty);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Transferred to bar')));
    }
  }
}

class _Low {
  const _Low({required this.bar, required this.warehouse});
  final bool bar;
  final bool warehouse;
}

class _GroupStats {
  const _GroupStats({
    required this.lowCount,
    required this.halfCount,
    required this.hintCount,
    required this.orderCount,
  });
  final int lowCount;
  final int halfCount;
  final int hintCount;
  final int orderCount;
}

enum _ExportKind { csv, printable }
