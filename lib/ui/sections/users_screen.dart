import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_account.dart';
import '../../viewmodels/users_view_model.dart';
import '../../controllers/app_controller.dart';

// Note: pagination not implemented; all users load into memory. Add paging if counts grow large.

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

const _permissionOptions = <String, String>{
  'editProducts': 'Edit products',
  'adjustQuantities': 'Adjust quantities',
  'createOrders': 'Create orders',
  'confirmOrders': 'Confirm orders',
  'receiveOrders': 'Receive orders',
  'transferStock': 'Transfer stock',
  'setRestockHint': 'Set restock hints',
  'viewHistory': 'View history',
  'addNotes': 'Add notes',
  'manageUsers': 'Manage users',
};

Map<String, bool> _roleDefaults(UserRole role) {
  switch (role) {
    case UserRole.owner:
      return { for (final k in _permissionOptions.keys) k: true };
    case UserRole.manager:
      return {
        'editProducts': true,
        'adjustQuantities': true,
        'createOrders': true,
        'confirmOrders': true,
        'receiveOrders': true,
        'transferStock': true,
        'setRestockHint': true,
        'viewHistory': true,
        'addNotes': true,
        'manageUsers': false,
      };
    case UserRole.staff:
      return {
        'editProducts': false,
        'adjustQuantities': false,
        'createOrders': true,
        'confirmOrders': false,
        'receiveOrders': false,
        'transferStock': false,
        'setRestockHint': true,
        'viewHistory': false,
        'addNotes': true,
        'manageUsers': false,
      };
  }
}

Map<String, bool> _effectivePermissions(UserAccount user) {
  // Start from role defaults and overlay any persisted custom flags.
  final base = _roleDefaults(user.role);
  return {...base, ...user.permissions};
}

class _UsersScreenState extends State<UsersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UsersViewModel>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<UsersViewModel?>();
    final app = context.watch<AppController>();
    final canManage = app.permissions
        .canManageUsers(app.permissionSnapshot(app.permissions));
    if (!canManage) {
      return const Center(child: Text('Access denied'));
    }
    if (vm == null) {
      return const Center(child: Text('Users module unavailable (no company selected).'));
    }
    if (vm.loading && vm.users.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.error != null) {
      return Center(child: Text('Error: ${vm.error}'));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: vm.users.length,
        itemBuilder: (context, index) {
          final user = vm.users[index];
          final effective = _effectivePermissions(user);
          final allowed = effective.entries
              .where((e) => e.value)
              .map((e) => _permissionOptions[e.key] ?? e.key)
              .toList();
          final summary = allowed.isEmpty ? 'No permissions' : allowed.join(', ');
          final statusColor = user.active
              ? Colors.green
              : Theme.of(context).colorScheme.error;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => _openUserDetail(context, user),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.displayName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Chip(
                          label: Text(user.role.name),
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.circle, size: 10, color: statusColor),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.active ? 'Active' : 'Inactive',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: statusColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Allowed: $summary',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${user.id}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Theme.of(context).colorScheme.outline),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddUser(context),
        child: const Icon(Icons.person_add),
      ),
    );
  }

  void _openAddUser(BuildContext context) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    UserRole role = UserRole.staff;
    Map<String, bool> permissions = Map<String, bool>.from(_roleDefaults(role));
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (ctx) {
        final vm = ctx.read<UsersViewModel?>();
        if (vm == null) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Users module unavailable (no active company).'),
          );
        }
        return StatefulBuilder(
          builder: (ctx, setStateSheet) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Display name'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email (optional)'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: pinCtrl,
                    decoration: const InputDecoration(labelText: 'PIN (4-6 digits, required)'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<UserRole>(
                    initialValue: role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: UserRole.values
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(r.name),
                            ))
                        .toList(),
                    onChanged: (v) => setStateSheet(() {
                      role = v ?? UserRole.staff;
                      permissions = Map<String, bool>.from(_roleDefaults(role));
                    }),
                  ),
                  const SizedBox(height: 12),
                  _permissionPicker(
                    permissions: permissions,
                    onChanged: (key, value) => setStateSheet(() => permissions[key] = value),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (nameCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(ctx)
                              .showSnackBar(const SnackBar(content: Text('Name required')));
                          return;
                        }
                        final pin = pinCtrl.text.trim();
                        if (pin.isEmpty || pin.length < 4 || pin.length > 6) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('PIN required (4-6 digits)')),
                          );
                          return;
                        }
                        await vm.addUser(
                          displayName: nameCtrl.text.trim(),
                          role: role,
                          email: emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
                          password: null,
                          pin: pin,
                          permissions: permissions,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Add user'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openUserDetail(BuildContext context, UserAccount user) {
    final vm = context.read<UsersViewModel?>();
    if (vm == null) return;
    UserRole role = user.role;
    Map<String, bool> permissions = _effectivePermissions(user);
    bool active = user.active;
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateSheet) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Edit ${user.displayName}', style: Theme.of(ctx).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<UserRole>(
                    initialValue: role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: UserRole.values
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(r.name),
                            ))
                        .toList(),
                    onChanged: (v) => setStateSheet(() {
                      role = v ?? role;
                      permissions = Map<String, bool>.from(_roleDefaults(role))..addAll(user.permissions);
                    }),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Active'),
                    value: active,
                    onChanged: (v) => setStateSheet(() => active = v),
                  ),
                  const SizedBox(height: 8),
                  Text('Permissions', style: Theme.of(ctx).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  _permissionPicker(
                    permissions: permissions,
                    onChanged: (key, value) => setStateSheet(() => permissions[key] = value),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Save'),
                      onPressed: () async {
                        await vm.updateRole(user.id, role);
                        await vm.updatePermissions(user.id, permissions);
                        if (active != user.active) {
                          await vm.setActive(user.id, active);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete user'),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: ctx,
                          builder: (dCtx) => AlertDialog(
                            title: const Text('Delete user'),
                            content: Text('Delete ${user.displayName}?'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(dCtx, false),
                                  child: const Text('Cancel')),
                              TextButton(
                                  onPressed: () => Navigator.pop(dCtx, true),
                                  child: const Text('Delete')),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await vm.deleteUser(user.id);
                          if (ctx.mounted) Navigator.pop(ctx);
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _permissionPicker({
    required Map<String, bool> permissions,
    required void Function(String key, bool value) onChanged,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _permissionOptions.entries.map((entry) {
        final key = entry.key;
        final label = entry.value;
        final selected = permissions[key] ?? false;
        return ChoiceChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                size: 16,
                color: selected ? colors.onPrimary : colors.primary,
              ),
              const SizedBox(width: 6),
              Text(label),
            ],
          ),
          selected: selected,
          selectedColor: colors.primary,
          labelStyle: TextStyle(
            color: selected ? colors.onPrimary : colors.onSurface,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
          backgroundColor: colors.surfaceContainerHighest.withValues(alpha: 0.6),
          onSelected: (v) => onChanged(key, v),
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }
}
