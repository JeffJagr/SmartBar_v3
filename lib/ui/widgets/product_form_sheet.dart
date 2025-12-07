import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/app_controller.dart';
import '../../models/product.dart';
import '../../viewmodels/inventory_view_model.dart';

/// Bottom sheet for creating or editing a product.
/// Uses InventoryViewModel to persist changes via repository (Firestore or stub).
class ProductFormSheet extends StatefulWidget {
  const ProductFormSheet({super.key, this.product});

  final Product? product;

  @override
  State<ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<ProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _groupCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _barQtyCtrl;
  late final TextEditingController _barMaxCtrl;
  late final TextEditingController _whQtyCtrl;
  late final TextEditingController _whTargetCtrl;
  late final TextEditingController _minThresholdCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _groupCtrl = TextEditingController(text: p?.group ?? '');
    _unitCtrl = TextEditingController(text: p?.unit ?? 'pcs');
    _barQtyCtrl = TextEditingController(text: (p?.barQuantity ?? 0).toString());
    _barMaxCtrl = TextEditingController(text: (p?.barMax ?? 0).toString());
    _whQtyCtrl = TextEditingController(text: (p?.warehouseQuantity ?? 0).toString());
    _whTargetCtrl = TextEditingController(text: (p?.warehouseTarget ?? 0).toString());
    _minThresholdCtrl =
        TextEditingController(text: (p?.minimalStockThreshold ?? 0).toString());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _groupCtrl.dispose();
    _unitCtrl.dispose();
    _barQtyCtrl.dispose();
    _barMaxCtrl.dispose();
    _whQtyCtrl.dispose();
    _whTargetCtrl.dispose();
    _minThresholdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product != null;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEdit ? 'Edit product' : 'Add product',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => v == null || v.isEmpty ? 'Enter name' : null,
              ),
              TextFormField(
                controller: _groupCtrl,
                decoration: const InputDecoration(labelText: 'Category / Group'),
              ),
              TextFormField(
                controller: _unitCtrl,
                decoration: const InputDecoration(labelText: 'Unit (e.g., bottle, keg)'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _barQtyCtrl,
                      decoration: const InputDecoration(labelText: 'Bar qty'),
                      keyboardType: TextInputType.number,
                      validator: _nonNegativeValidator,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _barMaxCtrl,
                      decoration: const InputDecoration(labelText: 'Bar target'),
                      keyboardType: TextInputType.number,
                      validator: _nonNegativeValidator,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _whQtyCtrl,
                      decoration: const InputDecoration(labelText: 'Warehouse qty'),
                      keyboardType: TextInputType.number,
                      validator: _nonNegativeValidator,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _whTargetCtrl,
                      decoration: const InputDecoration(labelText: 'Warehouse target'),
                      keyboardType: TextInputType.number,
                      validator: _nonNegativeValidator,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _minThresholdCtrl,
                decoration: const InputDecoration(labelText: 'Min stock threshold (optional)'),
                keyboardType: TextInputType.number,
                validator: _nonNegativeValidator,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(isEdit ? 'Save' : 'Add'),
                    onPressed: _saving ? null : () => _submit(isEdit),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit(bool isEdit) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final app = context.read<AppController>();
    final vm = context.read<InventoryViewModel>();
    final company = app.activeCompany;
    if (company == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active company selected')),
      );
      setState(() => _saving = false);
      return;
    }

    final minThreshold = int.tryParse(_minThresholdCtrl.text) ?? 0;
    final dataMap = {
      'name': _nameCtrl.text.trim(),
      'group': _groupCtrl.text.trim(),
      'unit': _unitCtrl.text.trim(),
      'barQuantity': int.tryParse(_barQtyCtrl.text) ?? 0,
      'barMax': int.tryParse(_barMaxCtrl.text) ?? 0,
      'warehouseQuantity': int.tryParse(_whQtyCtrl.text) ?? 0,
      'warehouseTarget': int.tryParse(_whTargetCtrl.text) ?? 0,
      'minimalStockThreshold': minThreshold > 0 ? minThreshold : null,
      'companyId': company.id,
    };
    dataMap.removeWhere((key, value) => value == null);

    try {
      if (isEdit && widget.product != null) {
        await vm.updateProduct(widget.product!.id, dataMap);
      } else {
        final product = Product(
          id: '', // Firestore repo will assign.
          companyId: company.id,
          name: dataMap['name'] as String,
          group: dataMap['group'] as String,
          unit: dataMap['unit'] as String,
          barQuantity: dataMap['barQuantity'] as int,
          barMax: dataMap['barMax'] as int,
          warehouseQuantity: dataMap['warehouseQuantity'] as int,
          warehouseTarget: dataMap['warehouseTarget'] as int,
          minimalStockThreshold: dataMap['minimalStockThreshold'] as int?,
          restockHint: 0,
          subgroup: null,
          salePrice: null,
          flagNeedsRestock: false,
        );
        await vm.addProduct(product);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEdit ? 'Product saved' : 'Product added')),
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
  }

  String? _nonNegativeValidator(String? value) {
    if (value == null || value.isEmpty) return null;
    final parsed = int.tryParse(value);
    if (parsed == null || parsed < 0) {
      return 'Must be >= 0';
    }
    return null;
  }
}
