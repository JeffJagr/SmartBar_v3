import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/pin_hasher.dart';

/// Debug-only helper to avoid lockouts during development.
class AdminSeeder {
  AdminSeeder({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> seedOwner({
    required String companyId,
    required String ownerUid,
    String? displayName,
  }) async {
    if (!kDebugMode) return;
    final data = {
      'companyId': companyId,
      'role': 'owner',
      'permissions': <String, bool>{
        'editProducts': true,
        'adjustQuantities': true,
        'createOrders': true,
        'confirmOrders': true,
        'receiveOrders': true,
        'transferStock': true,
        'setRestockHint': true,
        'viewHistory': true,
        'addNotes': true,
        'manageUsers': true,
        'manageSuppliers': true,
      },
      'active': true,
      if (displayName != null) 'displayName': displayName,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('members')
        .doc(ownerUid)
        .set(data, SetOptions(merge: true));
  }

  Future<void> seedStaffPin({
    required String companyId,
    required String companyCode,
    required String pin,
    String role = 'staff',
    Map<String, bool> permissions = const {},
    String? displayName,
  }) async {
    if (!kDebugMode) return;
    final pinHash = hashPin(companyCode, pin);
    await _firestore.collection('staffPins').doc(companyCode).set({
      'companyId': companyId,
      'companyCode': companyCode,
      'pinHash': pinHash,
      'role': role,
      'permissions': permissions,
      'active': true,
      if (displayName != null) 'displayName': displayName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
