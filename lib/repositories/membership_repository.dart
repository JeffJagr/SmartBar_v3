import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/member.dart';
import '../utils/firestore_error_handler.dart';

abstract class MembershipRepository {
  Future<Member?> getMember({
    required String companyId,
    required String uid,
  });

  Stream<Member?> streamMember({
    required String companyId,
    required String uid,
  });

  Future<void> upsertMemberSelf({
    required String companyId,
    required String uid,
    required String role,
    required Map<String, bool> permissions,
    String? displayName,
  });

  Future<void> updateMemberAsManager({
    required String companyId,
    required String targetUid,
    String? role,
    Map<String, bool>? permissions,
    bool? active,
    String? displayName,
  });
}

class FirestoreMembershipRepository implements MembershipRepository {
  FirestoreMembershipRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _membersCol(String companyId) =>
      _firestore.collection('companies').doc(companyId).collection('members');

  @override
  Future<Member?> getMember({
    required String companyId,
    required String uid,
  }) {
    return FirestoreErrorHandler.guard(
      operation: 'getMember',
      path: _membersCol(companyId).path,
      run: () async {
        final snap = await _membersCol(companyId).doc(uid).get();
        if (!snap.exists) return null;
        return Member.fromFirestore(snap);
      },
    );
  }

  @override
  Stream<Member?> streamMember({
    required String companyId,
    required String uid,
  }) {
    return _membersCol(companyId)
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? Member.fromFirestore(doc) : null);
  }

  @override
  Future<void> upsertMemberSelf({
    required String companyId,
    required String uid,
    required String role,
    required Map<String, bool> permissions,
    String? displayName,
  }) {
    return FirestoreErrorHandler.guard(
      operation: 'upsertMemberSelf',
      path: _membersCol(companyId).path,
      run: () async {
        final doc = _membersCol(companyId).doc(uid);
        await doc.set(
          {
            'companyId': companyId,
            'role': role,
            'permissions': permissions,
            'active': true,
            if (displayName != null && displayName.isNotEmpty) 'displayName': displayName,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      },
    );
  }

  @override
  Future<void> updateMemberAsManager({
    required String companyId,
    required String targetUid,
    String? role,
    Map<String, bool>? permissions,
    bool? active,
    String? displayName,
  }) {
    return FirestoreErrorHandler.guard(
      operation: 'updateMemberAsManager',
      path: _membersCol(companyId).path,
      run: () async {
        final data = <String, dynamic>{
          if (role != null) 'role': role,
          if (permissions != null) 'permissions': permissions,
          if (active != null) 'active': active,
          if (displayName != null && displayName.isNotEmpty) 'displayName': displayName,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (data.isEmpty) return;
        await _membersCol(companyId).doc(targetUid).set(data, SetOptions(merge: true));
      },
    );
  }
}
