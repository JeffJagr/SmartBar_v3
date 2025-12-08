import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../viewmodels/inventory_view_model.dart';
import '../widgets/adjust_quantity_sheet.dart';
import '../widgets/restock_hint_sheet.dart';
import '../widgets/product_form_sheet.dart';
import '../widgets/product_list_item.dart';

class BarScreen extends StatefulWidget {
  const BarScreen({super.key});

  @override
  State<BarScreen> createState() => _BarScreenState();
}

class _BarScreenState extends State<BarScreen> {
  String _search = '';
  String? _groupFilter;
  bool _lowOnly = false;
  bool _hintOnly = false;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<InventoryViewModel>();

    if (vm.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (vm.error != null) {
      return Center(child: Text('Error: ${vm.error}'));
    }

    if (vm.products.isEmpty) {
      return const Center(child: Text('No products yet.'));
    }

    final isOwner = vm.canEditQuantities;
    final groups = vm.products.map((p) => p.group).toSet().toList()..sort();
    final filtered = vm.products.where((p) {
      final matchesSearch = _search.isEmpty ||
          p.name.toLowerCase().contains(_search.toLowerCase()) ||
          p.group.toLowerCase().contains(_search.toLowerCase());
      final matchesGroup = _groupFilter == null || p.group == _groupFilter;
      final low = _lowStock(p);
      final matchesLow = !_lowOnly || low.bar || low.warehouse;
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
              final hintValue = p.restockHint ?? 0;
              final statusColor = _statusColor(hintValue, p.barMax);
              final low = _lowStock(p);
              final threshold = p.minimalStockThreshold ?? 0;
              final lowBar = threshold > 0 ? p.barQuantity <= threshold : low.bar;
              return ProductListItem(
                title: p.name,
                groupText: '${p.group}${p.subgroup != null ? " • ${p.subgroup}" : ""}',
                primaryLabel: 'Bar',
                primaryValue: '${p.barQuantity}/${p.barMax}',
                secondaryLabel: 'Warehouse',
                secondaryValue: '${p.warehouseQuantity}/${p.warehouseTarget}',
                primaryBadgeColor: Theme.of(context).colorScheme.primary,
                hintValue: hintValue,
                hintStatusColor: statusColor,
                lowPrimary: lowBar,
                lowSecondary: low.warehouse,
                lowPrimaryLabel: 'Low bar stock',
                lowSecondaryLabel: 'Low WH stock',
                onClearHint: () => vm.clearRestockHint(p.id),
                onSetHint: () => _showRestockHintSheet(
                  context,
                  product: p,
                  current: p.barQuantity,
                  max: p.barMax,
                ),
                onAdjust: isOwner
                    ? () => _showAdjustSheet(context, p.id, p.barQuantity, p.warehouseQuantity)
                    : null,
                onEdit: isOwner ? () => _openProductForm(context, p) : null,
                onDelete: isOwner ? () => _confirmDelete(context, p.id) : null,
                onReorder: isOwner
                    ? () => _openQuickOrder(
                          context: context,
                          product: p,
                        )
                    : null,
                showStaffReadOnly: !isOwner,
              );
            },
          ),
        ),
      ],
    );
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
  ) {
    showModalBottomSheet(
      context: context,
      builder: (_) => AdjustQuantitySheet(
        productId: productId,
        barQuantity: barQuantity,
        warehouseQuantity: warehouseQuantity,
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
      await context.read<InventoryViewModel>().deleteProduct(productId);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Product deleted')));
  }

  void _openQuickOrder({
    required BuildContext context,
    required Product product,
  }) {
    final qtyCtrl = TextEditingController();
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (ctx) {
        final vm = ctx.read<OrdersViewModel?>();
        final app = ctx.read<AppController>();
        final company = app.activeCompany;
        if (vm == null || company == null) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Orders unavailable (no company active).'),
          );
        }
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Order ${product.name}', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final qty = int.tryParse(qtyCtrl.text) ?? 0;
                    if (qty <= 0) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Enter a quantity')),
                      );
                      return;
                    }
                    await vm.createOrder(
                      companyId: company.id,
                      createdByUserId: app.ownerUser?.uid ?? app.currentStaff?.id ?? 'anon',
                      items: [
                        OrderItem(
                          productId: product.id,
                          productNameSnapshot: product.name,
                          quantityOrdered: qty,
                          unitCost: null,
                        )
                      ],
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Order placed for ${product.name} ($qty)')),
                      );
                    }
                  },
                  child: const Text('Place order'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
  }

  Color? _statusColor(int hint, int max) {
    if (hint <= 0) return null;
    final ratio = max > 0 ? hint / max : 0;
    if (ratio >= 0.66) return Colors.red;
    if (ratio >= 0.33) return Colors.orange;
    return Colors.green;
  }

  _Low _lowStock(Product p) {
    final threshold = p.minimalStockThreshold ?? 0;
    return _Low(
      bar: threshold > 0 && p.barQuantity < threshold,
      warehouse: threshold > 0 && p.warehouseQuantity < threshold,
    );
  }

}

class _Low {
  const _Low({required this.bar, required this.warehouse});
  final bool bar;
  final bool warehouse;
}
