import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/product.dart';
import '../repositories/inventory_repository.dart';
import '../repositories/group_repository.dart';
import '../repositories/history_repository.dart';
import '../services/permission_service.dart';
import '../models/history_entry.dart';
import '../utils/firestore_error_handler.dart';

/// ViewModel for inventory screens.
class InventoryViewModel extends ChangeNotifier {
  InventoryViewModel(this._repository, [this._groupRepository, this._historyRepository]);

  InventoryRepository _repository;
  final GroupRepository? _groupRepository;
  final HistoryRepository? _historyRepository;
  bool canEditQuantities = false;
  PermissionSnapshot? _permissionSnapshot;
  PermissionService? _permissionService;
  String? get _repoPath {
    if (_repository is FirestoreInventoryRepository) {
      return (_repository as FirestoreInventoryRepository).path;
    }
    return 'inventory';
  }

  List<Product> products = [];
  bool loading = true;
  String? error;
  bool saving = false;
  StreamSubscription<List<Product>>? _subscription;

  String _friendly(Object e, String op) => FirestoreErrorHandler.friendlyMessage(
        e,
        operation: op,
        path: _repoPath,
      );

  Future<void> init() async {
    await _load();
    _subscription?.cancel();
    _subscription = _repository.watchItems().listen((items) {
      products = items.isNotEmpty ? items : (_useFallback ? _fallbackSample() : <Product>[]);
      loading = false;
      error = null;
      notifyListeners();
    }, onError: (e) {
      error = _friendly(e, 'watchInventory');
      loading = false;
      notifyListeners();
    });
  }

  Future<String> exportCsv() async {
    try {
      return await _repository.exportCsv();
    } catch (e) {
      error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void replaceRepository(InventoryRepository repository) {
    if (identical(_repository, repository)) return;
    _subscription?.cancel();
    _repository = repository;
    canEditQuantities = false;
    init();
  }

  Future<void> _load() async {
    try {
      loading = true;
      notifyListeners();
      final fetched = await _repository.getItems();
      products = fetched.isNotEmpty ? fetched : (_useFallback ? _fallbackSample() : <Product>[]);
    } catch (e) {
      error = _friendly(e, 'loadInventory');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> updateRestockHint(String productId, int? hint) async {
    if (!_requireAuth()) return;
    if (_permissionService != null &&
        _permissionSnapshot != null &&
        !_permissionService!.canSetRestockHint(_permissionSnapshot!)) {
      error = 'You do not have permission to set restock hints.';
      notifyListeners();
      return;
    }
    // hint is only a suggestion; does not mutate actual quantities.
    try {
      saving = true;
      notifyListeners();
      await _repository.updateRestockHint(productId, hint);
      await _logHistory(
        action: 'restock_hint_set',
        itemId: productId,
        details: {'hint': hint ?? 0},
      );
      await _analyticsLog(
        event: 'restock_hint_update',
        productId: productId,
        data: {'hint': hint ?? 0},
      );
      products = await _repository.getItems();
      await _notifyRestockHint(productId: productId, hint: hint ?? 0);
    } catch (e) {
      error = _friendly(e, 'updateRestockHint');
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<void> clearRestockHint(String productId) async {
    if (!_requireAuth()) return;
    try {
      saving = true;
      notifyListeners();
      await _repository.clearRestockHint(productId);
      await _logHistory(action: 'restock_hint_clear', itemId: productId);
      products = await _repository.getItems();
      await _notifyRestockHint(productId: productId, hint: 0);
    } catch (e) {
      error = _friendly(e, 'clearRestockHint');
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<void> updateQuantities({
    required String productId,
    int? barQuantity,
    int? warehouseQuantity,
    int? barVolumeMl,
    int? warehouseVolumeMl,
  }) async {
    if (!_requireAuth()) return;
    if ((barQuantity ?? 0) < 0 ||
        (warehouseQuantity ?? 0) < 0 ||
        (barVolumeMl ?? 0) < 0 ||
        (warehouseVolumeMl ?? 0) < 0) {
      error = 'Quantities cannot be negative.';
      notifyListeners();
      return;
    }
    if (_permissionService != null &&
        _permissionSnapshot != null &&
        !_permissionService!.canAdjustQuantities(_permissionSnapshot!)) {
      error = 'Insufficient permissions to adjust quantities.';
      notifyListeners();
      return;
    }
    final previous = products.firstWhere(
      (p) => p.id == productId,
      orElse: () => products.isNotEmpty ? products.first : Product.empty(),
    );
    try {
      saving = true;
      notifyListeners();
      await _repository.updateQuantities(
        itemId: productId,
        barQuantity: barQuantity,
        warehouseQuantity: warehouseQuantity,
        barVolumeMl: barVolumeMl,
        warehouseVolumeMl: warehouseVolumeMl,
      );
      await _logHistory(
        action: 'quantity_update',
        itemId: productId,
        details: {
          if (barQuantity != null) 'barQuantity': barQuantity,
          if (warehouseQuantity != null) 'warehouseQuantity': warehouseQuantity,
          if (barVolumeMl != null) 'barVolumeMl': barVolumeMl,
          if (warehouseVolumeMl != null) 'warehouseVolumeMl': warehouseVolumeMl,
        },
      );
      await _analyticsLog(
        event: 'quantity_update',
        productId: productId,
        data: {
          if (barQuantity != null) 'barQuantity': barQuantity,
          if (warehouseQuantity != null) 'warehouseQuantity': warehouseQuantity,
          if (barVolumeMl != null) 'barVolumeMl': barVolumeMl,
          if (warehouseVolumeMl != null) 'warehouseVolumeMl': warehouseVolumeMl,
        },
      );
      products = await _repository.getItems();
      final updated = products.firstWhere(
        (p) => p.id == productId,
        orElse: () => Product.empty(),
      );
      await _maybeLogLow(previous, updated);
    } catch (e) {
      error = _friendly(e, 'updateQuantities');
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<void> transferToBar({
    required String productId,
    required int quantity,
  }) async {
    if (!_requireAuth()) return;
    if (_permissionService != null &&
        _permissionSnapshot != null &&
        !_permissionService!.canTransferStock(_permissionSnapshot!)) {
      error = 'You do not have permission to transfer stock.';
      notifyListeners();
      return;
    }
    try {
      saving = true;
      notifyListeners();
      await _repository.transferToBar(itemId: productId, quantity: quantity);
      products = await _repository.getItems();
      await _logHistory(
        action: 'transfer_to_bar',
        itemId: productId,
        details: {'quantity': quantity},
      );
      final updated = products.firstWhere(
        (p) => p.id == productId,
        orElse: () => Product.empty(),
      );
      await _maybeLogLow(null, updated);
      notifyListeners();
    } catch (e) {
      error = _friendly(e, 'transferToBar');
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<void> addProduct(Product product) async {
    if (!_requireAuth()) return;
    if (_permissionService != null &&
        _permissionSnapshot != null &&
        !_permissionService!.canEditProducts(_permissionSnapshot!)) {
      error = 'You do not have permission to add products.';
      notifyListeners();
      return;
    }
    try {
      saving = true;
      notifyListeners();
      await _repository.addProduct(product);
      await _logHistory(
        action: 'product_add',
        itemId: product.id,
        itemName: product.name,
      );
      products = await _repository.getItems();
    } catch (e) {
      error = _friendly(e, 'addProduct');
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<void> updateProduct(String productId, Map<String, dynamic> data) async {
    if (!_requireAuth()) return;
    if (_permissionService != null &&
        _permissionSnapshot != null &&
        !_permissionService!.canEditProducts(_permissionSnapshot!)) {
      error = 'You do not have permission to edit products.';
      notifyListeners();
      return;
    }
    try {
      saving = true;
      notifyListeners();
      await _repository.updateProduct(productId, data);
      await _logHistory(
        action: 'product_update',
        itemId: productId,
        details: data,
      );
      products = await _repository.getItems();
    } catch (e) {
      error = _friendly(e, 'updateProduct');
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<void> deleteProduct(String productId) async {
    if (!_requireAuth()) return;
    if (_permissionService != null &&
        _permissionSnapshot != null &&
        !_permissionService!.canEditProducts(_permissionSnapshot!)) {
      error = 'You do not have permission to delete products.';
      notifyListeners();
      return;
    }
    try {
      saving = true;
      notifyListeners();
      await _repository.deleteProduct(productId);
      await _logHistory(
        action: 'product_delete',
        itemId: productId,
      );
      products = await _repository.getItems();
    } catch (e) {
      error = _friendly(e, 'deleteProduct');
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<void> _logHistory({
    required String action,
    String? itemId,
    String? itemName,
    Map<String, dynamic>? details,
  }) async {
    if (_historyRepository == null) return;
    try {
      final entry = HistoryEntry(
        id: '',
        companyId: '',
        actionType: action,
        itemName: itemName ?? itemId ?? 'item',
        performedBy: _permissionSnapshot?.roleLabel ?? 'user',
        timestamp: DateTime.now(),
        details: details,
        itemId: itemId,
      );
      await _historyRepository.logEntry(entry);
    } catch (_) {
      // best-effort; ignore logging failures
    }
  }

  Future<void> _maybeLogLow(Product? previous, Product updated) async {
    if (_historyRepository == null || updated.id.isEmpty) return;
    final wasLow = previous != null && previous.id.isNotEmpty && _isLow(previous);
    final nowLow = _isLow(updated);
    if (nowLow && !wasLow) {
      await _logHistory(
        action: 'low_stock',
        itemId: updated.id,
        itemName: updated.name,
        details: {
          'barQuantity': updated.barQuantity,
          'barVolumeMl': updated.barVolumeMl,
          'thresholdCount': updated.minimalStockThreshold,
          'thresholdMl': updated.minVolumeThresholdMl,
        },
      );
      await _notifyLow(updated);
    }
  }

  bool _isLow(Product p) {
    final unitMl = p.unitVolumeMl ?? 0;
    if (p.trackVolume && unitMl > 0) {
      final currentMl = p.barVolumeMl ?? (p.barQuantity * unitMl);
      final thresholdMl = p.minVolumeThresholdMl ?? 0;
      if (thresholdMl > 0) return currentMl <= thresholdMl;
      final maxMl = p.barMax * unitMl;
      if (maxMl > 0) {
        final ratio = currentMl / maxMl;
        return ratio < 0.5;
      }
    }
    final threshold = p.minimalStockThreshold ?? 0;
    if (threshold > 0) return p.barQuantity <= threshold;
    if (p.barMax > 0) {
      final ratio = p.barQuantity / p.barMax;
      return ratio < 0.5;
    }
    return false;
  }

  Future<void> _notifyLow(Product p) async {
    if (p.companyId.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(p.companyId)
          .collection('notifications')
          .add({
        'type': 'low_stock',
        'productId': p.id,
        'productName': p.name,
        'barQuantity': p.barQuantity,
        'barVolumeMl': p.barVolumeMl,
        'thresholdCount': p.minimalStockThreshold,
        'thresholdMl': p.minVolumeThresholdMl,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (_) {
      // best-effort
    }
  }

  Future<void> _analyticsLog({
    required String event,
    required String productId,
    Map<String, dynamic>? data,
  }) async {
    try {
      final product = products.firstWhere(
        (p) => p.id == productId,
        orElse: () => Product.empty(),
      );
      final companyId = product.companyId;
      if (companyId.isEmpty) return;
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('analytics')
          .add({
        'event': event,
        'productId': productId,
        'at': Timestamp.fromDate(DateTime.now()),
        if (data != null) ...data,
      });
    } catch (_) {
      // best-effort
    }
  }

  Future<void> _notifyRestockHint({required String productId, required int hint}) async {
    final product = products.firstWhere(
      (p) => p.id == productId,
      orElse: () => Product.empty(),
    );
    final companyId = product.companyId;
    if (companyId.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('notifications')
          .add({
        'type': 'restock_hint',
        'productId': productId,
        'productName': product.name,
        'hint': hint,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (_) {
      // best-effort
    }
  }

  void setPermissions({required bool isOwner}) {
    canEditQuantities = isOwner;
    notifyListeners();
  }

  void applyPermissionContext({
    required PermissionSnapshot snapshot,
    PermissionService? service,
  }) {
    _permissionSnapshot = snapshot;
    _permissionService = service;
    canEditQuantities = service?.canAdjustQuantities(snapshot) ?? canEditQuantities;
    notifyListeners();
  }

  bool _requireAuth() {
    if (FirebaseAuth.instance.currentUser == null) {
      error = 'Not authenticated. Please sign in again.';
      notifyListeners();
      return false;
    }
    return true;
  }

  /// Assign selected items into a group (name + optional color/tag).
  Future<void> moveItemsToGroup({
    required List<String> itemIds,
    required String groupName,
    String? groupColor,
  }) async {
    if (itemIds.isEmpty) return;
    if (!_requireAuth()) return;
    try {
      saving = true;
      notifyListeners();
      final groupId = groupName.toLowerCase();
      for (final id in itemIds) {
        await _repository.updateProduct(id, {
          'group': groupName,
          'groupId': groupId,
          if (groupColor != null) 'groupColor': groupColor,
        });
      }
      await _groupRepository?.upsertGroup(
        id: groupId,
        name: groupName,
        color: groupColor,
        itemIds: itemIds,
      );
      products = await _repository.getItems();
    } catch (e) {
      error = _friendly(e, 'moveItemsToGroup');
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  /// Remove group assignment for selected items.
  Future<void> clearGroupForItems(List<String> itemIds) async {
    if (itemIds.isEmpty) return;
    if (!_requireAuth()) return;
    try {
      saving = true;
      notifyListeners();
      for (final id in itemIds) {
        await _repository.updateProduct(id, {
          'group': '',
          'groupId': null,
        });
      }
      await _groupRepository?.removeItemsFromGroup(itemIds);
      products = await _repository.getItems();
    } catch (e) {
      error = _friendly(e, 'clearGroupForItems');
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  /// Apply a group color to all products matching the group name (for migration/edits).
  Future<void> applyGroupColorToProducts({
    required String groupName,
    required String colorHex,
  }) async {
    if (!_requireAuth()) return;
    try {
      saving = true;
      notifyListeners();
      final matches = products.where((p) => p.group.toLowerCase() == groupName.toLowerCase());
      for (final p in matches) {
        await _repository.updateProduct(p.id, {'groupColor': colorHex});
      }
      products = await _repository.getItems();
    } catch (e) {
      error = _friendly(e, 'applyGroupColorToProducts');
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  /// Update products tied to a group (by id or name) with new name/color.
  Future<void> applyGroupUpdate({
    required String groupId,
    required String oldName,
    required String newName,
    required String? colorHex,
  }) async {
    if (!_requireAuth()) return;
    try {
      saving = true;
      notifyListeners();
      final matches = products.where((p) =>
          (p.groupId != null && p.groupId == groupId) ||
          p.group.toLowerCase() == oldName.toLowerCase());
      for (final p in matches) {
        await _repository.updateProduct(p.id, {
          'group': newName,
          'groupId': groupId,
          if (colorHex != null) 'groupColor': colorHex,
        });
      }
      products = await _repository.getItems();
    } catch (e) {
      error = _friendly(e, 'applyGroupUpdate');
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
  // Analytics logged to company/analytics on restock hints and quantity updates; batching can be added later if needed.
  // Low-stock notifications are emitted to the notifications collection (best-effort).
  // Restock transfers and supplier-aware order flows are integrated via transferToBar and add_to_order_sheet.

  bool get _useFallback => _repository is InMemoryInventoryRepository;

  List<Product> _fallbackSample() {
    // Fallback sample is used only when repository returns empty; disable _useFallback when data is seeded.
    return [
      Product(
        id: 'demo-1',
        companyId: 'demo',
        name: 'Sample Lager',
        group: 'Beer',
        unit: 'keg',
        barQuantity: 3,
        barMax: 6,
        warehouseQuantity: 8,
        warehouseTarget: 12,
        restockHint: 0,
      ),
      Product(
        id: 'demo-2',
        companyId: 'demo',
        name: 'Sample Gin',
        group: 'Spirits',
        unit: 'bottle',
        barQuantity: 5,
        barMax: 10,
        warehouseQuantity: 10,
        warehouseTarget: 20,
        restockHint: 0,
      ),
    ];
  }
}
