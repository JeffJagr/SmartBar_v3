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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Restock hint',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Fullness', style: theme.textTheme.bodyMedium),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 54,
                              child: TextField(
                                controller: _textController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                ),
                                style: theme.textTheme.titleMedium,
                                onChanged: (text) {
                                  final parsed = int.tryParse(text) ?? 0;
                                  final clamped = parsed.clamp(0, 100);
                                  setState(() {
                                    _percentFull = clamped.toDouble();
                                  });
                                },
                              ),
                            ),
                            Text('%', style: theme.textTheme.bodyMedium),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 6,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                    ),
                    child: Slider(
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
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hint is a suggestion; it does not change stock.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  _hintChips(theme),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.clear),
                label: const Text('Clear hint'),
                onPressed: () async {
                  final inv = Provider.of<InventoryViewModel>(context, listen: false);
                  final navigator = Navigator.of(context);
                  setState(() {
                    _percentFull = 100;
                    _textController.text = '100';
                  });
                  await inv.updateRestockHint(
                    widget.productId,
                    0,
                  );
                  if (!mounted) return;
                  navigator.pop();
                },
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
                onPressed: _saving ? null : _saveHint,
              ),
            ],
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

  Widget _hintChips(ThemeData theme) {
    final missing = _computedMissing();
    final max = widget.maxQuantity;
    final fullness = '${_percentFull.round()}% full';
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _chip(theme, fullness, theme.colorScheme.primary),
        _chip(theme, 'Missing: $missing of $max', theme.colorScheme.tertiary),
      ],
    );
  }

  Widget _chip(ThemeData theme, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(color: color),
      ),
    );
  }

  Future<void> _saveHint() async {
    final inv = Provider.of<InventoryViewModel>(context, listen: false);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await inv.updateRestockHint(
        widget.productId,
        _computedMissing(),
      );
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Restock hint saved')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
