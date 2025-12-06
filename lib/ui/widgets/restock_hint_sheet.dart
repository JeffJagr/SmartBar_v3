import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/inventory_view_model.dart';

/// Bottom sheet to adjust restockHint for a product.
/// restockHint is a suggestion only; it does not mutate actual stock.
class RestockHintSheet extends StatefulWidget {
  const RestockHintSheet({
    super.key,
    required this.productId,
    required this.initialValue,
    this.maxValue = 100,
  });

  final String productId;
  final int initialValue;
  final int maxValue;

  @override
  State<RestockHintSheet> createState() => _RestockHintSheetState();
}

class _RestockHintSheetState extends State<RestockHintSheet> {
  late int _value;
  final _textController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
    _textController.text = _value.toString();
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
            value: _value.toDouble(),
            min: 0,
            max: widget.maxValue.toDouble(),
            divisions: widget.maxValue ~/ 5,
            label: '$_value',
            onChanged: (v) {
              setState(() {
                _value = v.toInt();
                _textController.text = _value.toString();
              });
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Selected: $_value'),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _textController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Value',
                    isDense: true,
                  ),
                  onChanged: (text) {
                    final parsed = int.tryParse(text) ?? 0;
                    final clamped = parsed.clamp(0, widget.maxValue);
                    setState(() {
                      _value = clamped;
                    });
                  },
                ),
              ),
            ],
          ),
          Text(
            'Hint is a suggestion only; it does not change current stock.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              // Clearing restock hint sets it to zero; does not alter actual stock.
              setState(() {
                _value = 0;
                _textController.text = '0';
              });
              context.read<InventoryViewModel>().updateRestockHint(
                    widget.productId,
                    _value,
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
                            _value,
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
}
