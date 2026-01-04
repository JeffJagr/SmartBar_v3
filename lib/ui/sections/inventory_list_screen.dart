import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import '../../controllers/app_controller.dart';
import '../../models/order.dart';
import '../../models/product.dart';
import '../../ui/widgets/add_to_order_sheet.dart';
import '../../viewmodels/inventory_view_model.dart';
import '../../viewmodels/orders_view_model.dart';
import '../widgets/restock_hint_sheet.dart';
import '../widgets/product_form_sheet.dart';
import '../widgets/product_list_item.dart';

/// Combined inventory view with search/filters to handle large lists.
class InventoryListScreen extends StatefulWidget {
  const InventoryListScreen({super.key});

  @override
  State<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends State<InventoryListScreen> {
  String _search = '';
  String? _groupFilter;
  bool _lowOnly = false;
  bool _hintOnly = false;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<InventoryViewModel>();
    final ordersVm = context.watch<OrdersViewModel?>();
    final app = context.watch<AppController>();

    if (vm.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.error != null) {
      return Center(child: Text('Error: ${vm.error}'));
    }
    if (vm.products.isEmpty) {
      return const Center(child: Text('No products yet.'));
    }

    final perm = app.currentPermissionSnapshot;
    final canOrder = app.permissions.canCreateOrders(perm);
    final canManageProducts = app.permissions.canEditProducts(perm);
    final canAdjust = vm.canEditQuantities;
    final company = app.activeCompany;
    final groups = vm.products.map((p) => p.group).toSet().toList()..sort();
    final filtered = vm.products.where((p) {
      final matchesSearch = _search.isEmpty ||
          p.name.toLowerCase().contains(_search.toLowerCase()) ||
          p.group.toLowerCase().contains(_search.toLowerCase());
      final matchesGroup = _groupFilter == null || p.group == _groupFilter;
      final matchesLow =
          !_lowOnly || p.barQuantity < p.barMax || p.warehouseQuantity < p.warehouseTarget;
      final matchesHint = !_hintOnly || (p.restockHint ?? 0) > 0;
      return matchesSearch && matchesGroup && matchesLow && matchesHint;
    }).toList();

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
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All'),
                  ),
                  ...groups.map(
                    (g) => DropdownMenuItem<String?>(
                      value: g,
                      child: Text(g),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _groupFilter = v),
              ),
              const SizedBox(width: 8),
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
                          ? 'Inventory CSV copied'
                          : 'Printable inventory copied'),
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
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final p = filtered[index];
              final hint = p.restockHint ?? 0;
              final badgeColor = _badgeColor(context, hint, p.barMax);
              final threshold = p.minimalStockThreshold ?? 0;
              final lowPrimary =
                  threshold > 0 ? p.barQuantity <= threshold : p.barQuantity < p.barMax;
              final lowSecondary =
                  threshold > 0 ? p.warehouseQuantity <= threshold : p.warehouseQuantity < p.warehouseTarget;
              final activeOrderQty = _activeOrderQtyForProduct(ordersVm, p.id);
              final barMl = p.trackVolume && (p.unitVolumeMl ?? 0) > 0
                  ? (p.barVolumeMl ?? (p.barQuantity * (p.unitVolumeMl ?? 0)))
                  : null;
              final whMl = p.trackVolume && (p.unitVolumeMl ?? 0) > 0
                  ? (p.warehouseVolumeMl ?? (p.warehouseQuantity * (p.unitVolumeMl ?? 0)))
                  : null;
              return ProductListItem(
                title: p.name,
                groupText: '${p.group}${p.subgroup != null ? " - ${p.subgroup}" : ""}',
                groupColor: _parseColor(p.groupColor),
                primaryLabel: 'Bar',
                primaryValue: '${p.barQuantity}/${p.barMax}',
                primarySubValue: barMl != null ? '$barMl ml' : null,
                secondaryLabel: p.trackWarehouse ? 'Warehouse' : 'Bar only',
                secondaryValue:
                    p.trackWarehouse ? '${p.warehouseQuantity}/${p.warehouseTarget}' : '—',
                secondarySubValue: p.trackWarehouse && whMl != null ? '$whMl ml' : null,
                trackWarehouse: p.trackWarehouse,
                showBarOnlyBadge: !p.trackWarehouse,
                primaryBadgeColor: Theme.of(context).colorScheme.primary,
                hintValue: hint,
                hintStatusColor: badgeColor,
                activeOrderQty: activeOrderQty,
                lowPrimary: lowPrimary,
                lowSecondary: lowSecondary,
                lowPrimaryLabel: 'Low bar stock',
                lowSecondaryLabel: 'Low WH stock',
                onClearHint: () => vm.clearRestockHint(p.id),
                onSetHint: () => _openHintSheet(
                  context,
                  product: p,
                  current: p.barQuantity,
                  max: p.barMax,
                ),
                onEdit: canManageProducts ? () => _openEditSheet(context, p) : null,
                onDelete: canManageProducts
                    ? () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete product'),
                            content:
                                const Text('Are you sure you want to delete this product?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true && context.mounted) {
                          await context.read<InventoryViewModel>().deleteProduct(p.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Product deleted')),
                            );
                          }
                      }
                    }
                    : null,
                onReorder: ordersVm != null && company != null && canOrder
                    ? () => _openQuickOrder(
                          context: context,
                          product: p,
                          ordersVm: ordersVm,
                          app: app,
                          existingQty: activeOrderQty,
                        )
                    : null,
                showStaffReadOnly: !canAdjust,
              );
            },
          ),
        ),
      ],
    );
  }

  void _openHintSheet(
    BuildContext context, {
    required product,
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

  void _openEditSheet(BuildContext context, product) {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (_) => ProductFormSheet(product: product),
    );
  }

  void _openQuickOrder({
    required BuildContext context,
    required Product product,
    required OrdersViewModel ordersVm,
    required AppController app,
    required int existingQty,
  }) {
    final defaultQty = _suggestOrderQty(product);
    showAddToOrderSheet(
      context: context,
      app: app,
      ordersVm: ordersVm,
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

  int _suggestOrderQty(Product p) {
    final desired = (p.restockHint != null && p.restockHint! > 0) ? p.restockHint! : p.barMax;
    final missing = desired - p.barQuantity;
    return missing > 0 ? missing : 1;
  }

  Color? _badgeColor(BuildContext context, int hint, int target) {
    if (hint <= 0) return null;
    final ratio = target > 0 ? hint / target : 0;
    if (ratio >= 0.66) return Colors.red;
    if (ratio >= 0.33) return Colors.orange;
    return Theme.of(context).colorScheme.primary;
  }

  String _buildPrintable(List products) {
    final buffer = StringBuffer();
    buffer.writeln('INVENTORY SNAPSHOT');
    buffer.writeln('========================');
    for (final p in products) {
      buffer.writeln(
          '${p.name} | ${p.group}${p.subgroup != null ? " / ${p.subgroup}" : ""}');
      buffer.writeln(
          '  Bar: ${p.barQuantity}/${p.barMax}   Warehouse: ${p.warehouseQuantity}/${p.warehouseTarget}');
      if ((p.restockHint ?? 0) > 0) buffer.writeln('  Hint: ${p.restockHint}');
      buffer.writeln('------------------------');
    }
    return buffer.toString();
  }

  Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    try {
      final cleaned = hex.startsWith('#') ? hex.substring(1) : hex;
      final value = int.parse(cleaned, radix: 16);
      return Color(value <= 0xFFFFFF ? 0xFF000000 | value : value);
    } catch (_) {
      return null;
    }
  }
}

enum _ExportKind { csv, printable }
