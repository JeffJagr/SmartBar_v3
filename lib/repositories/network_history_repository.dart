import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/history_entry.dart';
import '../utils/firestore_error_handler.dart';

class NetworkHistoryPage {
  NetworkHistoryPage({
    required this.entries,
    required this.lastDocument,
    required this.hasMore,
  });

  final List<HistoryEntry> entries;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;
}

class NetworkHistoryRepository {
  NetworkHistoryRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<NetworkHistoryPage> fetchHistory({
    required List<String> companyIds,
    String? actionType,
    String? itemId,
    DateTime? startDate,
    DateTime? endDate,
    String? search,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 30,
  }) {
    return FirestoreErrorHandler.guard(
      operation: 'fetchNetworkHistory',
      path: 'collectionGroup/history',
      run: () async {
        if (companyIds.isEmpty) {
          return NetworkHistoryPage(entries: const [], lastDocument: null, hasMore: false);
        }
        final scopedCompanies = companyIds.take(10).toList();
        Query<Map<String, dynamic>> q = _firestore
            .collectionGroup('history')
            .where('companyId', whereIn: scopedCompanies)
            .orderBy('timestamp', descending: true);

        if (actionType != null && actionType.isNotEmpty) {
          q = q.where('actionType', isEqualTo: actionType);
        }
        if (itemId != null && itemId.isNotEmpty) {
          q = q.where('itemId', isEqualTo: itemId);
        }
        if (startDate != null) {
          q = q.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
        }
        if (endDate != null) {
          q = q.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
        }
        if (startAfter != null) {
          q = q.startAfterDocument(startAfter);
        }

        final snap = await q.limit(limit).get();
        var entries = snap.docs.map((d) => HistoryEntry.fromFirestore(d)).toList();

        if (search != null && search.isNotEmpty) {
          final term = search.toLowerCase();
          entries = entries
              .where((e) =>
                  e.itemName.toLowerCase().contains(term) ||
                  e.actionType.toLowerCase().contains(term) ||
                  (e.description ?? '').toLowerCase().contains(term))
              .toList();
        }

        return NetworkHistoryPage(
          entries: entries,
          lastDocument: snap.docs.isNotEmpty ? snap.docs.last : null,
          hasMore: snap.docs.length == limit,
        );
      },
    );
  }
}
