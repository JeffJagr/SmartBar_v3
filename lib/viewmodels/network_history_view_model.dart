import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/company.dart';
import '../models/history_entry.dart';
import '../repositories/network_history_repository.dart';

class NetworkHistoryViewModel extends ChangeNotifier {
  NetworkHistoryViewModel(this._repo, this._companies);

  final NetworkHistoryRepository _repo;
  final List<Company> _companies;

  final List<HistoryEntry> entries = [];
  bool loading = false;
  bool hasMore = true;
  String? error;

  final Set<String> _companyFilter = {};
  String actionFilter = '';
  String search = '';
  String itemIdFilter = '';
  DateTimeRange? dateRange;
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;

  List<String> get activeCompanyIds =>
      _companyFilter.isEmpty ? _companies.map((c) => c.id).toList() : _companyFilter.toList();
  Map<String, Company> get _companyMap => {for (final c in _companies) c.id: c};
  List<Company> get companies => _companies;
  String companyName(String companyId) => _companyMap[companyId]?.name ?? 'Unknown';

  Future<void> load({bool reset = false}) async {
    if (loading) return;
    if (reset) {
      entries.clear();
      _lastDoc = null;
      hasMore = true;
      error = null;
    }
    if (!hasMore) return;
    loading = true;
    notifyListeners();
    try {
      final page = await _repo.fetchHistory(
        companyIds: activeCompanyIds,
        actionType: actionFilter.isNotEmpty ? actionFilter : null,
        itemId: itemIdFilter.isNotEmpty ? itemIdFilter : null,
        startDate: dateRange?.start,
        endDate: dateRange?.end,
        search: search.isNotEmpty ? search : null,
        startAfter: _lastDoc,
        limit: 30,
      );
      entries.addAll(page.entries);
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

  void toggleCompany(String companyId) {
    if (_companyFilter.contains(companyId)) {
      _companyFilter.remove(companyId);
    } else {
      _companyFilter.add(companyId);
    }
    load(reset: true);
  }

  void setAction(String value) {
    actionFilter = value;
    load(reset: true);
  }

  void setSearch(String value) {
    search = value;
    load(reset: true);
  }

  void setItem(String value) {
    itemIdFilter = value;
    load(reset: true);
  }

  void setDateRange(DateTimeRange? range) {
    dateRange = range;
    load(reset: true);
  }
}
