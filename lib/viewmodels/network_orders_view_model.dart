import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/company.dart';
import '../models/order.dart';
import '../repositories/network_orders_repository.dart';

class NetworkOrdersViewModel extends ChangeNotifier {
  NetworkOrdersViewModel(this._repo, this._companies);

  final NetworkOrdersRepository _repo;
  final List<Company> _companies;

  final List<OrderModel> orders = [];
  bool loading = false;
  bool hasMore = true;
  String? error;

  final Set<String> _companyFilter = {};
  final Set<OrderStatus> _statusFilter = {};
  String supplierFilter = '';
  String searchFilter = '';
  DateTimeRange? dateRange;
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;

  List<String> get activeCompanyIds =>
      _companyFilter.isEmpty ? _companies.map((c) => c.id).toList() : _companyFilter.toList();

  Map<String, Company> get companyById => {for (final c in _companies) c.id: c};
  bool isStatusSelected(OrderStatus status) => _statusFilter.contains(status);

  Future<void> load({bool reset = false}) async {
    if (loading) return;
    if (reset) {
      orders.clear();
      _lastDoc = null;
      hasMore = true;
      error = null;
    }
    if (!hasMore) return;
    loading = true;
    notifyListeners();
    try {
      final page = await _repo.fetchOrders(
        companyIds: activeCompanyIds,
        statuses: _statusFilter.isEmpty ? null : _statusFilter.toList(),
        supplier: supplierFilter.isNotEmpty ? supplierFilter : null,
        productQuery: searchFilter.isNotEmpty ? searchFilter : null,
        startDate: dateRange?.start,
        endDate: dateRange?.end,
        startAfter: _lastDoc,
        limit: 20,
      );
      orders.addAll(page.orders);
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

  void toggleStatus(OrderStatus status) {
    if (_statusFilter.contains(status)) {
      _statusFilter.remove(status);
    } else {
      _statusFilter.add(status);
    }
    load(reset: true);
  }

  void setSupplier(String value) {
    supplierFilter = value.trim();
    load(reset: true);
  }

  void setSearch(String value) {
    searchFilter = value.trim();
    load(reset: true);
  }

  void setDateRange(DateTimeRange? range) {
    dateRange = range;
    load(reset: true);
  }
}
