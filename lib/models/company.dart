import 'package:cloud_firestore/cloud_firestore.dart';

class Company {
  const Company({
    required this.id,
    required this.name,
    required this.companyCode,
    required this.ownerIds,
    this.notificationLowStock = true,
    this.notificationOrderApprovals = true,
    this.notificationStaff = false,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String companyCode;
  final List<String> ownerIds;
  final bool notificationLowStock;
  final bool notificationOrderApprovals;
  final bool notificationStaff;
  final DateTime createdAt;

  factory Company.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Company.fromMap(doc.id, doc.data() ?? {});
  }

  factory Company.fromMap(String id, Map<String, dynamic> data) {
    final map = Map<String, dynamic>.from(data);
    final ownerIdsRaw = map['ownerIds'];
    final List<String> parsedOwnerIds = ownerIdsRaw is List
        ? ownerIdsRaw.whereType<String>().toList()
        : (map['ownerId'] is String ? [map['ownerId'] as String] : <String>[]);

    return Company(
      id: id,
      name: map['name'] as String? ?? '',
      companyCode: map['companyCode'] as String? ??
          map['code'] as String? ?? // fallback for legacy field
          '',
      ownerIds: parsedOwnerIds,
      notificationLowStock: map['notificationLowStock'] as bool? ?? true,
      notificationOrderApprovals: map['notificationOrderApprovals'] as bool? ?? true,
      notificationStaff: map['notificationStaff'] as bool? ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'companyCode': companyCode,
      'ownerIds': ownerIds,
      'notificationLowStock': notificationLowStock,
      'notificationOrderApprovals': notificationOrderApprovals,
      'notificationStaff': notificationStaff,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
