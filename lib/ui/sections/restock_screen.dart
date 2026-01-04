import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../controllers/app_controller.dart';
import '../../models/order.dart';
import '../../models/product.dart';
import '../../viewmodels/inventory_view_model.dart';
import '../../viewmodels/orders_view_model.dart';
import '../widgets/restock_hint_sheet.dart';
import '../widgets/add_to_order_sheet.dart';

class RestockScreen extends StatefulWidget {
  const RestockScreen({super.key});

  @override
  State<RestockScreen> createState() => _RestockScreenState();
}

class _RestockScreenState extends State<RestockScreen> {
  final Set<String> _selected = {};
  @override
  Widget build(BuildContext context) {
    final inventoryVm = context.watch<InventoryViewModel>();
    final ordersVm = context.watch<OrdersViewModel?>();
    final app = context.watch<AppController>();
    final company = app.activeCompany;
    final perm = app.currentPermissionSnapshot;
    final canOrder = app.permissions.canCreateOrders(perm);
    final canTransfer = app.permissions.canTransferStock(perm);

    if (inventoryVm.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (inventoryVm.error != null) {
      return Center(child: Text('Error: ${inventoryVm.error}'));
    }
    // Show only items that are low or have an explicit restock hint set.
    final items = inventoryVm.products.where((p) {
      final threshold = p.minimalStockThreshold ?? 0;
      final lowBar = threshold > 0 ? p.barQuantity < threshold : p.barQuantity < p.barMax;
      final lowWh = threshold > 0
          ? p.warehouseQuantity < threshold
          : p.warehouseQuantity < p.warehouseTarget;
      final hasHint = (p.restockHint ?? 0) > 0;
      return lowBar || lowWh || hasHint;
    }).toList();

    if (items.isEmpty) {
      return const Center(child: Text('All good! No items flagged for restock.'));
    }

    return Column(
      children: [
        if (_selected.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Text('${_selected.length} selected'),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selected
                        ..clear()
                        ..addAll(items.map((p) => p.id));
                    });
                  },
                  child: const Text('Select all'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Copy CSV',
                  icon: const Icon(Icons.copy_all),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final vm = context.read<InventoryViewModel>();
                    final csv = await vm.exportCsv();
                    await Clipboard.setData(ClipboardData(text: csv));
                    if (!mounted) return;
                    messenger.showSnackBar(const SnackBar(content: Text('Restock list copied')));
                  },
                ),
                if (canTransfer)
                  TextButton(
                    onPressed: () => _bulkTransfer(items, inventoryVm),
                    child: const Text('Transfer to bar'),
                  ),
                TextButton(
                  onPressed: () => setState(() => _selected.clear()),
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final p = items[index];
              final selected = _selected.contains(p.id);
              final threshold = p.minimalStockThreshold ?? 0;
              final hint = p.restockHint ?? 0;
              final activeOrderQty = _activeOrderQtyForProduct(ordersVm, p.id);
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: selected,
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _selected.add(p.id);
                              } else {
                                _selected.remove(p.id);
                              }
                            }),
                          ),
                          Expanded(
                            child:
                                Text(p.name, style: Theme.of(context).textTheme.titleMedium),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('${p.group}${p.subgroup != null ? " - ${p.subgroup}" : ""}',
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _chip(context, 'Bar ${p.barQuantity}/${p.barMax}',
                              color: p.barQuantity < (threshold > 0 ? threshold : p.barMax)
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(context).colorScheme.primary),
                          _chip(context, 'Warehouse ${p.warehouseQuantity}/${p.warehouseTarget}',
                              color: p.warehouseQuantity <
                                      (threshold > 0 ? threshold : p.warehouseTarget)
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(context).colorScheme.secondary),
                          if (hint > 0)
                            _chip(context, 'Hint $hint',
                                color: Theme.of(context).colorScheme.tertiary),
                          if (activeOrderQty > 0)
                            _chip(context, '$activeOrderQty in orders',
                                color: Theme.of(context).colorScheme.primary),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.lightbulb_outline, size: 16),
                            label: const Text('Set restock hint'),
                            onPressed: () => _openHintSheet(
                              context,
                              product: p,
                              current: p.barQuantity,
                              max: p.barMax,
                            ),
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.clear, size: 16),
                            label: const Text('Clear hint'),
                            onPressed: () => inventoryVm.clearRestockHint(p.id),
                          ),
                          if (canOrder && company != null)
                            OutlinedButton.icon(
                              icon: const Icon(Icons.shopping_cart_outlined, size: 16),
                              label: const Text('Order'),
                              onPressed: () => _openQuickOrder(
                                context: context,
                                product: p,
                                ordersVm: ordersVm,
                                app: app,
                                existingQty: activeOrderQty,
                              ),
                            ),
                          if (canTransfer)
                            OutlinedButton.icon(
                              icon: const Icon(Icons.swap_horiz, size: 16),
                              label: const Text('Transfer now'),
                              onPressed: () => _promptTransfer(
                                product: p,
                                inventoryVm: inventoryVm,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _bulkTransfer(List<Product> items, InventoryViewModel vm) async {
    if (_selected.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final app = context.read<AppController>();
    final perm = app.currentPermissionSnapshot;
    if (!app.permissions.canTransferStock(perm)) {
      messenger.showSnackBar(const SnackBar(content: Text('You do not have permission to transfer')));
      return;
    }
    final selectedItems = items.where((p) => _selected.contains(p.id));
    for (final p in selectedItems) {
      final needed = (p.barMax - p.barQuantity).clamp(0, p.warehouseQuantity);
      if (needed > 0) {
        await vm.transferToBar(productId: p.id, quantity: needed);
      }
    }
    if (mounted) {
      setState(() => _selected.clear());
      messenger.showSnackBar(const SnackBar(content: Text('Transferred selected items to bar')));
    }
  }

  Future<void> _promptTransfer({
    required Product product,
    required InventoryViewModel inventoryVm,
  }) async {
    final app = context.read<AppController>();
    final perm = app.currentPermissionSnapshot;
    if (!app.permissions.canTransferStock(perm)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You do not have permission to transfer')),
      );
      return;
    }
    final maxTransfer = (product.barMax - product.barQuantity).clamp(0, product.warehouseQuantity);
    if (maxTransfer <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to transfer')),
      );
      return;
    }
    final controller = TextEditingController(text: maxTransfer.toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Transfer ${product.name}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'Quantity (max $maxTransfer)'),
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
      if (qty <= 0 || qty > maxTransfer) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid quantity')),
        );
        return;
      }
      await inventoryVm.transferToBar(productId: product.id, quantity: qty);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transferred $qty to bar')),
        );
      }
    }
  }

  void _openHintSheet(
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

  void _openQuickOrder({
    required BuildContext context,
    required Product product,
    required OrdersViewModel? ordersVm,
    required AppController app,
    required int existingQty,
  }) {
    final vm = ordersVm;
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

  int _suggestOrderQty(Product p) {
    final desired = (p.restockHint != null && p.restockHint! > 0) ? p.restockHint! : p.barMax;
    final missing = desired - p.barQuantity;
    return missing > 0 ? missing : 1;
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
}
