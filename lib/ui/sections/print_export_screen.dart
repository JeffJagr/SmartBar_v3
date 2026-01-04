import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/inventory_view_model.dart';

class PrintExportScreen extends StatelessWidget {
  const PrintExportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final inventoryVm = context.watch<InventoryViewModel>();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Print / Export', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Export your products to CSV for printing or sharing. Copy the CSV and paste into Excel/Sheets.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copy inventory CSV'),
            onPressed: () async {
              final csv = _buildCsv(inventoryVm);
              await Clipboard.setData(ClipboardData(text: csv));
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('CSV copied to clipboard')));
              }
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: SelectableText(
                _buildCsv(inventoryVm),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _buildCsv(InventoryViewModel vm) {
    final buffer = StringBuffer();
    buffer.writeln('Name,Group,Subgroup,Unit,Bar Qty,Bar Max,WH Qty,WH Target,Restock Hint');
    for (final p in vm.products) {
      final row = [
        p.name,
        p.group,
        p.subgroup ?? '',
        p.unit,
        p.barQuantity,
        p.barMax,
        p.warehouseQuantity,
        p.warehouseTarget,
        p.restockHint ?? 0,
      ].map((v) => _escape(v)).join(',');
      buffer.writeln(row);
    }
    return buffer.toString();
  }

  String _escape(Object? value) {
    final s = value?.toString() ?? '';
    if (s.contains(',') || s.contains('"')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }
}
