import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/product.dart';
import '../repositories/inventory_repository.dart';

/// ViewModel for inventory screens.
/// TODO: replace stub repository with Firestore-backed implementation while keeping this interface.
class InventoryViewModel extends ChangeNotifier {
  InventoryViewModel(this._repository);

  InventoryRepository _repository;
  bool canEditQuantities = false;

  List<Product> products = [];
  bool loading = true;
  String? error;
  StreamSubscription<List<Product>>? _subscription;

  Future<void> init() async {
    await _load();
    _subscription = _repository.watchItems().listen((items) {
      products = items.isNotEmpty ? items : (_useFallback ? _fallbackSample() : <Product>[]);
      loading = false;
      error = null;
      notifyListeners();
    }, onError: (e) {
      error = e.toString();
      loading = false;
      notifyListeners();
    });
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
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> updateRestockHint(String productId, int? hint) async {
    // hint is only a suggestion; does not mutate actual quantities.
    try {
      await _repository.updateRestockHint(productId, hint);
      products = await _repository.getItems();
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> clearRestockHint(String productId) async {
    try {
      await _repository.clearRestockHint(productId);
      products = await _repository.getItems();
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateQuantities({
    required String productId,
    int? barQuantity,
    int? warehouseQuantity,
  }) async {
    try {
      await _repository.updateQuantities(
        itemId: productId,
        barQuantity: barQuantity,
        warehouseQuantity: warehouseQuantity,
      );
      products = await _repository.getItems();
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  void setPermissions({required bool isOwner}) {
    canEditQuantities = isOwner;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
  // TODO: trigger analytics/logging when hints change; add stock sync batching.
  // TODO: add push notifications via FCM when low stock detected.
  // TODO: integrate restock transfers and supplier order flows.

  bool get _useFallback => _repository is InMemoryInventoryRepository;

  List<Product> _fallbackSample() {
    // TODO: remove this fallback once Firestore data is seeded for each company.
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
