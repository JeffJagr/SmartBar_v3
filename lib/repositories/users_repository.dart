import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_account.dart';
import '../models/member.dart';
import '../utils/pin_hasher.dart';
import '../utils/firestore_error_handler.dart';

abstract class UsersRepository {
  Stream<List<UserAccount>> watchUsers();
  Future<void> addUser(UserAccount user);
  Future<void> updateRole(String userId, UserRole role);
  Future<void> deactivate(String userId, bool active);
  Future<void> updatePermissions(String userId, Map<String, bool> permissions);
  Future<void> deleteUser(String userId);
}

class FirestoreUsersRepository implements UsersRepository {
  FirestoreUsersRepository({
    required this.companyId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String companyId;
  final FirebaseFirestore _firestore;
  String? _cachedCompanyCode;

  String get path => _membersCol.path;

  CollectionReference<Map<String, dynamic>> get _membersCol =>
      _firestore.collection('companies').doc(companyId).collection('members');

  @override
  Stream<List<UserAccount>> watchUsers() {
    return _membersCol.snapshots().map(
      (snap) => snap.docs
          .map((d) => Member.fromFirestore(d))
          .map(_memberToUserAccount)
          .toList(),
    );
  }

  @override
  Future<void> addUser(UserAccount user) async {
    await FirestoreErrorHandler.guard(
      operation: 'addUser',
      path: path,
      run: () async {
        final companyCode = await _getCompanyCode();
        final codeUpper = companyCode.toUpperCase();
        final pinDocIds = <String>{companyCode, codeUpper};
        if (user.role == UserRole.staff &&
            (user.pin == null || user.pin!.trim().isEmpty)) {
          throw StateError('PIN is required for staff accounts.');
        }
        // Decide doc ID (stable if provided, otherwise generate once and reuse).
        final docRef = user.id.isNotEmpty
            ? _membersCol.doc(user.id)
            : _membersCol.doc();
        final id = docRef.id;
        final basePermissions = user.permissions.isNotEmpty
            ? user.permissions
            : (user.role == UserRole.staff
                  ? {
                      'createOrders': true,
                      'addNotes': true,
                      'setRestockHint': true,
                    }
                  : {});
        final data = <String, dynamic>{
          ...user.toMap()
            ..remove('pin'), // never store plaintext pin in member doc
          'companyId': companyId,
          'id': id,
        };
        if (basePermissions.isNotEmpty) {
          data['permissions'] = basePermissions;
        }
        // Generate a stable pinHash for staff PIN login (business ID/companyCode).
        final pinHash = user.pin != null
            ? hashPin(companyCode, user.pin!)
            : null;

        await docRef.set(data);
        await _firestore.collection('users').doc(id).set({
          'companyId': companyId,
          'displayName': user.displayName,
          'role': user.role.name,
          'active': user.active,
          if (user.email != null) 'email': user.email,
          if (basePermissions.isNotEmpty) 'permissions': basePermissions,
        });

        // Seed staffPins for PIN login if a PIN was provided (id = companyCode for lookup).
        if (pinHash != null) {
          for (final docId in pinDocIds) {
            final hashForDoc = hashPin(docId, user.pin!);
            await _firestore.collection('staffPins').doc(docId).set({
              'companyId': companyId,
              'companyCode': companyCode,
              'staffId': id,
              'pin': user.pin, // stored for MVP PIN login visibility
              'pinHash': hashForDoc,
              'displayName': user.displayName,
              'role': user.role.name,
              'permissions': basePermissions,
              'active': user.active,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
        }
      },
    );
  }

  Future<String> _getCompanyCode() async {
    if (_cachedCompanyCode != null && _cachedCompanyCode!.isNotEmpty)
      return _cachedCompanyCode!;
    try {
      final doc = await _firestore.collection('companies').doc(companyId).get();
      final data = doc.data() ?? {};
      final code = (data['companyCode'] as String? ?? companyId).trim();
      _cachedCompanyCode = code.isNotEmpty ? code : companyId;
      return _cachedCompanyCode!;
    } catch (_) {
      _cachedCompanyCode = companyId;
      return companyId;
    }
  }

  @override
  Future<void> updateRole(String userId, UserRole role) {
    return FirestoreErrorHandler.guard(
      operation: 'updateRole',
      path: '$path/$userId',
      run: () async {
        final data = {'role': role.name};
        final companyCode = await _getCompanyCode();
        final codeUpper = companyCode.toUpperCase();
        final pinDocIds = <String>{companyCode, codeUpper};
        await Future.wait([
          _membersCol.doc(userId).set(data, SetOptions(merge: true)),
          _firestore
              .collection('users')
              .doc(userId)
              .set(data, SetOptions(merge: true)),
          ...pinDocIds.map(
            (id) => _firestore.collection('staffPins').doc(id).set({
              'companyId': companyId,
              'role': role.name,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true)),
          ),
        ]);
      },
    );
  }

  @override
  Future<void> deactivate(String userId, bool active) {
    return FirestoreErrorHandler.guard(
      operation: 'deactivateUser',
      path: '$path/$userId',
      run: () async {
        final companyCode = await _getCompanyCode();
        final codeUpper = companyCode.toUpperCase();
        final pinDocIds = <String>{companyCode, codeUpper};
        await Future.wait([
          _membersCol.doc(userId).update({'active': active}),
          _firestore.collection('users').doc(userId).set({
            'active': active,
          }, SetOptions(merge: true)),
          ...pinDocIds.map(
            (id) => _firestore.collection('staffPins').doc(id).set({
              'companyId': companyId,
              'active': active,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true)),
          ),
        ]);
      },
    );
  }

  @override
  Future<void> updatePermissions(String userId, Map<String, bool> permissions) {
    return FirestoreErrorHandler.guard(
      operation: 'updatePermissions',
      path: '$path/$userId',
      run: () async {
        final data = {'permissions': permissions};
        final companyCode = await _getCompanyCode();
        final codeUpper = companyCode.toUpperCase();
        final pinDocIds = <String>{companyCode, codeUpper};
        await Future.wait([
          _membersCol.doc(userId).set(data, SetOptions(merge: true)),
          _firestore
              .collection('users')
              .doc(userId)
              .set(data, SetOptions(merge: true)),
          ...pinDocIds.map(
            (id) => _firestore.collection('staffPins').doc(id).set({
              'companyId': companyId,
              'permissions': permissions,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true)),
          ),
        ]);
      },
    );
  }

  @override
  Future<void> deleteUser(String userId) {
    return FirestoreErrorHandler.guard(
      operation: 'deleteUser',
      path: '$path/$userId',
      run: () => _membersCol.doc(userId).delete(),
    );
  }

  UserAccount _memberToUserAccount(Member m) {
    return UserAccount(
      id: m.id,
      companyId: m.companyId,
      displayName: m.displayName ?? '',
      role: _roleFromString(m.role),
      active: m.active,
      permissions: m.permissions,
      pin: null,
      email: null,
    );
  }

  UserRole _roleFromString(String value) {
    switch (value.toLowerCase()) {
      case 'owner':
        return UserRole.owner;
      case 'manager':
        return UserRole.manager;
      default:
        return UserRole.staff;
    }
  }
}
