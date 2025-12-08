import 'package:flutter/material.dart';

import '../../models/layout.dart';
import '../../models/product.dart';

/// Visual grid for the layout. UI-only; actions are routed via callbacks.
class LayoutGridPanel extends StatelessWidget {
  const LayoutGridPanel({
    super.key,
    required this.title,
    required this.products,
    this.layout,
    this.onCellTap,
    this.onCellAction,
    this.selectedProductId,
  });

  final String title;
  final List<Product> products;
  final Layout? layout;
  final void Function(LayoutCell cell)? onCellTap;
  final void Function(LayoutCell cell, String action)? onCellAction;
  final String? selectedProductId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final layoutCells = layout?.cells ?? [];
    final tiles = layoutCells.isNotEmpty ? layoutCells : [];
    final sampleProducts = products.take(tiles.isEmpty ? 15 : 0).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            title,
            style: theme.textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(8),
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 2.5,
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: layout?.columns ?? 3,
                  childAspectRatio: 1,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: tiles.isNotEmpty ? tiles.length : sampleProducts.length,
                itemBuilder: (context, index) {
                  if (tiles.isNotEmpty) {
                    final cell = tiles[index];
                    return _gridTileCell(context, cell);
                  } else {
                    final p = sampleProducts[index];
                    final slot = index + 1;
                    return _gridTileProduct(context, slot, p);
                  }
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _gridTileProduct(BuildContext context, int slot, Product product) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Slot $slot',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
          const Spacer(),
          Text(
            '${product.group}${product.subgroup != null ? " · ${product.subgroup}" : ""}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gridTileCell(BuildContext context, LayoutCell cell) {
    final theme = Theme.of(context);
    final zone = layout?.zones.firstWhere(
      (z) => z.id == cell.zoneId,
      orElse: () => const LayoutZone(id: '', name: ''),
    );
    final zoneLabel = zone.id.isNotEmpty ? zone.name : null;
    final containsSelected = selectedProductId != null &&
        cell.items.any((i) => i.productId == selectedProductId);

    return GestureDetector(
      onTap: onCellTap != null ? () => onCellTap!(cell) : null,
      onLongPress: onCellAction != null ? () => _showCellMenu(context, cell) : null,
      child: Container(
        decoration: BoxDecoration(
          color: zoneLabel != null
              ? theme.colorScheme.secondaryContainer.withOpacity(0.35)
              : theme.colorScheme.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: containsSelected
                ? theme.colorScheme.error
                : theme.colorScheme.primary.withOpacity(0.3),
            width: containsSelected ? 2 : 1,
          ),
          boxShadow: [
            if (containsSelected)
              BoxShadow(
                color: theme.colorScheme.error.withOpacity(0.35),
                blurRadius: 8,
                spreadRadius: 1,
              ),
          ],
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              cell.name?.isNotEmpty == true ? cell.name! : 'Cell ${cell.id.substring(0, 4)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (zoneLabel != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  zoneLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ),
            const Spacer(),
            Text(
              'r${cell.row + 1} • c${cell.column + 1}${cell.level != null ? " • L${cell.level}" : ""}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCellMenu(BuildContext context, LayoutCell cell) async {
    final actions = <String, String>{
      'rename': 'Rename',
      'delete': 'Delete',
      'setType': 'Change type',
      'setLevel': 'Change level',
      'assignItems': 'Assign items',
      'viewItems': 'View items',
      'clear': 'Clear',
      'group': 'Group/Zone',
      'capacity': 'Set capacity',
      'reserve': 'Mark reserved',
    };
    final selected = await showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(100, 100, 100, 100),
      items: actions.entries
          .map((e) => PopupMenuItem<String>(value: e.key, child: Text(e.value)))
          .toList(),
    );
    if (selected != null && onCellAction != null) {
      onCellAction!(cell, selected);
    }
  }
}
