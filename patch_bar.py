# -*- coding: utf-8 -*-
from pathlib import Path
path = Path('lib/ui/sections/bar_screen.dart')
text = path.read_text()
old = """            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final p = filtered[index];
                  final activeOrderQty = _activeOrderQtyForProduct(ordersVm, p.id);
                  final hintValue = p.restockHint ?? 0;
                  final statusColor = _statusColor(hintValue, p.barMax);
                  final low = _lowStock(p);
                  final threshold = p.minimalStockThreshold ?? 0;
                  final lowBar = threshold > 0 ? p.barQuantity <= threshold : low.bar;
                  final highlight = _selectedCellId != null &&
                      false; // TODO: map cell->items to highlight actual placements.
                  return ProductListItem(
                    title: p.name,
                    groupText: '${p.group}${p.subgroup != null ? " ?? ${p.subgroup}" : ""}',
                    primaryLabel: 'Bar',
                    primaryValue: '${p.barQuantity}/${p.barMax}',
                    secondaryLabel: 'Warehouse',
                    secondaryValue: '${p.warehouseQuantity}/${p.warehouseTarget}',
                    primaryBadgeColor: Theme.of(context).colorScheme.primary,
                    hintValue: hintValue,
                    hintStatusColor: statusColor,
                    activeOrderQty: activeOrderQty > 0 ? activeOrderQty : null,
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
                    onReorder: canOrder
                        ? () => _openQuickOrder(
                              context: context,
                              product: p,
                            )
                        : null,
                    showStaffReadOnly: !isOwner,
                  );
                },
              ),
            ),"""
new = """            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final p = filtered[index];
                  final activeOrderQty = _activeOrderQtyForProduct(ordersVm, p.id);
                  final hintValue = p.restockHint ?? 0;
                  final statusColor = _statusColor(hintValue, p.barMax);
                  final low = _lowStock(p);
                  final threshold = p.minimalStockThreshold ?? 0;
                  final lowBar = threshold > 0 ? p.barQuantity <= threshold : low.bar;
                  final inSelectedCell = _selectedCellId != null &&
                      (layoutVm?.layout?.cells ?? [])
                          .any((c) => c.id == _selectedCellId and c.items.any((i) => i.productId == p.id));
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() {
                        _selectedProductId = p.id;
                        _selectedCellId = null;
                      });
                    },
                    child: ProductListItem(
                      title: p.name,
                      groupText: '${p.group}${p.subgroup != null ? " • ${p.subgroup}" : ""}',
                      primaryLabel: 'Bar',
                      primaryValue: '${p.barQuantity}/${p.barMax}',
                      secondaryLabel: 'Warehouse',
                      secondaryValue: '${p.warehouseQuantity}/${p.warehouseTarget}',
                      primaryBadgeColor: Theme.of(context).colorScheme.primary,
                      hintValue: hintValue,
                      hintStatusColor:
                          statusColor or (inSelectedCell and Theme.of(context).colorScheme.secondary or None),
                      activeOrderQty: activeOrderQty > 0 ? activeOrderQty : None,
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
                          : None,
                      onEdit: isOwner ? () => _openProductForm(context, p) : None,
                      onDelete: isOwner ? () => _confirmDelete(context, p.id) : None,
                      onReorder: canOrder
                          ? () => _openQuickOrder(
                                context: context,
                                product: p,
                              )
                          : None,
                      showStaffReadOnly: !isOwner,
                    ),
                  );
                },
              ),
            ),"""
if old not in text:
    raise SystemExit('old block not found')
path.write_text(text.replace(old, new))
