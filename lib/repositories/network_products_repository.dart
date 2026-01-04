import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product.dart';
import '../utils/firestore_error_handler.dart';

class NetworkProductsRepository {
  NetworkProductsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final Map<String, List<Product>> _cache = {};

  Future<List<Product>> fetchProducts(String companyId) async {
    if (_cache.containsKey(companyId)) return _cache[companyId]!;
    return FirestoreErrorHandler.guard(
      operation: 'fetchNetworkProducts',
      path: 'companies/$companyId/products',
      run: () async {
        final snap = await _firestore
            .collection('companies')
            .doc(companyId)
            .collection('products')
            .orderBy('name')
            .get();
        final products = snap.docs.map((d) => Product.fromMap(d.id, d.data())).toList();
        _cache[companyId] = products;
        return products;
      },
    );
  }
}
