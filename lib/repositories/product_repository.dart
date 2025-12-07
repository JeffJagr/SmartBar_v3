import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product.dart';

/// Contract for product data access (used by Notes dropdowns and other UI helpers).
abstract class ProductRepository {
  Future<List<Product>> fetchProducts();
  Stream<List<Product>> watchProducts();
  Future<void> addProduct(Product product);
  Future<void> updateProduct(String id, Map<String, dynamic> data);
  Future<void> deleteProduct(String id);
  Future<void> setRestockHint(String productId, int? hint);
}

/// In-memory fallback for offline/demo.
class InMemoryProductRepository implements ProductRepository {
  final _controller = StreamController<List<Product>>.broadcast();
  List<Product> _cache = [];

  InMemoryProductRepository() {
    _cache = _seedProducts();
    _controller.add(_cache);
  }

  @override
  Future<List<Product>> fetchProducts() async {
    return _cache;
  }

  @override
  Stream<List<Product>> watchProducts() => _controller.stream;

  @override
  Future<void> updateProduct(String id, Map<String, dynamic> data) async {
    _cache = _cache.map((p) {
      if (p.id == id) {
        return Product(
          id: p.id,
          companyId: p.companyId,
          name: (data['name'] as String?) ?? p.name,
          group: (data['group'] as String?) ?? p.group,
          subgroup: p.subgroup,
          unit: (data['unit'] as String?) ?? p.unit,
          barQuantity: (data['barQuantity'] as int?) ?? p.barQuantity,
          barMax: (data['barMax'] as int?) ?? p.barMax,
          warehouseQuantity: (data['warehouseQuantity'] as int?) ?? p.warehouseQuantity,
          warehouseTarget: (data['warehouseTarget'] as int?) ?? p.warehouseTarget,
          salePrice: p.salePrice,
          restockHint: (data['restockHint'] as int?) ?? p.restockHint,
          flagNeedsRestock: p.flagNeedsRestock,
          minimalStockThreshold:
              (data['minimalStockThreshold'] as int?) ?? p.minimalStockThreshold,
        );
      }
      return p;
    }).toList();
    _controller.add(_cache);
  }

  @override
  Future<void> setRestockHint(String productId, int? hint) async {
    _cache = _cache
        .map((p) => p.id == productId ? p.copyWith(restockHint: hint) : p)
        .toList();
    _controller.add(_cache);
  }

  @override
  Future<void> addProduct(Product product) async {
    final id = product.id.isEmpty ? DateTime.now().millisecondsSinceEpoch.toString() : product.id;
    _cache = [
      ..._cache,
      Product(
        id: id,
        companyId: product.companyId,
        name: product.name,
        group: product.group,
        subgroup: product.subgroup,
        unit: product.unit,
        barQuantity: product.barQuantity,
        barMax: product.barMax,
        warehouseQuantity: product.warehouseQuantity,
        warehouseTarget: product.warehouseTarget,
        salePrice: product.salePrice,
        restockHint: product.restockHint,
        flagNeedsRestock: product.flagNeedsRestock,
        minimalStockThreshold: product.minimalStockThreshold,
      ),
    ];
    _controller.add(_cache);
  }

  @override
  Future<void> deleteProduct(String id) async {
    _cache = _cache.where((p) => p.id != id).toList();
    _controller.add(_cache);
  }

  List<Product> _seedProducts() {
    return [
      Product(
        id: 'p1',
        companyId: 'demo',
        name: 'House Lager',
        group: 'Beer',
        subgroup: 'Draft',
        unit: 'keg',
        barQuantity: 4,
        barMax: 6,
        warehouseQuantity: 8,
        warehouseTarget: 12,
        salePrice: 5.5,
        restockHint: 0,
        flagNeedsRestock: false,
      ),
      Product(
        id: 'p2',
        companyId: 'demo',
        name: 'Gin Bottle',
        group: 'Spirits',
        subgroup: 'Gin',
        unit: 'bottle',
        barQuantity: 6,
        barMax: 10,
        warehouseQuantity: 14,
        warehouseTarget: 20,
        salePrice: 9.0,
        restockHint: 0,
        flagNeedsRestock: false,
      ),
    ];
  }

  void dispose() {
    _controller.close();
  }
}

/// Firestore-backed implementation scoped per company.
class FirestoreProductRepository implements ProductRepository {
  FirestoreProductRepository({
    required this.companyId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String companyId;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('companies').doc(companyId).collection('products');

  @override
  Future<List<Product>> fetchProducts() async {
    final snap = await _col.orderBy('name').get();
    return snap.docs.map((d) => Product.fromMap(d.id, d.data())).toList();
  }

  @override
  Stream<List<Product>> watchProducts() {
    return _col.orderBy('name').snapshots().map(
          (snap) => snap.docs.map((d) => Product.fromMap(d.id, d.data())).toList(),
        );
  }

  @override
  Future<void> addProduct(Product product) {
    final data = product.toMap();
    data['companyId'] = companyId;
    return _col.add(data);
  }

  @override
  Future<void> updateProduct(String id, Map<String, dynamic> data) {
    return _col.doc(id).update(data);
  }

  @override
  Future<void> deleteProduct(String id) {
    return _col.doc(id).delete();
  }

  @override
  Future<void> setRestockHint(String productId, int? hint) {
    return _col.doc(productId).update({'restockHint': hint});
  }
}
