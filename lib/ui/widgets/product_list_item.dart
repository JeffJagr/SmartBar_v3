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
    this.activeOrderQty,
    this.primaryBadgeColor,
    this.hintStatusColor,
    this.showStaffReadOnly = false,
    this.staffMessage,
    this.lowPrimary = false,
    this.lowSecondary = false,
    this.lowPrimaryLabel,
    this.lowSecondaryLabel,
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
  final int? activeOrderQty;
  final Color? primaryBadgeColor;
  final Color? hintStatusColor;
  final bool showStaffReadOnly;
  final String? staffMessage;
  final bool lowPrimary;
  final bool lowSecondary;
  final String? lowPrimaryLabel;
  final String? lowSecondaryLabel;

  @override
  Widget build(BuildContext context) {
    final lowPrimaryLabelText = lowPrimaryLabel ?? 'Low';
    final lowSecondaryLabelText = lowSecondaryLabel ?? 'Low';
    return Card(
      color: hintStatusColor?.withValues(alpha: 0.08),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(groupText),
            const SizedBox(height: 4),
            Row(
              children: [
                _primaryQuantity(
                  context,
                  label: primaryLabel,
                  value: primaryValue,
                  color: primaryBadgeColor ?? Theme.of(context).colorScheme.primary,
                ),
                if (lowPrimary)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _badge(context, lowPrimaryLabelText, Colors.red),
                  ),
              ],
            ),
            Row(
              children: [
                _secondaryQuantity(
                  context,
                  label: secondaryLabel,
                  value: secondaryValue,
                ),
                if (lowSecondary)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _badge(context, lowSecondaryLabelText, Colors.orange),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if ((activeOrderQty ?? 0) > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Orders: $activeOrderQty',
                      style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600),
                    ),
                  ),
                if (hintValue > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: hintStatusColor?.withValues(alpha: 0.2) ??
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
                          onPressed: onClearHint,
                        ),
                      ],
                    ),
                  ),
                TextButton(
                  onPressed: onSetHint,
                  child: const Text('Set restock hint'),
                ),
                if (onReorder != null)
                  TextButton(
                    onPressed: onReorder,
                    child: const Text('Order / Reorder'),
                  ),
                if (onTransfer != null)
                  TextButton(
                    onPressed: onTransfer,
                    child: const Text('Transfer to bar'),
                  ),
                if (onAdjust != null)
                  TextButton(
                    onPressed: onAdjust,
                    child: const Text('Adjust qty'),
                  ),
                if (onEdit != null)
                  TextButton(
                    onPressed: onEdit,
                    child: const Text('Edit'),
                  ),
                if (onDelete != null)
                  IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onDelete,
                  ),
              ],
            ),
            if (showStaffReadOnly)
              Text(
                staffMessage ?? 'Staff: read-only quantities',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        onTap: onSetHint,
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

  Widget _primaryQuantity(BuildContext context,
      {required String label, required String value, required Color color}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
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
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _secondaryQuantity(BuildContext context,
      {required String label, required String value}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
