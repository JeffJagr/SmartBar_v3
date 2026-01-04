import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import '../../controllers/app_controller.dart';
import '../../models/order.dart';
import '../../models/product.dart';
import '../../models/supplier.dart';
import '../../viewmodels/inventory_view_model.dart';
import '../../viewmodels/orders_view_model.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  OrderStatus? _statusFilter;
  bool _sortDescending = true;
  String _search = '';
  String _timeWindow = 'All';
  final Map<String, TextEditingController> _receiveControllers = {};
  final TextEditingController _receiveNoteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrdersViewModel?>()?.init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OrdersViewModel?>();
    final inventoryVm = context.watch<InventoryViewModel>();
    final app = context.watch<AppController>();
    final company = app.activeCompany;
    final products = inventoryVm.products;
    final perm = app.currentPermissionSnapshot;
    final canCreate = app.permissions.canCreateOrders(perm);

    if (vm == null) {
      return const Scaffold(
        body: Center(child: Text('Orders are unavailable for this company.')),
      );
    }

    if (vm.loading && vm.orders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.error != null) {
      return Center(child: Text('Error: ${vm.error}'));
    }

    final orders = vm.orders
        .where((o) => _statusFilter == null || o.status == _statusFilter)
        .where((o) {
          if (_search.isEmpty) return true;
          final term = _search.toLowerCase();
          final label = _orderLabel(o).toLowerCase();
          final creator = (o.createdByName ?? o.createdByUserId).toLowerCase();
          final itemsText = o.items.map((i) => i.productNameSnapshot ?? i.productId).join(' ').toLowerCase();
          return label.contains(term) || creator.contains(term) || itemsText.contains(term);
        })
        .where((o) {
          if (_timeWindow == 'All') return true;
          final now = DateTime.now();
          if (_timeWindow == 'Today') {
            final start = DateTime(now.year, now.month, now.day);
            return o.createdAt.isAfter(start);
          }
          if (_timeWindow == '7d') {
            return now.difference(o.createdAt).inDays <= 7;
          }
          return true;
        })
        .toList()
      ..sort((a, b) => _sortDescending
          ? b.createdAt.compareTo(a.createdAt)
          : a.createdAt.compareTo(b.createdAt));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [
          PopupMenuButton<_ExportKind>(
            tooltip: 'Export / share',
            onSelected: (kind) => _exportAndCopy(context, orders, kind),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _ExportKind.csv,
                child: ListTile(
                  leading: Icon(Icons.copy_all),
                  title: Text('Copy CSV'),
                ),
              ),
              PopupMenuItem(
                value: _ExportKind.printable,
                child: ListTile(
                  leading: Icon(Icons.picture_as_pdf_outlined),
                  title: Text('Copy printable (PDF-ready)'),
                ),
              ),
            ],
            icon: const Icon(Icons.ios_share),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search order #, creator, products...',
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _statusChipFilter(null, 'All'),
                    _statusChipFilter(OrderStatus.pending, 'Pending'),
                    _statusChipFilter(OrderStatus.confirmed, 'Confirmed'),
                    _statusChipFilter(OrderStatus.delivered, 'Delivered'),
                    _statusChipFilter(OrderStatus.canceled, 'Canceled'),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButton<String>(
                        value: _timeWindow,
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('All time')),
                          DropdownMenuItem(value: 'Today', child: Text('Today')),
                          DropdownMenuItem(value: '7d', child: Text('Last 7 days')),
                        ],
                        onChanged: (v) => setState(() => _timeWindow = v ?? 'All'),
                      ),
                      IconButton(
                        tooltip: _sortDescending ? 'Newest first' : 'Oldest first',
                        onPressed: () => setState(() => _sortDescending = !_sortDescending),
                        icon: Icon(_sortDescending ? Icons.arrow_downward : Icons.arrow_upward),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                return _orderCard(context, order, app, vm, products);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: company == null || !canCreate
          ? null
          : FloatingActionButton(
              onPressed: () => _openNewOrderSheetV2(
                context: context,
                companyId: company.id,
                createdBy: app.ownerUser?.uid ?? app.currentStaff?.id ?? 'anon',
                createdByName: app.displayName,
                canCreate: canCreate,
              ),
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _orderCard(
    BuildContext context,
    OrderModel order,
    AppController app,
    OrdersViewModel vm,
    List<Product> products,
  ) {
    final perm = app.currentPermissionSnapshot;
    final canConfirm = app.permissions.canConfirmOrders(perm);
    final canReceive = app.permissions.canReceiveOrders(perm);
    final pendingBadge = order.status == OrderStatus.pending && canConfirm;
    final confirmable = order.status == OrderStatus.pending && canConfirm;
    final receivable = order.status != OrderStatus.delivered && canReceive;
    final canEditPending = order.status == OrderStatus.pending;

    String itemLine(OrderItem item) {
      final fallback = products.firstWhere(
        (p) => p.id == item.productId,
        orElse: () => Product(
          id: item.productId,
          companyId: '',
          name: 'Deleted product',
          group: '',
          unit: '',
          barQuantity: 0,
          barMax: 0,
          warehouseQuantity: 0,
          warehouseTarget: 0,
        ),
      );
      final name = item.productNameSnapshot ?? fallback.name;
      return '$name - ${item.quantityOrdered}';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        title: Row(
          children: [
            _statusChip(order.status, highlight: pendingBadge),
            const SizedBox(width: 8),
            if (_hasPartial(order))
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
              ),
            Text(
              _orderLabel(order),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        subtitle: Text('Created: ${_formatTs(order.createdAt)}'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ..._groupedItems(order.items, order.supplier).entries.map(
                (entry) {
                  final groupName =
                      (entry.key?.isNotEmpty == true) ? entry.key! : 'Store purchase';
                  final groupItems = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.storefront_outlined, size: 16),
                            const SizedBox(width: 6),
                            Text(groupName, style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ...groupItems.map(
                          (item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    itemLine(item),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 6),
              if (_missingSupplier(order))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                      const SizedBox(width: 6),
                      Text(
                        'Supplier TBD on some items',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                )
              else if (_hasMixedSuppliers(order))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.storefront_outlined, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Mixed suppliers',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                )
              else if ((order.supplier ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.storefront_outlined, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        order.supplier ?? '',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (order.confirmedAt != null)
                    _chip(
                      context,
                      'Confirmed: ${_formatTs(order.confirmedAt!)} by ${order.confirmedBy ?? "?"}',
                    ),
                  if (order.deliveredAt != null)
                    _chip(
                      context,
                      'Received: ${_formatTs(order.deliveredAt!)} by ${order.deliveredBy ?? "?"}',
                    ),
                  if (order.status == OrderStatus.canceled)
                    _chip(context, 'Canceled', color: Colors.red),
                ],
              ),
              if (order.deliveredBy != null && order.deliveredBy!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline, size: 16),
                      const SizedBox(width: 6),
                      Text('Received by ${order.deliveredBy}',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              if (_hasPartial(order)) ...[
                const SizedBox(height: 6),
                _partialInfo(context, order),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (canEditPending)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit items'),
                      onPressed: () => _editOrderItems(context, vm, order),
                    ),
                  if (order.status == OrderStatus.pending)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancel'),
                      onPressed: () => _cancelOrder(context, vm, order, app.displayName),
                    ),
                  if (confirmable)
                    FilledButton.icon(
                      icon: const Icon(Icons.verified),
                      onPressed: () => _confirmFlow(context, vm, order, app),
                      label: const Text('Confirm'),
                    ),
                  if (receivable)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.inventory_2_outlined),
                      onPressed: () => _receiveFlow(context, vm, order),
                      label: const Text('Mark received'),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _orderLabel(OrderModel order) {
    final number = order.orderNumber;
    if (number > 0) {
      final padded = number.toString().padLeft(4, '0');
      return '#$padded';
    }
    return order.id.isEmpty ? 'Order (new)' : 'Order ${order.id}';
  }

  Widget _statusChipFilter(OrderStatus? status, String label) {
    final selected = _statusFilter == status;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _statusFilter = status),
    );
  }

  /* // ignore: unused_element
  Future<void> _openNewOrderSheet({
    required BuildContext context,
    required String companyId,
    required String createdBy,
    required String createdByName,
    required bool canCreate,
  }) async {
    final vmTop = context.read<OrdersViewModel?>();
    final pendingOrders =
        vmTop?.orders.where((o) => o.status == OrderStatus.pending).toList() ?? [];
    OrderModel? targetOrder;
    if (!canCreate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You do not have permission to create orders.')),
      );
      return;
    }
    final suppliers = await _fetchSuppliers(companyId);
    if (!context.mounted) return;
    final manualSupplierCtrl = TextEditingController();
    String? selectedSupplierId;
    bool useManualSupplier = false;
    await showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (ctx) {
        final inventory = ctx.read<InventoryViewModel>().products;
        final vm = ctx.read<OrdersViewModel?>();
        final items = <OrderItem>[];
        final controllers = <TextEditingController>[];
        final suppliersByLine = <String?>[];
        final supplierOptions = [
          const DropdownMenuItem(value: '', child: Text('Store purchase')),
          ...suppliers.map(
            (s) => DropdownMenuItem(value: s.name, child: Text(s.name)),
          ),
        ];

        String defaultSupplierForProduct(String productId) {
          final prod = inventory.firstWhere(
            (p) => p.id == productId,
            orElse: () => Product(
              id: productId,
              companyId: '',
              name: 'Product',
              group: '',
              unit: '',
              barQuantity: 0,
              barMax: 0,
              warehouseQuantity: 0,
              warehouseTarget: 0,
            ),
          );
          return prod.supplierName ?? '';
        }

        void addLine() {
          if (inventory.isEmpty) return;
          final prod = inventory.first;
          controllers.add(TextEditingController(text: '1'));
          items.add(
            OrderItem(
              productId: prod.id,
              productNameSnapshot: prod.name,
              quantityOrdered: 1,
              unitCost: null,
              supplierName: prod.supplierName,
            ),
          );
          suppliersByLine.add(prod.supplierName ?? '');
        }

        if (inventory.isNotEmpty) addLine();

        return StatefulBuilder(
          builder: (sheetCtx, setState) {
            if (vm == null) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Orders are unavailable right now.'),
              );
            }
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (pendingOrders.isNotEmpty) ...[
                      Text('Add to existing or create new',
                          style: Theme.of(sheetCtx).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.playlist_add_check),
                          labelText: 'Target order',
                        ),
                        value: targetOrder?.id ?? '',
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
                              final match =
                                  pendingOrders.where((o) => o.id == v).toList();
                              targetOrder = match.isNotEmpty ? match.first : null;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      'New Order',
                      style: Theme.of(sheetCtx).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Text('Supplier', style: Theme.of(sheetCtx).textTheme.titleSmall),
                    DropdownButtonFormField<String>(
                      initialValue: useManualSupplier ? '__manual' : (selectedSupplierId ?? ''),
                      items: [
                        const DropdownMenuItem(value: '', child: Text('No supplier')),
                        ...suppliers.map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name),
                          ),
                        ),
                        const DropdownMenuItem(
                          value: '__manual',
                          child: Text('Other / store purchase'),
                        ),
                      ],
                      onChanged: (v) {
                        setState(() {
                          if (v == '__manual') {
                            useManualSupplier = true;
                            selectedSupplierId = null;
                          } else {
                            useManualSupplier = false;
                            selectedSupplierId = (v == null || v.isEmpty) ? null : v;
                            manualSupplierCtrl.clear();
                          }
                        });
                      },
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.storefront_outlined),
                        labelText: 'Supplier (optional)',
                      ),
                    ),
                    if (useManualSupplier) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: manualSupplierCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Supplier name (manual)',
                          prefixIcon: Icon(Icons.edit_outlined),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (items.isEmpty) const Text('No products available to order'),
                    ...List.generate(items.length, (i) {
                      final line = items[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                            initialValue: line.productId.isNotEmpty
                                ? line.productId
                                : (inventory.isNotEmpty ? inventory.first.id : null),
                            items: inventory
                                .map(
                                      (p) => DropdownMenuItem(
                                        value: p.id,
                                        child: Text(p.name),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() {
                                    final prod = inventory.firstWhere(
                                      (p) => p.id == v,
                                      orElse: () => inventory.isNotEmpty
                                          ? inventory.first
                                          : Product(
                                              id: v,
                                              companyId: '',
                                              name: 'Product',
                                              group: '',
                                              unit: '',
                                              barQuantity: 0,
                                              barMax: 0,
                                              warehouseQuantity: 0,
                                              warehouseTarget: 0,
                                            ),
                                    );
                                    items[i] = OrderItem(
                                      productId: v,
                                      productNameSnapshot: prod.name,
                                      quantityOrdered: line.quantityOrdered,
                                      unitCost: line.unitCost,
                                      supplierName: suppliersByLine[i]?.isNotEmpty == true
                                          ? suppliersByLine[i]
                                          : prod.supplierName,
                                    );
                                    suppliersByLine[i] = suppliersByLine[i]?.isNotEmpty == true
                                        ? suppliersByLine[i]
                                        : (prod.supplierName ?? '');
                                  });
                                },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Supplier',
                              prefixIcon: Icon(Icons.storefront_outlined),
                            ),
                            initialValue:
                                suppliersByLine[i] ?? defaultSupplierForProduct(line.productId),
                            items: supplierOptions,
                            onChanged: (val) {
                              setState(() {
                                suppliersByLine[i] = val ?? '';
                                items[i] = OrderItem(
                                  productId: items[i].productId,
                                  productNameSnapshot: items[i].productNameSnapshot,
                                  quantityOrdered: items[i].quantityOrdered,
                                  unitCost: items[i].unitCost,
                                  supplierName: suppliersByLine[i],
                                );
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: controllers[i],
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Qty'),
                            onChanged: (v) {
                              final qty = int.tryParse(v) ?? 0;
                              setState(() {
                                items[i] = OrderItem(
                                  productId: line.productId,
                                  productNameSnapshot: line.productNameSnapshot,
                                  quantityOrdered: qty,
                                  unitCost: line.unitCost,
                                  supplierName: suppliersByLine[i],
                                );
                              });
                            },
                          ),
                        ),
                            IconButton(
                              tooltip: 'Remove',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () {
                                setState(() {
                                  items.removeAt(i);
                                  controllers.removeAt(i);
                                  suppliersByLine.removeAt(i);
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                    TextButton.icon(
                      onPressed: inventory.isEmpty ? null : () => setState(addLine),
                      icon: const Icon(Icons.add),
                      label: const Text('Add product'),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.save),
                        label: const Text('Create order'),
                        onPressed: inventory.isEmpty
                            ? null
                            : () async {
                                final filteredItems = items
                                    .where((e) => e.quantityOrdered > 0 && e.productId.isNotEmpty)
                                    .toList();
                                if (filteredItems.isEmpty) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                        content: Text('Add at least one item with quantity')),
                                  );
                                  return;
                                }
                                String? supplierName;
                                if (useManualSupplier) {
                                  supplierName = manualSupplierCtrl.text.trim().isNotEmpty
                                      ? manualSupplierCtrl.text.trim()
                                      : null;
                                } else if (selectedSupplierId != null) {
                                  final found = suppliers.firstWhere(
                                    (s) => s.id == selectedSupplierId,
                                    orElse: () => Supplier(id: selectedSupplierId!, name: ''),
                                  );
                                  supplierName =
                                      found.name.isNotEmpty ? found.name : selectedSupplierId;
                                }
                                await vm.createOrder(
                                  companyId: companyId,
                                  createdByUserId: createdBy,
                                  createdByName: createdByName,
                                  supplier: supplierName,
                                  items: filteredItems,
                                );
                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  */
  Widget _statusChip(OrderStatus status, {bool highlight = false}) {
    Color color;
    String label;
    switch (status) {
      case OrderStatus.pending:
        color = Colors.orange;
        label = 'Pending';
        break;
      case OrderStatus.confirmed:
        color = Colors.blue;
        label = 'Confirmed';
        break;
      case OrderStatus.delivered:
        color = Colors.green;
        label = 'Received';
        break;
      case OrderStatus.canceled:
        color = Colors.red;
        label = 'Canceled';
        break;
    }
    return Chip(
      label: Text(label),
      backgroundColor: highlight ? color : color.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: highlight ? Colors.white : color,
        fontWeight: FontWeight.w600,
      ),
    );
  }
  Future<void> _openNewOrderSheetV2({
    required BuildContext context,
    required String companyId,
    required String createdBy,
    required String createdByName,
    required bool canCreate,
  }) async {
    if (!canCreate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You do not have permission to create orders.')),
      );
      return;
    }
    final vm = context.read<OrdersViewModel?>();
    final inventory = context.read<InventoryViewModel>().products;
    final suppliers = await _fetchSuppliers(companyId);
    if (!context.mounted) return;
    final pendingOrders =
        vm?.orders.where((o) => o.status == OrderStatus.pending).toList() ?? [];
    OrderModel? targetOrder;
    final items = <OrderItem>[];
    final qtyControllers = <TextEditingController>[];
    final supplierByLine = <String?>[];

    void addLine() {
      if (inventory.isEmpty) return;
      final prod = inventory.first;
      items.add(OrderItem(
        productId: prod.id,
        productNameSnapshot: prod.name,
        quantityOrdered: 1,
        unitCost: null,
        supplierName: prod.supplierName,
      ));
      qtyControllers.add(TextEditingController(text: '1'));
      supplierByLine.add(prod.supplierName ?? '');
    }

    if (inventory.isNotEmpty) addLine();

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
              if (vm == null) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Orders are unavailable right now.'),
                );
              }
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
                              final match =
                                  pendingOrders.where((o) => o.id == v).toList();
                              targetOrder = match.isNotEmpty ? match.first : null;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text('Add products', style: Theme.of(sheetCtx).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (items.isEmpty) const Text('No products available'),
                    ...List.generate(items.length, (i) {
                      final line = items[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () async {
                                final picked = await _pickProduct(sheetCtx, inventory);
                                if (picked == null) return;
                                setState(() {
                                  items[i] = OrderItem(
                                    productId: picked.id,
                                    productNameSnapshot: picked.name,
                                    quantityOrdered: line.quantityOrdered,
                                    unitCost: line.unitCost,
                                    supplierName: picked.supplierName,
                                  );
                                  supplierByLine[i] = picked.supplierName ?? '';
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
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Supplier',
                                      prefixIcon: Icon(Icons.storefront_outlined),
                                    ),
                                    initialValue: supplierByLine[i] ?? '',
                                    items: [
                                      const DropdownMenuItem(value: '', child: Text('Store purchase')),
                                      ...suppliers.map(
                                        (s) => DropdownMenuItem(
                                          value: s.name,
                                          child: Text(s.name),
                                        ),
                                      ),
                                    ],
                                    onChanged: (val) {
                                      setState(() {
                                        supplierByLine[i] = val ?? '';
                                        items[i] = OrderItem(
                                          productId: items[i].productId,
                                          productNameSnapshot: items[i].productNameSnapshot,
                                          quantityOrdered: items[i].quantityOrdered,
                                          unitCost: items[i].unitCost,
                                          supplierName: supplierByLine[i],
                                        );
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 80,
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
                                IconButton(
                                  tooltip: 'Remove',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () {
                                    setState(() {
                                      items.removeAt(i);
                                      qtyControllers.removeAt(i);
                                      supplierByLine.removeAt(i);
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    TextButton.icon(
                      onPressed: inventory.isEmpty ? null : () => setState(addLine),
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
                            await vm.createOrder(
                              companyId: companyId,
                              createdByUserId: createdBy,
                              createdByName: createdByName,
                              supplier: null,
                              items: filteredItems,
                            );
                          } else {
                            final merged = _mergeItems(targetOrder!.items, filteredItems);
                            await vm.updateOrderItems(targetOrder!, merged);
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

  bool _hasPartial(OrderModel order) {
    final delivered = order.deliveredQuantities;
    if (delivered == null || delivered.isEmpty) return false;
    for (final item in order.items) {
      final got = delivered[item.productId] ?? item.quantityOrdered;
      if (got != item.quantityOrdered) return true;
    }
    return false;
  }

  bool _hasMixedSuppliers(OrderModel order) {
    final suppliers = order.items
        .map((i) => (i.supplierName ?? '').trim())
        .where((s) => s.isNotEmpty)
        .toSet();
    return suppliers.length > 1;
  }

  bool _missingSupplier(OrderModel order) {
    return order.items.any((i) => (i.supplierName ?? '').isEmpty) &&
        (order.supplier == null || order.supplier!.isEmpty);
  }

  Widget _partialInfo(BuildContext context, OrderModel order) {
    final delivered = order.deliveredQuantities ?? {};
    final warning = Icons.warning_amber_rounded;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(warning, color: Colors.orange),
            const SizedBox(width: 6),
            Text(
              'Partial receipt',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.orange, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...order.items.map((item) {
          final got = delivered[item.productId] ?? item.quantityOrdered;
          final ordered = item.quantityOrdered;
          final color = got < ordered ? Colors.orange : scheme.primary;
          return Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '${item.productNameSnapshot ?? item.productId}: $got / $ordered',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
            ),
          );
        }),
        if ((order.deliveredNote ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Note: ${order.deliveredNote}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurface),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Note: (no comment)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          icon: const Icon(Icons.local_shipping_outlined),
          label: const Text('Receive remaining'),
          onPressed: () => _receiveFlow(context, Provider.of<OrdersViewModel>(context, listen: false), order),
        ),
      ],
    );
  }

  Widget _chip(BuildContext context, String label, {Color? color}) {
    final scheme = Theme.of(context).colorScheme;
    final bg = color?.withValues(alpha: 0.12) ?? scheme.surfaceContainerHighest;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color ?? scheme.onSurface),
      ),
    );
  }

  String _formatTs(DateTime ts) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dd = ts.day.toString().padLeft(2, '0');
    final mm = months[ts.month - 1];
    final yy = (ts.year % 100).toString().padLeft(2, '0');
    final hh = ts.hour.toString().padLeft(2, '0');
    final min = ts.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yy $hh:$min';
  }

  String _exportCsv(List<OrderModel> orders) {
    final buffer = StringBuffer();
    buffer.writeln('Order,Status,Created,Items,CreatedBy,Supplier');
    for (final o in orders) {
      final items = o.items
          .map((i) => '${i.productNameSnapshot ?? i.productId} x${i.quantityOrdered}')
          .join(' | ');
      buffer.writeln(
          '${_orderLabel(o)},${o.status.name},${_formatTs(o.createdAt)},$items,${o.createdByName ?? o.createdByUserId},${o.supplier ?? ''}');
    }
    return buffer.toString();
  }

  String _exportPrintable(List<OrderModel> orders) {
    final buffer = StringBuffer();
    buffer.writeln('ORDERS SUMMARY');
    buffer.writeln('============================');
    for (final o in orders) {
      buffer.writeln(
          '${_orderLabel(o)} | ${o.status.name.toUpperCase()} | ${_formatTs(o.createdAt)} | by ${o.createdByName ?? o.createdByUserId}');
      for (final item in o.items) {
        buffer.writeln('  - ${item.productNameSnapshot ?? item.productId}  x${item.quantityOrdered}');
      }
      if ((o.supplier ?? '').isNotEmpty) buffer.writeln('    Supplier: ${o.supplier}');
      if (o.confirmedAt != null) buffer.writeln('    Confirmed: ${_formatTs(o.confirmedAt!)}');
      if (o.deliveredAt != null) buffer.writeln('    Received: ${_formatTs(o.deliveredAt!)}');
      buffer.writeln('----------------------------');
    }
    return buffer.toString();
  }

  Future<void> _exportAndCopy(
    BuildContext context,
    List<OrderModel> orders,
    _ExportKind kind,
  ) async {
    final text = kind == _ExportKind.csv ? _exportCsv(orders) : _exportPrintable(orders);
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    final label = kind == _ExportKind.csv ? 'CSV' : 'Printable summary';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard')),
    );
  }

  Future<void> _cancelOrder(
    BuildContext context,
    OrdersViewModel vm,
    OrderModel order,
    String canceledBy,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel order'),
        content: Text('Cancel ${_orderLabel(order)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes, cancel')),
        ],
      ),
    );
    if (ok == true) {
      await vm.cancelOrder(order, canceledBy: canceledBy);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Order canceled')));
    }
  }

  Future<void> _editOrderItems(
    BuildContext context,
    OrdersViewModel vm,
    OrderModel order,
  ) async {
    final controllers = order.items
        .map((i) => TextEditingController(text: i.quantityOrdered.toString()))
        .toList();
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Edit order items', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...List.generate(order.items.length, (i) {
                final item = order.items[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(child: Text(item.productNameSnapshot ?? item.productId)),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: controllers[i],
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Qty'),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save'),
                  onPressed: () async {
                    final newItems = <OrderItem>[];
                    for (var i = 0; i < order.items.length; i++) {
                      final qty = int.tryParse(controllers[i].text) ?? 0;
                      newItems.add(OrderItem(
                        productId: order.items[i].productId,
                        productNameSnapshot: order.items[i].productNameSnapshot,
                        quantityOrdered: qty,
                        unitCost: order.items[i].unitCost,
                        supplierName: order.items[i].supplierName,
                      ));
                    }
                    await vm.updateOrderItems(order, newItems);
                    if (!ctx.mounted) return;
                    await Navigator.of(ctx).maybePop();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmFlow(
    BuildContext context,
    OrdersViewModel vm,
    OrderModel order,
    AppController app,
  ) async {
    final companyId = app.activeCompany?.id;
    if (companyId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No active company selected')));
      return;
    }
    final suppliers = await _fetchSuppliers(companyId);
    if (!context.mounted) return;
    String? selectedSupplierId;
    bool useManualSupplier = false;
    final distinctSuppliers = order.items
        .map((i) => (i.supplierName ?? '').trim())
        .where((s) => s.isNotEmpty)
        .toSet();
    final hasMixedSuppliers = distinctSuppliers.length > 1;
    bool keepMixed = hasMixedSuppliers;
    String? seededSupplier = order.supplier;
    // If no order-level supplier and items share one supplier, seed it; otherwise stay mixed.
    if (!hasMixedSuppliers) {
      seededSupplier ??= order.items.firstWhere(
        (i) => (i.supplierName ?? '').isNotEmpty,
        orElse: () => const OrderItem(productId: '', quantityOrdered: 0),
      ).supplierName;
    } else {
      seededSupplier = null;
    }
    if ((seededSupplier ?? '').isNotEmpty) {
      final matchByName = suppliers.where(
        (s) => s.name.toLowerCase() == seededSupplier!.toLowerCase(),
      );
      if (matchByName.isNotEmpty) {
        selectedSupplierId = matchByName.first.id;
      } else {
        useManualSupplier = true;
      }
    }
    final manualCtrl = TextEditingController(
      text: useManualSupplier ? (seededSupplier ?? '') : '',
    );
    final supplierByItem = {
      for (final it in order.items) it.productId: (it.supplierName ?? ''),
    };
    final manualByItem = {
      for (final it in order.items) it.productId: TextEditingController(),
    };
    final products = context.read<InventoryViewModel>().products;
    final result = await showModalBottomSheet<bool>(
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
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Confirm order', style: Theme.of(sheetCtx).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (hasMixedSuppliers)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Suppliers detected in this order:',
                              style: Theme.of(sheetCtx).textTheme.bodyMedium),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: _groupedItems(order.items, null).entries.map((entry) {
                              final label = (entry.key?.isNotEmpty == true)
                                  ? entry.key!
                                  : 'Store purchase';
                              return Chip(
                                label: Text('$label (${entry.value.length} items)'),
                                padding: EdgeInsets.zero,
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Keep per-item suppliers, or choose one to apply to empty lines.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  DropdownButtonFormField<String>(
                    initialValue: useManualSupplier
                        ? '__manual'
                        : (keepMixed
                            ? '__mixed'
                            : (selectedSupplierId ?? '')),
                    items: [
                      if (hasMixedSuppliers)
                        const DropdownMenuItem(
                          value: '__mixed',
                          child: Text('Keep per-item suppliers (mixed)'),
                        ),
                      const DropdownMenuItem(value: '', child: Text('No supplier')),
                      ...suppliers.map(
                        (s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(s.name),
                        ),
                      ),
                      const DropdownMenuItem(
                        value: '__manual',
                        child: Text('Other / store purchase'),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() {
                        if (v == '__manual') {
                          useManualSupplier = true;
                          selectedSupplierId = null;
                          keepMixed = false;
                        } else if (v == '__mixed') {
                          keepMixed = true;
                          useManualSupplier = false;
                          selectedSupplierId = null;
                          manualCtrl.clear();
                        } else {
                          keepMixed = false;
                          useManualSupplier = false;
                          selectedSupplierId = (v == null || v.isEmpty) ? null : v;
                          manualCtrl.clear();
                        }
                      });
                    },
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.storefront_outlined),
                      labelText: 'Supplier (optional)',
                    ),
                  ),
                  if (useManualSupplier) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: manualCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Supplier name (manual)',
                        prefixIcon: Icon(Icons.edit_outlined),
                      ),
                    ),
                  ],
                  if (!keepMixed &&
                      ((useManualSupplier && manualCtrl.text.trim().isNotEmpty) ||
                          (!useManualSupplier && (selectedSupplierId ?? '').isNotEmpty))) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          String? chosen;
                          if (useManualSupplier) {
                            chosen = manualCtrl.text.trim();
                          } else if (selectedSupplierId != null && selectedSupplierId!.isNotEmpty) {
                            final found = suppliers.firstWhere(
                              (s) => s.id == selectedSupplierId,
                              orElse: () =>
                                  Supplier(id: selectedSupplierId!, name: selectedSupplierId!),
                            );
                            chosen = found.name.isNotEmpty ? found.name : selectedSupplierId!;
                          }
                          if (chosen != null && chosen.isNotEmpty) {
                            supplierByItem.updateAll((key, value) {
                              return (value.isEmpty || value == '__manual') ? chosen! : value;
                            });
                            manualByItem.forEach((key, ctrl) {
                              if (ctrl.text.trim().isEmpty && (supplierByItem[key] ?? '').isNotEmpty) {
                                ctrl.clear();
                              }
                            });
                          }
                        });
                      },
                      icon: const Icon(Icons.playlist_add_check),
                      label: const Text('Apply to empty lines'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text('Suppliers per item', style: Theme.of(sheetCtx).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  ...order.items.map((it) {
                    final productName =
                        products.firstWhere((p) => p.id == it.productId, orElse: () => Product(
                          id: it.productId,
                          companyId: '',
                          name: it.productNameSnapshot ?? 'Product',
                          group: '',
                          unit: '',
                          barQuantity: 0,
                          barMax: 0,
                          warehouseQuantity: 0,
                          warehouseTarget: 0,
                        )).name;
                    final key = it.productId;
                    final selected = supplierByItem[key] ?? '';
                    final isManual = selected == '__manual';
                    final preferred = (it.supplierName ?? '').trim();
                    Widget? badge;
                    if (isManual || selected == '__manual') {
                      badge = _chip(sheetCtx, 'Manual', color: Colors.blueGrey);
                    } else if (selected.isEmpty) {
                      badge = _chip(sheetCtx, 'TBD', color: Colors.orange);
                    } else if (preferred.isNotEmpty && preferred == selected) {
                      badge = _chip(sheetCtx, 'Preferred', color: Colors.green);
                    } else if (preferred.isNotEmpty && preferred != selected) {
                      badge = _chip(sheetCtx, 'Changed', color: Colors.amber);
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  productName,
                                  style: Theme.of(sheetCtx).textTheme.bodyLarge,
                                ),
                              ),
                              if (badge != null) badge,
                            ],
                          ),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Preferred supplier',
                              prefixIcon: Icon(Icons.storefront_outlined),
                            ),
                            key: ValueKey('confirm-supplier-$key-$selected'),
                            initialValue: isManual ? '__manual' : (selected.isNotEmpty ? selected : null),
                            items: [
                              const DropdownMenuItem(value: '', child: Text('Store purchase / none')),
                              ...suppliers.map(
                                (s) => DropdownMenuItem(
                                  value: s.name,
                                  child: Row(
                                    children: [
                                      if (s.name == (it.supplierName ?? ''))
                                        const Icon(Icons.star, size: 16, color: Colors.amber),
                                      Text(s.name),
                                    ],
                                  ),
                                ),
                              ),
                              const DropdownMenuItem(
                                value: '__manual',
                                child: Text('Other (manual)'),
                              ),
                            ],
                            onChanged: (val) {
                              setState(() {
                                supplierByItem[key] = val ?? '';
                                if (val != '__manual') {
                                  manualByItem[key]?.clear();
                                }
                              });
                            },
                          ),
                          if (isManual) ...[
                            const SizedBox(height: 6),
                            TextField(
                              controller: manualByItem[key],
                              decoration: const InputDecoration(
                                labelText: 'Manual supplier',
                                prefixIcon: Icon(Icons.edit_outlined),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.verified),
                      label: const Text('Confirm'),
                      onPressed: () async {
                        // Build updated items from per-line selections; default remains existing.
                        final updatedItems = order.items.map((it) {
                          final sel = supplierByItem[it.productId] ?? (it.supplierName ?? '');
                          if (sel == '__manual') {
                            final manual = manualByItem[it.productId]?.text.trim() ?? '';
                            return OrderItem(
                              productId: it.productId,
                              productNameSnapshot: it.productNameSnapshot,
                              quantityOrdered: it.quantityOrdered,
                              unitCost: it.unitCost,
                              supplierName: manual.isNotEmpty ? manual : null,
                            );
                          }
                          return OrderItem(
                            productId: it.productId,
                            productNameSnapshot: it.productNameSnapshot,
                            quantityOrdered: it.quantityOrdered,
                            unitCost: it.unitCost,
                            supplierName: sel.isNotEmpty ? sel : null,
                          );
                        }).toList();

                        // If all items share one supplier after edits, set order-level supplier.
                        final distinctAfter = updatedItems
                            .map((i) => (i.supplierName ?? '').trim())
                            .where((s) => s.isNotEmpty)
                            .toSet();
                        final orderSupplier =
                            distinctAfter.length == 1 ? distinctAfter.first : order.supplier;

                        await vm.updateOrderItems(order.copyWith(supplier: orderSupplier), updatedItems);
                        await vm.confirmOrder(
                          order,
                          confirmedBy: app.displayName,
                          supplier: orderSupplier,
                        );
                        if (ctx.mounted) Navigator.of(ctx).pop(true);
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    manualCtrl.dispose();
    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${_orderLabel(order)} confirmed')));
    }
  }

  Future<void> _receiveFlow(
    BuildContext context,
    OrdersViewModel vm,
    OrderModel order,
  ) async {
    final receivedBy = context.read<AppController>().displayName;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Everything arrived?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
        ],
      ),
    );
    if (yes == true) {
      await vm.markReceived(order, deliveredBy: receivedBy);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_orderLabel(order)} marked received')),
        );
      }
      return;
    }
    // Partial receive dialog
    for (final item in order.items) {
      _receiveControllers[item.productId] =
          TextEditingController(text: item.quantityOrdered.toString());
    }
    _receiveNoteCtrl.clear();
    if (!context.mounted) return;
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Partial receipt', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...order.items.map((item) {
                final ctrl = _receiveControllers[item.productId]!;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(child: Text(item.productNameSnapshot ?? item.productId)),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: ctrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Arrived / ${item.quantityOrdered}',
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              TextField(
                controller: _receiveNoteCtrl,
                decoration: const InputDecoration(labelText: 'Comment (optional)'),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save'),
                  onPressed: () async {
                    final map = <String, int>{};
                    for (final item in order.items) {
                      map[item.productId] = int.tryParse(
                            _receiveControllers[item.productId]?.text ?? '',
                          ) ??
                          0;
                    }
                    await vm.markReceivedWithDetails(
                      order,
                      receivedQuantities: map,
                      note: _receiveNoteCtrl.text.trim().isEmpty
                          ? null
                          : _receiveNoteCtrl.text.trim(),
                      deliveredBy: receivedBy,
                    );
                    if (ctx.mounted) {
                      await Navigator.of(ctx).maybePop();
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<List<Supplier>> _fetchSuppliers(String companyId) async {
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

  Map<String?, List<OrderItem>> _groupedItems(List<OrderItem> items, String? orderSupplier) {
    final map = <String?, List<OrderItem>>{};
    for (final item in items) {
      final key = (item.supplierName?.isNotEmpty == true)
          ? item.supplierName
          : (orderSupplier?.isNotEmpty == true ? orderSupplier : '');
      map.putIfAbsent(key, () => []);
      map[key]!.add(item);
    }
    return map;
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

  Future<Product?> _pickProduct(BuildContext context, List<Product> products) async {
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
                        final isHalfBar = p.barMax > 0 && p.barQuantity < (p.barMax * 0.7) && !isLowBar;
                        final lowBadge = isLowBar
                            ? Chip(
                                label: const Text('Low'),
                                backgroundColor: Colors.red.withValues(alpha: 0.15),
                                labelStyle: const TextStyle(color: Colors.red),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              )
                            : isHalfBar
                                ? Chip(
                                    label: const Text('Half'),
                                    backgroundColor: Colors.amber.withValues(alpha: 0.2),
                                    labelStyle: const TextStyle(color: Colors.amber),
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  )
                                : null;
                        return ListTile(
                          title: Text(p.name),
                          subtitle: Text(
                            [
                              p.group,
                              if ((p.supplierName ?? '').isNotEmpty) 'Supplier: ${p.supplierName}'
                            ].whereType<String>().join(' • '),
                          ),
                          trailing: lowBadge,
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
}

enum _ExportKind { csv, printable }
