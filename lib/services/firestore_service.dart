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
    String? companyCode,
  }) async {
    final generatedCode = companyCode ??
        'BAR-${DateTime.now().millisecondsSinceEpoch.remainder(100000).toString().padLeft(5, '0')}';
    if (companyCode != null && companyCode.isNotEmpty) {
      // TODO: move uniqueness check to a transaction or Cloud Function.
      final existing = await _firestore
          .collection('companies')
          .where('companyCode', isEqualTo: generatedCode)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        throw StateError('Company code already exists');
      }
    }
    final docRef = await _firestore.collection('companies').add({
      'name': name,
      'companyCode': generatedCode,
      'ownerIds': [ownerId],
      'createdAt': FieldValue.serverTimestamp(),
    });
    final snapshot = await docRef.get();
    return Company.fromMap(snapshot.id, snapshot.data() ?? {});
  }

  Future<List<Company>> fetchCompaniesForOwner(String ownerId) async {
    try {
      final snapshot = await _firestore
          .collection('companies')
          .where('ownerIds', arrayContains: ownerId)
          .get();
      return snapshot.docs
          .map((doc) => Company.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('fetchCompaniesForOwner failed: $e');
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
      return Company.fromMap(doc.id, doc.data());
    } catch (e) {
      debugPrint('fetchCompanyByCode failed: $e');
      return null;
    }
  }

  Stream<List<Product>> productsStream(String companyId) {
    return _firestore
        .collection('products')
        .where('companyId', isEqualTo: companyId)
        .orderBy('name')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Product.fromMap(doc.id, doc.data())).toList());
  }

  Stream<List<OrderModel>> ordersStream(String companyId) {
    return _firestore
        .collection('orders')
        .where('companyId', isEqualTo: companyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OrderModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  Stream<List<HistoryEntry>> historyStream(String companyId) {
    return _firestore
        .collection('history')
        .where('companyId', isEqualTo: companyId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => HistoryEntry.fromMap(doc.id, doc.data()))
            .toList());
  }
}
