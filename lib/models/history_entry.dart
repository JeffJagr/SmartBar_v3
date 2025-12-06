import 'package:cloud_firestore/cloud_firestore.dart';

class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.companyId,
    required this.actionType,
    required this.itemName,
    required this.performedBy,
    required this.timestamp,
    this.description,
    this.details,
    this.itemId,
  });

  final String id;
  final String companyId;
  final String actionType;
  final String itemName;
  final String performedBy;
  final DateTime timestamp;
  final String? description;
  final Map<String, dynamic>? details;
  final String? itemId;

  /// For legacy callers that still expect createdAt.
  DateTime get createdAt => timestamp;

  factory HistoryEntry.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return HistoryEntry.fromMap(doc.id, doc.data() ?? {});
  }

  factory HistoryEntry.fromMap(String id, Map<String, dynamic> data) {
    return HistoryEntry(
      id: id,
      companyId: data['companyId'] as String? ?? '',
      actionType: data['actionType'] as String? ?? data['type'] as String? ?? 'unknown',
      itemName: data['itemName'] as String? ?? data['item'] as String? ?? '',
      performedBy: data['performedBy'] as String? ?? data['actor'] as String? ?? 'system',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ??
          (data['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      description: data['description'] as String?,
      details: (data['details'] as Map?)?.cast<String, dynamic>(),
      itemId: data['itemId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'actionType': actionType,
      'itemName': itemName,
      'performedBy': performedBy,
      'timestamp': Timestamp.fromDate(timestamp),
      if (description != null) 'description': description,
      if (details != null) 'details': details,
      if (itemId != null) 'itemId': itemId,
    };
  }
}
