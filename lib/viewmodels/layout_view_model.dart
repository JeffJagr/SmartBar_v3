import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/layout.dart';
import '../repositories/layout_repository.dart';
import '../services/permission_service.dart';

class LayoutViewModel extends ChangeNotifier {
  LayoutViewModel(this._repo);

  final LayoutRepository _repo;

  Layout? layout;
  bool loading = true;
  String? error;
  PermissionSnapshot? _snapshot;
  PermissionService? _permissions;
  StreamSubscription<Layout?>? _sub;

  Future<void> init({required String scope}) async {
    loading = true;
    notifyListeners();
    _sub?.cancel();
    _sub = _repo.watchLayout(scope: scope).listen((data) {
      layout = data;
      loading = false;
      error = null;
      notifyListeners();
    }, onError: (e) {
      error = e.toString();
      loading = false;
      notifyListeners();
    });
  }

  void applyPermissionContext({
    required PermissionSnapshot snapshot,
    PermissionService? service,
  }) {
    _snapshot = snapshot;
    _permissions = service;
  }

  bool get canEdit =>
      _permissions != null && _snapshot != null && _permissions!.canEditProducts(_snapshot!);

  Future<void> createEmptyLayout({
    required String companyId,
    required String scope,
    required int rows,
    required int columns,
  }) async {
    if (!canEdit) {
      error = 'No permission to edit layout';
      notifyListeners();
      return;
    }
    final cells = <LayoutCell>[];
    final uuid = const Uuid();
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < columns; c++) {
        cells.add(LayoutCell(id: uuid.v4(), row: r, column: c, items: const []));
      }
    }
    final l = Layout(
      id: scope,
      companyId: companyId,
      scope: scope,
      rows: rows,
      columns: columns,
      cells: cells,
      zones: const [],
      updatedAt: DateTime.now(),
    );
    await _repo.saveLayout(l);
  }

  Future<void> renameCell(String cellId, String name) async {
    if (!canEdit || layout == null) return;
    final cells = layout!.cells
        .map((c) => c.id == cellId ? LayoutCell(id: c.id, row: c.row, column: c.column, level: c.level, zoneId: c.zoneId, name: name, type: c.type, capacity: c.capacity, items: c.items) : c)
        .toList();
    await _repo.saveLayout(layout!.copyWith(cells: cells, updatedAt: DateTime.now()));
  }

  Future<void> updateCellType(String cellId, String? type, int? capacity) async {
    if (!canEdit || layout == null) return;
    final cells = layout!.cells
        .map((c) => c.id == cellId
            ? LayoutCell(
                id: c.id,
                row: c.row,
                column: c.column,
                level: c.level,
                zoneId: c.zoneId,
                name: c.name,
                type: type,
                capacity: capacity,
                items: c.items,
              )
            : c)
        .toList();
    await _repo.saveLayout(layout!.copyWith(cells: cells, updatedAt: DateTime.now()));
  }

  Future<void> assignZone(String cellId, String zoneId) async {
    if (!canEdit || layout == null) return;
    final cells = layout!.cells
        .map((c) => c.id == cellId
            ? LayoutCell(
                id: c.id,
                row: c.row,
                column: c.column,
                level: c.level,
                zoneId: zoneId,
                name: c.name,
                type: c.type,
                capacity: c.capacity,
                items: c.items,
              )
            : c)
        .toList();
    await _repo.saveLayout(layout!.copyWith(cells: cells, updatedAt: DateTime.now()));
  }

  Future<void> createZone(String name, List<String> cellIds) async {
    if (!canEdit || layout == null) return;
    final uuid = const Uuid();
    final newZone = LayoutZone(id: uuid.v4(), name: name, cellIds: cellIds);
    final zones = [...layout!.zones, newZone];
    await _repo.saveLayout(layout!.copyWith(zones: zones, updatedAt: DateTime.now()));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

extension on Layout {
  Layout copyWith({
    String? id,
    String? companyId,
    String? scope,
    int? rows,
    int? columns,
    List<LayoutZone>? zones,
    List<LayoutCell>? cells,
    DateTime? updatedAt,
  }) {
    return Layout(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      scope: scope ?? this.scope,
      rows: rows ?? this.rows,
      columns: columns ?? this.columns,
      zones: zones ?? this.zones,
      cells: cells ?? this.cells,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
