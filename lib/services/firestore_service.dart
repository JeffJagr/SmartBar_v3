import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/company.dart';
import '../models/history_entry.dart';
import '../models/order.dart';
import '../models/product.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<Company> createCompany({
    required String name,
    required String ownerId,
    required String companyCode,
  }) async {
    if (companyCode.trim().isEmpty) {
      throw StateError('Business ID is required');
    }
    final generatedCode = companyCode.trim();
    // Ensure company code is unique across companies and staffPins.
    final existing = await _firestore
        .collection('companies')
        .where('companyCode', isEqualTo: generatedCode)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      throw StateError('Business ID already exists');
    }
    final pinDocExisting = await _firestore
        .collection('staffPins')
        .doc(generatedCode)
        .get();
    if (pinDocExisting.exists) {
      throw StateError('Business ID already exists');
    }

    final docRef = _firestore.collection('companies').doc();
    // Create company doc first so subsequent writes satisfy security rules.
    await docRef.set({
      'name': name,
      'companyCode': generatedCode,
      'ownerIds': [ownerId],
      'ownerId': ownerId, // legacy compatibility for older queries/rules
      'createdBy': ownerId,
      'partnerEmails': [],
      'notificationLowStock': true,
      'notificationOrderApprovals': true,
      'notificationStaff': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    // Link owner via authMap (membership for rules).
    await docRef.collection('authMap').doc(ownerId).set({
      'companyId': docRef.id,
      'role': 'owner',
      'permissions': {
        'manageUsers': true,
        'editProducts': true,
        'adjustQuantities': true,
        'createOrders': true,
        'confirmOrders': true,
        'receiveOrders': true,
        'transferStock': true,
        'setRestockHint': true,
        'viewHistory': true,
        'addNotes': true,
        'manageSuppliers': true,
      },
      'active': true,
      'displayName': 'Owner',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    final snapshot = await docRef.get();
    final company = Company.fromMap(snapshot.id, snapshot.data() ?? {});
    return company;
  }

  Future<List<Company>> fetchCompaniesForUser({
    required String ownerId,
    String? email,
  }) async {
    try {
      final col = _firestore.collection('companies');
      final ownerSnap = await col
          .where('ownerIds', arrayContains: ownerId)
          .get();
      final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = [
        ...ownerSnap.docs,
      ];
      if (email != null && email.isNotEmpty) {
        final lower = email.toLowerCase();
        final partnerSnap = await col
            .where('partnerEmails', arrayContains: lower)
            .get();
        docs.addAll(
          partnerSnap.docs.where(
            (d) => docs.indexWhere((e) => e.id == d.id) == -1,
          ),
        );
      }
      // Legacy fallback: ownerId single field
      if (docs.isEmpty) {
        final legacySnap = await col.where('ownerId', isEqualTo: ownerId).get();
        docs.addAll(
          legacySnap.docs.where(
            (d) => docs.indexWhere((e) => e.id == d.id) == -1,
          ),
        );
      }
      return docs
          .map((doc) {
            final raw = doc.data();
            if (raw.isEmpty) return null;
            final data = Map<String, dynamic>.from(raw);
            return Company.fromMap(doc.id, data);
          })
          .whereType<Company>()
          .toList();
    } catch (e) {
      debugPrint('fetchCompaniesForUser failed: $e');
      return [];
    }
  }

  Future<Company?> fetchCompanyByCode(String companyCode) async {
    try {
      final snapshot = await _firestore
          .collection('companies')
          .where('companyCode', isEqualTo: companyCode)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      final data = Map<String, dynamic>.from(doc.data());
      return Company.fromMap(doc.id, data);
    } catch (e) {
      debugPrint('fetchCompanyByCode failed: $e');
      return null;
    }
  }

  Future<Company?> fetchCompanyById(String companyId) async {
    try {
      final doc = await _firestore.collection('companies').doc(companyId).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      return Company.fromMap(doc.id, Map<String, dynamic>.from(data));
    } catch (e) {
      debugPrint('fetchCompanyById failed: $e');
      return null;
    }
  }

  Stream<List<Product>> productsStream(String companyId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('products')
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Product.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<OrderModel>> ordersStream(String companyId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => OrderModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<HistoryEntry>> historyStream(String companyId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('history')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => HistoryEntry.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  /// Fetch a company-scoped user document (role/permissions) for the current auth user.
  Future<Map<String, dynamic>?> fetchCompanyUser(
    String companyId,
    String uid,
  ) async {
    try {
      final snap = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('users')
          .doc(uid)
          .get();
      return snap.data();
    } catch (_) {
      return null;
    }
  }

  Future<void> addPartnerEmail({
    required String companyId,
    required String email,
  }) async {
    final lower = email.trim().toLowerCase();
    if (lower.isEmpty) return;
    await _firestore.collection('companies').doc(companyId).update({
      'partnerEmails': FieldValue.arrayUnion([lower]),
    });
  }
}
