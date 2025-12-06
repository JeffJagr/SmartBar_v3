import 'package:cloud_firestore/cloud_firestore.dart';

class StaffMember {
  const StaffMember({
    required this.id,
    required this.companyId,
    required this.name,
    required this.pin,
    required this.role,
  });

  final String id;
  final String companyId;
  final String name;
  final String pin;
  final String role;

  factory StaffMember.fromMap(String id, Map<String, dynamic> data) {
    return StaffMember(
      id: id,
      companyId: data['companyId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      pin: data['pin'] as String? ?? '',
      role: data['role'] as String? ?? 'Worker',
    );
  }

  factory StaffMember.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return StaffMember.fromMap(doc.id, doc.data() ?? {});
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'name': name,
      'pin': pin,
      'role': role,
    };
  }
}
