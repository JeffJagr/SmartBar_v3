import '../state/app_state.dart';
import '../models/user_account.dart';

/// Snapshot of the current user's permission context.
class PermissionSnapshot {
  const PermissionSnapshot({
    required this.isOwner,
    required this.role,
    this.flags = const {},
    this.roleLabel = '',
  });

  final bool isOwner;
  final UserRole role;
  final Map<String, bool> flags;
  final String roleLabel;

  bool get isManager => role == UserRole.manager;
  bool get isStaff => role == UserRole.staff;

  bool flag(String key, {bool defaultValue = false}) =>
      flags[key] ?? defaultValue;
}

/// Central place for evaluating permissions. Keep business rules here rather
/// than scattered across UI widgets.
class PermissionService {
  const PermissionService();

  /// Build a snapshot from the current app controller state and optional
  /// explicit flags pulled from a user document.
  PermissionSnapshot fromApp({
    required AppState app,
    Map<String, bool> explicitFlags = const {},
  }) {
    final rawRole = app.currentStaffMember?.role.toLowerCase() ?? '';
    final derivedRole = app.isOwner
        ? UserRole.owner
        : rawRole.contains('manager')
            ? UserRole.manager
            : UserRole.staff;

    return PermissionSnapshot(
      isOwner: app.isOwner,
      role: derivedRole,
      flags: explicitFlags,
      roleLabel: rawRole,
    );
  }

  bool canEditProducts(PermissionSnapshot snapshot) =>
      snapshot.isOwner ||
      snapshot.isManager ||
      snapshot.flag('editProducts', defaultValue: snapshot.isManager);

  bool canAdjustQuantities(PermissionSnapshot snapshot) =>
      snapshot.isOwner ||
      snapshot.isManager ||
      snapshot.flag('adjustQuantities', defaultValue: snapshot.isManager);

  bool canCreateOrders(PermissionSnapshot snapshot) =>
    snapshot.isOwner ||
      snapshot.isManager ||
      snapshot.flag('createOrders', defaultValue: snapshot.isManager);

  bool canConfirmOrders(PermissionSnapshot snapshot) =>
      snapshot.isOwner ||
      snapshot.flag('confirmOrders', defaultValue: snapshot.isManager);

  bool canReceiveOrders(PermissionSnapshot snapshot) =>
      snapshot.isOwner ||
      snapshot.flag('receiveOrders', defaultValue: true);

  bool canManageUsers(PermissionSnapshot snapshot) =>
      snapshot.isOwner || snapshot.flag('manageUsers');

  bool canViewHistory(PermissionSnapshot snapshot) =>
      snapshot.isOwner ||
      snapshot.isManager ||
      snapshot.flag('viewHistory', defaultValue: true);

  bool canSetRestockHint(PermissionSnapshot snapshot) =>
      snapshot.isOwner ||
      snapshot.isManager ||
      snapshot.flag('setRestockHint', defaultValue: true);

  bool canTransferStock(PermissionSnapshot snapshot) =>
      snapshot.isOwner ||
      snapshot.isManager ||
      snapshot.flag('transferStock', defaultValue: snapshot.isManager);

  bool canAddNotes(PermissionSnapshot snapshot) =>
      snapshot.isOwner ||
      snapshot.isManager ||
      snapshot.flag('addNotes', defaultValue: true);
}
