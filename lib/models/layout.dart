import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a visual layout for a bar or warehouse.
/// Cells and zones are stored here so items can be placed without mutating the item itself.
class Layout {
  const Layout({
    required this.id,
    required this.companyId,
    required this.scope, // e.g. 'bar' or 'warehouse'
    required this.rows,
    required this.columns,
    this.zones = const [],
    this.cells = const [],
    this.updatedAt,
    this.lastUpdatedBy,
  });

  final String id;
  final String companyId;
  final String scope;
  final int rows;
  final int columns;
  final List<LayoutZone> zones;
  final List<LayoutCell> cells;
  final DateTime? updatedAt;
  final String? lastUpdatedBy;

  factory Layout.fromMap(String id, Map<String, dynamic> data) {
    return Layout(
      id: id,
      companyId: data['companyId'] as String? ?? '',
      scope: data['scope'] as String? ?? 'bar',
      rows: (data['rows'] as num?)?.toInt() ?? 0,
      columns: (data['columns'] as num?)?.toInt() ?? 0,
      zones: (data['zones'] as List<dynamic>? ?? [])
          .map((e) => LayoutZone.fromMap((e as Map).cast<String, dynamic>()))
          .toList(),
      cells: (data['cells'] as List<dynamic>? ?? [])
          .map((e) => LayoutCell.fromMap((e as Map).cast<String, dynamic>()))
          .toList(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      lastUpdatedBy: data['lastUpdatedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'scope': scope,
      'rows': rows,
      'columns': columns,
      if (zones.isNotEmpty) 'zones': zones.map((z) => z.toMap()).toList(),
      if (cells.isNotEmpty) 'cells': cells.map((c) => c.toMap()).toList(),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (lastUpdatedBy != null) 'lastUpdatedBy': lastUpdatedBy,
    };
  }
}

class LayoutZone {
  const LayoutZone({
    required this.id,
    required this.name,
    this.color,
    this.description,
    this.cellIds = const [],
    this.type,
  });

  final String id;
  final String name;
  final String? color;
  final String? description;
  final List<String> cellIds;
  final String? type;

  factory LayoutZone.fromMap(Map<String, dynamic> data) {
    return LayoutZone(
      id: data['id'] as String? ?? '',
      name: data['name'] as String? ?? '',
      color: data['color'] as String?,
      description: data['description'] as String?,
      cellIds: (data['cellIds'] as List<dynamic>? ?? []).cast<String>(),
      type: data['type'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      if (color != null) 'color': color,
      if (description != null) 'description': description,
      if (cellIds.isNotEmpty) 'cellIds': cellIds,
      if (type != null) 'type': type,
    };
  }
}

class LayoutCell {
  const LayoutCell({
    required this.id,
    required this.row,
    required this.column,
    this.level,
    this.zoneId,
    this.name,
    this.type,
    this.capacity,
    this.items = const [],
  });

  final String id;
  final int row;
  final int column;
  final int? level;
  final String? zoneId;
  final String? name;
  final String? type;
  final int? capacity;
  final List<CellItemPlacement> items;

  factory LayoutCell.fromMap(Map<String, dynamic> data) {
    return LayoutCell(
      id: data['id'] as String? ?? '',
      row: (data['row'] as num?)?.toInt() ?? 0,
      column: (data['column'] as num?)?.toInt() ?? 0,
      level: (data['level'] as num?)?.toInt(),
      zoneId: data['zoneId'] as String?,
      name: data['name'] as String?,
      type: data['type'] as String?,
      capacity: (data['capacity'] as num?)?.toInt(),
      items: (data['items'] as List<dynamic>? ?? [])
          .map((e) => CellItemPlacement.fromMap((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'row': row,
      'column': column,
      if (level != null) 'level': level,
      if (zoneId != null) 'zoneId': zoneId,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (capacity != null) 'capacity': capacity,
      if (items.isNotEmpty) 'items': items.map((i) => i.toMap()).toList(),
    };
  }
}

class CellItemPlacement {
  const CellItemPlacement({
    required this.productId,
    this.quantity = 0,
    this.status,
  });

  final String productId;
  final int quantity;
  final String? status;

  factory CellItemPlacement.fromMap(Map<String, dynamic> data) {
    return CellItemPlacement(
      productId: data['productId'] as String? ?? '',
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      status: data['status'] as String?,
    );
  }

  CellItemPlacement copyWith({
    String? productId,
    int? quantity,
    String? status,
  }) {
    return CellItemPlacement(
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'quantity': quantity,
      if (status != null) 'status': status,
    };
  }
}
