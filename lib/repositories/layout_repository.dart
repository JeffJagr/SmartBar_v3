import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/layout.dart';

abstract class LayoutRepository {
  Stream<Layout?> watchLayout({required String scope});
  Future<Layout?> fetchLayout({required String scope});
  Future<void> saveLayout(Layout layout);
}

class FirestoreLayoutRepository implements LayoutRepository {
  FirestoreLayoutRepository({required this.companyId, FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final String companyId;
  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _doc(String scope) => _firestore
      .collection('companies')
      .doc(companyId)
      .collection('layouts')
      .doc(scope);

  @override
  Stream<Layout?> watchLayout({required String scope}) {
    return _doc(scope).snapshots().map((snap) {
      if (!snap.exists) return null;
      return Layout.fromMap(snap.id, snap.data() ?? {});
    });
  }

  @override
  Future<Layout?> fetchLayout({required String scope}) async {
    final snap = await _doc(scope).get();
    if (!snap.exists) return null;
    return Layout.fromMap(snap.id, snap.data() ?? {});
  }

  @override
  Future<void> saveLayout(Layout layout) {
    return _doc(layout.scope).set(layout.toMap(), SetOptions(merge: true));
  }
}

class InMemoryLayoutRepository implements LayoutRepository {
  Layout? _layout;

  @override
  Stream<Layout?> watchLayout({required String scope}) async* {
    yield _layout;
  }

  @override
  Future<Layout?> fetchLayout({required String scope}) async {
    return _layout;
  }

  @override
  Future<void> saveLayout(Layout layout) async {
    _layout = layout;
  }
}
