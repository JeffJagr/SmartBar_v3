import 'package:cloud_firestore/cloud_firestore.dart';

class OrderItem {
  const OrderItem({
    required this.productId,
    required this.quantity,
    this.unitCost,
  });

  final String productId;
  final int quantity;
  final double? unitCost;

  factory OrderItem.fromMap(Map<String, dynamic> data) {
    return OrderItem(
      productId: data['productId'] as String? ?? '',
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      unitCost: (data['unitCost'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'quantity': quantity,
      if (unitCost != null) 'unitCost': unitCost,
    };
  }
}

enum OrderStatus {
  pending,
  confirmed,
  delivered,
}

class OrderModel {
  const OrderModel({
    required this.id,
    required this.companyId,
    required this.createdByUserId,
    required this.status,
    required this.items,
    required this.createdAt,
    this.supplier,
  });

  final String id;
  final String companyId;
  final String? supplier;
  final String createdByUserId;
  final OrderStatus status;
  final List<OrderItem> items;
  final DateTime createdAt;

  factory OrderModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return OrderModel.fromMap(doc.id, doc.data() ?? {});
  }

  factory OrderModel.fromMap(String id, Map<String, dynamic> data) {
    return OrderModel(
      id: id,
      companyId: data['companyId'] as String? ?? '',
      createdByUserId: data['createdByUserId'] as String? ?? '',
      supplier: data['supplier'] as String?,
      status: _statusFromString(data['status'] as String?),
      items: (data['items'] as List<dynamic>? ?? [])
          .map((e) => OrderItem.fromMap((e as Map).cast<String, dynamic>()))
          .toList(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'createdByUserId': createdByUserId,
      if (supplier != null) 'supplier': supplier,
      'status': status.name,
      'items': items.map((e) => e.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  OrderModel copyWith({
    OrderStatus? status,
    List<OrderItem>? items,
    String? createdByUserId,
  }) {
    return OrderModel(
      id: id,
      companyId: companyId,
      supplier: supplier,
      status: status ?? this.status,
      items: items ?? this.items,
      createdAt: createdAt,
      createdByUserId: createdByUserId ?? this.createdByUserId,
    );
  }

  static OrderStatus _statusFromString(String? value) {
    switch (value) {
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'delivered':
        return OrderStatus.delivered;
      default:
        return OrderStatus.pending;
    }
  }
}
