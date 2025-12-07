import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/history_entry.dart';
import '../repositories/history_repository.dart';

class HistoryViewModel extends ChangeNotifier {
  HistoryViewModel(this._repo);

  final HistoryRepository _repo;
  List<HistoryEntry> entries = [];
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
      entries = _applyFilters(data);
      loading = false;
      error = null;
      notifyListeners();
    }, onError: (e) {
      error = e.toString();
      loading = false;
      notifyListeners();
    });
  }

  void setFilters({String? action, String? productId}) {
    actionFilter = action;
    productFilter = productId;
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
