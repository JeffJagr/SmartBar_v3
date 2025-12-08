import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/inventory_view_model.dart';

/// Bottom sheet to adjust bar/warehouse quantities for a product.
class AdjustQuantitySheet extends StatefulWidget {
  const AdjustQuantitySheet({
    super.key,
    required this.productId,
    required this.barQuantity,
    required this.warehouseQuantity,
  });

  final String productId;
  final int barQuantity;
  final int warehouseQuantity;

  @override
  State<AdjustQuantitySheet> createState() => _AdjustQuantitySheetState();
}

class _AdjustQuantitySheetState extends State<AdjustQuantitySheet> {
  late int _barQty;
  late int _whQty;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _barQty = widget.barQuantity;
    _whQty = widget.warehouseQuantity;
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = context.read<InventoryViewModel>().canEditQuantities;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Adjust quantities',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (!isOwner)
            Text(
              'Staff: read-only. Ask an owner/manager to adjust quantities.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 8),
          _qtyRow(
            label: 'Bar qty',
            value: _barQty,
            onChanged: isOwner ? (v) => setState(() => _barQty = v) : null,
          ),
          _qtyRow(
            label: 'Warehouse qty',
            value: _whQty,
            onChanged: isOwner ? (v) => setState(() => _whQty = v) : null,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Save'),
            onPressed: !isOwner || _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    try {
                      final changed =
                          _barQty != widget.barQuantity || _whQty != widget.warehouseQuantity;
                      var proceed = true;
                      if (changed) {
                        proceed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Confirm change'),
                                content: Text(
                                  'Update quantities?\nBar: ${widget.barQuantity} → $_barQty\nWarehouse: ${widget.warehouseQuantity} → $_whQty',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.of(ctx).pop(true),
                                    child: const Text('Update'),
                                  ),
                                ],
                              ),
                            ) ??
                            false;
                      }
                      if (!proceed) {
                        if (mounted) setState(() => _saving = false);
                        return;
                      }
                      await context.read<InventoryViewModel>().updateQuantities(
                            productId: widget.productId,
                            barQuantity: _barQty,
                            warehouseQuantity: _whQty,
                          );
                      if (!mounted) return;
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Quantities updated')),
                      );
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to update: $e')),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _saving = false);
                    }
                  },
          ),
        ],
      ),
    );
  }

  Widget _qtyRow({
    required String label,
    required int value,
    required ValueChanged<int>? onChanged,
  }) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        _Stepper(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final canChange = onChanged != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: canChange ? () => onChanged!((value - 1).clamp(0, 1000000)) : null,
        ),
        Text('$value'),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: canChange ? () => onChanged!(value + 1) : null,
        ),
      ],
    );
  }
}
