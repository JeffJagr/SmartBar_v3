import 'package:flutter/material.dart';

import '../../models/layout.dart';
import '../../models/product.dart';

/// Visual grid for bar/warehouse layout. Pure UI; actions are routed via callbacks.
class LayoutGridPanel extends StatelessWidget {
  const LayoutGridPanel({
    super.key,
    required this.title,
    required this.products,
    this.layout,
    this.onCellTap,
    this.onCellAction,
    this.selectedProductId,
    this.selectedCellId,
    this.readOnly = false,
    this.showMiniMap = false,
    this.onToggleMiniMap,
    this.onProductDropped,
    this.onCellPreview,
  });

  final String title;
  final List<Product> products;
  final Layout? layout;
  final void Function(LayoutCell cell)? onCellTap;
  final void Function(LayoutCell cell, String action)? onCellAction;
  final String? selectedProductId;
  final String? selectedCellId;
  final bool readOnly;
  final bool showMiniMap;
  final VoidCallback? onToggleMiniMap;
  final void Function(LayoutCell cell, String productId)? onProductDropped;
  final void Function(LayoutCell cell)? onCellPreview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final layoutCells = layout?.cells ?? [];
    final tiles = layoutCells.isNotEmpty ? layoutCells : <LayoutCell>[];
    final sampleProducts = products.take(tiles.isEmpty ? 15 : 0).toList();
    final productMap = {for (final p in products) p.id: p};

    final Map<String, _ZoneStatus> zoneStatus = {};
    for (final cell in tiles) {
      if (cell.zoneId == null) continue;
      final status = zoneStatus[cell.zoneId!] ?? _ZoneStatus();
      if (cell.items.isNotEmpty) status.hasItems = true;
      for (final it in cell.items) {
        final prod = productMap[it.productId];
        if (prod == null) continue;
        final threshold = prod.minimalStockThreshold ?? 0;
        final low = threshold > 0 &&
            (prod.barQuantity <= threshold || prod.warehouseQuantity <= threshold);
        if (low) status.hasLow = true;
        if ((prod.restockHint ?? 0) > 0) status.hasHint = true;
      }
      zoneStatus[cell.zoneId!] = status;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(title, style: theme.textTheme.titleMedium),
              ),
              if (onToggleMiniMap != null)
                IconButton(
                  tooltip: showMiniMap ? 'Hide mini map' : 'Show mini map',
                  icon: Icon(showMiniMap ? Icons.map_outlined : Icons.map),
                  onPressed: onToggleMiniMap,
                ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(8),
            child: Stack(
              children: [
                InteractiveViewer(
                  minScale: 0.6,
                  maxScale: 3.0,
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
                        return _gridTileCell(context, cell, productMap, zoneStatus);
                      } else {
                        final p = sampleProducts[index];
                        final slot = index + 1;
                        return _gridTileProduct(context, slot, p);
                      }
                    },
                  ),
                ),
                if (showMiniMap && tiles.isNotEmpty)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Opacity(
                      opacity: 0.9,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.shadow.withValues(alpha: 0.2),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        width: 120,
                        height: 120,
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: layout?.columns ?? 3,
                            crossAxisSpacing: 2,
                            mainAxisSpacing: 2,
                          ),
                          itemCount: tiles.length,
                          itemBuilder: (context, index) {
                            final cell = tiles[index];
                            final containsSelected = selectedProductId != null &&
                                cell.items.any((i) => i.productId == selectedProductId);
                            final isSelectedCell =
                                selectedCellId != null && selectedCellId == cell.id;
                            return Container(
                              decoration: BoxDecoration(
                                color: containsSelected
                                    ? theme.colorScheme.error.withValues(alpha: 0.6)
                                    : theme.colorScheme.primary.withValues(alpha: 0.2),
                                border: Border.all(
                                  color: isSelectedCell
                                      ? theme.colorScheme.secondary
                                      : theme.colorScheme.outline.withValues(alpha: 0.5),
                                  width: isSelectedCell ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
              ],
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
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
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
            '${product.group}${product.subgroup != null ? " - ${product.subgroup}" : ""}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gridTileCell(
    BuildContext context,
    LayoutCell cell,
    Map<String, Product> productMap,
    Map<String, _ZoneStatus> zoneStatus,
  ) {
    final theme = Theme.of(context);
    final zone = layout?.zones.firstWhere(
          (z) => z.id == cell.zoneId,
          orElse: () => const LayoutZone(id: '', name: ''),
        ) ??
        const LayoutZone(id: '', name: '');
    final zoneLabel = zone.id.isNotEmpty ? zone.name : null;
    final zoneColor = zone.color != null ? _parseColor(zone.color!, theme) : null;
    final containsSelected = selectedProductId != null &&
        cell.items.any((i) => i.productId == selectedProductId);
    final isSelectedCell = selectedCellId != null && selectedCellId == cell.id;

    bool hasLow = false;
    bool hasHint = false;
    bool hasItems = cell.items.isNotEmpty;
    for (final it in cell.items) {
      final prod = productMap[it.productId];
      if (prod == null) continue;
      final threshold = prod.minimalStockThreshold ?? 0;
      final low = threshold > 0 &&
          (prod.barQuantity <= threshold || prod.warehouseQuantity <= threshold);
      if (low) hasLow = true;
      if ((prod.restockHint ?? 0) > 0) hasHint = true;
    }
    final zoneStat = cell.zoneId != null ? zoneStatus[cell.zoneId!] : null;
    final zoneHasLow = zoneStat?.hasLow ?? false;
    final zoneHasHint = zoneStat?.hasHint ?? false;
    final zoneHasItems = zoneStat?.hasItems ?? false;

    final cellContent = GestureDetector(
      onTap: onCellTap != null ? () => onCellTap!(cell) : null,
      onLongPress:
          (!readOnly && onCellAction != null) ? () => _showCellMenu(context, cell) : null,
      onDoubleTap: onCellPreview != null ? () => onCellPreview!(cell) : null,
      child: Container(
        decoration: BoxDecoration(
          color: zoneColor ??
              (zoneLabel != null
                  ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.35)
                  : theme.colorScheme.primary.withValues(alpha: hasItems ? 0.12 : 0.08)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelectedCell
                ? theme.colorScheme.secondary
                : containsSelected
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary.withValues(alpha: 0.3),
            width: (containsSelected || isSelectedCell) ? 2 : 1,
          ),
          boxShadow: [
            if (containsSelected || isSelectedCell)
              BoxShadow(
                color: (containsSelected
                        ? theme.colorScheme.error
                        : theme.colorScheme.secondary)
                    .withValues(alpha: 0.3),
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
                child: Row(
                  children: [
                    _zoneIconWidget(zone.type, theme, zoneColor),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        zoneLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                    ),
                    if (zoneHasLow)
                      Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Icon(Icons.report_problem, size: 14, color: theme.colorScheme.error),
                      ),
                    if (zoneHasHint)
                      Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Icon(Icons.lightbulb, size: 14, color: theme.colorScheme.tertiary),
                      ),
                    if (zoneHasItems)
                      Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Icon(Icons.inventory_2, size: 14, color: theme.colorScheme.primary),
                      ),
                  ],
                ),
              ),
            const Spacer(),
            Row(
              children: [
                Text(
                  'r${cell.row + 1} • c${cell.column + 1}${cell.level != null ? " • L${cell.level}" : ""}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const Spacer(),
                if (hasLow)
                  Icon(Icons.report_problem, size: 16, color: theme.colorScheme.error),
                if (hasHint)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(Icons.lightbulb, size: 16, color: theme.colorScheme.tertiary),
                  ),
                if (hasItems)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(Icons.inventory_2, size: 16, color: theme.colorScheme.primary),
                  ),
              ],
            ),
            if (layout?.updatedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Updated ${layout!.updatedAt}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (onProductDropped == null || readOnly) {
      return cellContent;
    }

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data.isNotEmpty,
      onAcceptWithDetails: (details) => onProductDropped!(cell, details.data),
      builder: (context, candidateData, rejectedData) {
        return Container(
          decoration: candidateData.isNotEmpty
              ? BoxDecoration(
                  border: Border.all(color: theme.colorScheme.secondary, width: 2),
                  borderRadius: BorderRadius.circular(10),
                )
              : null,
          child: cellContent,
        );
      },
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
      'editZone': 'Edit zone (name/color/type)',
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

  Widget _zoneIconWidget(String? type, ThemeData theme, Color? zoneColor) {
    return Icon(_zoneIcon(type), size: 16, color: zoneColor ?? theme.colorScheme.secondary);
  }

  IconData _zoneIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'fridge':
        return Icons.ac_unit;
      case 'sink':
        return Icons.water_drop;
      case 'cash':
      case 'desk':
        return Icons.point_of_sale;
      case 'prep':
      case 'kitchen':
        return Icons.flatware;
      default:
        return Icons.grid_view;
    }
  }

  Color? _parseColor(String hex, ThemeData theme) {
    try {
      final cleaned = hex.startsWith('#') ? hex.substring(1) : hex;
      final value = int.parse(cleaned, radix: 16);
      if (value <= 0xFFFFFF) {
        return Color(0xFF000000 | value).withValues(alpha: 0.4);
      }
      return Color(value).withValues(alpha: 0.4);
    } catch (_) {
      return theme.colorScheme.secondaryContainer.withValues(alpha: 0.35);
    }
  }
}

class _ZoneStatus {
  bool hasLow = false;
  bool hasHint = false;
  bool hasItems = false;
}
