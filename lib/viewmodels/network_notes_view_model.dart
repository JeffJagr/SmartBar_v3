import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/company.dart';
import '../models/note.dart';
import '../repositories/network_notes_repository.dart';

class NetworkNotesViewModel extends ChangeNotifier {
  NetworkNotesViewModel(this._repo, this._companies, {required this.currentUserId});

  final NetworkNotesRepository _repo;
  final List<Company> _companies;
  final String currentUserId;

  final List<Note> notes = [];
  bool loading = false;
  bool hasMore = true;
  String? error;

  final Set<String> _companyFilter = {};
  String tagFilter = 'all';
  bool showDone = true;
  String search = '';
  String linkedProductFilter = '';
  String assigneeFilter = '';
  String mentionFilter = '';
  bool assignedToMe = false;
  bool unreadOnly = false;
  DateTimeRange? dateRange;
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;

  List<Company> get companies => _companies;

  List<String> get activeCompanyIds =>
      _companyFilter.isEmpty ? _companies.map((c) => c.id).toList() : _companyFilter.toList();

  Map<String, Company> get _companyMap => {for (final c in _companies) c.id: c};

  String companyName(String companyId) => _companyMap[companyId]?.name ?? 'Unknown';
  Map<String, Company> get companiesById => _companyMap;

  Future<void> load({bool reset = false}) async {
    if (loading) return;
    if (reset) {
      notes.clear();
      _lastDoc = null;
      hasMore = true;
      error = null;
    }
    if (!hasMore) return;
    loading = true;
    notifyListeners();
    try {
      final page = await _repo.fetchNotes(
        companyIds: activeCompanyIds,
        tag: tagFilter,
        isDone: showDone ? null : false,
        linkedProductId: linkedProductFilter.isNotEmpty ? linkedProductFilter : null,
        assigneeId: assigneeFilter.isNotEmpty ? assigneeFilter : null,
        mentionId: mentionFilter.isNotEmpty ? mentionFilter : null,
        startDate: dateRange?.start,
        endDate: dateRange?.end,
        search: search.isNotEmpty ? search : null,
        currentUserId: currentUserId,
        assignedToMe: assignedToMe,
        unreadOnly: unreadOnly,
        startAfter: _lastDoc,
        limit: 20,
      );
      notes.addAll(page.notes);
      _lastDoc = page.lastDocument;
      hasMore = page.hasMore;
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> addNote({
    required String companyId,
    required String authorId,
    required String authorName,
    required String content,
    required String tag,
    String? linkedProductId,
    String? priority,
    List<String> assigneeIds = const [],
    List<String> mentionIds = const [],
  }) async {
    try {
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
      await _repo.addNote(companyId: companyId, note: note);
      await load(reset: true);
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  void toggleCompany(String companyId) {
    if (_companyFilter.contains(companyId)) {
      _companyFilter.remove(companyId);
    } else {
      _companyFilter.add(companyId);
    }
    load(reset: true);
  }

  void setTag(String value) {
    tagFilter = value;
    load(reset: true);
  }

  void setShowDone(bool value) {
    showDone = value;
    load(reset: true);
  }

  void setSearch(String value) {
    search = value;
    load(reset: true);
  }

  void setLinkedProduct(String value) {
    linkedProductFilter = value;
    load(reset: true);
  }

  void setAssignee(String value) {
    assigneeFilter = value;
    load(reset: true);
  }

  void setAssignedToMe(bool value) {
    assignedToMe = value;
    load(reset: true);
  }

  void setUnreadOnly(bool value) {
    unreadOnly = value;
    load(reset: true);
  }

  void setMention(String value) {
    mentionFilter = value;
    load(reset: true);
  }

  void setDateRange(DateTimeRange? range) {
    dateRange = range;
    load(reset: true);
  }

  Future<void> markDone(Note note) async {
    try {
      await _repo.markDone(
        companyId: note.companyId,
        noteId: note.id,
        doneBy: currentUserId,
      );
      await load(reset: true);
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> markRead(Note note) async {
    if (note.readBy.containsKey(currentUserId)) return;
    try {
      await _repo.markRead(
        companyId: note.companyId,
        noteId: note.id,
        userId: currentUserId,
      );
      await load(reset: true);
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }
}
