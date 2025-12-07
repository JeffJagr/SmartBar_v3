import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/app_controller.dart';
import '../../models/product.dart';
import '../../viewmodels/notes_view_model.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _contentController = TextEditingController();
  String _tag = 'TODO';
  String _priority = 'Normal';
  String? _linkedProductId;
  bool _submitting = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NotesViewModel>();

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
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: () => _openAddNote(context, vm.products),
            tooltip: 'Add Note',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => vm.init(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: vm.notes.length,
            itemBuilder: (context, index) {
              final note = vm.notes[index];
              final priorityIcon = _priorityIcon(note.priority);
              final priorityColor = _priorityColor(note.priority);
              final timestamp = note.timestamp.toLocal();
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Row(
                    children: [
                      if (priorityIcon != null)
                        Icon(priorityIcon, size: 16, color: priorityColor ?? Colors.orange),
                      if (priorityIcon != null) const SizedBox(width: 6),
                      Expanded(child: Text(note.content)),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                  trailing: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 140),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
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
                              await context.read<NotesViewModel>().markDone(
                                    id: note.id,
                                    doneBy: doneBy,
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
                              await context.read<NotesViewModel>().deleteNote(note.id);
                            },
                            child: const Text('Delete'),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddNote(context, vm.products),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _openAddNote(BuildContext context, List<Product> products) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final app = ctx.read<AppController>();
        final notesVm = ctx.read<NotesViewModel>();
        final authorId = app.ownerUser?.uid ?? app.currentStaff?.id ?? 'anon';
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
                      value: _tag,
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
                      value: _linkedProductId,
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
                      value: _priority,
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
                                setState(() => _submitting = true);
                                try {
                                  await notesVm.addNote(
                                    authorId: authorId,
                                    authorName: authorName,
                                    content: _contentController.text.trim(),
                                    tag: _tag,
                                    linkedProductId: _linkedProductId,
                                    priority: _priority,
                                  );
                                  _contentController.clear();
                                  _linkedProductId = null;
                                  _priority = 'Normal';
                                  if (!mounted) return;
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
