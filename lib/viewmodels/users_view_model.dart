import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_account.dart';
import '../repositories/users_repository.dart';
import '../services/permission_service.dart';
import '../utils/firestore_error_handler.dart';

class UsersViewModel extends ChangeNotifier {
  UsersViewModel(this._repo);

  final UsersRepository _repo;
  PermissionSnapshot? _permissionSnapshot;
  PermissionService? _permissionService;
  String? get _repoPath {
    if (_repo is FirestoreUsersRepository) {
      return _repo.path;
    }
    return 'members';
  }

  List<UserAccount> users = [];
  bool loading = true;
  String? error;
  StreamSubscription<List<UserAccount>>? _sub;

  String _friendly(Object e, String op) => FirestoreErrorHandler.friendlyMessage(
        e,
        operation: op,
        path: _repoPath,
      );

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
      error = _friendly(e, 'watchUsers');
      loading = false;
      notifyListeners();
    });
  }

  Future<void> addUser({
    required String displayName,
    required UserRole role,
    String? email,
    String? password,
    String? pin,
    Map<String, bool> permissions = const {},
  }) async {
    if (FirebaseAuth.instance.currentUser == null) {
      error = 'Not authenticated. Please sign in again.';
      notifyListeners();
      return;
    }
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
      // Staff use PIN-based auth; we do not create a Firebase Auth user here.
      final uid = 'pin-${DateTime.now().millisecondsSinceEpoch}';
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
      // staffPins doc is written inside FirestoreUsersRepository so PIN login works.
    } catch (e) {
      error = _friendly(e, 'addUser');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> updateRole(String userId, UserRole role) async {
    if (FirebaseAuth.instance.currentUser == null) {
      error = 'Not authenticated. Please sign in again.';
      notifyListeners();
      return;
    }
    if (_permissionService != null &&
        _permissionSnapshot != null &&
        !_permissionService!.canManageUsers(_permissionSnapshot!)) {
      error = 'You do not have permission to manage users.';
      notifyListeners();
      return;
    }
    try {
      await _repo.updateRole(userId, role);
    } catch (e) {
      error = _friendly(e, 'updateRole');
      notifyListeners();
    }
  }

  Future<void> setActive(String userId, bool active) async {
    if (FirebaseAuth.instance.currentUser == null) {
      error = 'Not authenticated. Please sign in again.';
      notifyListeners();
      return;
    }
    if (_permissionService != null &&
        _permissionSnapshot != null &&
        !_permissionService!.canManageUsers(_permissionSnapshot!)) {
      error = 'You do not have permission to manage users.';
      notifyListeners();
      return;
    }
    try {
      await _repo.deactivate(userId, active);
    } catch (e) {
      error = _friendly(e, 'deactivate');
      notifyListeners();
    }
  }

  Future<void> deleteUser(String userId) async {
    if (FirebaseAuth.instance.currentUser == null) {
      error = 'Not authenticated. Please sign in again.';
      notifyListeners();
      return;
    }
    if (_permissionService != null &&
        _permissionSnapshot != null &&
        !_permissionService!.canManageUsers(_permissionSnapshot!)) {
      error = 'You do not have permission to manage users.';
      notifyListeners();
      return;
    }
    try {
      await _repo.deleteUser(userId);
    } catch (e) {
      error = _friendly(e, 'deleteUser');
      notifyListeners();
    }
  }

  Future<void> updatePermissions(String userId, Map<String, bool> permissions) async {
    if (FirebaseAuth.instance.currentUser == null) {
      error = 'Not authenticated. Please sign in again.';
      notifyListeners();
      return;
    }
    if (_permissionService != null &&
        _permissionSnapshot != null &&
        !_permissionService!.canManageUsers(_permissionSnapshot!)) {
      error = 'You do not have permission to manage users.';
      notifyListeners();
      return;
    }
    try {
      await _repo.updatePermissions(userId, permissions);
    } catch (e) {
      error = _friendly(e, 'updatePermissions');
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
