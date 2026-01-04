import 'package:cloud_firestore/cloud_firestore.dart';

/// Canonical membership document stored at companies/{companyId}/members/{uid}.
class Member {
  const Member({
    required this.id,
    required this.companyId,
    required this.role,
    this.permissions = const {},
    this.active = true,
    this.displayName,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String companyId;
  final String role; // 'owner' | 'manager' | 'staff'
  final Map<String, bool> permissions;
  final bool active;
  final String? displayName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Member.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Member.fromMap(doc.id, doc.data() ?? {});
  }

  factory Member.fromMap(String id, Map<String, dynamic> data) {
    return Member(
      id: id,
      companyId: data['companyId'] as String? ?? '',
      role: (data['role'] as String? ?? 'staff').toLowerCase(),
      permissions: (data['permissions'] as Map?)?.cast<String, bool>() ?? const {},
      active: data['active'] as bool? ?? true,
      displayName: data['displayName'] as String?,
      createdAt: _toDateTime(data['createdAt']),
      updatedAt: _toDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap({bool includeTimestamps = true}) {
    return {
      'companyId': companyId,
      'role': role,
      'permissions': permissions,
      'active': active,
      if (displayName != null) 'displayName': displayName,
      if (includeTimestamps) 'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Member copyWith({
    String? role,
    Map<String, bool>? permissions,
    bool? active,
    String? displayName,
  }) {
    return Member(
      id: id,
      companyId: companyId,
      role: role ?? this.role,
      permissions: permissions ?? this.permissions,
      active: active ?? this.active,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
