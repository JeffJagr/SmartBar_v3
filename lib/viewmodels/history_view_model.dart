import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/history_entry.dart';
import '../repositories/history_repository.dart';

class HistoryViewModel extends ChangeNotifier {
  HistoryViewModel(this._repo);

  final HistoryRepository _repo;
  List<HistoryEntry> entries = [];
  List<HistoryEntry> _allEntries = [];
  bool loading = true;
  String? error;
  StreamSubscription<List<HistoryEntry>>? _sub;

  String? actionFilter;
  String? productFilter;

  Future<void> init() async {
    _sub?.cancel();
    loading = true;
    notifyListeners();
    _sub = _repo.watchEntries().listen((data) {
      _allEntries = data;
      entries = _applyFilters(_allEntries);
      loading = false;
      error = null;
      notifyListeners();
    }, onError: (e) {
      error = e.toString();
      loading = false;
      notifyListeners();
    });
  }

  Future<void> refresh({int limit = 100}) async {
    try {
      loading = true;
      notifyListeners();
      final latest = await _repo.fetchLatest(limit: limit);
      _allEntries = latest;
      entries = _applyFilters(_allEntries);
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void setFilters({String? action, String? productId}) {
    actionFilter = action;
    productFilter = productId;
    entries = _applyFilters(_allEntries);
    notifyListeners();
  }

  List<HistoryEntry> _applyFilters(List<HistoryEntry> list) {
    return list.where((e) {
      final matchAction = actionFilter == null || e.actionType == actionFilter;
      final matchProduct = productFilter == null || e.itemId == productFilter;
      return matchAction && matchProduct;
    }).toList();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
