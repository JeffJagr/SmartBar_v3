import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/note.dart';
import '../utils/firestore_error_handler.dart';

/// Stub repository for notes. Replace with Firestore CRUD later.
abstract class NoteRepository {
  Future<List<Note>> getNotes();
  Stream<List<Note>> watchNotes();
  Future<void> addNote(Note note);
  Future<void> deleteNote(String id);
  Future<void> markDone({
    required String id,
    required String doneBy,
    required DateTime doneAt,
  });
  Future<void> markRead({
    required String id,
    required String userId,
    required DateTime readAt,
  });
  Future<List<Note>> filterNotes({
    String? linkedProductId,
    String? tag,
  });
}

class InMemoryNoteRepository implements NoteRepository {
  final List<Note> _notes = [
    Note(
      id: 'n1',
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      authorId: 'owner-1',
      authorName: 'Owner',
      content: 'Check keg levels before weekend rush.',
      tag: 'TODO',
      linkedProductId: 'p1',
      companyId: 'sample-company',
    ),
    Note(
      id: 'n2',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      authorId: 'staff-1',
      authorName: 'Alex',
      content: 'Need to reorder gin bottles.',
      tag: 'Important',
      linkedProductId: 'p2',
      companyId: 'sample-company',
    ),
  ];

  final _controller = StreamController<List<Note>>.broadcast();

  InMemoryNoteRepository() {
    _controller.add(_notes);
  }

  @override
  Future<List<Note>> getNotes() async {
    return List<Note>.unmodifiable(_notes);
  }

  @override
  Stream<List<Note>> watchNotes() => _controller.stream;

  @override
  Future<void> addNote(Note note) async {
    _notes.insert(0, note);
    _controller.add(_notes);
  }

  @override
  Future<void> deleteNote(String id) async {
    _notes.removeWhere((n) => n.id == id);
    _controller.add(_notes);
  }

  @override
  Future<void> markDone({
    required String id,
    required String doneBy,
    required DateTime doneAt,
  }) async {
    for (var i = 0; i < _notes.length; i++) {
      if (_notes[i].id == id) {
        _notes[i] = _notes[i].copyWith(
          isDone: true,
          doneBy: doneBy,
          doneAt: doneAt,
        );
        _controller.add(_notes);
        break;
      }
    }
  }

  @override
  Future<List<Note>> filterNotes({
    String? linkedProductId,
    String? tag,
  }) async {
    return _notes.where((n) {
      final matchesProduct = linkedProductId == null || n.linkedProductId == linkedProductId;
      final matchesTag = tag == null || n.tag.toLowerCase() == tag.toLowerCase();
      return matchesProduct && matchesTag;
    }).toList(growable: false);
  }

  void dispose() {
    _controller.close();
  }

  @override
  Future<void> markRead({
    required String id,
    required String userId,
    required DateTime readAt,
  }) async {
    for (var i = 0; i < _notes.length; i++) {
      if (_notes[i].id == id) {
        final newReadBy = Map<String, DateTime>.from(_notes[i].readBy);
        newReadBy[userId] = readAt;
        _notes[i] = _notes[i].copyWith(readBy: newReadBy);
        _controller.add(_notes);
        break;
      }
    }
  }
}

class FirestoreNoteRepository implements NoteRepository {
  FirestoreNoteRepository({
    required this.companyId,
    this.enableNotifications = true,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final String companyId;
  final bool enableNotifications;

  String get path => _col.path;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('companies').doc(companyId).collection('notes');

  Note _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Note(
      id: doc.id,
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
      companyId: data['companyId'] as String? ?? companyId,
      assigneeIds: (data['assigneeIds'] as List<dynamic>? ?? []).cast<String>(),
      mentionIds: (data['mentionIds'] as List<dynamic>? ?? []).cast<String>(),
      readBy: (data['readBy'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, (v as Timestamp?)?.toDate() ?? DateTime.now())),
    );
  }

  Map<String, dynamic> _toMap(Note note) {
    return {
      'timestamp': Timestamp.fromDate(note.timestamp),
      'authorId': note.authorId,
      'authorName': note.authorName,
      'content': note.content,
      'tag': note.tag,
      'companyId': note.companyId.isNotEmpty ? note.companyId : companyId,
      if (note.priority != null) 'priority': note.priority,
      if (note.linkedProductId != null) 'linkedProductId': note.linkedProductId,
      if (note.assigneeIds.isNotEmpty) 'assigneeIds': note.assigneeIds,
      if (note.mentionIds.isNotEmpty) 'mentionIds': note.mentionIds,
      if (note.readBy.isNotEmpty)
        'readBy': note.readBy.map((k, v) => MapEntry(k, Timestamp.fromDate(v))),
      'isDone': note.isDone,
      if (note.doneBy != null) 'doneBy': note.doneBy,
      if (note.doneAt != null) 'doneAt': Timestamp.fromDate(note.doneAt!),
    };
  }

  @override
  Future<List<Note>> getNotes() {
    return FirestoreErrorHandler.guard(
      operation: 'getNotes',
      path: path,
      run: () async {
        final snap = await _col.orderBy('timestamp', descending: true).get();
        return snap.docs.map(_fromDoc).toList();
      },
    );
  }

  @override
  Stream<List<Note>> watchNotes() {
    return _col.orderBy('timestamp', descending: true).snapshots().map(
          (snap) => snap.docs.map(_fromDoc).toList(),
        );
  }

  @override
  Future<void> addNote(Note note) {
    return FirestoreErrorHandler.guard(
      operation: 'addNote',
      path: path,
      run: () => _col.add(_toMap(note)).then((ref) async {
        if (enableNotifications) {
          await _notify(
            type: 'note_add',
            noteId: ref.id,
            note: note,
          );
        }
      }),
    );
  }

  @override
  Future<void> deleteNote(String id) {
    return FirestoreErrorHandler.guard(
      operation: 'deleteNote',
      path: '$path/$id',
      run: () => _col.doc(id).delete(),
    );
  }

  @override
  Future<void> markDone({
    required String id,
    required String doneBy,
    required DateTime doneAt,
  }) {
    return FirestoreErrorHandler.guard(
      operation: 'markNoteDone',
      path: '$path/$id',
      run: () => _col.doc(id).update({
        'isDone': true,
        'doneBy': doneBy,
        'doneAt': Timestamp.fromDate(doneAt),
      }).then((_) async {
        if (enableNotifications) {
          await _notify(
            type: 'note_done',
            noteId: id,
            doneBy: doneBy,
          );
        }
      }),
    );
  }

  @override
  Future<void> markRead({
    required String id,
    required String userId,
    required DateTime readAt,
  }) {
    return FirestoreErrorHandler.guard(
      operation: 'markNoteRead',
      path: '$path/$id',
      run: () => _col.doc(id).update({
        'readBy.$userId': Timestamp.fromDate(readAt),
      }),
    );
  }

  @override
  Future<List<Note>> filterNotes({
    String? linkedProductId,
    String? tag,
  }) {
    return FirestoreErrorHandler.guard(
      operation: 'filterNotes',
      path: path,
      run: () async {
        Query<Map<String, dynamic>> q = _col;
        if (linkedProductId != null) {
          q = q.where('linkedProductId', isEqualTo: linkedProductId);
        }
        if (tag != null) {
          q = q.where('tag', isEqualTo: tag);
        }
        // Index suggestion: notes(tag, linkedProductId, timestamp desc)
        final snap = await q.orderBy('timestamp', descending: true).get();
        return snap.docs.map(_fromDoc).toList();
      },
    );
  }
}

extension on FirestoreNoteRepository {
  Future<void> _notify({
    required String type,
    required String noteId,
    Note? note,
    String? doneBy,
  }) async {
    try {
      await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('notifications')
          .add({
        'type': type,
        'noteId': noteId,
        if (note != null) 'content': note.content,
        if (note != null) 'tag': note.tag,
        if (note != null && note.linkedProductId != null) 'productId': note.linkedProductId,
        if (note != null && note.assigneeIds.isNotEmpty) 'assigneeIds': note.assigneeIds,
        if (note != null && note.mentionIds.isNotEmpty) 'mentionIds': note.mentionIds,
        if (doneBy != null) 'doneBy': doneBy,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (_) {
      // best-effort; do not block note flow
    }
  }
}
