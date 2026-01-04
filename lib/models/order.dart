import 'package:cloud_firestore/cloud_firestore.dart';

class OrderItem {
  const OrderItem({
    required this.productId,
    required this.quantityOrdered,
    this.productNameSnapshot,
    this.unitCost,
    this.supplierName,
  });

  final String productId;
  final int quantityOrdered;
  final String? productNameSnapshot;
  final double? unitCost;
  final String? supplierName;

  factory OrderItem.fromMap(Map<String, dynamic> data) {
    return OrderItem(
      productId: data['productId'] as String? ?? '',
      quantityOrdered:
          (data['quantityOrdered'] as num?)?.toInt() ?? (data['quantity'] as num?)?.toInt() ?? 0,
      productNameSnapshot: data['productNameSnapshot'] as String?,
      unitCost: (data['unitCost'] as num?)?.toDouble(),
      supplierName: data['supplierName'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'quantityOrdered': quantityOrdered,
      if (productNameSnapshot != null) 'productNameSnapshot': productNameSnapshot,
      // Write legacy key for backward compatibility.
      'quantity': quantityOrdered,
      if (unitCost != null) 'unitCost': unitCost,
      if (supplierName != null) 'supplierName': supplierName,
    };
  }
}

enum OrderStatus {
  pending,
  confirmed,
  delivered,
  canceled,
}

class OrderModel {
  OrderModel({
    required this.id,
    required this.companyId,
    required this.orderNumber,
    required this.createdByUserId,
    required this.status,
    required this.items,
    DateTime? createdAt,
    this.supplier,
    this.createdByName,
    this.confirmedAt,
    this.confirmedBy,
    this.deliveredAt,
    this.deliveredBy,
    this.deliveredQuantities,
    this.deliveredNote,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String companyId;
  final int orderNumber;
  final String? supplier;
  final String createdByUserId;
  final String? createdByName;
  final OrderStatus status;
  final List<OrderItem> items;
  final DateTime createdAt;
  final DateTime? confirmedAt;
  final String? confirmedBy;
  final DateTime? deliveredAt;
  final String? deliveredBy;
  final Map<String, int>? deliveredQuantities;
  final String? deliveredNote;

  factory OrderModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return OrderModel.fromMap(doc.id, doc.data() ?? {});
  }

  factory OrderModel.fromMap(String id, Map<String, dynamic> data) {
    return OrderModel(
      id: id,
      companyId: data['companyId'] as String? ?? '',
      orderNumber: (data['orderNumber'] as num?)?.toInt() ?? 0,
      createdByUserId: data['createdByUserId'] as String? ?? '',
      supplier: data['supplier'] as String?,
      createdByName: data['createdByName'] as String?,
      status: _statusFromString(data['status'] as String?),
      items: (data['items'] as List<dynamic>? ?? [])
          .map((e) => OrderItem.fromMap((e as Map).cast<String, dynamic>()))
          .toList(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      confirmedAt: (data['confirmedAt'] as Timestamp?)?.toDate(),
      confirmedBy: data['confirmedBy'] as String?,
      deliveredAt: (data['deliveredAt'] as Timestamp?)?.toDate(),
      deliveredBy: data['deliveredBy'] as String?,
      deliveredQuantities: (data['deliveredQuantities'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, (v as num).toInt())),
      deliveredNote: data['deliveredNote'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'orderNumber': orderNumber,
      'createdByUserId': createdByUserId,
      if (createdByName != null) 'createdByName': createdByName,
      if (supplier != null) 'supplier': supplier,
      'status': status.name,
      'items': items.map((e) => e.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      if (confirmedAt != null) 'confirmedAt': Timestamp.fromDate(confirmedAt!),
      if (confirmedBy != null) 'confirmedBy': confirmedBy,
      if (deliveredAt != null) 'deliveredAt': Timestamp.fromDate(deliveredAt!),
      if (deliveredBy != null) 'deliveredBy': deliveredBy,
      if (deliveredQuantities != null) 'deliveredQuantities': deliveredQuantities,
      if (deliveredNote != null) 'deliveredNote': deliveredNote,
    };
  }

  OrderModel copyWith({
    OrderStatus? status,
    List<OrderItem>? items,
    String? createdByUserId,
    int? orderNumber,
    String? supplier,
    String? confirmedBy,
    DateTime? confirmedAt,
    String? deliveredBy,
    DateTime? deliveredAt,
    Map<String, int>? deliveredQuantities,
    String? deliveredNote,
  }) {
    return OrderModel(
      id: id,
      companyId: companyId,
      orderNumber: orderNumber ?? this.orderNumber,
      supplier: supplier ?? this.supplier,
      status: status ?? this.status,
      items: items ?? this.items,
      createdAt: createdAt,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      createdByName: createdByName,
      confirmedBy: confirmedBy ?? this.confirmedBy,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      deliveredBy: deliveredBy ?? this.deliveredBy,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      deliveredQuantities: deliveredQuantities ?? this.deliveredQuantities,
      deliveredNote: deliveredNote ?? this.deliveredNote,
    );
  }

  static OrderStatus _statusFromString(String? value) {
    switch (value) {
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'delivered':
        return OrderStatus.delivered;
      case 'canceled':
        return OrderStatus.canceled;
      default:
        return OrderStatus.pending;
    }
  }
}
