import 'package:flutter/material.dart';

import '../../models/product.dart';

/// Simple visual grid to illustrate where items are placed.
/// This is UI-only and does not alter backend data.
class LayoutGridPanel extends StatelessWidget {
  const LayoutGridPanel({
    super.key,
    required this.title,
    required this.products,
  });

  final String title;
  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tiles = products.take(15).toList();
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
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: tiles.length,
              itemBuilder: (context, index) {
                final p = tiles[index];
                final slot = index + 1;
                return _gridTile(context, slot, p);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _gridTile(BuildContext context, int slot, Product product) {
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
            '${product.group}${product.subgroup != null ? " • ${product.subgroup}" : ""}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}
