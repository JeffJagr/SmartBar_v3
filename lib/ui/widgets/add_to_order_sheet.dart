import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../controllers/app_controller.dart';
import '../../models/order.dart';
import '../../models/product.dart';
import '../../models/supplier.dart';
import '../../viewmodels/orders_view_model.dart';

Future<void> showAddToOrderSheet({
  required BuildContext context,
  required AppController app,
  required OrdersViewModel ordersVm,
  required List<Product> inventory,
  required Product initialProduct,
  int? defaultQuantity,
}) async {
  final perm = app.currentPermissionSnapshot;
  if (!app.permissions.canCreateOrders(perm)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('You do not have permission to create orders.')),
    );
    return;
  }
  // Supplier selection is deferred to managers at confirmation; we only attach preferred automatically.
  final suppliers = await _fetchSuppliers(app.activeCompany?.id);
  if (!context.mounted) return;
  final pendingOrders =
      ordersVm.orders.where((o) => o.status == OrderStatus.pending).toList();
  OrderModel? targetOrder;

  int suggestQty(Product p) {
    final desired = (p.restockHint != null && p.restockHint! > 0) ? p.restockHint! : p.barMax;
    final missing = desired > 0 ? (desired - p.barQuantity) : 1;
    return missing > 0 ? missing : 1;
  }

  final items = <OrderItem>[
    OrderItem(
      productId: initialProduct.id,
      productNameSnapshot: initialProduct.name,
      quantityOrdered: defaultQuantity ?? suggestQty(initialProduct),
      unitCost: null,
      supplierName: initialProduct.supplierName, // auto-attach preferred supplier if set
    ),
  ];
  final qtyControllers = <TextEditingController>[
    TextEditingController(text: (defaultQuantity ?? suggestQty(initialProduct)).toString())
  ];
  // We don’t ask for supplier here; kept for potential future use.
  final supplierByLine = <String?>[initialProduct.supplierName];

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
        child: StatefulBuilder(
          builder: (sheetCtx, setState) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pendingOrders.isNotEmpty) ...[
                    Text('Target order', style: Theme.of(sheetCtx).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: targetOrder?.id ?? '',
                      items: [
                        const DropdownMenuItem(value: '', child: Text('New order')),
                        ...pendingOrders.map(
                          (o) => DropdownMenuItem(
                            value: o.id,
                            child: Text('${_orderLabel(o)} • ${o.supplier ?? 'Mixed'}'),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        setState(() {
                          if (v == null || v.isEmpty) {
                            targetOrder = null;
                          } else {
                            final match = pendingOrders.where((o) => o.id == v).toList();
                            targetOrder = match.isNotEmpty ? match.first : null;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text('Add products', style: Theme.of(sheetCtx).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...List.generate(items.length, (i) {
                    final line = items[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () async {
                              final picked = await _pickProduct(sheetCtx, inventory, suppliers);
                              if (picked == null) return;
                              setState(() {
                                items[i] = OrderItem(
                                  productId: picked.id,
                                  productNameSnapshot: picked.name,
                                  quantityOrdered: line.quantityOrdered,
                                  unitCost: line.unitCost,
                                  supplierName:
                                      picked.supplierName, // auto attach preferred supplier if any
                                );
                                supplierByLine[i] = picked.supplierName ?? '';
                                final suggested = suggestQty(picked);
                                qtyControllers[i].text = suggested.toString();
                                items[i] = OrderItem(
                                  productId: items[i].productId,
                                  productNameSnapshot: items[i].productNameSnapshot,
                                  quantityOrdered: suggested,
                                  unitCost: items[i].unitCost,
                                  supplierName: items[i].supplierName,
                                );
                              });
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Product',
                                prefixIcon: Icon(Icons.search),
                                border: OutlineInputBorder(),
                              ),
                              child: Text(
                                line.productNameSnapshot ?? 'Tap to select product',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Preferred supplier',
                                    prefixIcon: Icon(Icons.storefront_outlined),
                                  ),
                                  child: Text(
                                    (line.supplierName?.isNotEmpty == true)
                                        ? line.supplierName!
                                        : 'TBD (set on confirm)',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 90,
                                child: TextField(
                                  controller: qtyControllers[i],
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Qty'),
                                  onChanged: (v) {
                                    final qty = int.tryParse(v) ?? 0;
                                    setState(() {
                                      items[i] = OrderItem(
                                        productId: items[i].productId,
                                        productNameSnapshot: items[i].productNameSnapshot,
                                        quantityOrdered: qty,
                                        unitCost: items[i].unitCost,
                                        supplierName: items[i].supplierName,
                                      );
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        final prod = inventory.isNotEmpty ? inventory.first : initialProduct;
                        items.add(OrderItem(
                          productId: prod.id,
                          productNameSnapshot: prod.name,
                          quantityOrdered: 1,
                          unitCost: null,
                          supplierName: prod.supplierName,
                        ));
                        qtyControllers.add(TextEditingController(text: '1'));
                        supplierByLine.add(prod.supplierName ?? '');
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add product'),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: Text(targetOrder == null ? 'Create order' : 'Add to order'),
                      onPressed: () async {
                        final filteredItems = items
                            .where((e) => e.quantityOrdered > 0 && e.productId.isNotEmpty)
                            .toList();
                        if (filteredItems.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Add at least one item with quantity')),
                          );
                          return;
                        }
                        if (targetOrder == null) {
                          await ordersVm.createOrder(
                            companyId: app.activeCompany!.id,
                            createdByUserId: app.ownerUser?.uid ?? app.currentStaff?.id ?? 'anon',
                            createdByName: app.displayName,
                            supplier: null,
                            items: filteredItems,
                          );
                        } else {
                          final merged = _mergeItems(targetOrder!.items, filteredItems);
                          await ordersVm.updateOrderItems(targetOrder!, merged);
                        }
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}

List<OrderItem> _mergeItems(List<OrderItem> existing, List<OrderItem> additions) {
  final merged = <String, OrderItem>{};
  for (final item in existing) {
    final key = '${item.productId}__${item.supplierName ?? ''}';
    merged[key] = item;
  }
  for (final item in additions) {
    final key = '${item.productId}__${item.supplierName ?? ''}';
    if (merged.containsKey(key)) {
      final current = merged[key]!;
      merged[key] = OrderItem(
        productId: current.productId,
        productNameSnapshot: current.productNameSnapshot ?? item.productNameSnapshot,
        quantityOrdered: current.quantityOrdered + item.quantityOrdered,
        unitCost: current.unitCost ?? item.unitCost,
        supplierName: current.supplierName ?? item.supplierName,
      );
    } else {
      merged[key] = item;
    }
  }
  return merged.values.toList();
}

Future<Product?> _pickProduct(
    BuildContext context, List<Product> products, List<Supplier> suppliers) async {
  String query = '';
  return showModalBottomSheet<Product>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      var filtered = products;
      return StatefulBuilder(
        builder: (sheetCtx, setState) {
          filtered = query.isEmpty
              ? products
              : products
                  .where((p) =>
                      p.name.toLowerCase().contains(query.toLowerCase()) ||
                      (p.group.toLowerCase().contains(query.toLowerCase())) ||
                      ((p.supplierName ?? '').toLowerCase().contains(query.toLowerCase())))
                  .toList();
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search by name, group, supplier',
                  ),
                  onChanged: (v) => setState(() => query = v),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 320,
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final p = filtered[index];
                      final isLowBar = p.barMax > 0 && p.barQuantity < p.barMax / 2;
                      final isHalfBar =
                          p.barMax > 0 && p.barQuantity < (p.barMax * 0.7) && !isLowBar;
                      final lowBadge = isLowBar
                          ? const Text('Low', style: TextStyle(color: Colors.red))
                          : isHalfBar
                              ? const Text('Half', style: TextStyle(color: Colors.amber))
                              : null;
                      final preferredSupplier = suppliers
                          .firstWhere((s) => s.name == p.supplierName, orElse: () => Supplier(id: '', name: ''));
                      return ListTile(
                        title: Text(p.name),
                        subtitle: Text(
                          [
                            p.group,
                            if ((p.supplierName ?? '').isNotEmpty) 'Supplier: ${p.supplierName}'
                          ].whereType<String>().join(' • '),
                        ),
                        trailing: lowBadge ??
                            (preferredSupplier.name.isNotEmpty
                                ? const Icon(Icons.star, color: Colors.amber, size: 16)
                                : null),
                        onTap: () => Navigator.pop(context, p),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

String _orderLabel(OrderModel order) {
  if (order.orderNumber > 0) {
    return '#${order.orderNumber.toString().padLeft(4, '0')}';
  }
  return order.id.isNotEmpty ? order.id : 'Order';
}

Future<List<Supplier>> _fetchSuppliers(String? companyId) async {
  if (companyId == null) return [];
  try {
    final snap = await FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('suppliers')
        .orderBy('name')
        .get();
    return snap.docs.map((d) => Supplier.fromMap(d.id, d.data())).toList();
  } catch (_) {
    return [];
  }
}
