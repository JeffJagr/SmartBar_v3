import '../controllers/app_controller.dart';
import '../state/app_state.dart';
import '../models/user_account.dart';
import '../models/member.dart';

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
    // If AppState is an AppController it exposes currentStaffMember; otherwise use currentStaff.
    final rawRole = (app is AppController
            ? app.currentStaffMember?.role
            : app.currentStaff?.role)
        ?.toLowerCase() ??
        '';
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

  /// Build a snapshot directly from a membership document.
  PermissionSnapshot fromMember(Member? member) {
    final userRole = _roleFromString(member?.role);
    return PermissionSnapshot(
      isOwner: userRole == UserRole.owner,
      role: userRole,
      flags: member?.permissions ?? const {},
      roleLabel: member?.role ?? '',
    );
  }

  bool hasPermission(PermissionSnapshot snapshot, String key,
          {bool defaultValue = false}) =>
      snapshot.flags[key] ?? defaultValue;

  bool canEditProducts(PermissionSnapshot snapshot) =>
      snapshot.isOwner || snapshot.isManager || snapshot.flag('editProducts');

  bool canAdjustQuantities(PermissionSnapshot snapshot) =>
      snapshot.isOwner || snapshot.isManager || snapshot.flag('adjustQuantities');

  bool canCreateOrders(PermissionSnapshot snapshot) =>
      snapshot.isOwner || snapshot.isManager || snapshot.flag('createOrders');

  bool canConfirmOrders(PermissionSnapshot snapshot) =>
      snapshot.isOwner || snapshot.isManager || snapshot.flag('confirmOrders');

  bool canReceiveOrders(PermissionSnapshot snapshot) =>
      snapshot.isOwner || snapshot.isManager || snapshot.flag('receiveOrders');

  bool canManageUsers(PermissionSnapshot snapshot) =>
      snapshot.isOwner || snapshot.flag('manageUsers');

  bool canViewHistory(PermissionSnapshot snapshot) =>
      snapshot.isOwner || snapshot.isManager || snapshot.flag('viewHistory');

  bool canSetRestockHint(PermissionSnapshot snapshot) =>
      snapshot.isOwner || snapshot.isManager || snapshot.flag('setRestockHint');

  bool canTransferStock(PermissionSnapshot snapshot) =>
      snapshot.isOwner || snapshot.isManager || snapshot.flag('transferStock');

  bool canAddNotes(PermissionSnapshot snapshot) =>
      snapshot.isOwner || snapshot.isManager || snapshot.flag('addNotes');

  bool canManageSuppliers(PermissionSnapshot snapshot) =>
      snapshot.isOwner || snapshot.isManager || snapshot.flag('manageSuppliers');

  UserRole _roleFromString(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'owner':
        return UserRole.owner;
      case 'manager':
        return UserRole.manager;
      default:
        return UserRole.staff;
    }
  }
}
