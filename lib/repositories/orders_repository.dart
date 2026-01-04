import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/order.dart';
import '../utils/firestore_error_handler.dart';

abstract class OrdersRepository {
  Stream<List<OrderModel>> watchOrders();
  Future<void> createOrder(OrderModel order);
  Future<void> updateStatus(
    String orderId,
    OrderStatus status, {
    String? confirmedBy,
    DateTime? confirmedAt,
    String? deliveredBy,
    DateTime? deliveredAt,
    Map<String, int>? deliveredQuantities,
    String? deliveredNote,
    String? supplier,
  });

  Future<void> updateItems(String orderId, List<OrderItem> items);
}

class FirestoreOrdersRepository implements OrdersRepository {
  FirestoreOrdersRepository({required this.companyId, FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final String companyId;
  final FirebaseFirestore _firestore;

  String get path => _col.path;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('companies').doc(companyId).collection('orders');
  DocumentReference<Map<String, dynamic>> get _counterDoc => _firestore
      .collection('companies')
      .doc(companyId)
      .collection('meta')
      .doc('orders_counter');

  @override
  Stream<List<OrderModel>> watchOrders() {
    return _col.orderBy('createdAt', descending: true).snapshots().map(
          (snap) => snap.docs.map((d) => OrderModel.fromFirestore(d)).toList(),
        );
  }

  @override
  Future<void> createOrder(OrderModel order) {
    return FirestoreErrorHandler.guard(
      operation: 'createOrder',
      path: path,
      run: () => _firestore.runTransaction((txn) async {
        final counterSnap = await txn.get(_counterDoc);
        final last = (counterSnap.data()?['last'] as num?)?.toInt() ?? 0;
        final next = last + 1;
        txn.set(_counterDoc, {'last': next});

        final data = order.copyWith(orderNumber: next).toMap();
        data['companyId'] = companyId;
        final newDoc = _col.doc();
        txn.set(newDoc, data);
      }),
    );
  }

  @override
  Future<void> updateStatus(
    String orderId,
    OrderStatus status, {
    String? confirmedBy,
    DateTime? confirmedAt,
    String? deliveredBy,
    DateTime? deliveredAt,
    Map<String, int>? deliveredQuantities,
    String? deliveredNote,
    String? supplier,
  }) {
    return FirestoreErrorHandler.guard(
      operation: 'updateOrderStatus',
      path: '$path/$orderId',
      run: () {
        final data = <String, dynamic>{
          'status': status.name,
        };
        if (confirmedBy != null) data['confirmedBy'] = confirmedBy;
        if (confirmedAt != null) data['confirmedAt'] = Timestamp.fromDate(confirmedAt);
        if (deliveredBy != null) data['deliveredBy'] = deliveredBy;
        if (deliveredAt != null) data['deliveredAt'] = Timestamp.fromDate(deliveredAt);
        if (deliveredQuantities != null) data['deliveredQuantities'] = deliveredQuantities;
        if (deliveredNote != null) data['deliveredNote'] = deliveredNote;
        if (supplier != null) data['supplier'] = supplier;
        return _col.doc(orderId).update(data);
      },
    );
  }

  @override
  Future<void> updateItems(String orderId, List<OrderItem> items) {
    return FirestoreErrorHandler.guard(
      operation: 'updateOrderItems',
      path: '$path/$orderId',
      run: () => _col.doc(orderId).update({
        'items': items.map((e) => e.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
  }
}
