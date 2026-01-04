import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/order.dart';
import '../models/history_entry.dart';
import '../repositories/orders_repository.dart';
import '../repositories/inventory_repository.dart';
import '../repositories/history_repository.dart';
import '../services/permission_service.dart';
import '../utils/firestore_error_handler.dart';

class OrdersViewModel extends ChangeNotifier {
  OrdersViewModel(this._ordersRepo, this._inventoryRepo, {HistoryRepository? historyRepo})
      : _historyRepo = historyRepo;

  final OrdersRepository _ordersRepo;
  final InventoryRepository _inventoryRepo;
  final HistoryRepository? _historyRepo;
  PermissionSnapshot? _permissionSnapshot;
  PermissionService? _permissionService;
  String? get _repoPath {
    if (_ordersRepo is FirestoreOrdersRepository) {
      return _ordersRepo.path;
    }
    return 'orders';
  }

  List<OrderModel> orders = [];
  bool loading = true;
  String? error;
  StreamSubscription<List<OrderModel>>? _sub;

  String _friendly(Object e, String op) => FirestoreErrorHandler.friendlyMessage(
        e,
        operation: op,
        path: _repoPath,
      );

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
      error = _friendly(e, 'watchOrders');
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
      error = null;
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
      if (_historyRepo != null) {
        await _historyRepo.logEntry(
          HistoryEntry(
            id: '',
            companyId: companyId,
            actionType: 'order_create',
            itemName: 'Order ${_orderLabel(order)}',
            description: 'Created by ${createdByName ?? createdByUserId}',
            performedBy: _permissionSnapshot?.roleLabel ?? 'user',
            timestamp: DateTime.now(),
            details: {
              'items': items.length,
              'status': order.status.name,
              if ((supplier ?? '').isNotEmpty) 'supplier': supplier,
            },
          ),
        );
      }
    } catch (e) {
      error = _friendly(e, 'createOrder');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> markReceived(OrderModel order, {String? deliveredBy}) async {
    await markReceivedWithDetails(
      order,
      receivedQuantities: null,
      note: null,
      deliveredBy: deliveredBy,
    );
  }

  Future<void> markReceivedWithDetails(
    OrderModel order, {
    Map<String, int>? receivedQuantities,
    String? note,
    String? deliveredBy,
  }) async {
    if (!_requireAuth()) return;
    if (_permissionService != null &&
        _permissionSnapshot != null &&
        !_permissionService!.canReceiveOrders(_permissionSnapshot!)) {
      error = 'You do not have permission to receive orders.';
      notifyListeners();
      return;
    }
    try {
      error = null;
      loading = true;
      notifyListeners();
      final existing = order.deliveredQuantities ?? {};
      final merged = Map<String, int>.from(existing);
      // Increment warehouse stock for each item (use receivedQuantities if provided).
      for (final item in order.items) {
        final target = receivedQuantities != null
            ? (receivedQuantities[item.productId] ?? item.quantityOrdered)
            : item.quantityOrdered;
        final already = existing[item.productId] ?? 0;
        final delta = target - already;
        merged[item.productId] = target;
        if (delta > 0) {
          await _inventoryRepo.addWarehouseStock(
            itemId: item.productId,
            delta: delta,
          );
          if (_historyRepo != null) {
            await _historyRepo.logEntry(
              HistoryEntry(
                id: '',
                companyId: order.companyId,
                actionType: 'order_received',
                itemName: item.productNameSnapshot ?? item.productId,
                description:
                    'Received $delta units (total $target) from order ${_orderLabel(order)}',
                performedBy: _permissionSnapshot?.roleLabel ?? 'user',
                timestamp: DateTime.now(),
                details: {
                  'productId': item.productId,
                  'quantity': delta,
                  'orderId': order.id,
                  if ((order.supplier ?? '').isNotEmpty) 'supplier': order.supplier,
                  if (note != null && note.isNotEmpty) 'note': note,
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
        deliveredBy: deliveredBy,
        deliveredQuantities: merged,
        deliveredNote: note ?? order.deliveredNote,
      );
      if (_historyRepo != null) {
        await _historyRepo.logEntry(
          HistoryEntry(
            id: '',
            companyId: order.companyId,
            actionType: 'order_delivered',
            itemName: _orderLabel(order),
            description: note != null && note.isNotEmpty ? note : 'Marked received',
            performedBy: _permissionSnapshot?.roleLabel ?? 'user',
            timestamp: DateTime.now(),
            details: {
              'items': order.items.length,
              if ((order.supplier ?? '').isNotEmpty) 'supplier': order.supplier,
              if (note != null && note.isNotEmpty) 'note': note,
            },
          ),
        );
      }
    } catch (e) {
      error = _friendly(e, 'markReceived');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> confirmOrder(
    OrderModel order, {
    required String confirmedBy,
    String? supplier,
  }) async {
    if (!_requireAuth()) return;
    if (_permissionService != null &&
        _permissionSnapshot != null &&
        !_permissionService!.canConfirmOrders(_permissionSnapshot!)) {
      error = 'You do not have permission to confirm orders.';
      notifyListeners();
      return;
    }
    try {
      error = null;
      await _ordersRepo.updateStatus(
        order.id,
        OrderStatus.confirmed,
        confirmedAt: DateTime.now(),
        confirmedBy: confirmedBy,
        supplier: supplier ?? order.supplier,
      );
      if (_historyRepo != null) {
        await _historyRepo.logEntry(
          HistoryEntry(
            id: '',
            companyId: order.companyId,
            actionType: 'order_confirmed',
            itemName: _orderLabel(order),
            description: 'Confirmed by $confirmedBy',
            performedBy: _permissionSnapshot?.roleLabel ?? 'user',
            timestamp: DateTime.now(),
            details: {
              if ((supplier ?? order.supplier)?.isNotEmpty == true)
                'supplier': supplier ?? order.supplier,
            },
          ),
        );
      }
    } catch (e) {
      error = _friendly(e, 'confirmOrder');
      notifyListeners();
    }
  }

  Future<void> cancelOrder(OrderModel order, {required String canceledBy}) async {
    if (!_requireAuth()) return;
    try {
      error = null;
      await _ordersRepo.updateStatus(
        order.id,
        OrderStatus.canceled,
      );
      if (_historyRepo != null) {
        await _historyRepo.logEntry(
          HistoryEntry(
            id: '',
            companyId: order.companyId,
            actionType: 'order_canceled',
            itemName: _orderLabel(order),
            description: 'Canceled by $canceledBy',
            performedBy: _permissionSnapshot?.roleLabel ?? 'user',
            timestamp: DateTime.now(),
          ),
        );
      }
    } catch (e) {
      error = _friendly(e, 'cancelOrder');
      notifyListeners();
    }
  }

  Future<void> updateOrderItems(OrderModel order, List<OrderItem> items) async {
    if (!_requireAuth()) return;
    try {
      error = null;
      await _ordersRepo.updateItems(order.id, items);
      if (_historyRepo != null) {
        await _historyRepo.logEntry(
          HistoryEntry(
            id: '',
            companyId: order.companyId,
            actionType: 'order_update',
            itemName: _orderLabel(order),
            description: 'Items updated',
            performedBy: _permissionSnapshot?.roleLabel ?? 'user',
            timestamp: DateTime.now(),
            details: {'lines': items.length},
          ),
        );
      }
    } catch (e) {
      error = _friendly(e, 'updateOrderItems');
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
