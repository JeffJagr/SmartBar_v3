import 'package:flutter/material.dart';

import '../models/company.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../repositories/network_products_repository.dart';
import '../repositories/orders_repository.dart';

enum NetworkCartAction { pending, confirm, deliver, cancel }

class NetworkCartLine {
  NetworkCartLine({
    required this.id,
    required this.companyId,
    required this.productId,
    required this.productName,
    required this.quantity,
    this.supplierName,
  });

  final String id;
  final String companyId;
  final String productId;
  final String productName;
  final int quantity;
  final String? supplierName;

  NetworkCartLine copyWith({int? quantity}) {
    return NetworkCartLine(
      id: id,
      companyId: companyId,
      productId: productId,
      productName: productName,
      quantity: quantity ?? this.quantity,
      supplierName: supplierName,
    );
  }
}

class NetworkCartViewModel extends ChangeNotifier {
  NetworkCartViewModel({
    required List<Company> companies,
    required NetworkProductsRepository productsRepository,
  })  : _companies = companies,
        _productsRepo = productsRepository;

  final List<Company> _companies;
  final NetworkProductsRepository _productsRepo;

  final List<NetworkCartLine> lines = [];
  bool submitting = false;
  String? error;

  Map<String, Company> get companyById => {for (final c in _companies) c.id: c};

  Future<List<Product>> fetchProductsForCompany(String companyId) {
    return _productsRepo.fetchProducts(companyId);
  }

  void addLine({
    required String companyId,
    required Product product,
    required int quantity,
    String? supplierName,
  }) {
    if (quantity <= 0) return;
    lines.add(
      NetworkCartLine(
        id: 'line-${DateTime.now().millisecondsSinceEpoch}',
        companyId: companyId,
        productId: product.id,
        productName: product.name,
        supplierName: supplierName?.isNotEmpty == true
            ? supplierName
            : (product.supplierName?.isNotEmpty == true ? product.supplierName : null),
        quantity: quantity,
      ),
    );
    notifyListeners();
  }

  void updateQuantity(String lineId, int newQty) {
    final idx = lines.indexWhere((l) => l.id == lineId);
    if (idx == -1) return;
    if (newQty <= 0) {
      lines.removeAt(idx);
    } else {
      lines[idx] = lines[idx].copyWith(quantity: newQty);
    }
    notifyListeners();
  }

  void removeLine(String lineId) {
    lines.removeWhere((l) => l.id == lineId);
    notifyListeners();
  }

  int get totalItems => lines.fold(0, (sum, l) => sum + l.quantity);

  Map<String, int> get totalsBySupplier {
    final map = <String, int>{};
    for (final l in lines) {
      final key = l.supplierName ?? 'Supplier TBD';
      map[key] = (map[key] ?? 0) + l.quantity;
    }
    return map;
  }

  Map<String, int> get totalsByCompany {
    final map = <String, int>{};
    for (final l in lines) {
      map[l.companyId] = (map[l.companyId] ?? 0) + l.quantity;
    }
    return map;
  }

  Future<void> submit({
    required NetworkCartAction action,
    required String userId,
    required String userName,
  }) async {
    if (lines.isEmpty) return;
    submitting = true;
    error = null;
    notifyListeners();
    try {
      // Group by company + supplier to keep per-supplier orders.
      final grouped = <String, List<NetworkCartLine>>{};
      for (final line in lines) {
        final supplier = line.supplierName ?? 'Supplier TBD';
        final key = '${line.companyId}::$supplier';
        grouped.putIfAbsent(key, () => []).add(line);
      }

      for (final entry in grouped.entries) {
        final parts = entry.key.split('::');
        final companyId = parts.first;
        final supplier = parts.length > 1 ? parts.last : null;
        final repo = FirestoreOrdersRepository(companyId: companyId);
        final items = entry.value
            .map(
              (l) => OrderItem(
                productId: l.productId,
                productNameSnapshot: l.productName,
                supplierName: l.supplierName ?? supplier,
                quantityOrdered: l.quantity,
              ),
            )
            .toList();

        final now = DateTime.now();
        final status = _statusForAction(action);
        final order = OrderModel(
          id: '',
          companyId: companyId,
          orderNumber: 0,
          createdByUserId: userId,
          createdByName: userName,
          supplier: supplier,
          status: status,
          items: items,
          createdAt: now,
          confirmedAt: action == NetworkCartAction.confirm || action == NetworkCartAction.deliver
              ? now
              : null,
          confirmedBy:
              action == NetworkCartAction.confirm || action == NetworkCartAction.deliver ? userId : null,
          deliveredAt: action == NetworkCartAction.deliver ? now : null,
          deliveredBy: action == NetworkCartAction.deliver ? userId : null,
          deliveredQuantities: action == NetworkCartAction.deliver
              ? {for (final l in entry.value) l.productId: l.quantity}
              : null,
        );

        await repo.createOrder(order);
      }
      lines.clear();
    } catch (e) {
      error = e.toString();
    } finally {
      submitting = false;
      notifyListeners();
    }
  }

  OrderStatus _statusForAction(NetworkCartAction action) {
    switch (action) {
      case NetworkCartAction.pending:
        return OrderStatus.pending;
      case NetworkCartAction.confirm:
        return OrderStatus.confirmed;
      case NetworkCartAction.deliver:
        return OrderStatus.delivered;
      case NetworkCartAction.cancel:
        return OrderStatus.canceled;
    }
  }
}
