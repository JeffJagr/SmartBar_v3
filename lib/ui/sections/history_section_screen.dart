import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../controllers/app_controller.dart';
import '../../models/history_entry.dart';
import '../../models/supplier.dart';
import '../../viewmodels/history_view_model.dart';

class HistorySectionScreen extends StatefulWidget {
  const HistorySectionScreen({super.key});

  @override
  State<HistorySectionScreen> createState() => _HistorySectionScreenState();
}

class _HistorySectionScreenState extends State<HistorySectionScreen> {
  String _search = '';
  String _timeWindow = 'All';
  String _supplierFilter = 'All';
  List<Supplier> _suppliers = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HistoryViewModel?>()?.init();
      _loadSuppliers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HistoryViewModel?>();
    if (vm == null) {
      return const Center(child: Text('History not available'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: vm.refresh,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<_ExportKind>(
            tooltip: 'Export / share',
            onSelected: (kind) async {
              final entries = _filteredEntries(vm.entries, vm.actionFilter);
              final text = kind == _ExportKind.csv ? _exportCsv(entries) : _exportPrintable(entries);
              final messenger = ScaffoldMessenger.of(context);
              await Clipboard.setData(ClipboardData(text: text));
              if (!mounted) return;
              messenger.showSnackBar(
                SnackBar(content: Text(kind == _ExportKind.csv ? 'History CSV copied' : 'Printable history copied')),
              );
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _ExportKind.csv,
                child: ListTile(
                  leading: Icon(Icons.copy_all),
                  title: Text('Copy CSV'),
                ),
              ),
              PopupMenuItem(
                value: _ExportKind.printable,
                child: ListTile(
                  leading: Icon(Icons.picture_as_pdf_outlined),
                  title: Text('Copy printable (PDF-ready)'),
                ),
              ),
            ],
            icon: const Icon(Icons.ios_share),
          ),
        ],
      ),
      body: vm.loading
          ? const Center(child: CircularProgressIndicator())
          : vm.error != null
              ? Center(child: Text('Error: ${vm.error}'))
              : _buildContent(context, vm),
    );
  }

  Widget _buildContent(BuildContext context, HistoryViewModel vm) {
    final entries = vm.entries;
    final actionTypes = {
      'All',
      ...vm.entries.map((e) => e.actionType),
    }.toList()
      ..sort();

    if (entries.isEmpty) {
      return const Center(child: Text('No history yet'));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search name, user, details…',
                  ),
                  onChanged: (v) => setState(() => _search = v.toLowerCase()),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _timeWindow,
                items: const [
                  DropdownMenuItem(value: 'All', child: Text('All time')),
                  DropdownMenuItem(value: 'Today', child: Text('Today')),
                  DropdownMenuItem(value: '7d', child: Text('Last 7 days')),
                ],
                onChanged: (v) => setState(() => _timeWindow = v ?? 'All'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Text('Supplier:', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _supplierFilter,
                items: [
                  const DropdownMenuItem(value: 'All', child: Text('All suppliers')),
                  ..._suppliers.map(
                    (s) => DropdownMenuItem(value: s.name, child: Text(s.name)),
                  ),
                ],
                onChanged: (v) => setState(() => _supplierFilter = v ?? 'All'),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: actionTypes.map((type) {
              final selected =
                  vm.actionFilter == null ? type == 'All' : vm.actionFilter == type;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(type),
                  selected: selected,
                  onSelected: (_) {
                    vm.setFilters(action: type == 'All' ? null : type);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => vm.refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _filteredEntries(entries, vm.actionFilter).length,
              itemBuilder: (context, index) {
                final e = _filteredEntries(entries, vm.actionFilter)[index];
                return _entryCard(context, e);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _entryCard(BuildContext context, HistoryEntry e) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _chip(context, e.actionType, color: _actionColor(e.actionType)),
                if (e.performedBy.isNotEmpty)
                  _chip(context, 'By ${e.performedBy}',
                      color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2)),
                _chip(context, _formatTs(e.timestamp),
                    color: Theme.of(context).colorScheme.surfaceContainerHighest),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              e.itemName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (e.description != null) ...[
              const SizedBox(height: 4),
              Text(e.description!),
            ],
            if (e.details != null && e.details!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: e.details!.entries
                    .map((d) => _chip(context, '${d.key}: ${d.value}',
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.3)))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String label, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? Theme.of(context).colorScheme.surfaceContainerHighest)
            .withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  String _formatTs(DateTime ts) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dd = ts.day.toString().padLeft(2, '0');
    final mm = months[ts.month - 1];
    final yy = (ts.year % 100).toString().padLeft(2, '0');
    final hh = ts.hour.toString().padLeft(2, '0');
    final min = ts.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yy $hh:$min';
  }

  List<HistoryEntry> _filteredEntries(List<HistoryEntry> entries, String? action) {
    final now = DateTime.now();
    return entries.where((e) {
      if (action != null && action.isNotEmpty && e.actionType != action) return false;
      if (_supplierFilter != 'All') {
        final supplier =
            (e.details != null ? (e.details!['supplier'] as String? ?? '') : '').toLowerCase();
        if (!supplier.contains(_supplierFilter.toLowerCase())) return false;
      }
      if (_search.isNotEmpty) {
        final haystack =
            '${e.itemName} ${e.performedBy} ${e.details} ${e.description}'.toLowerCase();
        if (!haystack.contains(_search)) return false;
      }
      if (_timeWindow == 'Today') {
        final start = DateTime(now.year, now.month, now.day);
        if (e.timestamp.isBefore(start)) return false;
      } else if (_timeWindow == '7d') {
        if (now.difference(e.timestamp).inDays > 7) return false;
      }
      return true;
    }).toList();
  }

  Color _actionColor(String action) {
    switch (action) {
      case 'order_create':
        return Colors.blue.withValues(alpha: 0.2);
      case 'order_received':
      case 'order_delivered':
        return Colors.green.withValues(alpha: 0.2);
      case 'order_confirmed':
        return Colors.teal.withValues(alpha: 0.2);
      case 'product_edit':
        return Colors.orange.withValues(alpha: 0.2);
      case 'product_delete':
        return Colors.red.withValues(alpha: 0.2);
      case 'transfer':
        return Colors.purple.withValues(alpha: 0.2);
      case 'note_add':
      case 'note_done':
        return Colors.indigo.withValues(alpha: 0.2);
      default:
        return Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);
    }
  }

  String _exportCsv(List<HistoryEntry> entries) {
    final buffer = StringBuffer();
    buffer.writeln('Action,Item,By,Timestamp,Details');
    for (final e in entries) {
      final details = (e.details ?? {}).entries.map((d) => '${d.key}:${d.value}').join(' | ');
      buffer.writeln(
          '${e.actionType},${e.itemName},${e.performedBy},${_formatTs(e.timestamp)},$details');
    }
    return buffer.toString();
  }

  String _exportPrintable(List<HistoryEntry> entries) {
    final buffer = StringBuffer();
    buffer.writeln('HISTORY LOG');
    buffer.writeln('========================');
    for (final e in entries) {
      buffer.writeln(
          '${e.actionType} | ${e.itemName} | ${_formatTs(e.timestamp)} | by ${e.performedBy}');
      if (e.description != null && e.description!.isNotEmpty) {
        buffer.writeln('  ${e.description}');
      }
      if (e.details != null && e.details!.isNotEmpty) {
        for (final d in e.details!.entries) {
          buffer.writeln('  - ${d.key}: ${d.value}');
        }
      }
      buffer.writeln('------------------------');
    }
    return buffer.toString();
  }

  Future<void> _loadSuppliers() async {
    final app = context.read<AppController?>();
    final companyId = app?.activeCompany?.id;
    if (companyId == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('suppliers')
          .orderBy('name')
          .get();
      if (!mounted) return;
      setState(() {
        _suppliers = snap.docs.map((d) => Supplier.fromMap(d.id, d.data())).toList();
      });
    } catch (_) {
      // Optional list; ignore fetch errors. Suppliers load once per history screen.
    }
  }
}

enum _ExportKind { csv, printable }
