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
    this.barMax,
    this.warehouseTarget,
    this.unitVolumeMl,
    this.trackVolume = false,
    this.trackWarehouse = true,
    this.barVolumeMl,
    this.warehouseVolumeMl,
  });

  final String productId;
  final int barQuantity;
  final int warehouseQuantity;
  final int? barMax;
  final int? warehouseTarget;
  final int? unitVolumeMl;
  final bool trackVolume;
  final bool trackWarehouse;
  final int? barVolumeMl;
  final int? warehouseVolumeMl;

  @override
  State<AdjustQuantitySheet> createState() => _AdjustQuantitySheetState();
}

class _AdjustQuantitySheetState extends State<AdjustQuantitySheet> {
  late int _barQty;
  late int _whQty;
  int? _barMlQty;
  int? _whMlQty;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final unitVol = widget.unitVolumeMl ?? 0;
    _barQty = widget.barQuantity;
    _whQty = widget.warehouseQuantity;
    if (widget.trackVolume) {
      _barMlQty = widget.barVolumeMl ??
          (unitVol > 0 ? widget.barQuantity * unitVol : null);
      _whMlQty = widget.warehouseVolumeMl ??
          (unitVol > 0 ? widget.warehouseQuantity * unitVol : null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = context.read<InventoryViewModel>().canEditQuantities;
    final barMax = (widget.barMax ?? (widget.barQuantity * 2)).clamp(0, 1000000);
    final whMax =
        (widget.warehouseTarget ?? (widget.warehouseQuantity * 2)).clamp(0, 1000000);
    final showWarehouse = widget.trackWarehouse;
    final unitVol = widget.unitVolumeMl ?? 0;
    final trackVol = widget.trackVolume;
    final barMaxMl = trackVol && unitVol > 0
        ? (widget.barMax ?? barMax) * unitVol
        : (widget.barMax ?? barMax);
    final whMaxMl = trackVol && unitVol > 0
        ? (widget.warehouseTarget ?? whMax) * unitVol
        : (widget.warehouseTarget ?? whMax);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Adjust quantities',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          if (widget.trackVolume && (widget.unitVolumeMl ?? 0) > 0)
            Text(
              'Tracking volume: ${widget.unitVolumeMl} ml per unit',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 12),
          if (!canEdit)
            Text(
              'Staff: read-only. Ask an owner/manager to adjust quantities.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 8),
          _qtyRow(
            label: 'Bar qty',
            value: _barQty,
            max: barMax,
            unitVolumeMl: null,
            onChanged: canEdit ? (v) => setState(() => _barQty = v) : null,
          ),
          if (trackVol)
            _qtyRowMl(
              label: 'Bar (ml)',
              value: _barMlQty ?? 0,
              max: barMaxMl,
              step: unitVol > 0 ? unitVol : 10,
              onChanged: canEdit ? (ml) => setState(() => _barMlQty = ml) : null,
            ),
          if (showWarehouse)
            _qtyRow(
              label: 'Warehouse qty',
              value: _whQty,
              max: whMax,
              unitVolumeMl: null,
              onChanged: canEdit ? (v) => setState(() => _whQty = v) : null,
            ),
          if (showWarehouse && trackVol)
            _qtyRowMl(
              label: 'Warehouse (ml)',
              value: _whMlQty ?? 0,
              max: whMaxMl,
              step: unitVol > 0 ? unitVol : 10,
              onChanged: canEdit ? (ml) => setState(() => _whMlQty = ml) : null,
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
            onPressed: !canEdit || _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    try {
                      final changed =
                          _barQty != widget.barQuantity ||
                          _whQty != widget.warehouseQuantity ||
                          (trackVol && (_barMlQty != widget.barVolumeMl || _whMlQty != widget.warehouseVolumeMl));
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
                        if (!context.mounted) return;
                      }
                      if (!proceed) {
                        if (mounted) setState(() => _saving = false);
                        return;
                      }
                      final vm = context.read<InventoryViewModel>();
                      await vm.updateQuantities(
                        productId: widget.productId,
                        barQuantity: _barQty,
                        warehouseQuantity: _whQty,
                        barVolumeMl: trackVol ? _barMlQty : null,
                        warehouseVolumeMl: trackVol && showWarehouse ? _whMlQty : null,
                      );
                      if (!context.mounted) return;
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
    required int max,
    required ValueChanged<int>? onChanged,
    int? unitVolumeMl,
  }) {
    final cappedMax = max <= 0 ? 1 : max;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              '$value / $cappedMax',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (unitVolumeMl != null && unitVolumeMl > 0) ...[
              const SizedBox(width: 6),
              Text(
                '${value * unitVolumeMl} ml',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _Stepper(
              value: value,
              onChanged: onChanged,
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 78,
              child: TextField(
                key: ValueKey('$label-$value'),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                ),
                keyboardType: TextInputType.number,
                controller: TextEditingController(text: value.toString()),
                onSubmitted: onChanged == null
                    ? null
                    : (v) {
                        final parsed = int.tryParse(v) ?? value;
                        onChanged(parsed.clamp(0, cappedMax));
                      },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Slider(
                value: value.clamp(0, cappedMax).toDouble(),
                min: 0,
                max: cappedMax.toDouble(),
                divisions: cappedMax > 50 ? 50 : cappedMax,
                label: '$value',
                activeColor: _colorForValue(value, cappedMax),
                onChanged: onChanged == null ? null : (v) => onChanged(v.round()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _colorForValue(int value, int max) {
    final ratio = max == 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    if (ratio < 0.5) return Colors.red;
    if (ratio < 0.8) return Colors.orange;
    return Colors.green;
  }

  Widget _qtyRowMl({
    required String label,
    required int value,
    required int max,
    required int step,
    required ValueChanged<int>? onChanged,
  }) {
    final cappedMax = max <= 0 ? 1 : max;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              '$value ml / $cappedMax ml',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _Stepper(
              value: value,
              step: step.clamp(1, 1000000),
              onChanged: onChanged,
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 90,
              child: TextField(
                key: ValueKey('$label-ml-$value'),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                ),
                keyboardType: TextInputType.number,
                controller: TextEditingController(text: value.toString()),
                onSubmitted: onChanged == null
                    ? null
                    : (v) {
                        final parsed = int.tryParse(v) ?? value;
                        onChanged(parsed.clamp(0, cappedMax));
                      },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Slider(
                value: value.clamp(0, cappedMax).toDouble(),
                min: 0,
                max: cappedMax.toDouble(),
                divisions: cappedMax > 50 ? 50 : cappedMax,
                label: '$value ml',
                activeColor: _colorForValue(value, cappedMax),
                onChanged: onChanged == null ? null : (v) => onChanged(v.round()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.onChanged, this.step = 1});

  final int value;
  final ValueChanged<int>? onChanged;
  final int step;

  @override
  Widget build(BuildContext context) {
    final canChange = onChanged != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: canChange ? () => onChanged!((value - step).clamp(0, 1000000)) : null,
        ),
        Text('$value'),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: canChange ? () => onChanged!(value + step) : null,
        ),
      ],
    );
  }
}
