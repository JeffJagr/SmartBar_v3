import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/history_view_model.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String? _actionFilter;
  final TextEditingController _productCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HistoryViewModel>().init();
    });
  }

  @override
  void dispose() {
    _productCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HistoryViewModel>();
    if (vm.loading && vm.entries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.error != null) {
      return Center(child: Text('Error: ${vm.error}'));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('History / Audit'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _actionFilter,
                    decoration: const InputDecoration(labelText: 'Action type'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All')),
                      DropdownMenuItem(value: 'product_edit', child: Text('Product edit')),
                      DropdownMenuItem(value: 'product_delete', child: Text('Product delete')),
                      DropdownMenuItem(value: 'transfer', child: Text('Transfer')),
                      DropdownMenuItem(value: 'order_create', child: Text('Order create')),
                      DropdownMenuItem(value: 'order_receive', child: Text('Order received')),
                    ],
                    onChanged: (v) {
                      setState(() => _actionFilter = v);
                      vm.setFilters(action: v, productId: _productCtrl.text.isEmpty ? null : _productCtrl.text);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _productCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Filter by productId',
                    ),
                    onChanged: (v) {
                      vm.setFilters(action: _actionFilter, productId: v.isEmpty ? null : v);
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: vm.entries.length,
              itemBuilder: (context, index) {
                final e = vm.entries[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text('${e.actionType} — ${e.itemName}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${e.performedBy} • ${e.timestamp}'),
                        if (e.description != null) Text(e.description!),
                        if (e.details != null) Text(e.details.toString()),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
