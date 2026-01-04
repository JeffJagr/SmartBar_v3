import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/app_controller.dart';
import '../../models/product.dart';
import '../../models/supplier.dart';
import '../../repositories/group_repository.dart';
import '../../ui/widgets/group_management_sheet.dart';
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
  late final TextEditingController _unitVolumeCtrl;
  late final TextEditingController _minVolumeThresholdCtrl;
  List<GroupMeta> _groups = [];
  List<Supplier> _suppliers = [];
  String? _selectedGroupId;
  Color? _selectedGroupColor;
  bool _loadingGroups = false;
  bool _loadingSuppliers = false;
  bool _saving = false;
  bool _trackVolume = false;
  bool _trackWarehouse = true;
  String? _selectedSupplierId;
  String? _selectedSupplierName;

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
    _trackVolume = p?.trackVolume ?? false;
    _unitVolumeCtrl = TextEditingController(text: (p?.unitVolumeMl ?? 0).toString());
    _minVolumeThresholdCtrl =
        TextEditingController(text: (p?.minVolumeThresholdMl ?? 0).toString());
    _trackWarehouse = p?.trackWarehouse ?? true;
    _selectedSupplierId = (p?.supplierId?.isNotEmpty ?? false) ? p?.supplierId : null;
    _selectedSupplierName = p?.supplierName;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGroups();
      _loadSuppliers();
    });
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
    _unitVolumeCtrl.dispose();
    _minVolumeThresholdCtrl.dispose();
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
              Row(
                children: [
                  Icon(isEdit ? Icons.edit_note_outlined : Icons.add_box_outlined,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    isEdit ? 'Edit product' : 'Add product',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _sectionCard(
                title: 'Basics',
                subtitle: 'Name, group, and unit',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Product name',
                        prefixIcon: Icon(Icons.local_drink_outlined),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Enter name' : null,
                    ),
                    const SizedBox(height: 10),
                    if (_loadingGroups)
                      const LinearProgressIndicator()
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ..._groups.map((g) {
                            final selected =
                                _selectedGroupId == g.id || _groupCtrl.text == g.name;
                            return ChoiceChip(
                              label: Text(g.name),
                              avatar: g.color != null
                                  ? CircleAvatar(
                                      backgroundColor: _parseColor(g.color),
                                      radius: 6,
                                    )
                                  : null,
                              selected: selected,
                              onSelected: (_) {
                                setState(() {
                                  _selectedGroupId = g.id;
                                  _selectedGroupColor = _parseColor(g.color);
                                  _groupCtrl.text = g.name;
                                });
                              },
                            );
                          }),
                          ActionChip(
                            label: const Text('New group'),
                            avatar: const Icon(Icons.add),
                            onPressed: _openGroupManager,
                          ),
                        ],
                      ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _groupCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Category / Group',
                        prefixIcon: Icon(Icons.folder_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _unitCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Unit (e.g., bottle, keg, ml)',
                        prefixIcon: Icon(Icons.straighten),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _sectionCard(
                title: 'Supplier',
                subtitle: 'Optional supplier attribution',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_loadingSuppliers)
                      const LinearProgressIndicator()
                    else
                      DropdownButtonFormField<String>(
                        initialValue: _selectedSupplierId ?? '',
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('No supplier'),
                          ),
                          ..._suppliers.map(
                            (s) => DropdownMenuItem(
                              value: s.id,
                              child: Text(s.name),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          setState(() {
                            if (v == null || v.isEmpty) {
                              _selectedSupplierId = null;
                              _selectedSupplierName = null;
                            } else {
                              _selectedSupplierId = v;
                              final match = _suppliers.firstWhere(
                                (s) => s.id == v,
                                orElse: () => Supplier(id: v, name: ''),
                              );
                              _selectedSupplierName = match.name;
                            }
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Supplier (optional)',
                          prefixIcon: Icon(Icons.store_mall_directory_outlined),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Pick a supplier to surface in orders, history, and stats. Leave empty for ad-hoc purchases.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _sectionCard(
                title: 'Tracking',
                subtitle: 'Choose how you count this item',
                child: Column(
                  children: [
                    _switchTile(
                      context,
                      title: 'Track by volume (ml)',
                      subtitle: 'Use ml values for quantities and low-stock checks',
                      value: _trackVolume,
                      onChanged: (v) => setState(() => _trackVolume = v),
                      icon: Icons.opacity_outlined,
                    ),
                    _switchTile(
                      context,
                      title: 'Track warehouse stock',
                      subtitle: 'Turn off if item lives only at the bar',
                      value: _trackWarehouse,
                      onChanged: (v) => setState(() => _trackWarehouse = v),
                      icon: Icons.warehouse_outlined,
                    ),
                    if (_trackVolume) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _unitVolumeCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Full volume per unit (ml)',
                                prefixIcon: Icon(Icons.scale_outlined),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _minVolumeThresholdCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Low threshold (ml)',
                                helperText: 'Alert when remaining volume is below this',
                                prefixIcon: Icon(Icons.warning_amber_rounded),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _sectionCard(
                title: 'Targets',
                subtitle: 'Bar and warehouse quantities',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _barQtyCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Bar qty',
                              prefixIcon: Icon(Icons.local_bar_outlined),
                            ),
                            keyboardType: TextInputType.number,
                            validator: _nonNegativeValidator,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _barMaxCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Bar target',
                              prefixIcon: Icon(Icons.flag_outlined),
                            ),
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
                            decoration: const InputDecoration(
                              labelText: 'Warehouse qty',
                              prefixIcon: Icon(Icons.inventory_2_outlined),
                            ),
                            keyboardType: TextInputType.number,
                            validator: _nonNegativeValidator,
                            enabled: _trackWarehouse,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _whTargetCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Warehouse target',
                              prefixIcon: Icon(Icons.flag_circle_outlined),
                            ),
                            keyboardType: TextInputType.number,
                            validator: _nonNegativeValidator,
                            enabled: _trackWarehouse,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _minThresholdCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Min stock threshold (optional)',
                        helperText: 'Use for low-stock warnings',
                        prefixIcon: Icon(Icons.report_gmailerrorred_outlined),
                      ),
                      keyboardType: TextInputType.number,
                      validator: _nonNegativeValidator,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
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
    final groupRepo = context.read<GroupRepository?>();
    final company = app.activeCompany;
    if (company == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active company selected')),
      );
      setState(() => _saving = false);
      return;
    }

    final minThreshold = int.tryParse(_minThresholdCtrl.text) ?? 0;
    final unitVolume = int.tryParse(_unitVolumeCtrl.text) ?? 0;
    final minVolumeThreshold = int.tryParse(_minVolumeThresholdCtrl.text) ?? 0;
    final groupHex = _currentGroupHex();
    final supplierSelected = _selectedSupplierId != null && _selectedSupplierId!.isNotEmpty;
    Supplier? selectedSupplier;
    if (supplierSelected) {
      selectedSupplier = _suppliers.firstWhere(
        (s) => s.id == _selectedSupplierId,
        orElse: () => Supplier(id: _selectedSupplierId!, name: _selectedSupplierName ?? ''),
      );
    }
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
      'trackWarehouse': _trackWarehouse,
      if (groupHex != null) 'groupColor': groupHex,
    };
    if (supplierSelected && selectedSupplier != null) {
      dataMap['supplierId'] = selectedSupplier.id;
      dataMap['supplierName'] = selectedSupplier.name.isNotEmpty
          ? selectedSupplier.name
          : (_selectedSupplierName ?? selectedSupplier.id);
    }
    if (_trackVolume) {
      dataMap['trackVolume'] = true;
      if (unitVolume > 0) dataMap['unitVolumeMl'] = unitVolume;
      if (minVolumeThreshold > 0) {
        dataMap['minVolumeThresholdMl'] = minVolumeThreshold;
      }
      // Seed volume fields from current counts for convenience.
      final barCount = int.tryParse(_barQtyCtrl.text) ?? 0;
      final whCount = int.tryParse(_whQtyCtrl.text) ?? 0;
      if (unitVolume > 0) {
        dataMap['barVolumeMl'] = barCount * unitVolume;
        dataMap['warehouseVolumeMl'] = whCount * unitVolume;
      }
    } else {
      dataMap['trackVolume'] = false;
      dataMap['unitVolumeMl'] = null;
      dataMap['minVolumeThresholdMl'] = null;
      dataMap['barVolumeMl'] = null;
      dataMap['warehouseVolumeMl'] = null;
    }
    dataMap.removeWhere((key, value) => value == null);
    if (isEdit && !supplierSelected) {
      dataMap['supplierId'] = FieldValue.delete();
      dataMap['supplierName'] = FieldValue.delete();
    }

    try {
      if (isEdit && widget.product != null) {
        await vm.updateProduct(widget.product!.id, dataMap);
      } else {
        final product = Product(
          id: '', // Firestore repo will assign.
          companyId: company.id,
          name: dataMap['name'] as String,
          group: dataMap['group'] as String,
          groupColor: groupHex,
          unit: dataMap['unit'] as String,
          barQuantity: dataMap['barQuantity'] as int,
          barMax: dataMap['barMax'] as int,
          warehouseQuantity: dataMap['warehouseQuantity'] as int,
          warehouseTarget: dataMap['warehouseTarget'] as int,
          minimalStockThreshold: dataMap['minimalStockThreshold'] as int?,
          trackVolume: dataMap['trackVolume'] as bool? ?? false,
          unitVolumeMl: dataMap['unitVolumeMl'] as int?,
          minVolumeThresholdMl: dataMap['minVolumeThresholdMl'] as int?,
          trackWarehouse: dataMap['trackWarehouse'] as bool? ?? true,
          barVolumeMl: dataMap['barVolumeMl'] as int?,
          warehouseVolumeMl: dataMap['warehouseVolumeMl'] as int?,
          restockHint: 0,
          subgroup: null,
          salePrice: null,
          flagNeedsRestock: false,
          supplierId: supplierSelected ? selectedSupplier?.id : null,
          supplierName: supplierSelected ? selectedSupplier?.name : null,
        );
        await vm.addProduct(product);
        // Persist group metadata if selected/new.
        if (groupRepo != null && _groupCtrl.text.trim().isNotEmpty) {
          final gid = _selectedGroupId ?? _groupCtrl.text.trim().toLowerCase();
          await groupRepo.upsertGroup(
            id: gid,
            name: _groupCtrl.text.trim(),
            color: _selectedGroupColor != null ? _hexFromColor(_selectedGroupColor!) : null,
          );
        }
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

  Future<void> _loadGroups() async {
    final repo = context.read<GroupRepository?>();
    if (repo == null) return;
    setState(() => _loadingGroups = true);
    try {
      final items = await repo.listGroups();
      setState(() {
        _groups = items;
        final existingName = _groupCtrl.text.trim();
        final match = _groups.where((g) => g.name.toLowerCase() == existingName.toLowerCase());
        if (match.isNotEmpty) {
          final g = match.first;
          _selectedGroupId = g.id;
          _selectedGroupColor = _parseColor(g.color);
        }
      });
    } catch (_) {
      // ignore
    } finally {
      setState(() => _loadingGroups = false);
    }
  }

  Future<void> _loadSuppliers() async {
    final app = context.read<AppController>();
    final company = app.activeCompany;
    if (company == null) return;
    setState(() => _loadingSuppliers = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('companies')
          .doc(company.id)
          .collection('suppliers')
          .orderBy('name')
          .get();
      final list = snap.docs.map((d) => Supplier.fromMap(d.id, d.data())).toList();
      setState(() {
        _suppliers = list;
        if (_selectedSupplierId != null) {
          final match = list.where((s) => s.id == _selectedSupplierId);
          if (match.isNotEmpty) {
            _selectedSupplierName = match.first.name;
          }
        } else if ((_selectedSupplierName ?? '').isNotEmpty) {
          final byName = list.where(
              (s) => s.name.toLowerCase() == _selectedSupplierName!.toLowerCase());
          if (byName.isNotEmpty) {
            _selectedSupplierId = byName.first.id;
            _selectedSupplierName = byName.first.name;
          }
        }
      });
    } catch (_) {
      // ignore errors silently for optional suppliers.
    } finally {
      setState(() => _loadingSuppliers = false);
    }
  }

  void _openGroupManager() async {
    await showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (ctx) => GroupManagementSheet(
        repository: ctx.read<GroupRepository?>(),
        canManage: true,
      ),
    );
    await _loadGroups();
  }

  Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    try {
      final cleaned = hex.startsWith('#') ? hex.substring(1) : hex;
      final value = int.parse(cleaned, radix: 16);
      return Color(value <= 0xFFFFFF ? 0xFF000000 | value : value);
    } catch (_) {
      return null;
    }
  }

  String _hexFromColor(Color color) {
    final argb = color.toARGB32();
    return '#${argb.toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  String? _currentGroupHex() {
    if (_selectedGroupColor != null) {
      return _hexFromColor(_selectedGroupColor!);
    }
    final name = _groupCtrl.text.trim().toLowerCase();
    final match = _groups.firstWhere(
      (g) => g.name.toLowerCase() == name && g.color != null && g.color!.isNotEmpty,
      orElse: () => GroupMeta(id: '', name: '', color: null, itemIds: const []),
    );
    if (match.color != null && match.color!.isNotEmpty) {
      return match.color;
    }
    return null;
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _switchTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}
