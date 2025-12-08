import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/order.dart';
import '../models/history_entry.dart';
import '../repositories/orders_repository.dart';
import '../repositories/inventory_repository.dart';
import '../repositories/history_repository.dart';
import '../services/permission_service.dart';

class OrdersViewModel extends ChangeNotifier {
  OrdersViewModel(this._ordersRepo, this._inventoryRepo, {HistoryRepository? historyRepo})
      : _historyRepo = historyRepo;

  final OrdersRepository _ordersRepo;
  final InventoryRepository _inventoryRepo;
  final HistoryRepository? _historyRepo;
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
    if (!_requireAuth()) return;
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
    if (!_requireAuth()) return;
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
          if (_historyRepo != null) {
            await _historyRepo?.logEntry(
              HistoryEntry(
                id: '',
                companyId: order.companyId,
                actionType: 'order_received',
                itemName: item.productNameSnapshot ?? item.productId,
                description:
                    'Received ${item.quantityOrdered} units from order ${_orderLabel(order)}',
                performedBy: _permissionSnapshot?.roleLabel ?? 'user',
                timestamp: DateTime.now(),
                details: {
                  'productId': item.productId,
                  'quantity': item.quantityOrdered,
                  'orderId': order.id,
                },
              ),
            );
          }
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
    if (!_requireAuth()) return;
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

  bool _requireAuth() {
    if (FirebaseAuth.instance.currentUser == null) {
      error = 'Not authenticated. Please sign in again.';
      notifyListeners();
      return false;
    }
    return true;
  }

  String _orderLabel(OrderModel order) {
    if (order.orderNumber > 0) {
      return '#${order.orderNumber.toString().padLeft(4, '0')}';
    }
    return order.id.isEmpty ? 'order' : order.id;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
