import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product.dart';

/// Abstraction for inventory data access.
abstract class InventoryRepository {
  Future<List<Product>> getItems();
  Stream<List<Product>> watchItems();
  Future<void> updateRestockHint(String itemId, int? hintValue);
  Future<void> clearRestockHint(String itemId);
  Future<void> updateQuantities({
    required String itemId,
    int? barQuantity,
    int? warehouseQuantity,
  });
  // TODO: add supplier linkage, restock transfer operations, and export support.
}

/// In-memory stub implementation. Replace with Firestore-backed repo later.
class InMemoryInventoryRepository implements InventoryRepository {
  InMemoryInventoryRepository() {
    _items = _seed();
    _controller.add(_items);
  }

  late List<Product> _items;
  final _controller = StreamController<List<Product>>.broadcast();

  @override
  Future<List<Product>> getItems() async {
    return _items;
  }

  @override
  Stream<List<Product>> watchItems() => _controller.stream;

  @override
  Future<void> updateRestockHint(String itemId, int? hintValue) async {
    _items = _items
        .map((p) => p.id == itemId ? p.copyWith(restockHint: hintValue) : p)
        .toList();
    _controller.add(_items);
  }

  @override
  Future<void> clearRestockHint(String itemId) async {
    await updateRestockHint(itemId, 0);
  }

  @override
  Future<void> updateQuantities({
    required String itemId,
    int? barQuantity,
    int? warehouseQuantity,
  }) async {
    _items = _items.map((p) {
      if (p.id == itemId) {
        return p.copyWith(
          barQuantity: barQuantity ?? p.barQuantity,
          warehouseQuantity: warehouseQuantity ?? p.warehouseQuantity,
        );
      }
      return p;
    }).toList();
    _controller.add(_items);
  }

  List<Product> _seed() {
    // TODO: replace with Firestore fetch per company.
    return [
      Product(
        id: 'i1',
        companyId: 'demo',
        name: 'House Lager',
        group: 'Beer',
        unit: 'keg',
        barQuantity: 4,
        barMax: 6,
        warehouseQuantity: 8,
        warehouseTarget: 12,
        restockHint: 0,
      ),
      Product(
        id: 'i2',
        companyId: 'demo',
        name: 'Gin Bottle',
        group: 'Spirits',
        unit: 'bottle',
        barQuantity: 6,
        barMax: 10,
        warehouseQuantity: 14,
        warehouseTarget: 20,
        restockHint: 0,
      ),
    ];
  }

  void dispose() {
    _controller.close();
  }
}

/// Firestore implementation scoped by company.
class FirestoreInventoryRepository implements InventoryRepository {
  FirestoreInventoryRepository({
    required this.companyId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final String companyId;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('companies').doc(companyId).collection('products');

  @override
  Future<List<Product>> getItems() async {
    final snap = await _col.orderBy('name').get();
    return snap.docs.map((d) => Product.fromMap(d.id, d.data())).toList();
  }

  @override
  Stream<List<Product>> watchItems() {
    return _col.orderBy('name').snapshots().map(
          (snap) => snap.docs.map((d) => Product.fromMap(d.id, d.data())).toList(),
        );
  }

  @override
  Future<void> updateRestockHint(String itemId, int? hintValue) {
    return _col.doc(itemId).update({'restockHint': hintValue});
  }

  @override
  Future<void> clearRestockHint(String itemId) => updateRestockHint(itemId, 0);
  // TODO: add stock movement history logging and low-stock notifications via FCM.

  @override
  Future<void> updateQuantities({
    required String itemId,
    int? barQuantity,
    int? warehouseQuantity,
  }) {
    final data = <String, dynamic>{};
    if (barQuantity != null) data['barQuantity'] = barQuantity;
    if (warehouseQuantity != null) data['warehouseQuantity'] = warehouseQuantity;
    return _col.doc(itemId).update(data);
  }
}
