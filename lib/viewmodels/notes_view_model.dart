import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/note.dart';
import '../models/product.dart';
import '../repositories/note_repository.dart';
import '../repositories/product_repository.dart';

/// ViewModel for notes/comments. Keeps notes separate from UI.
/// Firestore-backed repos stream in real time; in-memory fallback is used only when no company is active.
class NotesViewModel extends ChangeNotifier {
  NotesViewModel(this._noteRepo, this._productRepo);

  NoteRepository _noteRepo;
  final ProductRepository _productRepo;
  bool canDeleteNotes = false;
  bool canMarkDone = true;

  List<Note> notes = [];
  List<Product> products = [];
  bool loading = true;
  String? error;

  StreamSubscription<List<Note>>? _subscription;

  Future<void> init() async {
    try {
      loading = true;
      notifyListeners();
      notes = await _noteRepo.getNotes();
      products = await _productRepo.fetchProducts();
      _subscription = _noteRepo.watchNotes().listen((data) {
        notes = data;
        loading = false;
        error = null;
        notifyListeners();
      }, onError: (e) {
        error = e.toString();
        loading = false;
        notifyListeners();
      });
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> addNote({
    required String authorId,
    required String authorName,
    required String content,
    required String tag,
    String? linkedProductId,
    String? priority,
  }) async {
    final note = Note(
      id: 'note-${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      authorId: authorId,
      authorName: authorName,
      content: content,
      tag: tag,
      linkedProductId: linkedProductId,
      priority: priority,
    );
    try {
      await _noteRepo.addNote(note);
      // Stream will update; fetch is a fallback for non-stream repos.
      notes = await _noteRepo.getNotes();
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> markDone({
    required String id,
    required String doneBy,
  }) async {
    try {
      await _noteRepo.markDone(
        id: id,
        doneBy: doneBy,
        doneAt: DateTime.now(),
      );
      notes = await _noteRepo.getNotes();
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteNote(String id) async {
    try {
      await _noteRepo.deleteNote(id);
      notes = await _noteRepo.getNotes();
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
  // TODO: add filters/search, and push notifications to relevant staff/owners on new notes.

  void replaceRepository(NoteRepository repo) {
    if (identical(_noteRepo, repo)) return;
    _subscription?.cancel();
    _noteRepo = repo;
    init();
  }

  void setPermissions({required bool isOwner}) {
    canDeleteNotes = isOwner;
    canMarkDone = true; // TODO: refine per-role if needed.
    notifyListeners();
  }
  // TODO: add filters/search, printing/export of notes, and reporting hooks.
}

