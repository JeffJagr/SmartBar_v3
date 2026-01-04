import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/app_controller.dart';
import '../../models/supplier.dart';
import '../../repositories/supplier_repository.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  Stream<List<Supplier>>? _stream;
  FirestoreSupplierRepository? _repo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = context.watch<AppController>();
    final company = app.activeCompany;
    if (company != null) {
      _repo = FirestoreSupplierRepository(companyId: company.id);
      _stream = _repo!.watchSuppliers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final perm = app.currentPermissionSnapshot;
    final canManage =
        app.permissions.canManageSuppliers(perm);
    final products = app.products;
    if (_stream == null) {
      return const Center(child: Text('Select a company to manage suppliers.'));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suppliers'),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _openEdit(context, canManage),
            ),
        ],
      ),
      body: StreamBuilder<List<Supplier>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final suppliers = snap.data ?? [];
          if (suppliers.isEmpty) {
            return Center(
              child: TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add supplier'),
                onPressed: canManage ? () => _openEdit(context, canManage) : null,
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: suppliers.length,
            itemBuilder: (context, i) {
              final s = suppliers[i];
              final count = products
                  .where((p) =>
                      (p.supplierId?.isNotEmpty == true && p.supplierId == s.id) ||
                      (p.supplierId == null &&
                          (p.supplierName ?? '').toLowerCase() == s.name.toLowerCase()))
                  .length;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(s.name, style: Theme.of(context).textTheme.titleMedium),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$count product${count == 1 ? '' : 's'}'),
                      if (s.contactEmail != null && s.contactEmail!.isNotEmpty)
                        Text('Email: ${s.contactEmail}'),
                      if (s.contactPhone != null && s.contactPhone!.isNotEmpty)
                        Text('Phone: ${s.contactPhone}'),
                      if (s.leadTimeDays != null) Text('Lead time: ${s.leadTimeDays} days'),
                      if (s.notes != null && s.notes!.isNotEmpty) Text(s.notes!),
                    ],
                  ),
                  trailing: canManage
                      ? IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _openEdit(context, canManage, supplier: s),
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openEdit(BuildContext context, bool canManage, {Supplier? supplier}) async {
    final nameCtrl = TextEditingController(text: supplier?.name ?? '');
    final emailCtrl = TextEditingController(text: supplier?.contactEmail ?? '');
    final phoneCtrl = TextEditingController(text: supplier?.contactPhone ?? '');
    final leadCtrl = TextEditingController(
        text: supplier?.leadTimeDays != null ? supplier!.leadTimeDays.toString() : '');
    final notesCtrl = TextEditingController(text: supplier?.notes ?? '');
    final repo = _repo;
    if (repo == null) return;
    await showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  supplier == null ? 'Add supplier' : 'Edit supplier',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email (optional)'),
                ),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone (optional)'),
                ),
                TextField(
                  controller: leadCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Lead time (days, optional)'),
                ),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes (optional)'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (supplier != null)
                      TextButton.icon(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        label: const Text('Delete', style: TextStyle(color: Colors.red)),
                        onPressed: () async {
                          await repo.delete(supplier.id);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                      ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save'),
                      onPressed: () async {
                        final app = context.read<AppController>();
                        final company = app.activeCompany;
                        if (company == null) return;
                        final lead =
                            leadCtrl.text.trim().isEmpty ? null : int.tryParse(leadCtrl.text);
                        final data = Supplier(
                          id: supplier?.id ?? '',
                          name: nameCtrl.text.trim(),
                          contactEmail: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                          contactPhone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                          leadTimeDays: lead,
                          notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                        );
                        await repo.addOrUpdate(data);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
