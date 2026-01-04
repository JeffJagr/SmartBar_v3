import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/app_controller.dart';
import '../../models/company.dart';
import '../../models/product.dart';
import '../../repositories/network_products_repository.dart';
import '../../viewmodels/network_cart_view_model.dart';

class NetworkCartScreen extends StatelessWidget {
  const NetworkCartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final companies = app.companies;
    if (companies.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Network Cart')),
        body: const Center(child: Text('No companies available.')),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => NetworkCartViewModel(
        companies: companies,
        productsRepository: NetworkProductsRepository(),
      ),
      child: const _NetworkCartBody(),
    );
  }
}

class _NetworkCartBody extends StatelessWidget {
  const _NetworkCartBody();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final vm = context.watch<NetworkCartViewModel>();
    final totalsByCompany = vm.totalsByCompany;
    final totalsBySupplier = vm.totalsBySupplier;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Cart'),
        actions: [
          IconButton(
            tooltip: 'Add item',
            icon: const Icon(Icons.add_shopping_cart_outlined),
            onPressed: () => _openAddItemSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Chip(label: Text('Total items: ${vm.totalItems}')),
                ...totalsBySupplier.entries
                    .map((e) => Chip(label: Text('${e.key}: ${e.value} items'))),
                ...totalsByCompany.entries
                    .map((e) => Chip(label: Text('${_companyName(vm.companyById, e.key)}: ${e.value}'))),
              ],
            ),
          ),
          Expanded(
            child: vm.lines.isEmpty
                ? const Center(child: Text('Cart is empty. Add products to build a network order.'))
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    children: _groupBySupplier(vm.lines).entries.map((entry) {
                      final supplier = entry.key;
                      final lines = entry.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ExpansionTile(
                          initiallyExpanded: true,
                          title: Text(supplier),
                          subtitle: Text('${lines.length} lines'),
                          children: lines.map((line) {
                            final companyName = _companyName(vm.companyById, line.companyId);
                            return ListTile(
                              title: Text(line.productName),
                              subtitle: Text('$companyName • ${line.supplierName ?? 'Supplier TBD'}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline),
                                    onPressed: () =>
                                        vm.updateQuantity(line.id, (line.quantity - 1).clamp(0, 999999)),
                                  ),
                                  Text('x${line.quantity}'),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline),
                                    onPressed: () =>
                                        vm.updateQuantity(line.id, (line.quantity + 1).clamp(1, 999999)),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => vm.removeLine(line.id),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    }).toList(),
                  ),
          ),
          if (vm.error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(vm.error!, style: const TextStyle(color: Colors.red)),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: vm.submitting
                          ? null
                          : () => vm.submit(
                                action: NetworkCartAction.pending,
                                userId: app.ownerUser?.uid ?? '',
                                userName: app.displayName,
                              ),
                      child: vm.submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save (Pending)'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: vm.submitting
                          ? null
                          : () => vm.submit(
                                action: NetworkCartAction.confirm,
                                userId: app.ownerUser?.uid ?? '',
                                userName: app.displayName,
                              ),
                      child: const Text('Confirm'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: vm.submitting
                          ? null
                          : () => vm.submit(
                                action: NetworkCartAction.deliver,
                                userId: app.ownerUser?.uid ?? '',
                                userName: app.displayName,
                              ),
                      child: const Text('Mark Delivered'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: vm.submitting
                        ? null
                        : () => vm.submit(
                              action: NetworkCartAction.cancel,
                              userId: app.ownerUser?.uid ?? '',
                              userName: app.displayName,
                            ),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, List<NetworkCartLine>> _groupBySupplier(List<NetworkCartLine> lines) {
    final map = <String, List<NetworkCartLine>>{};
    for (final l in lines) {
      final key = l.supplierName ?? 'Supplier TBD';
      map.putIfAbsent(key, () => []).add(l);
    }
    return map;
  }

  String _companyName(Map<String, Company> companies, String id) =>
      companies[id]?.name ?? 'Unknown company';

  Future<void> _openAddItemSheet(BuildContext context) async {
    final vm = context.read<NetworkCartViewModel>();
    final companies = vm.companyById.values.toList();
    String selectedCompanyId = companies.first.id;
    List<Product> products = await vm.fetchProductsForCompany(selectedCompanyId);
    Product? selectedProduct = products.isNotEmpty ? products.first : null;
    if (!context.mounted) return;
    final qtyController = TextEditingController(text: '1');
    final supplierController = TextEditingController(
      text: selectedProduct?.supplierName ?? '',
    );
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedCompanyId,
                    decoration: const InputDecoration(labelText: 'Company'),
                    items: companies
                        .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                        .toList(),
                    onChanged: (val) async {
                      if (val == null) return;
                      selectedCompanyId = val;
                      products = await vm.fetchProductsForCompany(selectedCompanyId);
                      selectedProduct = products.isNotEmpty ? products.first : null;
                      supplierController.text = selectedProduct?.supplierName ?? '';
                      if (!ctx.mounted) return;
                      setState(() {});
                    },
                 ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedProduct?.id,
                    decoration: const InputDecoration(labelText: 'Product'),
                    items: products
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.name),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      selectedProduct = products.firstWhere((p) => p.id == val);
                      supplierController.text = selectedProduct?.supplierName ?? '';
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: qtyController,
                    decoration: const InputDecoration(labelText: 'Quantity'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: supplierController,
                    decoration: const InputDecoration(labelText: 'Supplier (optional)'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add line'),
                    onPressed: selectedProduct == null
                        ? null
                        : () {
                            final qty = int.tryParse(qtyController.text) ?? 0;
                            if (qty <= 0) return;
                            vm.addLine(
                              companyId: selectedCompanyId,
                              product: selectedProduct!,
                              quantity: qty,
                              supplierName: supplierController.text.trim().isEmpty
                                  ? null
                                  : supplierController.text.trim(),
                            );
                            Navigator.of(ctx).pop();
                          },
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
