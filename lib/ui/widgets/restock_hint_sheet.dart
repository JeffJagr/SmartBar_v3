import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/inventory_view_model.dart';

/// Bottom sheet to adjust restockHint for a product.
/// restockHint is a suggestion only; it does not mutate actual stock.
class RestockHintSheet extends StatefulWidget {
  const RestockHintSheet({
    super.key,
    required this.productId,
    required this.currentQuantity,
    required this.maxQuantity,
  });

  final String productId;
  final int currentQuantity;
  final int maxQuantity;

  @override
  State<RestockHintSheet> createState() => _RestockHintSheetState();
}

class _RestockHintSheetState extends State<RestockHintSheet> {
  late double _percentFull;
  final _textController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _percentFull = _initialPercent();
    _textController.text = _percentFull.round().toString();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Set restock hint',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Slider(
            value: _percentFull,
            min: 0,
            max: 100,
            divisions: 20,
            label: '${_percentFull.round()}%',
            onChanged: (v) {
              setState(() {
                _percentFull = v;
                _textController.text = _percentFull.round().toString();
              });
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Fullness: ${_percentFull.round()}%'),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _textController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '%',
                    isDense: true,
                  ),
                  onChanged: (text) {
                    final parsed = int.tryParse(text) ?? 0;
                    final clamped = parsed.clamp(0, 100);
                    setState(() {
                      _percentFull = clamped.toDouble();
                    });
                  },
                ),
              ),
            ],
          ),
          Text(
            'Hint is a suggestion only; it does not change current stock. Slider represents % fullness.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Text(
            _hintSummary(),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              // Clearing restock hint sets it to zero; does not alter actual stock.
              setState(() {
                _percentFull = 100;
                _textController.text = '100';
              });
              context.read<InventoryViewModel>().updateRestockHint(
                    widget.productId,
                    0,
                  );
              Navigator.of(context).pop();
            },
            child: const Text('Clear hint'),
          ),
          ElevatedButton.icon(
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Save hint'),
            onPressed: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    try {
                      await context.read<InventoryViewModel>().updateRestockHint(
                            widget.productId,
                            _computedMissing(),
                          );
                      if (!mounted) return;
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Restock hint saved')),
                      );
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to save: $e')),
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

  double _initialPercent() {
    final max = widget.maxQuantity;
    if (max <= 0) return 100;
    final percent = (widget.currentQuantity / max) * 100;
    return percent.clamp(0, 100);
  }

  int _computedMissing() {
    final max = widget.maxQuantity;
    if (max <= 0) return 0;
    final missing = max * ((100 - _percentFull) / 100);
    return missing.round();
  }

  String _hintSummary() {
    final max = widget.maxQuantity;
    if (max <= 0) {
      return 'Approximate missing: N/A (no target set)';
    }
    final missing = _computedMissing();
    return 'Approximate missing: $missing of $max';
  }
}
