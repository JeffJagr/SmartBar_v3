import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/app_controller.dart';
import '../../models/product.dart';
import '../../models/note.dart';
import '../../viewmodels/notes_view_model.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _contentController = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();
  String _tag = 'TODO'; // default tag label
  String _priority = 'Normal';
  String? _linkedProductId;
  bool _submitting = false;
  String _search = '';
  String _tagFilter = 'all';
  bool _showDone = true;

  @override
  void dispose() {
    _contentController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NotesViewModel>();
    final app = context.watch<AppController>();
    final perm = app.currentPermissionSnapshot;
    final canAdd = app.permissions.canAddNotes(perm);

    if (vm.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.error != null) {
      return Center(child: Text('Error: ${vm.error}'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
        actions: [
          if (canAdd)
            IconButton(
              icon: const Icon(Icons.add_comment_outlined),
              onPressed: () => _openAddNote(context, vm.products, canAdd: canAdd),
              tooltip: 'Add Note',
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => vm.init(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: vm.filteredNotes.where(_matchesSearch).length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _searchCtrl,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search notes, tags, products…',
                        ),
                        onChanged: (v) {
                          setState(() => _search = v.toLowerCase());
                          vm.setSearch(v);
                        },
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _tagChip('all', 'All'),
                          _tagChip('todo', 'TODO'),
                          _tagChip('info', 'Info'),
                          _tagChip('alert', 'Alert'),
                          FilterChip(
                            label: const Text('Show done'),
                            selected: _showDone,
                            onSelected: (v) {
                              setState(() => _showDone = v);
                              vm.toggleShowDone(v);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }
              final filtered = vm.filteredNotes.where(_matchesSearch).toList();
              if (filtered.isEmpty) {
                return const Center(child: Text('No notes yet'));
              }
              final note = filtered[index - 1];
              final priorityIcon = _priorityIcon(note.priority);
              final priorityColor = _priorityColor(note.priority);
              final timestamp = note.timestamp.toLocal();
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (priorityIcon != null)
                                  Icon(priorityIcon,
                                      size: 16, color: priorityColor ?? Colors.orange),
                                if (priorityIcon != null) const SizedBox(width: 6),
                                Expanded(child: Text(note.content)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${note.authorName} • ${timestamp.toString()}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (note.isDone && note.doneBy != null && note.doneAt != null)
                              Text(
                                'Done by ${note.doneBy} on ${note.doneAt}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.green),
                              ),
                            if (note.linkedProductId != null)
                              Text(
                                'Linked product: ${_productName(vm.products, note.linkedProductId!)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Chip(
                              label: Text(note.tag),
                              backgroundColor: _tagColor(note.tag).withValues(alpha: 0.15),
                              labelStyle: TextStyle(color: _tagColor(note.tag)),
                            ),
                            if (!note.isDone && note.tag == 'TODO')
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                ),
                                onPressed: () async {
                                  final app = context.read<AppController>();
                                  final doneBy = app.displayName;
                                  final vm = context.read<NotesViewModel>();
                                  await vm.markDone(id: note.id, doneBy: doneBy);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Note marked done')),
                                  );
                                },
                                child: const Text('Mark done'),
                              ),
                            if (vm.canDeleteNotes)
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                ),
                                onPressed: () async {
                                  final vm = context.read<NotesViewModel>();
                                  await vm.deleteNote(note.id);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(const SnackBar(content: Text('Note deleted')));
                                },
                                child: const Text('Delete'),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
      floatingActionButton: canAdd
          ? FloatingActionButton(
              onPressed: () => _openAddNote(context, vm.products, canAdd: canAdd),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  bool _matchesSearch(Note note) {
    if (_search.isEmpty && _tagFilter == 'all' && _showDone) return true;
    final haystack =
        '${note.content} ${note.tag} ${note.linkedProductId ?? ''} ${note.authorName}'.toLowerCase();
    final tagOk = _tagFilter == 'all' ? true : note.tag.toLowerCase() == _tagFilter;
    final doneOk = _showDone || !note.isDone;
    return haystack.contains(_search) && tagOk && doneOk;
  }

  Widget _tagChip(String value, String label) {
    final selected = _tagFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() {
        _tagFilter = value;
        context.read<NotesViewModel>().setTagFilter(value);
      }),
    );
  }

  void _openAddNote(BuildContext context, List<Product> products, {required bool canAdd}) {
    if (!canAdd) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You do not have permission to add notes.')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final app = ctx.read<AppController>();
        final notesVm = ctx.read<NotesViewModel>();
        final authorId = app.ownerUser?.uid ?? app.currentStaff?.id ?? 'anon';
        final companyId = app.activeCompany?.id ?? '';
        final authorName = app.displayName;
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (sheetContext, setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Note',
                      style: Theme.of(sheetContext).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _contentController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Content',
                        hintText: 'Write your note...',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _tag,
                      decoration: const InputDecoration(labelText: 'Tag'),
                      items: const [
                        DropdownMenuItem(value: 'TODO', child: Text('TODO')),
                        DropdownMenuItem(value: 'Important', child: Text('Important')),
                        DropdownMenuItem(value: 'NB', child: Text('NB')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _tag = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: _linkedProductId,
                      decoration: const InputDecoration(labelText: 'Linked product (optional)'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('General note'),
                        ),
                        ...products.map(
                          (p) => DropdownMenuItem<String?>(
                            value: p.id,
                            child: Text(p.name),
                          ),
                        ),
                      ],
                      onChanged: (value) => setState(() => _linkedProductId = value),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _priority,
                      decoration: const InputDecoration(labelText: 'Priority'),
                      items: const [
                        DropdownMenuItem(value: 'Normal', child: Text('Normal')),
                        DropdownMenuItem(value: 'Important', child: Text('Important')),
                        DropdownMenuItem(value: 'Info', child: Text('Info')),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _priority = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: _submitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_outlined),
                        label: const Text('Save Note'),
                        onPressed: _submitting
                            ? null
                            : () async {
                                if (companyId.isEmpty) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                        content: Text('Active company is required to add a note.')),
                                  );
                                  return;
                                }
                                setState(() => _submitting = true);
                                try {
                                  await notesVm.addNote(
                                    authorId: authorId,
                                    authorName: authorName,
                                    content: _contentController.text.trim(),
                                    tag: _tag,
                                    linkedProductId: _linkedProductId,
                                    priority: _priority,
                                    companyId: companyId,
                                  );
                                  _contentController.clear();
                                  _linkedProductId = null;
                                  _priority = 'Normal';
                                  if (!ctx.mounted) return;
                                  Navigator.of(ctx).pop();
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(content: Text('Note saved')),
                                  );
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text('Failed to save note: $e')),
                                    );
                                  }
                                } finally {
                                  if (mounted) setState(() => _submitting = false);
                                }
                              },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _productName(List<Product> products, String id) {
    return products.firstWhere(
      (p) => p.id == id,
      orElse: () => const Product(
        id: 'unknown',
        companyId: '',
        name: 'Unknown product',
        group: '',
        unit: '',
        barQuantity: 0,
        barMax: 0,
        warehouseQuantity: 0,
        warehouseTarget: 0,
      ),
    ).name;
  }

  Color _tagColor(String tag) {
    switch (tag) {
      case 'Important':
        return Colors.red;
      case 'NB':
        return Colors.blue;
      case 'TODO':
      default:
        return Colors.orange;
    }
  }

  IconData? _priorityIcon(String? priority) {
    switch (priority) {
      case 'Important':
        return Icons.priority_high;
      case 'Info':
        return Icons.info_outline;
      default:
        return null;
    }
  }

  Color? _priorityColor(String? priority) {
    switch (priority) {
      case 'Important':
        return Colors.red;
      case 'Info':
        return Colors.blue;
      default:
        return null;
    }
  }
}
