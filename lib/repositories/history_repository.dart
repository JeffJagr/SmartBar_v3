import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/history_entry.dart';
import '../utils/firestore_error_handler.dart';

abstract class HistoryRepository {
  Future<void> logEntry(HistoryEntry entry);
  Stream<List<HistoryEntry>> watchEntries();
  Future<List<HistoryEntry>> fetchLatest({int limit});
}

class FirestoreHistoryRepository implements HistoryRepository {
  FirestoreHistoryRepository({
    required this.companyId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final String companyId;

  String get path => _col.path;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('companies').doc(companyId).collection('history');

  @override
  Future<void> logEntry(HistoryEntry entry) {
    return FirestoreErrorHandler.guard(
      operation: 'logHistoryEntry',
      path: path,
      run: () => _col.add(entry.toMap()),
    );
  }

  @override
  Stream<List<HistoryEntry>> watchEntries() {
    return _col.orderBy('timestamp', descending: true).snapshots().map(
          (snap) => snap.docs.map((d) => HistoryEntry.fromFirestore(d)).toList(),
        );
  }

  @override
  Future<List<HistoryEntry>> fetchLatest({int limit = 100}) {
    return FirestoreErrorHandler.guard(
      operation: 'fetchHistory',
      path: path,
      run: () async {
        final snap = await _col.orderBy('timestamp', descending: true).limit(limit).get();
        return snap.docs.map((d) => HistoryEntry.fromFirestore(d)).toList();
      },
    );
  }
}
