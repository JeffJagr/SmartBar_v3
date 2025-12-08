import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/app_controller.dart';
import '../../models/order.dart';
import '../../models/product.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrdersViewModel>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OrdersViewModel>();
    final app = context.watch<AppController>();
    final company = app.activeCompany;
    final products = context.watch<InventoryViewModel>().products;

    if (vm.loading && vm.orders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.error != null) {
      return Center(child: Text('Error: ${vm.error}'));
    }

    final orders = vm.orders
        .where((o) => _statusFilter == null || o.status == _statusFilter)
        .toList()
      ..sort((a, b) => _sortDescending
          ? b.createdAt.compareTo(a.createdAt)
          : a.createdAt.compareTo(b.createdAt));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    _statusChipFilter(null, 'All'),
                    _statusChipFilter(OrderStatus.pending, 'Pending'),
                    _statusChipFilter(OrderStatus.confirmed, 'Confirmed'),
                    _statusChipFilter(OrderStatus.delivered, 'Delivered'),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: _sortDescending ? 'Newest first' : 'Oldest first',
                    onPressed: () => setState(() => _sortDescending = !_sortDescending),
                    icon: Icon(_sortDescending ? Icons.arrow_downward : Icons.arrow_upward),
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
      floatingActionButton: FloatingActionButton(
        onPressed: company == null
            ? null
            : () => _openNewOrderSheet(
                  context: context,
                  companyId: company.id,
                  createdBy: app.ownerUser?.uid ?? app.currentStaff?.id ?? 'anon',
                  createdByName: app.displayName,
                ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _orderCard(BuildContext context, OrderModel order, AppController app,
      OrdersViewModel vm, List<Product> products) {
    final perm = app.currentPermissionSnapshot;
    final canConfirm = app.permissions.canConfirmOrders(perm);
    final canReceive = app.permissions.canReceiveOrders(perm);
    String itemLine(OrderItem item) {
      final name = item.productNameSnapshot ??
          products.firstWhere(
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
          ).name;
      return '$name × ${item.quantityOrdered}';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        title: Row(
          children: [
            _statusChip(order.status),
            const SizedBox(width: 8),
            Text(_orderLabel(order)),
          ],
        ),
        subtitle: Text('Created: ${order.createdAt}'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...order.items.map((item) => Text(
                    '• ${itemLine(item)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  )),
              if (order.confirmedAt != null) Text('Confirmed: ${order.confirmedAt}'),
              if (order.deliveredAt != null) Text('Delivered: ${order.deliveredAt}'),
              Row(
                children: [
                  if (order.status == OrderStatus.pending && canConfirm)
                    TextButton(
                      onPressed: () => vm.confirmOrder(
                        order,
                        confirmedBy: app.displayName,
                      ),
                      child: const Text('Confirm'),
                    ),
                  if (order.status != OrderStatus.delivered && canReceive)
                    TextButton(
                      onPressed: () async {
                        await vm.markReceived(order);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Warehouse updated from ${_orderLabel(order)}'),
                            ),
                          );
                        }
                      },
                      child: const Text('Mark received'),
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

  void _openNewOrderSheet({
    required BuildContext context,
    required String companyId,
    required String createdBy,
    required String createdByName,
  }) {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (ctx) {
        final inventory = ctx.read<InventoryViewModel>().products;
        final vm = ctx.read<OrdersViewModel>();
        final items = <OrderItem>[];
        final controllers = <TextEditingController>[];

        void addLine() {
          controllers.add(TextEditingController());
          items.add(
            OrderItem(
              productId: inventory.isNotEmpty ? inventory.first.id : '',
              productNameSnapshot: inventory.isNotEmpty ? inventory.first.name : '',
              quantityOrdered: 0,
              unitCost: null,
            ),
          );
        }

        if (inventory.isNotEmpty) addLine();

        return StatefulBuilder(
          builder: (sheetCtx, setState) {
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
                    Text(
                      'New Order',
                      style: Theme.of(sheetCtx).textTheme.titleMedium,
                    ),
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
                                      orElse: () => inventory.first,
                                    );
                                    items[i] = OrderItem(
                                      productId: v,
                                      productNameSnapshot: prod.name,
                                      quantityOrdered: line.quantityOrdered,
                                      unitCost: line.unitCost,
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
                                    );
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    TextButton.icon(
                      onPressed: () => setState(addLine),
                      icon: const Icon(Icons.add),
                      label: const Text('Add product'),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.save),
                        label: const Text('Create order'),
                        onPressed: () async {
                          final filteredItems = items
                              .where((e) => e.quantityOrdered > 0 && e.productId.isNotEmpty)
                              .toList();
                          if (filteredItems.isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Add at least one item with quantity')),
                            );
                            return;
                          }
                          await vm.createOrder(
                            companyId: companyId,
                            createdByUserId: createdBy,
                            createdByName: createdByName,
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

  Widget _statusChip(OrderStatus status) {
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
    }
    return Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.15),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
    );
  }
}
