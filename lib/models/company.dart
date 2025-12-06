import 'package:cloud_firestore/cloud_firestore.dart';

class Company {
  const Company({
    required this.id,
    required this.name,
    required this.companyCode,
    required this.ownerIds,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String companyCode;
  final List<String> ownerIds;
  final DateTime createdAt;

  factory Company.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Company.fromMap(doc.id, doc.data() ?? {});
  }

  factory Company.fromMap(String id, Map<String, dynamic> data) {
    return Company(
      id: id,
      name: data['name'] as String? ?? '',
      companyCode: data['companyCode'] as String? ??
          data['code'] as String? ?? // fallback for legacy field
          '',
      ownerIds: (data['ownerIds'] as List<dynamic>? ?? []).cast<String>(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'companyCode': companyCode,
      'ownerIds': ownerIds,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
