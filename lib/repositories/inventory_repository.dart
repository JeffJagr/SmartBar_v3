import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product.dart';
import '../utils/firestore_error_handler.dart';

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
    int? barVolumeMl,
    int? warehouseVolumeMl,
  });
  Future<void> addWarehouseStock({
    required String itemId,
    required int delta,
  });
  Future<void> transferToBar({
    required String itemId,
    required int quantity,
  });
  Future<void> addProduct(Product product);
  Future<void> updateProduct(String itemId, Map<String, dynamic> data);
  Future<void> updateSupplier({
    required String itemId,
    String? supplierId,
    String? supplierName,
  });
  Future<String> exportCsv();
  Future<void> deleteProduct(String itemId);
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
    int? barVolumeMl,
    int? warehouseVolumeMl,
  }) async {
    _items = _items.map((p) {
      if (p.id == itemId) {
        return p.copyWith(
          barQuantity: barQuantity ?? p.barQuantity,
          warehouseQuantity: warehouseQuantity ?? p.warehouseQuantity,
          barVolumeMl: barVolumeMl ?? p.barVolumeMl,
          warehouseVolumeMl: warehouseVolumeMl ?? p.warehouseVolumeMl,
        );
      }
      return p;
    }).toList();
    _controller.add(_items);
  }

  @override
  Future<void> addProduct(Product product) async {
    final id = product.id.isEmpty ? DateTime.now().millisecondsSinceEpoch.toString() : product.id;
    _items = [
      ..._items,
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
    _controller.add(_items);
  }

  @override
  Future<void> updateProduct(String itemId, Map<String, dynamic> data) async {
    _items = _items.map((p) {
      if (p.id == itemId) {
        return Product(
          id: p.id,
          companyId: p.companyId,
          name: (data['name'] as String?) ?? p.name,
          group: (data['group'] as String?) ?? p.group,
          groupId: (data['groupId'] as String?) ?? p.groupId,
          groupColor: (data['groupColor'] as String?) ?? p.groupColor,
          groupMetadata: (data['groupMetadata'] as Map<String, dynamic>?) ?? p.groupMetadata,
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
          trackVolume: (data['trackVolume'] as bool?) ?? p.trackVolume,
          unitVolumeMl: (data['unitVolumeMl'] as int?) ?? p.unitVolumeMl,
          minVolumeThresholdMl: (data['minVolumeThresholdMl'] as int?) ?? p.minVolumeThresholdMl,
          trackWarehouse: (data['trackWarehouse'] as bool?) ?? p.trackWarehouse,
          barVolumeMl: (data['barVolumeMl'] as int?) ?? p.barVolumeMl,
          warehouseVolumeMl: (data['warehouseVolumeMl'] as int?) ?? p.warehouseVolumeMl,
        );
      }
      return p;
    }).toList();
    _controller.add(_items);
  }

  @override
  Future<void> deleteProduct(String itemId) async {
    _items = _items.where((p) => p.id != itemId).toList();
    _controller.add(_items);
  }

  @override
  Future<void> transferToBar({
    required String itemId,
    required int quantity,
  }) async {
    if (quantity <= 0) return;
    _items = _items.map((p) {
      if (p.id == itemId) {
        final newWh = (p.warehouseQuantity - quantity).clamp(0, 1 << 30);
        final newBar = p.barQuantity + quantity;
        final newHint = ((p.restockHint ?? 0) - quantity).clamp(0, 1 << 30);
        return p.copyWith(
          warehouseQuantity: newWh,
          barQuantity: newBar,
          // Reduce hint by the transferred amount; clear it when satisfied.
          restockHint: newHint,
        );
      }
      return p;
    }).toList();
    _controller.add(_items);
  }

  @override
  Future<void> addWarehouseStock({required String itemId, required int delta}) async {
    if (delta == 0) return;
    _items = _items.map((p) {
      if (p.id == itemId) {
        final newWh = (p.warehouseQuantity + delta).clamp(0, 1 << 30);
        return p.copyWith(warehouseQuantity: newWh);
      }
      return p;
    }).toList();
    _controller.add(_items);
  }

  List<Product> _seed() {
    // Fallback demo seed used only when no Firestore data is available.
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

  @override
  Future<void> updateSupplier({
    required String itemId,
    String? supplierId,
    String? supplierName,
  }) async {
    _items = _items.map((p) {
      if (p.id == itemId) {
        return p.copyWith(
          supplierId: supplierId,
          supplierName: supplierName,
        );
      }
      return p;
    }).toList();
    _controller.add(_items);
  }

  @override
  Future<String> exportCsv() async {
    final buffer = StringBuffer('Name,Group,BarQty/Max,WHQty/Target,Supplier\n');
    for (final p in _items) {
      buffer.writeln(
          '${p.name},${p.group},${p.barQuantity}/${p.barMax},${p.warehouseQuantity}/${p.warehouseTarget},${p.supplierName ?? ''}');
    }
    return buffer.toString();
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

  String get path => _col.path;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('companies').doc(companyId).collection('products');

  @override
  Future<List<Product>> getItems() {
    return FirestoreErrorHandler.guard(
      operation: 'getItems',
      path: path,
      run: () async {
        final snap = await _col.orderBy('name').get();
        return snap.docs.map((d) => Product.fromMap(d.id, d.data())).toList();
      },
    );
  }

  @override
  Stream<List<Product>> watchItems() {
    return _col.orderBy('name').snapshots().map(
          (snap) => snap.docs.map((d) => Product.fromMap(d.id, d.data())).toList(),
        );
  }

  @override
  Future<void> updateRestockHint(String itemId, int? hintValue) {
    return FirestoreErrorHandler.guard(
      operation: 'updateRestockHint',
      path: '$path/$itemId',
      run: () => _col.doc(itemId).update({'restockHint': hintValue}),
    );
  }

  @override
  Future<void> clearRestockHint(String itemId) => updateRestockHint(itemId, 0);

  @override
  Future<void> updateQuantities({
    required String itemId,
    int? barQuantity,
    int? warehouseQuantity,
    int? barVolumeMl,
    int? warehouseVolumeMl,
  }) {
    return FirestoreErrorHandler.guard(
      operation: 'updateQuantities',
      path: '$path/$itemId',
      run: () {
        final data = <String, dynamic>{};
        if (barQuantity != null) data['barQuantity'] = barQuantity;
        if (warehouseQuantity != null) data['warehouseQuantity'] = warehouseQuantity;
        if (barVolumeMl != null) data['barVolumeMl'] = barVolumeMl;
        if (warehouseVolumeMl != null) data['warehouseVolumeMl'] = warehouseVolumeMl;
        return _col.doc(itemId).update(data);
      },
    );
  }

  @override
  Future<void> addProduct(Product product) {
    return FirestoreErrorHandler.guard(
      operation: 'addProduct',
      path: path,
      run: () => _col.add(product.toMap()),
    );
  }

  @override
  Future<void> updateProduct(String itemId, Map<String, dynamic> data) {
    return FirestoreErrorHandler.guard(
      operation: 'updateProduct',
      path: '$path/$itemId',
      run: () => _col.doc(itemId).update(data),
    );
  }

  @override
  Future<void> updateSupplier({
    required String itemId,
    String? supplierId,
    String? supplierName,
  }) {
    return FirestoreErrorHandler.guard(
      operation: 'updateSupplier',
      path: '$path/$itemId',
      run: () => _col.doc(itemId).update({
        'supplierId': supplierId,
        'supplierName': supplierName,
      }),
    );
  }

  @override
  Future<void> deleteProduct(String itemId) {
    return FirestoreErrorHandler.guard(
      operation: 'deleteProduct',
      path: '$path/$itemId',
      run: () => _col.doc(itemId).delete(),
    );
  }

  @override
  Future<void> addWarehouseStock({required String itemId, required int delta}) async {
    if (delta == 0) return;
    await FirestoreErrorHandler.guard(
      operation: 'addWarehouseStock',
      path: '$path/$itemId',
      run: () => _col.doc(itemId).update({'warehouseQuantity': FieldValue.increment(delta)}),
    );
  }

  @override
  Future<void> transferToBar({
    required String itemId,
    required int quantity,
  }) async {
    if (quantity <= 0) return;
    await FirestoreErrorHandler.guard(
      operation: 'transferToBar',
      path: '$path/$itemId',
      run: () => _firestore.runTransaction((txn) async {
        final docRef = _col.doc(itemId);
        final snap = await txn.get(docRef);
        if (!snap.exists) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'not-found',
            message: 'Product not found',
          );
        }
        final data = snap.data()!;
        final currentBar = (data['barQuantity'] as num?)?.toInt() ?? 0;
        final currentWh = (data['warehouseQuantity'] as num?)?.toInt() ?? 0;
        final currentHint = (data['restockHint'] as num?)?.toInt() ?? 0;
        if (currentWh < quantity) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'failed-precondition',
            message: 'Not enough in warehouse',
          );
        }
        final newWh = currentWh - quantity;
        final newBar = currentBar + quantity;
        final newHint = (currentHint - quantity);
        txn.update(docRef, {
          'warehouseQuantity': newWh,
          'barQuantity': newBar,
          // Reduce the restock hint by transferred amount; clear when satisfied.
          if (currentHint > 0) 'restockHint': newHint > 0 ? newHint : 0,
        });
      }),
    );
  }

  @override
  Future<String> exportCsv() {
    return FirestoreErrorHandler.guard(
      operation: 'exportCsv',
      path: path,
      run: () async {
        final items = await getItems();
        final buffer = StringBuffer('Name,Group,BarQty/Max,WHQty/Target,Supplier\n');
        for (final p in items) {
          buffer.writeln(
              '${p.name},${p.group},${p.barQuantity}/${p.barMax},${p.warehouseQuantity}/${p.warehouseTarget},${p.supplierName ?? ''}');
        }
        return buffer.toString();
      },
    );
  }
}
