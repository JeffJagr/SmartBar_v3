import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/layout.dart';
import '../repositories/layout_repository.dart';
import '../services/permission_service.dart';

class LayoutViewModel extends ChangeNotifier {
  LayoutViewModel(this._repo);

  LayoutRepository _repo;
  Layout? layout;
  bool loading = true;
  String? error;
  String _scope = 'bar';
  PermissionSnapshot? _snapshot;
  PermissionService? _permissions;
  StreamSubscription<Layout?>? _sub;

  Future<void> init({required String scope}) async {
    _scope = scope;
    loading = true;
    notifyListeners();
    _sub?.cancel();
    _sub = _repo.watchLayout(scope: _scope).listen((data) {
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

  void replaceRepository(LayoutRepository repo) {
    if (identical(_repo, repo)) return;
    _sub?.cancel();
    _repo = repo;
    init(scope: _scope);
  }

  void applyPermissionContext({
    required PermissionSnapshot snapshot,
    PermissionService? service,
  }) {
    _snapshot = snapshot;
    _permissions = service;
    notifyListeners();
  }

  bool get canEdit =>
      _permissions != null && _snapshot != null && _permissions!.canEditProducts(_snapshot!);

  Future<void> ensureDefaultLayout({
    required String companyId,
    required String scope,
    int rows = 3,
    int columns = 3,
  }) async {
    if (layout != null) return;
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
      lastUpdatedBy: null,
    );
    await _repo.saveLayout(l);
  }

  Future<void> setGridSize({
    required int rows,
    required int columns,
  }) async {
    if (!canEdit) return;
    final uuid = const Uuid();
    final cells = <LayoutCell>[];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < columns; c++) {
        cells.add(LayoutCell(id: uuid.v4(), row: r, column: c, items: const []));
      }
    }
    final newLayout = (layout ??
            Layout(
              id: _scope,
              companyId: '',
              scope: _scope,
              rows: rows,
              columns: columns,
              zones: const [],
              cells: cells,
              updatedAt: DateTime.now(),
              lastUpdatedBy: null,
            ))
        .copyWith(
      rows: rows,
      columns: columns,
      cells: cells,
      updatedAt: DateTime.now(),
      lastUpdatedBy: null,
    );
    await _repo.saveLayout(newLayout);
  }

  Future<void> addRow() async {
    if (!canEdit || layout == null) return;
    final uuid = const Uuid();
    final nextRow = (layout?.rows ?? 0);
    final cols = layout?.columns ?? 0;
    final newCells = [
      ...layout!.cells,
      for (int c = 0; c < cols; c++)
        LayoutCell(id: uuid.v4(), row: nextRow, column: c, items: const []),
    ];
    await _repo.saveLayout(layout!.copyWith(
      rows: nextRow + 1,
      cells: newCells,
      updatedAt: DateTime.now(),
      lastUpdatedBy: null,
    ));
  }

  Future<void> addColumn() async {
    if (!canEdit || layout == null) return;
    final uuid = const Uuid();
    final nextCol = (layout?.columns ?? 0);
    final rows = layout?.rows ?? 0;
    final newCells = [
      ...layout!.cells,
      for (int r = 0; r < rows; r++)
        LayoutCell(id: uuid.v4(), row: r, column: nextCol, items: const []),
    ];
    await _repo.saveLayout(layout!.copyWith(
      columns: nextCol + 1,
      cells: newCells,
      updatedAt: DateTime.now(),
      lastUpdatedBy: null,
    ));
  }

  Future<void> deleteCell(String cellId) async {
    if (!canEdit || layout == null) return;
    final cells = layout!.cells.where((c) => c.id != cellId).toList();
    await _repo.saveLayout(layout!.copyWith(
      cells: cells,
      updatedAt: DateTime.now(),
      lastUpdatedBy: null,
    ));
  }

  Future<void> renameCell(String cellId, String name) async {
    if (!canEdit || layout == null) return;
    final cells = layout!.cells
        .map((c) => c.id == cellId ? c.copyWith(name: name) : c)
        .toList();
    await _repo.saveLayout(layout!.copyWith(
      cells: cells,
      updatedAt: DateTime.now(),
      lastUpdatedBy: null,
    ));
  }

  Future<void> updateCellAttributes(
    String cellId, {
    String? name,
    String? type,
    int? capacity,
    int? level,
  }) async {
    if (!canEdit || layout == null) return;
    final cells = layout!.cells
        .map((c) => c.id == cellId
            ? c.copyWith(
                name: name ?? c.name,
                type: type ?? c.type,
                capacity: capacity ?? c.capacity,
                level: level ?? c.level,
              )
            : c)
        .toList();
    await _repo.saveLayout(layout!.copyWith(
      cells: cells,
      updatedAt: DateTime.now(),
      lastUpdatedBy: null,
    ));
  }

  Future<void> assignZone({
    required String cellId,
    required String zoneName,
  }) async {
    if (!canEdit || layout == null) return;
    final existing = layout!.zones.firstWhere(
      (z) => z.name.toLowerCase() == zoneName.toLowerCase(),
      orElse: () => const LayoutZone(id: '', name: ''),
    );
    final zoneId = existing.id.isNotEmpty ? existing.id : const Uuid().v4();
    final zones = existing.id.isNotEmpty
        ? layout!.zones
        : [...layout!.zones, LayoutZone(id: zoneId, name: zoneName)];
    final cells = layout!.cells
        .map((c) => c.id == cellId ? c.copyWith(zoneId: zoneId) : c)
        .toList();
    await _repo.saveLayout(
      layout!.copyWith(
        zones: zones,
        cells: cells,
        updatedAt: DateTime.now(),
        lastUpdatedBy: null,
      ),
    );
  }

  Future<void> clearZone(String cellId) async {
    if (!canEdit || layout == null) return;
    final cells =
        layout!.cells.map((c) => c.id == cellId ? c.copyWith(zoneId: null) : c).toList();
    await _repo.saveLayout(layout!.copyWith(
      cells: cells,
      updatedAt: DateTime.now(),
      lastUpdatedBy: null,
    ));
  }

  Future<void> updateZone({
    required String zoneId,
    String? name,
    String? color,
    String? type,
  }) async {
    if (!canEdit || layout == null) return;
    final zones = layout!.zones
        .map((z) => z.id == zoneId
            ? LayoutZone(
                id: z.id,
                name: name ?? z.name,
                color: color ?? z.color,
                description: z.description,
                cellIds: z.cellIds,
                type: type ?? z.type,
              )
            : z)
        .toList();
    await _repo.saveLayout(
      layout!.copyWith(
        zones: zones,
        updatedAt: DateTime.now(),
        lastUpdatedBy: null,
      ),
    );
  }

  /// Export current layout as JSON for backup/template.
  String? exportLayoutJson() {
    if (layout == null) return null;
    return jsonEncode(layout!.toMap());
  }

  /// Import layout JSON (expects map-like string). Overwrites current layout.
  Future<void> importLayoutJson(String jsonString) async {
    if (!canEdit) return;
    try {
      final map = jsonDecode(jsonString) as Map<String, dynamic>;
      final imported = Layout.fromMap(_scope, map).copyWith(
        updatedAt: DateTime.now(),
        lastUpdatedBy: null,
      );
      await _repo.saveLayout(imported);
    } catch (e) {
      error = 'Failed to import layout: $e';
      notifyListeners();
    }
  }

  Future<void> setItemPlacement({
    required String cellId,
    required String productId,
    required int quantity,
  }) async {
    if (!canEdit || layout == null) return;
    final cells = layout!.cells.map((c) {
      if (c.id != cellId) return c;
      final updatedItems = <CellItemPlacement>[];
      bool replaced = false;
      for (final it in c.items) {
        if (it.productId == productId) {
          updatedItems.add(it.copyWith(quantity: quantity));
          replaced = true;
        } else {
          updatedItems.add(it);
        }
      }
      if (!replaced) {
        updatedItems.add(CellItemPlacement(productId: productId, quantity: quantity));
      }
      return c.copyWith(items: updatedItems);
    }).toList();
    await _repo.saveLayout(layout!.copyWith(
      cells: cells,
      updatedAt: DateTime.now(),
      lastUpdatedBy: null,
    ));
  }

  Future<void> clearItemPlacement({
    required String cellId,
    required String productId,
  }) async {
    if (!canEdit || layout == null) return;
    final cells = layout!.cells.map((c) {
      if (c.id != cellId) return c;
      return c.copyWith(items: c.items.where((it) => it.productId != productId).toList());
    }).toList();
    await _repo.saveLayout(layout!.copyWith(
      cells: cells,
      updatedAt: DateTime.now(),
      lastUpdatedBy: null,
    ));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

extension LayoutCopy on Layout {
  Layout copyWith({
    String? id,
    String? companyId,
    String? scope,
    int? rows,
    int? columns,
    List<LayoutZone>? zones,
    List<LayoutCell>? cells,
    DateTime? updatedAt,
    String? lastUpdatedBy,
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
      lastUpdatedBy: lastUpdatedBy ?? this.lastUpdatedBy,
    );
  }
}

extension CellCopy on LayoutCell {
  LayoutCell copyWith({
    String? id,
    int? row,
    int? column,
    int? level,
    String? zoneId,
    String? name,
    String? type,
    int? capacity,
    List<CellItemPlacement>? items,
  }) {
    return LayoutCell(
      id: id ?? this.id,
      row: row ?? this.row,
      column: column ?? this.column,
      level: level ?? this.level,
      zoneId: zoneId ?? this.zoneId,
      name: name ?? this.name,
      type: type ?? this.type,
      capacity: capacity ?? this.capacity,
      items: items ?? this.items,
    );
  }
}
