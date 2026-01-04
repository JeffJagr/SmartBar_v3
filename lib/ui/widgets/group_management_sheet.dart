import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../repositories/group_repository.dart';
import '../../viewmodels/inventory_view_model.dart';

/// Bottom sheet for managing groups (create / edit inline).
class GroupManagementSheet extends StatefulWidget {
  const GroupManagementSheet({super.key, required this.repository, required this.canManage});

  final GroupRepository? repository;
  final bool canManage;

  @override
  State<GroupManagementSheet> createState() => _GroupManagementSheetState();
}

class _GroupManagementSheetState extends State<GroupManagementSheet> {
  late Future<List<GroupMeta>> _future;
  final TextEditingController _nameCtrl = TextEditingController();
  Color? _selectedColor;
  final Map<String, Color?> _rowColors = {};
  final Map<String, String> _rowNames = {};

  static const List<Color> _palette = [
    Color(0xFF7B61FF), // purple
    Color(0xFFFF6B6B), // coral red
    Color(0xFF4ECDC4), // teal
    Color(0xFFFFB347), // amber
    Color(0xFF1E90FF), // dodger blue
    Color(0xFF2ECC71), // green
    Color(0xFFFF66C4), // pink
    Color(0xFF6C757D), // slate
    Color(0xFF8E44AD), // deep violet
    Color(0xFF3498DB), // refined blue
    Color(0xFF16A085), // jade
    Color(0xFFF39C12), // saffron
    Color(0xFF27AE60), // forest
    Color(0xFFC0392B), // wine red
    Color(0xFF95A5A6), // silver
    Color(0xFF34495E), // midnight blue
  ];

  @override
  void initState() {
    super.initState();
    _future = widget.repository?.listGroups() ?? Future.value([]);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (widget.repository == null) return;
    setState(() {
      _future = widget.repository!.listGroups();
    });
  }

  Future<void> _createGroup() async {
    if (!widget.canManage || widget.repository == null) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final invVm = mounted ? Provider.of<InventoryViewModel?>(context, listen: false) : null;
    final selected = _selectedColor ?? _palette.first;
    final colorHex = _hexFromColor(selected);
    final id = name.toLowerCase();
    await widget.repository!.upsertGroup(id: id, name: name, color: colorHex);
    await invVm?.applyGroupColorToProducts(groupName: name, colorHex: colorHex);
    await _refresh();
    _nameCtrl.clear();
    setState(() => _selectedColor = null);
  }

  Future<void> _deleteGroup(String id) async {
    if (!widget.canManage || widget.repository == null) return;
    await widget.repository!.deleteGroup(id);
    await _refresh();
  }

  Future<void> _saveExistingGroup(
    GroupMeta g, {
    required String newName,
    required Color newColor,
  }) async {
    final repo = widget.repository;
    final inv = mounted ? Provider.of<InventoryViewModel?>(context, listen: false) : null;
    if (repo == null) return;
    final colorHex = _hexFromColor(newColor);
    await repo.upsertGroup(id: g.id, name: newName, color: colorHex);
    if (inv != null) {
      await inv.applyGroupUpdate(
        groupId: g.id,
        oldName: g.name,
        newName: newName,
        colorHex: colorHex,
      );
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.canManage) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('You do not have permission to manage groups.'),
      );
    }
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxHeight = constraints.maxHeight * 0.9;
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + bottomInset),
            child: SizedBox(
              height: maxHeight,
              child: FutureBuilder<List<GroupMeta>>(
                future: _future,
                builder: (context, snapshot) {
                  final groups = snapshot.data ?? [];
                  return ListView(
                    padding: EdgeInsets.only(bottom: bottomInset),
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.palette_outlined),
                          const SizedBox(width: 8),
                          Text('Manage groups', style: Theme.of(context).textTheme.titleMedium),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildCreateCard(),
                      const SizedBox(height: 12),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const Center(child: CircularProgressIndicator()),
                      if (snapshot.connectionState != ConnectionState.waiting && groups.isEmpty)
                        const Text('No groups yet.'),
                      if (groups.isNotEmpty)
                        ...groups.map((g) => _buildGroupRow(g)),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCreateCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Create new group', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Group name',
                prefixIcon: Icon(Icons.edit_outlined),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _palette
                  .map(
                    (c) => GestureDetector(
                      onTap: () => setState(() => _selectedColor = c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: _selectedColor == c ? 38 : 32,
                        height: _selectedColor == c ? 38 : 32,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          boxShadow: _selectedColor == c
                              ? [
                                  BoxShadow(
                                    color: c.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add_outlined),
                    label: const Text('Create'),
                    onPressed: _createGroup,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reload'),
                  onPressed: _refresh,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupRow(GroupMeta g) {
    final currentName = _rowNames[g.id] ?? g.name;
    final currentColor = _rowColors[g.id] ?? _parseColor(g.color) ?? _palette.first;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: currentColor,
                  child: Text(
                    currentName.isNotEmpty ? currentName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: currentName,
                    decoration: const InputDecoration.collapsed(hintText: 'Group name'),
                    onChanged: (v) => _rowNames[g.id] = v,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteGroup(g.id),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _palette
                  .map(
                    (c) => GestureDetector(
                      onTap: () => setState(() => _rowColors[g.id] = c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: currentColor == c ? 34 : 28,
                        height: currentColor == c ? 34 : 28,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          boxShadow: currentColor == c
                              ? [
                                  BoxShadow(
                                    color: c.withValues(alpha: 0.25),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('${g.itemIds.length} items',
                    style: Theme.of(context).textTheme.bodySmall),
                const Spacer(),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Save changes'),
                  onPressed: () => _saveExistingGroup(
                    g,
                    newName: (_rowNames[g.id] ?? g.name).trim().isNotEmpty
                        ? (_rowNames[g.id] ?? g.name).trim()
                        : g.name,
                    newColor: currentColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    try {
      final cleaned = hex.startsWith('#') ? hex.substring(1) : hex;
      final value = int.parse(cleaned, radix: 16);
      return Color(value <= 0xFFFFFF ? 0xFF000000 | value : value);
    } catch (_) {
      return null;
    }
  }

  String _hexFromColor(Color color) {
    final argb = color.toARGB32();
    return '#${argb.toRadixString(16).padLeft(8, '0').substring(2)}';
  }
}
