import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/history_entry.dart';

abstract class HistoryRepository {
  Future<void> logEntry(HistoryEntry entry);
  Stream<List<HistoryEntry>> watchEntries();
}

class FirestoreHistoryRepository implements HistoryRepository {
  FirestoreHistoryRepository({
    required this.companyId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final String companyId;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('companies').doc(companyId).collection('history');

  @override
  Future<void> logEntry(HistoryEntry entry) {
    return _col.add(entry.toMap());
  }

  @override
  Stream<List<HistoryEntry>> watchEntries() {
    return _col.orderBy('timestamp', descending: true).snapshots().map(
          (snap) => snap.docs.map((d) => HistoryEntry.fromFirestore(d)).toList(),
        );
  }
}
