import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/app_controller.dart';
import '../../viewmodels/inventory_view_model.dart';
import '../widgets/adjust_quantity_sheet.dart';
import '../widgets/restock_hint_sheet.dart';

class WarehouseScreen extends StatelessWidget {
  const WarehouseScreen({super.key});

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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: vm.products.length,
      itemBuilder: (context, index) {
        final p = vm.products[index];
        final hintValue = p.restockHint ?? 0;
        final statusColor = _statusColor(hintValue, p.warehouseTarget);
        final isOwner = context.read<AppController>().isOwner;
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
                Text('Bar: ${p.barQuantity}/${p.barMax}'),
                Text('Warehouse: ${p.warehouseQuantity}/${p.warehouseTarget}'),
                const SizedBox(height: 4),
                Row(
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
                              onPressed: () =>
                                  context.read<InventoryViewModel>().clearRestockHint(p.id),
                            ),
                          ],
                        ),
                      ),
                    const Spacer(),
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

  Color? _statusColor(int hint, int target) {
    if (hint <= 0) return null;
    final ratio = target > 0 ? hint / target : 0;
    if (ratio >= 0.66) return Colors.red;
    if (ratio >= 0.33) return Colors.orange;
    return Colors.green;
  }
}
