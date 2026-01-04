import 'package:flutter/material.dart';

/// Reusable list item for products to keep screens lean and consistent.
class ProductListItem extends StatelessWidget {
  const ProductListItem({
    super.key,
    required this.title,
    required this.groupText,
    required this.primaryLabel,
    required this.primaryValue,
    required this.secondaryLabel,
    required this.secondaryValue,
    required this.hintValue,
    required this.onSetHint,
    required this.onClearHint,
    this.onAdjust,
    this.onEdit,
    this.onDelete,
    this.onTransfer,
    this.onReorder,
    this.supplierName,
    this.activeOrderQty,
    this.primaryBadgeColor,
    this.hintStatusColor,
    this.showStaffReadOnly = false,
    this.staffMessage,
    this.lowPrimary = false,
    this.lowSecondary = false,
    this.lowPrimaryLabel,
    this.lowSecondaryLabel,
    this.onTap,
    this.trackWarehouse = true,
    this.primarySubValue,
    this.secondarySubValue,
    this.showBarOnlyBadge = false,
    this.groupColor,
  });

  final String title;
  final String groupText;
  final String primaryLabel;
  final String primaryValue;
  final String secondaryLabel;
  final String secondaryValue;
  final int hintValue;
  final VoidCallback onSetHint;
  final VoidCallback onClearHint;
  final VoidCallback? onAdjust;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTransfer;
  final VoidCallback? onReorder;
  /// Supplier name preferred for ordering; used to show a badge.
  final String? supplierName;
  final int? activeOrderQty;
  final Color? primaryBadgeColor;
  final Color? hintStatusColor;
  final bool showStaffReadOnly;
  final String? staffMessage;
  final bool lowPrimary;
  final bool lowSecondary;
  final String? lowPrimaryLabel;
  final String? lowSecondaryLabel;
  final VoidCallback? onTap;
  final bool trackWarehouse;
  final String? primarySubValue;
  final String? secondarySubValue;
  final bool showBarOnlyBadge;
  final Color? groupColor;

  @override
  Widget build(BuildContext context) {
    final lowPrimaryLabelText = lowPrimaryLabel ?? 'Low';
    final lowSecondaryLabelText = lowSecondaryLabel ?? 'Low';
    return Card(
      color: hintStatusColor?.withValues(alpha: 0.05),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap ?? onSetHint,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor:
                        (groupColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.85),
                    child: Text(
                      title.isNotEmpty ? title[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (showBarOnlyBadge)
                    _badge(context, 'Bar only', Theme.of(context).colorScheme.outline),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                groupText,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              _quantityRow(
                context,
                label: primaryLabel,
                value: primaryValue,
                subValue: primarySubValue,
                color: primaryBadgeColor ?? Theme.of(context).colorScheme.primary,
                low: lowPrimary ? lowPrimaryLabelText : null,
              ),
              if (trackWarehouse)
                _quantityRow(
                  context,
                  label: secondaryLabel,
                  value: secondaryValue,
                  subValue: secondarySubValue,
                  color: Theme.of(context).colorScheme.secondary,
                  low: lowSecondary ? lowSecondaryLabelText : null,
                  muted: true,
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if ((supplierName ?? '').isNotEmpty)
                    _chip(
                      context,
                      'Supplier: $supplierName',
                      color: Theme.of(context).colorScheme.primary,
                      icon: Icons.storefront_outlined,
                    ),
                  if ((activeOrderQty ?? 0) > 0)
                    _chip(
                      context,
                      '$activeOrderQty in orders',
                      color: Colors.blue,
                      icon: Icons.shopping_cart_outlined,
                    ),
                  if (hintValue > 0)
                    _chip(
                      context,
                      'Hint: $hintValue',
                      color: hintStatusColor ?? Theme.of(context).colorScheme.tertiary,
                      icon: Icons.lightbulb_outline,
                      trailing: IconButton(
                        iconSize: 16,
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.clear, size: 16),
                        tooltip: 'Clear hint',
                        onPressed: onClearHint,
                      ),
                    ),
                  if (lowPrimary)
                    _badge(context, lowPrimaryLabelText, Colors.red),
                  if (lowSecondary)
                    _badge(context, lowSecondaryLabelText, Colors.orange),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: onSetHint,
                    icon: const Icon(Icons.lightbulb_outline),
                    label: const Text('Set restock hint'),
                  ),
                  if (onReorder != null)
                    TextButton.icon(
                      onPressed: onReorder,
                      icon: const Icon(Icons.shopping_cart_checkout_outlined),
                      label: const Text('Order / Reorder'),
                    ),
                  if (onTransfer != null)
                    TextButton.icon(
                      onPressed: onTransfer,
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('Transfer to bar'),
                    ),
                  if (onAdjust != null)
                    TextButton.icon(
                      onPressed: onAdjust,
                      icon: const Icon(Icons.tune),
                      label: const Text('Adjust qty'),
                    ),
                  if (onEdit != null)
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                  if (onDelete != null)
                    TextButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                    ),
                ],
              ),
              if (showStaffReadOnly) ...[
                const SizedBox(height: 4),
                Text(
                  staffMessage ?? 'Staff: read-only quantities',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
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

  Widget _quantityRow(
    BuildContext context, {
    required String label,
    required String value,
    String? subValue,
    required Color color,
    String? low,
    bool muted = false,
  }) {
    final textColor =
        muted ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: muted ? 0.08 : 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          if (subValue != null) ...[
            const SizedBox(width: 6),
            Text(
              subValue,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
            ),
          ],
          if (low != null) ...[
            const SizedBox(width: 6),
            _badge(context, low, Colors.red),
          ],
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    String label, {
    required Color color,
    IconData? icon,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 4),
            trailing,
          ],
        ],
      ),
    );
  }
}
