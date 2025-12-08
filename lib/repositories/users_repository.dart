import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_account.dart';

abstract class UsersRepository {
  Stream<List<UserAccount>> watchUsers();
  Future<void> addUser(UserAccount user);
  Future<void> updateRole(String userId, UserRole role);
  Future<void> deactivate(String userId, bool active);
  Future<void> updatePermissions(String userId, Map<String, bool> permissions);
  Future<void> deleteUser(String userId);
}

class FirestoreUsersRepository implements UsersRepository {
  FirestoreUsersRepository({required this.companyId, FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final String companyId;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('companies').doc(companyId).collection('users');

  @override
  Stream<List<UserAccount>> watchUsers() {
    return _col.snapshots().map(
          (snap) => snap.docs.map((d) => UserAccount.fromFirestore(d)).toList(),
        );
  }

  @override
  Future<void> addUser(UserAccount user) async {
    final data = user.toMap();
    data['companyId'] = companyId;
    final id = user.id.isNotEmpty ? user.id : null;
    if (id != null) {
      await _col.doc(id).set(data);
      await _firestore.collection('users').doc(id).set({
        'companyId': companyId,
        'displayName': user.displayName,
        'role': user.role.name,
        'active': user.active,
        if (user.email != null) 'email': user.email,
        if (user.permissions.isNotEmpty) 'permissions': user.permissions,
      });
    } else {
      await _col.add(data);
    }
  }

  @override
  Future<void> updateRole(String userId, UserRole role) {
    return _col.doc(userId).update({'role': role.name});
  }

  @override
  Future<void> deactivate(String userId, bool active) {
    return _col.doc(userId).update({'active': active});
  }

  @override
  Future<void> updatePermissions(String userId, Map<String, bool> permissions) {
    return _col.doc(userId).update({'permissions': permissions});
  }

  @override
  Future<void> deleteUser(String userId) {
    return _col.doc(userId).delete();
  }
}
