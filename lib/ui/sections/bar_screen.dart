import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../viewmodels/inventory_view_model.dart';
import '../widgets/adjust_quantity_sheet.dart';
import '../widgets/restock_hint_sheet.dart';
import '../widgets/product_form_sheet.dart';

class BarScreen extends StatelessWidget {
  const BarScreen({super.key});

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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: vm.products.length,
      itemBuilder: (context, index) {
        final p = vm.products[index];
        final hintValue = p.restockHint ?? 0;
        final statusColor = _statusColor(hintValue, p.barMax);
        final low = _lowStock(p);
        return Card(
          color: statusColor?.withValues(alpha: 0.08),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(p.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${p.group}${p.subgroup != null ? " • ${p.subgroup}" : ""}'),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('Bar: ${p.barQuantity}/${p.barMax}'),
                    if (low.bar)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: _badge(context, 'Low bar stock', Colors.red),
                      ),
                  ],
                ),
                Row(
                  children: [
                    Text('Warehouse: ${p.warehouseQuantity}/${p.warehouseTarget}'),
                    if (low.warehouse)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: _badge(context, 'Low WH stock', Colors.orange),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (hintValue > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor?.withValues(alpha: 0.2) ??
                              Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('⚠️'),
                            const SizedBox(width: 4),
                            Text('Hint: $hintValue'),
                            IconButton(
                              iconSize: 18,
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.clear, size: 16),
                              tooltip: 'Clear hint',
                              onPressed: () => vm.clearRestockHint(p.id),
                            ),
                          ],
                        ),
                      ),
                    TextButton(
                      onPressed: () => _showRestockHintSheet(context, p.id, hintValue),
                      child: const Text('Set restock hint'),
                    ),
                    if (isOwner)
                      TextButton(
                        onPressed: () =>
                            _showAdjustSheet(context, p.id, p.barQuantity, p.warehouseQuantity),
                        child: const Text('Adjust qty'),
                      ),
                    if (isOwner)
                      TextButton(
                        onPressed: () => _openProductForm(context, p),
                        child: const Text('Edit'),
                      ),
                    if (isOwner)
                      IconButton(
                        tooltip: 'Delete',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmDelete(context, p.id),
                      ),
                  ],
                ),
                if (!isOwner)
                  Text(
                    'Staff: read-only quantities',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            onTap: () => _showRestockHintSheet(context, p.id, hintValue),
          ),
        );
      },
    );
  }

  void _showRestockHintSheet(BuildContext context, String productId, int current) {
    showModalBottomSheet(
      context: context,
      builder: (_) => RestockHintSheet(productId: productId, initialValue: current),
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

  Widget _badge(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11),
      ),
    );
  }
}

class _Low {
  const _Low({required this.bar, required this.warehouse});
  final bool bar;
  final bool warehouse;
}
