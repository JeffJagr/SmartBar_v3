import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/order.dart';
import '../utils/firestore_error_handler.dart';

class NetworkOrderPage {
  NetworkOrderPage({
    required this.orders,
    required this.lastDocument,
    required this.hasMore,
  });

  final List<OrderModel> orders;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;
}

class NetworkOrdersRepository {
  NetworkOrdersRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<NetworkOrderPage> fetchOrders({
    required List<String> companyIds,
    List<OrderStatus>? statuses,
    String? supplier,
    String? productQuery,
    DateTime? startDate,
    DateTime? endDate,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 20,
  }) {
    return FirestoreErrorHandler.guard(
      operation: 'fetchNetworkOrders',
      path: 'collectionGroup/orders',
      run: () async {
        if (companyIds.isEmpty) {
          return NetworkOrderPage(orders: const [], lastDocument: null, hasMore: false);
        }
        // Firestore whereIn supports max 10 values; trim to first 10 for now.
        final scopedCompanies = companyIds.take(10).toList();
        Query<Map<String, dynamic>> q =
            _firestore.collectionGroup('orders').where('companyId', whereIn: scopedCompanies);

        if (statuses != null && statuses.isNotEmpty) {
          q = q.where('status', whereIn: statuses.map((s) => s.name).toList());
        }
        if (supplier != null && supplier.isNotEmpty) {
          q = q.where('supplier', isEqualTo: supplier);
        }
        if (startDate != null) {
          q = q.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
        }
        if (endDate != null) {
          q = q.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
        }
        q = q.orderBy('createdAt', descending: true);
        if (startAfter != null) {
          q = q.startAfterDocument(startAfter);
        }

        final snap = await q.limit(limit).get();
        var orders = snap.docs.map((d) => OrderModel.fromFirestore(d)).toList();

        if (productQuery != null && productQuery.isNotEmpty) {
          final term = productQuery.toLowerCase();
          orders = orders
              .where(
                (o) => o.items.any(
                  (item) =>
                      (item.productNameSnapshot ?? '').toLowerCase().contains(term) ||
                      item.productId.toLowerCase().contains(term),
                ),
              )
              .toList();
        }

        return NetworkOrderPage(
          orders: orders,
          lastDocument: snap.docs.isNotEmpty ? snap.docs.last : null,
          hasMore: snap.docs.length == limit,
        );
      },
    );
  }
}
