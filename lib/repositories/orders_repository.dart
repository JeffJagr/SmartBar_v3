import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/order.dart';

abstract class OrdersRepository {
  Stream<List<OrderModel>> watchOrders();
  Future<void> createOrder(OrderModel order);
  Future<void> updateStatus(String orderId, OrderStatus status);
}

class FirestoreOrdersRepository implements OrdersRepository {
  FirestoreOrdersRepository({required this.companyId, FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final String companyId;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('companies').doc(companyId).collection('orders');

  @override
  Stream<List<OrderModel>> watchOrders() {
    return _col.orderBy('createdAt', descending: true).snapshots().map(
          (snap) => snap.docs.map((d) => OrderModel.fromFirestore(d)).toList(),
        );
  }

  @override
  Future<void> createOrder(OrderModel order) {
    final data = order.toMap();
    data['companyId'] = companyId;
    return _col.add(data);
  }

  @override
  Future<void> updateStatus(String orderId, OrderStatus status) {
    return _col.doc(orderId).update({'status': status.name});
  }
}
