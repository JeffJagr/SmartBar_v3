import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_account.dart';
import '../repositories/users_repository.dart';
import '../services/permission_service.dart';

class UsersViewModel extends ChangeNotifier {
  UsersViewModel(this._repo);

  final UsersRepository _repo;
  PermissionSnapshot? _permissionSnapshot;
  PermissionService? _permissionService;

  List<UserAccount> users = [];
  bool loading = true;
  String? error;
  StreamSubscription<List<UserAccount>>? _sub;

  Future<void> init() async {
    _sub?.cancel();
    loading = true;
    notifyListeners();
    _sub = _repo.watchUsers().listen((data) {
      users = data;
      loading = false;
      error = null;
      notifyListeners();
    }, onError: (e) {
      error = e.toString();
      loading = false;
      notifyListeners();
    });
  }

  Future<void> addUser({
    required String displayName,
    required UserRole role,
    required String email,
    required String password,
    String? pin,
    Map<String, bool> permissions = const {},
  }) async {
    if (_permissionService != null &&
        _permissionSnapshot != null &&
        !_permissionService!.canManageUsers(_permissionSnapshot!)) {
      error = 'You do not have permission to manage users.';
      notifyListeners();
      return;
    }
    try {
      loading = true;
      notifyListeners();
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      final uid = credential.user?.uid ?? '';
      if (uid.isEmpty) {
        throw Exception('Failed to create auth user');
      }
      final user = UserAccount(
        id: uid,
        companyId: '',
        displayName: displayName,
        role: role,
        active: true,
        pin: pin,
        email: email,
        permissions: permissions,
      );
      await _repo.addUser(user);
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> updateRole(String userId, UserRole role) async {
    if (_permissionService != null &&
        _permissionSnapshot != null &&
        !_permissionService!.canManageUsers(_permissionSnapshot!)) {
      error = 'You do not have permission to manage users.';
      notifyListeners();
      return;
    }
    await _repo.updateRole(userId, role);
  }

  Future<void> setActive(String userId, bool active) async {
    if (_permissionService != null &&
        _permissionSnapshot != null &&
        !_permissionService!.canManageUsers(_permissionSnapshot!)) {
      error = 'You do not have permission to manage users.';
      notifyListeners();
      return;
    }
    await _repo.deactivate(userId, active);
  }

  Future<void> deleteUser(String userId) async {
    if (_permissionService != null &&
        _permissionSnapshot != null &&
        !_permissionService!.canManageUsers(_permissionSnapshot!)) {
      error = 'You do not have permission to manage users.';
      notifyListeners();
      return;
    }
    await _repo.deleteUser(userId);
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
