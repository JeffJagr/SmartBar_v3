import 'dart:async';

import '../models/product.dart';

/// Stub repository for products. Replace with Firestore-backed implementation later.
class ProductRepository {
  final _controller = StreamController<List<Product>>.broadcast();
  List<Product> _cache = [];

  ProductRepository() {
    _cache = _seedProducts();
    _controller.add(_cache);
  }

  Future<List<Product>> fetchProducts() async {
    return _cache;
  }

  Stream<List<Product>> watchProducts() {
    return _controller.stream;
  }

  Future<void> updateProduct(Product product) async {
    _cache = _cache.map((p) => p.id == product.id ? product : p).toList();
    _controller.add(_cache);
  }

  /// Set a restock hint for the given product. This does not change quantities,
  /// only suggests how much to move/prepare.
  Future<void> setRestockHint(String productId, int? hint) async {
    final updated = _cache.map((p) {
      if (p.id == productId) {
        return p.copyWith(restockHint: hint);
      }
      return p;
    }).toList();
    _cache = updated;
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
