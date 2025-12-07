import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/inventory_view_model.dart';
import '../widgets/restock_hint_sheet.dart';
import '../widgets/product_form_sheet.dart';

/// Generic inventory list combining bar + warehouse view.
/// Shows restockHint as a badge (non-destructive suggestion).
class InventoryListScreen extends StatelessWidget {
  const InventoryListScreen({super.key});

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
        final hint = p.restockHint ?? 0;
        final badgeColor = _badgeColor(context, hint, p.barMax);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: badgeColor == null ? null : badgeColor.withValues(alpha: 0.08),
          child: ListTile(
            title: Text(p.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${p.group}${p.subgroup != null ? " • ${p.subgroup}" : ""}'),
                const SizedBox(height: 4),
                Text('Bar: ${p.barQuantity}/${p.barMax}'),
                Text('Warehouse: ${p.warehouseQuantity}/${p.warehouseTarget}'),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (hint > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeColor?.withValues(alpha: 0.2) ??
                              Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('⚠️'),
                            const SizedBox(width: 4),
                            Text('Hint: $hint'),
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
                      onPressed: () => _openHintSheet(context, p.id, hint),
                      child: const Text('Set restock hint'),
                    ),
                    if (isOwner)
                      TextButton(
                        onPressed: () => _openEditSheet(context, p),
                        child: const Text('Edit'),
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
            onTap: () => _openHintSheet(context, p.id, hint),
          ),
        );
      },
    );
  }

  void _openHintSheet(BuildContext context, String productId, int current) {
    showModalBottomSheet(
      context: context,
      builder: (_) => RestockHintSheet(productId: productId, initialValue: current),
    );
  }

  void _openEditSheet(BuildContext context, product) {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (_) => ProductFormSheet(product: product),
    );
  }

  Color? _badgeColor(BuildContext context, int hint, int target) {
    if (hint <= 0) return null;
    final ratio = target > 0 ? hint / target : 0;
    if (ratio >= 0.66) return Colors.red;
    if (ratio >= 0.33) return Colors.orange;
    return Theme.of(context).colorScheme.primary;
  }
}
