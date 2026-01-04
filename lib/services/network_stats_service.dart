import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/company.dart';

class CompanyStats {
  CompanyStats({
    required this.companyId,
    required this.companyName,
    required this.companyCode,
    required this.pendingOrders,
    required this.confirmedOrders,
    required this.deliveredRecently,
    required this.openNotes,
    required this.historyEntriesRecent,
  });

  final String companyId;
  final String companyName;
  final String companyCode;
  final int pendingOrders;
  final int confirmedOrders;
  final int deliveredRecently;
  final int openNotes;
  final int historyEntriesRecent;
}

class OrdersOverTimePoint {
  OrdersOverTimePoint({required this.day, required this.count});

  final DateTime day;
  final int count;
}

class NetworkStatsService {
  NetworkStatsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<List<CompanyStats>> fetchCompanyStats({
    required List<Company> companies,
    DateTime? since,
  }) async {
    if (companies.isEmpty) return [];
    final cutoff = since ?? DateTime.now().subtract(const Duration(days: 30));
    final results = <CompanyStats>[];

    for (final company in companies) {
      final ordersCol =
          _firestore.collection('companies').doc(company.id).collection('orders');
      final notesCol =
          _firestore.collection('companies').doc(company.id).collection('notes');
      final historyCol =
          _firestore.collection('companies').doc(company.id).collection('history');

      final pending = await _count(
        ordersCol.where('status', isEqualTo: 'pending'),
      );
      final confirmed = await _count(
        ordersCol.where('status', isEqualTo: 'confirmed'),
      );
      final deliveredRecent = await _count(
        ordersCol
            .where('status', isEqualTo: 'delivered')
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff)),
      );
      final openNotes = await _count(
        notesCol.where('isDone', isEqualTo: false),
      );
      final historyRecent = await _count(
        historyCol.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff)),
      );

      results.add(
        CompanyStats(
          companyId: company.id,
          companyName: company.name,
          companyCode: company.companyCode,
          pendingOrders: pending,
          confirmedOrders: confirmed,
          deliveredRecently: deliveredRecent,
          openNotes: openNotes,
          historyEntriesRecent: historyRecent,
        ),
      );
    }
    return results;
  }

  Future<int> _count(Query<Map<String, dynamic>> query) async {
    try {
      final agg = await query.count().get();
      return agg.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<List<OrdersOverTimePoint>> ordersOverTime({
    required List<String> companyIds,
    required DateTimeRange range,
  }) async {
    if (companyIds.isEmpty) return [];
    final scoped = companyIds.take(10).toList();
    Query<Map<String, dynamic>> q = _firestore
        .collectionGroup('orders')
        .where('companyId', whereIn: scoped)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(range.start))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(range.end))
        .orderBy('createdAt');
    final snap = await q.get();
    final buckets = <DateTime, int>{};
    for (final doc in snap.docs) {
      final ts = doc.data()['createdAt'] as Timestamp?;
      if (ts == null) continue;
      final day = DateTime(ts.toDate().year, ts.toDate().month, ts.toDate().day);
      buckets[day] = (buckets[day] ?? 0) + 1;
    }
    return buckets.entries
        .map((e) => OrdersOverTimePoint(day: e.key, count: e.value))
        .toList()
      ..sort((a, b) => a.day.compareTo(b.day));
  }
}
