import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/note.dart';

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
    ),
    Note(
      id: 'n2',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      authorId: 'staff-1',
      authorName: 'Alex',
      content: 'Need to reorder gin bottles.',
      tag: 'Important',
      linkedProductId: 'p2',
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
    // TODO: replace with Firestore queries and indexes.
    return _notes.where((n) {
      final matchesProduct = linkedProductId == null || n.linkedProductId == linkedProductId;
      final matchesTag = tag == null || n.tag == tag;
      return matchesProduct && matchesTag;
    }).toList(growable: false);
  }

  void dispose() {
    _controller.close();
  }
}

class FirestoreNoteRepository implements NoteRepository {
  FirestoreNoteRepository({
    required this.companyId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final String companyId;

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
    );
  }

  Map<String, dynamic> _toMap(Note note) {
    return {
      'timestamp': Timestamp.fromDate(note.timestamp),
      'authorId': note.authorId,
      'authorName': note.authorName,
      'content': note.content,
      'tag': note.tag,
      if (note.priority != null) 'priority': note.priority,
      if (note.linkedProductId != null) 'linkedProductId': note.linkedProductId,
      'isDone': note.isDone,
      if (note.doneBy != null) 'doneBy': note.doneBy,
      if (note.doneAt != null) 'doneAt': Timestamp.fromDate(note.doneAt!),
    };
  }

  @override
  Future<List<Note>> getNotes() async {
    final snap = await _col.orderBy('timestamp', descending: true).get();
    return snap.docs.map(_fromDoc).toList();
  }

  @override
  Stream<List<Note>> watchNotes() {
    return _col.orderBy('timestamp', descending: true).snapshots().map(
          (snap) => snap.docs.map(_fromDoc).toList(),
        );
  }

  @override
  Future<void> addNote(Note note) {
    return _col.add(_toMap(note));
  }

  @override
  Future<void> deleteNote(String id) {
    return _col.doc(id).delete();
  }

  @override
  Future<void> markDone({
    required String id,
    required String doneBy,
    required DateTime doneAt,
  }) {
    return _col.doc(id).update({
      'isDone': true,
      'doneBy': doneBy,
      'doneAt': Timestamp.fromDate(doneAt),
    });
  }

  @override
  Future<List<Note>> filterNotes({
    String? linkedProductId,
    String? tag,
  }) async {
    Query<Map<String, dynamic>> q = _col;
    if (linkedProductId != null) {
      q = q.where('linkedProductId', isEqualTo: linkedProductId);
    }
    if (tag != null) {
      q = q.where('tag', isEqualTo: tag);
    }
    final snap = await q.orderBy('timestamp', descending: true).get();
    return snap.docs.map(_fromDoc).toList();
  }
  // TODO: emit notifications to interested users when a new note is created or marked done.
}
