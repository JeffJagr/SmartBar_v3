import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/order.dart';
import '../repositories/orders_repository.dart';
import '../repositories/inventory_repository.dart';

class OrdersViewModel extends ChangeNotifier {
  OrdersViewModel(this._ordersRepo, this._inventoryRepo);

  final OrdersRepository _ordersRepo;
  final InventoryRepository _inventoryRepo;

  List<OrderModel> orders = [];
  bool loading = true;
  String? error;
  StreamSubscription<List<OrderModel>>? _sub;

  Future<void> init() async {
    _sub?.cancel();
    loading = true;
    notifyListeners();
    _sub = _ordersRepo.watchOrders().listen((data) {
      orders = data;
      loading = false;
      error = null;
      notifyListeners();
    }, onError: (e) {
      error = e.toString();
      loading = false;
      notifyListeners();
    });
  }

  Future<void> createOrder({
    required String companyId,
    required String createdByUserId,
    String? supplier,
    required List<OrderItem> items,
  }) async {
    try {
      loading = true;
      notifyListeners();
      final order = OrderModel(
        id: '',
        companyId: companyId,
        createdByUserId: createdByUserId,
        supplier: supplier,
        status: OrderStatus.pending,
        items: items,
        createdAt: DateTime.now(),
      );
      await _ordersRepo.createOrder(order);
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> markReceived(OrderModel order) async {
    try {
      loading = true;
      notifyListeners();
      // Increment warehouse stock for each item.
      for (final item in order.items) {
        if (item.quantity > 0) {
          await _inventoryRepo.addWarehouseStock(itemId: item.productId, delta: item.quantity);
        }
      }
      await _ordersRepo.updateStatus(order.id, OrderStatus.delivered);
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
