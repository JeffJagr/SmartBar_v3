import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/staff_session.dart';
import '../utils/pin_hasher.dart';

class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<User?> get onAuthStateChanged => _auth.authStateChanges();

  Future<UserCredential> registerOwner({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> signInOwner({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<StaffSession> signInStaff({
    required String companyCode,
    required String pin,
  }) async {
    await _ensureAnonymousAuth();
    final normalizedCode = companyCode.trim().toUpperCase();
    final rawCode = companyCode.trim();
    final providedPin = pin.trim();
    String currentPath = 'staffPins/$normalizedCode';
    try {
      var doc =
          await _firestore.collection('staffPins').doc(normalizedCode).get();
      if (!doc.exists && rawCode.isNotEmpty && rawCode != normalizedCode) {
        currentPath = 'staffPins/$rawCode';
        doc = await _firestore.collection('staffPins').doc(rawCode).get();
      }
      if (!doc.exists) {
        throw FirebaseAuthException(
          code: 'invalid-credentials',
          message: 'Invalid company code or PIN.',
        );
      }
      final data = doc.data() ?? {};
      final companyId = data['companyId'] as String? ?? '';
      if (companyId.isEmpty) {
        throw FirebaseAuthException(
          code: 'invalid-company',
          message: 'This company code is not linked to a company.',
        );
      }
      if (data['active'] == false) {
        throw FirebaseAuthException(
          code: 'inactive-pin',
          message: 'This staff code is inactive. Ask your manager to re-enable it.',
        );
      }

      final expectedHash = (data['pinHash'] as String? ?? '').trim();
      final providedHash = hashPin(normalizedCode, providedPin);
      final plainPin = (data['pin'] as String?)?.trim();
      final legacyPin = data['pin'] as String?;
      final pinMatches = (plainPin != null && plainPin.isNotEmpty)
          ? plainPin == providedPin
          : expectedHash.isNotEmpty
              ? providedHash == expectedHash
              : legacyPin == providedPin;
      if (!pinMatches) {
        throw FirebaseAuthException(
          code: 'invalid-credentials',
          message: 'Invalid company code or PIN.',
        );
      }

      final uid = _auth.currentUser?.uid ?? '';
      if (uid.isEmpty) {
        throw FirebaseAuthException(
          code: 'no-auth-uid',
          message: 'Could not establish authentication for staff login.',
        );
      }

      var role = (data['role'] as String? ?? 'staff').toLowerCase();
      if (role != 'staff') {
        // Staff PIN login should never elevate above staff.
        role = 'staff';
      }
      final permissions =
          _cleanStaffPermissions(Map<String, dynamic>.from(data['permissions'] as Map? ?? {}));
      final displayName = data['displayName'] as String? ?? 'Staff';

      // Create the authMap link first so subsequent company writes pass rules.
      currentPath = 'companies/$companyId/authMap/$uid';
      final authMapRef = _firestore
          .collection('companies')
          .doc(companyId)
          .collection('authMap')
          .doc(uid);
      await authMapRef.set({
        'companyId': companyId,
        'role': role,
        'permissions': permissions,
        'active': true,
        'displayName': displayName,
        'staffId': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      currentPath = 'companies/$companyId/members/$uid';
      final memberRef = _firestore.collection('companies').doc(companyId).collection('members').doc(uid);
      await memberRef.set({
        'companyId': companyId,
        'role': role,
        'permissions': permissions,
        'active': true,
        'displayName': displayName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final sessionRef = _firestore
          .collection('companies')
          .doc(companyId)
          .collection('staffSessions')
          .doc(uid);
      await sessionRef.set({
        'companyId': companyId,
        'staffId': uid,
        'role': role,
        'permissions': permissions,
        'displayName': displayName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final globalUserRef = _firestore.collection('users').doc(uid);
      await globalUserRef.set({
        'role': 'staff',
        'companyId': companyId,
        'displayName': displayName,
        'permissions': permissions,
        'active': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return StaffSession(
        companyId: companyId,
        displayName: displayName,
        staffId: uid,
        role: role,
        permissions: permissions,
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        debugPrint(
            'permission-denied during staff sign-in at $currentPath uid=${_auth.currentUser?.uid ?? 'none'} companyCode=$normalizedCode');
        throw FirebaseAuthException(
          code: e.code,
          message:
              'Access denied while accessing $currentPath. Ask your manager to check permissions.',
        );
      }
      throw FirebaseAuthException(
        code: e.code,
        message: e.message ?? 'Login failed. Please try again.',
      );
    } catch (e) {
      if (e is FirebaseAuthException) rethrow;
      throw FirebaseAuthException(code: 'internal', message: e.toString());
    }
  }

  Map<String, bool> _cleanStaffPermissions(Map<String, dynamic> raw) {
    return {
      // Defaults are permissive for allowed staff actions; disallow escalations.
      if (!raw.containsKey('createOrders') || raw['createOrders'] == true) 'createOrders': true,
      if (!raw.containsKey('addNotes') || raw['addNotes'] == true) 'addNotes': true,
      if (!raw.containsKey('setRestockHint') || raw['setRestockHint'] == true)
        'setRestockHint': true,
      if (raw['viewHistory'] == true) 'viewHistory': true,
    };
  }

  Future<void> _ensureAnonymousAuth() async {
    final current = _auth.currentUser;
    if (current != null && current.uid.isNotEmpty && current.isAnonymous) return;
    if (current != null && !current.isAnonymous) {
      await _auth.signOut();
    }
    try {
      await _auth.signInAnonymously();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'admin-restricted-operation' || e.code == 'operation-not-allowed') {
        throw FirebaseAuthException(
          code: e.code,
          message: 'Anonymous auth is not enabled. Enable Anonymous sign-in in Firebase Auth settings.',
        );
      }
      rethrow;
    }
  }
}
