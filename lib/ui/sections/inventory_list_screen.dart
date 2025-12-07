import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/inventory_view_model.dart';
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
              final lowPrimary = p.barQuantity < p.barMax;
              final lowSecondary = p.warehouseQuantity < p.warehouseTarget;
              return ProductListItem(
                title: p.name,
                groupText: '${p.group}${p.subgroup != null ? " • ${p.subgroup}" : ""}',
                primaryLabel: 'Bar',
                primaryValue: '${p.barQuantity}/${p.barMax}',
                secondaryLabel: 'Warehouse',
                secondaryValue: '${p.warehouseQuantity}/${p.warehouseTarget}',
                primaryBadgeColor: Theme.of(context).colorScheme.primary,
                hintValue: hint,
                hintStatusColor: badgeColor,
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
                onEdit: isOwner ? () => _openEditSheet(context, p) : null,
                showStaffReadOnly: !isOwner,
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

  Color? _badgeColor(BuildContext context, int hint, int target) {
    if (hint <= 0) return null;
    final ratio = target > 0 ? hint / target : 0;
    if (ratio >= 0.66) return Colors.red;
    if (ratio >= 0.33) return Colors.orange;
    return Theme.of(context).colorScheme.primary;
  }

}
