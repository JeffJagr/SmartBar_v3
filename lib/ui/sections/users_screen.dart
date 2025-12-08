import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_account.dart';
import '../../viewmodels/users_view_model.dart';
import '../../controllers/app_controller.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
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
    final vm = context.watch<UsersViewModel>();
    final app = context.watch<AppController>();
    final canManage = app.permissions
        .canManageUsers(app.permissionSnapshot(app.permissions));
    if (!canManage) {
      return const Center(child: Text('Access denied'));
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
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(user.displayName),
              subtitle: Text('${user.role.name} • ${user.active ? "Active" : "Inactive"}'),
              trailing: PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'deactivate') {
                    await vm.setActive(user.id, false);
                  } else if (value == 'activate') {
                    await vm.setActive(user.id, true);
                  } else if (value.startsWith('role:')) {
                    final roleStr = value.split(':').last;
                    final role = UserRole.values.firstWhere(
                      (r) => r.name == roleStr,
                      orElse: () => UserRole.staff,
                    );
                    await vm.updateRole(user.id, role);
                  } else if (value == 'delete') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete user'),
                        content: Text('Delete ${user.displayName}?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel')),
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete')),
                        ],
                      ),
                    );
                    if (confirm == true) await vm.deleteUser(user.id);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'role:owner', child: Text('Make owner')),
                  const PopupMenuItem(value: 'role:manager', child: Text('Make manager')),
                  const PopupMenuItem(value: 'role:staff', child: Text('Make staff')),
                  if (user.active)
                    const PopupMenuItem(value: 'deactivate', child: Text('Deactivate'))
                  else
                    const PopupMenuItem(value: 'activate', child: Text('Activate')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
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
    final pinCtrl = TextEditingController();
    UserRole role = UserRole.staff;
    final permissions = <String, bool>{
      'editProducts': false,
      'createOrders': false,
      'confirmOrders': false,
      'manageUsers': false,
      'viewHistory': false,
    };
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (ctx) {
        final vm = ctx.read<UsersViewModel>();
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
                controller: pinCtrl,
                decoration: const InputDecoration(labelText: 'PIN / Password (required)'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<UserRole>(
                initialValue: role,
                items: UserRole.values
                    .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(r.name),
                        ))
                    .toList(),
                onChanged: (v) => role = v ?? UserRole.staff,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: permissions.keys.map((key) {
                  return FilterChip(
                    label: Text(key),
                    selected: permissions[key] ?? false,
                    onSelected: (v) => permissions[key] = v,
                  );
                }).toList(),
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
                    if (pin.isEmpty || pin.length < 4) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('PIN/password required (min 4 chars)')),
                      );
                      return;
                    }
                    await vm.addUser(
                      displayName: nameCtrl.text.trim(),
                      role: role,
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
  }
}
