import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/note.dart';
import '../models/product.dart';
import '../repositories/note_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/history_repository.dart';
import '../models/history_entry.dart';

/// ViewModel for notes/comments. Keeps notes separate from UI.
/// Firestore-backed repos stream in real time; in-memory fallback is used only when no company is active.
class NotesViewModel extends ChangeNotifier {
  NotesViewModel(this._noteRepo, this._productRepo, [this._historyRepo]);

  NoteRepository _noteRepo;
  final ProductRepository _productRepo;
  final HistoryRepository? _historyRepo;
  bool canDeleteNotes = false;
  bool canMarkDone = true;

  List<Note> notes = [];
  List<Product> products = [];
  String _search = '';
  String _tagFilter = 'all';
  bool _showDone = true;
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

  List<Note> get filteredNotes {
    final term = _search.toLowerCase();
    return notes.where((n) {
      final matchesSearch = term.isEmpty ||
          n.content.toLowerCase().contains(term) ||
          (n.authorName.toLowerCase().contains(term)) ||
          (n.tag.toLowerCase().contains(term));
      final matchesTag = _tagFilter == 'all' ? true : n.tag.toLowerCase() == _tagFilter;
      final matchesDone = _showDone || !n.isDone;
      return matchesSearch && matchesTag && matchesDone;
    }).toList();
  }

  void setSearch(String value) {
    _search = value;
    notifyListeners();
  }

  void setTagFilter(String tag) {
    _tagFilter = tag.toLowerCase();
    notifyListeners();
  }

  void toggleShowDone(bool value) {
    _showDone = value;
    notifyListeners();
  }

  Future<void> addNote({
    required String authorId,
    required String authorName,
    required String content,
    required String tag,
    required String companyId,
    String? linkedProductId,
    String? priority,
    List<String> assigneeIds = const [],
    List<String> mentionIds = const [],
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
      companyId: companyId,
      assigneeIds: assigneeIds,
      mentionIds: mentionIds,
    );
    try {
      await _noteRepo.addNote(note);
      // Stream will update; fetch is a fallback for non-stream repos.
      notes = await _noteRepo.getNotes();
      await _logHistory(
        action: 'note_add',
        itemName: content,
        details: {
          'author': authorName,
          'tag': tag,
          if (linkedProductId != null) 'productId': linkedProductId,
        },
      );
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
      final note = notes.firstWhere((n) => n.id == id, orElse: () => notes.first);
      await _noteRepo.markDone(
        id: id,
        doneBy: doneBy,
        doneAt: DateTime.now(),
      );
      notes = await _noteRepo.getNotes();
      await _logHistory(
        action: 'note_done',
        itemName: note.content,
        details: {'doneBy': doneBy, 'tag': note.tag},
      );
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteNote(String id) async {
    try {
      final note = notes.firstWhere((n) => n.id == id, orElse: () => notes.first);
      await _noteRepo.deleteNote(id);
      notes = await _noteRepo.getNotes();
      await _logHistory(
        action: 'note_delete',
        itemName: note.content,
        details: {'tag': note.tag},
      );
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
  // Notifications are emitted in the FirestoreNoteRepository (notifications collection).

  void replaceRepository(NoteRepository repo) {
    if (identical(_noteRepo, repo)) return;
    _subscription?.cancel();
    _noteRepo = repo;
    init();
  }

  void setPermissions({required bool isOwner}) {
    canDeleteNotes = isOwner;
    // Allow all roles to mark notes done; tighten later if needed.
    canMarkDone = true;
    notifyListeners();
  }

  Future<void> _logHistory({
    required String action,
    String? itemName,
    Map<String, dynamic>? details,
  }) async {
    if (_historyRepo == null) return;
    try {
      final entry = HistoryEntry(
        id: '',
        companyId: '',
        actionType: action,
        itemName: itemName ?? 'note',
        performedBy: 'user',
        timestamp: DateTime.now(),
        details: details,
      );
      await _historyRepo.logEntry(entry);
    } catch (_) {
      // best-effort
    }
  }
}

