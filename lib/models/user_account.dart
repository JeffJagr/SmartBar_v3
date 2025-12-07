import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { owner, manager, staff }

class UserAccount {
  const UserAccount({
    required this.id,
    required this.companyId,
    required this.displayName,
    required this.role,
    required this.active,
  });

  final String id;
  final String companyId;
  final String displayName;
  final UserRole role;
  final bool active;

  factory UserAccount.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return UserAccount.fromMap(doc.id, doc.data() ?? {});
  }

  factory UserAccount.fromMap(String id, Map<String, dynamic> data) {
    return UserAccount(
      id: id,
      companyId: data['companyId'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      role: _roleFromString(data['role'] as String?),
      active: data['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'displayName': displayName,
      'role': role.name,
      'active': active,
    };
  }

  static UserRole _roleFromString(String? value) {
    switch (value) {
      case 'manager':
        return UserRole.manager;
      case 'owner':
        return UserRole.owner;
      default:
        return UserRole.staff;
    }
  }
}
