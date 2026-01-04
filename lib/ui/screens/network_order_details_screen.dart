import 'package:flutter/material.dart';

import '../../models/order.dart';
import '../../models/company.dart';

class NetworkOrderDetailsScreen extends StatelessWidget {
  const NetworkOrderDetailsScreen({
    super.key,
    required this.order,
    required this.company,
  });

  final OrderModel order;
  final Company? company;

  @override
  Widget build(BuildContext context) {
    final supplier = order.supplier?.isNotEmpty == true ? order.supplier! : 'No supplier';
    return Scaffold(
      appBar: AppBar(
        title: Text('#${order.orderNumber.toString().padLeft(4, '0')} • $supplier'),
        bottom: company != null
            ? PreferredSize(
                preferredSize: const Size.fromHeight(28),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    company!.name,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              )
            : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusPill(status: order.status),
            const SizedBox(height: 8),
            Text('Created: ${order.createdAt.toLocal()}'),
            if (order.confirmedAt != null)
              Text('Confirmed: ${order.confirmedAt!.toLocal()} by ${order.confirmedBy ?? ''}'),
            if (order.deliveredAt != null)
              Text('Delivered: ${order.deliveredAt!.toLocal()} by ${order.deliveredBy ?? ''}'),
            const Divider(height: 24),
            Text('Line items', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: order.items.length,
                separatorBuilder: (_, index) => const Divider(height: 16),
                itemBuilder: (context, index) {
                  final item = order.items[index];
                  return ListTile(
                    title: Text(item.productNameSnapshot ?? item.productId),
                    subtitle:
                        item.supplierName != null ? Text('Supplier: ${item.supplierName}') : null,
                    trailing: Text('x${item.quantityOrdered}'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case OrderStatus.pending:
        color = Colors.amber;
        break;
      case OrderStatus.confirmed:
        color = Colors.blue;
        break;
      case OrderStatus.delivered:
        color = Colors.green;
        break;
      case OrderStatus.canceled:
        color = Colors.grey;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(status.name, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }
}
