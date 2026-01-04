import 'package:flutter/material.dart';

import '../models/company.dart';
import '../services/network_stats_service.dart';

class NetworkStatsViewModel extends ChangeNotifier {
  NetworkStatsViewModel(this._service, this._companies);

  final NetworkStatsService _service;
  final List<Company> _companies;

  List<CompanyStats> stats = [];
  List<OrdersOverTimePoint> overTime = [];
  bool loading = false;
  String? error;
  DateTimeRange range =
      DateTimeRange(start: DateTime.now().subtract(const Duration(days: 30)), end: DateTime.now());
  final Set<String> _companyFilter = {};
  String supplierFilter = '';

  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      final selectedCompanies =
          _companyFilter.isEmpty ? _companies : _companies.where((c) => _companyFilter.contains(c.id)).toList();
      stats = await _service.fetchCompanyStats(
        companies: selectedCompanies,
        since: range.start,
      );
      overTime = await _service.ordersOverTime(
        companyIds: selectedCompanies.map((c) => c.id).toList(),
        range: range,
      );
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void setRange(DateTimeRange newRange) {
    range = newRange;
    load();
  }

  void toggleCompany(String companyId) {
    if (_companyFilter.contains(companyId)) {
      _companyFilter.remove(companyId);
    } else {
      _companyFilter.add(companyId);
    }
    load();
  }

  void setSupplier(String value) {
    supplierFilter = value;
    // Placeholder: supplier filter can be wired to future supplier-aware stats.
    notifyListeners();
  }

  List<Company> get companies =>
      _companyFilter.isEmpty ? _companies : _companies.where((c) => _companyFilter.contains(c.id)).toList();

  List<Company> get allCompanies => _companies;
}
