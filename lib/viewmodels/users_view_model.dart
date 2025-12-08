import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/user_account.dart';
import '../repositories/users_repository.dart';

class UsersViewModel extends ChangeNotifier {
  UsersViewModel(this._repo);

  final UsersRepository _repo;

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
    String? pin,
    Map<String, bool> permissions = const {},
  }) async {
    try {
      loading = true;
      notifyListeners();
      final user = UserAccount(
        id: '',
        companyId: '',
        displayName: displayName,
        role: role,
        active: true,
        pin: pin,
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
    await _repo.updateRole(userId, role);
  }

  Future<void> setActive(String userId, bool active) async {
    await _repo.deactivate(userId, active);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
