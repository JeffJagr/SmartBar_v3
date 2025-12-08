import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/order.dart';
import '../repositories/orders_repository.dart';
import '../repositories/inventory_repository.dart';
import '../services/permission_service.dart';

class OrdersViewModel extends ChangeNotifier {
  OrdersViewModel(this._ordersRepo, this._inventoryRepo);

  final OrdersRepository _ordersRepo;
  final InventoryRepository _inventoryRepo;
  PermissionSnapshot? _permissionSnapshot;
  PermissionService? _permissionService;

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
    String? createdByName,
  }) async {
    if (_permissionService != null &&
        _permissionSnapshot != null &&
        !_permissionService!.canCreateOrders(_permissionSnapshot!)) {
      error = 'You do not have permission to create orders.';
      notifyListeners();
      return;
    }
    try {
      loading = true;
      notifyListeners();
      final order = OrderModel(
        id: '',
        companyId: companyId,
        orderNumber: 0, // Will be assigned in repository transaction.
        createdByUserId: createdByUserId,
        createdByName: createdByName,
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
    if (_permissionService != null &&
        _permissionSnapshot != null &&
        !_permissionService!.canReceiveOrders(_permissionSnapshot!)) {
      error = 'You do not have permission to receive orders.';
      notifyListeners();
      return;
    }
    try {
      loading = true;
      notifyListeners();
      // Increment warehouse stock for each item.
      for (final item in order.items) {
        if (item.quantityOrdered > 0) {
          await _inventoryRepo.addWarehouseStock(
            itemId: item.productId,
            delta: item.quantityOrdered,
          );
        }
      }
      await _ordersRepo.updateStatus(
        order.id,
        OrderStatus.delivered,
        deliveredAt: DateTime.now(),
      );
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> confirmOrder(OrderModel order, {required String confirmedBy}) async {
    if (_permissionService != null &&
        _permissionSnapshot != null &&
        !_permissionService!.canConfirmOrders(_permissionSnapshot!)) {
      error = 'You do not have permission to confirm orders.';
      notifyListeners();
      return;
    }
    try {
      await _ordersRepo.updateStatus(
        order.id,
        OrderStatus.confirmed,
        confirmedAt: DateTime.now(),
        confirmedBy: confirmedBy,
      );
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  void applyPermissionContext({
    required PermissionSnapshot snapshot,
    PermissionService? service,
  }) {
    _permissionSnapshot = snapshot;
    _permissionService = service;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
