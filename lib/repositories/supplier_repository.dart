import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/supplier.dart';

abstract class SupplierRepository {
  Stream<List<Supplier>> watchSuppliers();
  Future<void> addOrUpdate(Supplier supplier);
  Future<void> delete(String id);
}

class FirestoreSupplierRepository implements SupplierRepository {
  FirestoreSupplierRepository({
    required this.companyId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String companyId;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('companies').doc(companyId).collection('suppliers');

  @override
  Stream<List<Supplier>> watchSuppliers() {
    return _col.orderBy('name').snapshots().map(
          (snap) => snap.docs
              .map((d) => Supplier.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  @override
  Future<void> addOrUpdate(Supplier supplier) async {
    // If no ID is provided, create a new document so the stream picks up the generated ID.
    final doc = supplier.id.isEmpty ? _col.doc() : _col.doc(supplier.id);
    await doc.set(supplier.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> delete(String id) => _col.doc(id).delete();
}
