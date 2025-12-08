import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/staff_session.dart';

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
    // Ensure we have an auth context for rules; anonymous is sufficient for lookup.
    if (_auth.currentUser == null || !_auth.currentUser!.isAnonymous) {
      await _auth.signInAnonymously();
    }
    // TODO: Move this to a callable cloud function for better security.
    final snapshot = await _firestore
        .collection('staffPins')
        .where('companyCode', isEqualTo: companyCode)
        .where('pin', isEqualTo: pin)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-credentials',
        message: 'Invalid company code or PIN',
      );
    }

    final data = snapshot.docs.first.data();
    return StaffSession(
      companyId: data['companyId'] as String? ?? '',
      displayName: data['displayName'] as String? ?? 'Staff',
      staffId: snapshot.docs.first.id,
    );
  }
}
