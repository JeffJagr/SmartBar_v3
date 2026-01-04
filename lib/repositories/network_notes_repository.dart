import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/note.dart';
import 'note_repository.dart';
import '../utils/firestore_error_handler.dart';

class NetworkNotesPage {
  NetworkNotesPage({
    required this.notes,
    required this.lastDocument,
    required this.hasMore,
  });

  final List<Note> notes;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;
}

class NetworkNotesRepository {
  NetworkNotesRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<NetworkNotesPage> fetchNotes({
    required List<String> companyIds,
    String? tag,
    bool? isDone,
    String? linkedProductId,
    String? assigneeId,
    String? mentionId,
    DateTime? startDate,
    DateTime? endDate,
    String? search,
    String? currentUserId,
    bool assignedToMe = false,
    bool unreadOnly = false,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 20,
  }) {
    return FirestoreErrorHandler.guard(
      operation: 'fetchNetworkNotes',
      path: 'collectionGroup/notes',
      run: () async {
        if (companyIds.isEmpty) {
          return NetworkNotesPage(notes: const [], lastDocument: null, hasMore: false);
        }
        final scopedCompanies = companyIds.take(10).toList();
        Query<Map<String, dynamic>> q =
            _firestore.collectionGroup('notes').where('companyId', whereIn: scopedCompanies);

        if (tag != null && tag.isNotEmpty && tag.toLowerCase() != 'all') {
          q = q.where('tag', isEqualTo: tag);
        }
        if (isDone != null) {
          q = q.where('isDone', isEqualTo: isDone);
        }
        if (linkedProductId != null && linkedProductId.isNotEmpty) {
          q = q.where('linkedProductId', isEqualTo: linkedProductId);
        }
        if (assigneeId != null && assigneeId.isNotEmpty) {
          q = q.where('assigneeIds', arrayContains: assigneeId);
        }
        if (mentionId != null && mentionId.isNotEmpty) {
          q = q.where('mentionIds', arrayContains: mentionId);
        }
        if (startDate != null) {
          q = q.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
        }
        if (endDate != null) {
          q = q.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
        }
        q = q.orderBy('timestamp', descending: true);
        if (startAfter != null) {
          q = q.startAfterDocument(startAfter);
        }

        final snap = await q.limit(limit).get();
        var notes = snap.docs.map((d) {
          final data = d.data();
          return Note(
            id: d.id,
            timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
            authorId: data['authorId'] as String? ?? '',
            authorName: data['authorName'] as String? ?? 'Unknown',
            content: data['content'] as String? ?? '',
            tag: data['tag'] as String? ?? 'NB',
            priority: data['priority'] as String?,
            linkedProductId: data['linkedProductId'] as String?,
            isDone: data['isDone'] as bool? ?? false,
            doneBy: data['doneBy'] as String?,
            doneAt: (data['doneAt'] as Timestamp?)?.toDate(),
            companyId: data['companyId'] as String? ?? '',
            assigneeIds: (data['assigneeIds'] as List<dynamic>? ?? []).cast<String>(),
            mentionIds: (data['mentionIds'] as List<dynamic>? ?? []).cast<String>(),
            readBy: (data['readBy'] as Map<String, dynamic>? ?? {})
                .map((k, v) => MapEntry(k, (v as Timestamp?)?.toDate() ?? DateTime.now())),
          );
        }).toList();

        if (search != null && search.isNotEmpty) {
          final term = search.toLowerCase();
          notes = notes
              .where(
                (n) =>
                    n.content.toLowerCase().contains(term) ||
                    n.authorName.toLowerCase().contains(term) ||
                    n.tag.toLowerCase().contains(term),
              )
              .toList();
        }

        if (assignedToMe && currentUserId != null && currentUserId.isNotEmpty) {
          notes = notes.where((n) => n.assigneeIds.contains(currentUserId)).toList();
        }
        if (unreadOnly && currentUserId != null && currentUserId.isNotEmpty) {
          notes = notes.where((n) => !n.readBy.containsKey(currentUserId)).toList();
        }

        return NetworkNotesPage(
          notes: notes,
          lastDocument: snap.docs.isNotEmpty ? snap.docs.last : null,
          hasMore: snap.docs.length == limit,
        );
      },
    );
  }

  Future<void> addNote({
    required String companyId,
    required Note note,
  }) async {
    final repo = FirestoreNoteRepository(companyId: companyId);
    await repo.addNote(note.copyWith(companyId: companyId));
  }

  Future<void> markDone({
    required String companyId,
    required String noteId,
    required String doneBy,
  }) async {
    final repo = FirestoreNoteRepository(companyId: companyId);
    await repo.markDone(id: noteId, doneBy: doneBy, doneAt: DateTime.now());
  }

  Future<void> markRead({
    required String companyId,
    required String noteId,
    required String userId,
  }) async {
    final repo = FirestoreNoteRepository(companyId: companyId);
    await repo.markRead(id: noteId, userId: userId, readAt: DateTime.now());
  }
}
