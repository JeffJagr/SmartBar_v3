import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../controllers/app_controller.dart';
import '../../screens/company/company_list_screen.dart';

class CompanySettingsScreen extends StatefulWidget {
  const CompanySettingsScreen({super.key});

  @override
  State<CompanySettingsScreen> createState() => _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends State<CompanySettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _inviteEmailCtrl = TextEditingController();
  bool _lowStockAlerts = true;
  bool _orderApprovals = true;
  bool _staffNotifications = false;
  bool _saving = false;
  bool _loadedFromCompany = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _inviteEmailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final company = app.activeCompany;
    if (company == null) {
      return const Center(child: Text('No company selected'));
    }
    final isOwner = app.isOwner;
    if (!_loadedFromCompany) {
      _nameCtrl.text = company.name;
      _codeCtrl.text = company.companyCode;
      _lowStockAlerts = company.notificationLowStock;
      _orderApprovals = company.notificationOrderApprovals;
      _staffNotifications = company.notificationStaff;
      _loadedFromCompany = true;
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Company settings', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Identity', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameCtrl,
                  enabled: isOwner,
                  decoration: const InputDecoration(labelText: 'Company name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _codeCtrl,
                  enabled: isOwner,
                  decoration: const InputDecoration(labelText: 'Business ID (code)'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy code'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: company.companyCode));
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(content: Text('Code copied')));
                      },
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.copy_all),
                      label: const Text('Copy company ID'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: company.id));
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(content: Text('Company ID copied')));
                      },
                    ),
                    const Spacer(),
                    if (isOwner)
                      ElevatedButton.icon(
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save),
                        label: const Text('Save'),
                        onPressed: _saving
                            ? null
                            : () => _saveCompany(
                                  companyId: company.id,
                                  isOwner: isOwner,
                                ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Partner owners', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: _inviteEmailCtrl,
                  enabled: isOwner,
                  decoration: const InputDecoration(
                    labelText: 'Partner email',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Invite'),
                      onPressed: isOwner && !_saving
                          ? () => _invitePartner(company.id, _inviteEmailCtrl.text.trim())
                          : null,
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: () => _inviteEmailCtrl.clear(),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Leave company', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'If you leave, you will lose access until re-invited.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.exit_to_app),
                  label: const Text('Leave company'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                  onPressed: isOwner && !_saving
                      ? () => _confirmLeaveCompany(company.id, app.ownerUser?.uid)
                      : null,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Plan', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.bolt, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text('Blaze (pay as you go)',
                        style: Theme.of(context).textTheme.bodyMedium),
                    const Spacer(),
                    Text('Active', style: Theme.of(context).textTheme.labelLarge),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Billing and quotas managed in Firebase console. We will surface usage here later.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Notifications', style: Theme.of(context).textTheme.titleMedium),
                SwitchListTile(
                  title: const Text('Low stock alerts'),
                  subtitle: const Text('Notify owners/managers when stock drops below target'),
                  value: _lowStockAlerts,
                  onChanged: (v) => setState(() => _lowStockAlerts = v),
                ),
                SwitchListTile(
                  title: const Text('Order approvals'),
                  subtitle: const Text('Ask owner/manager approval before sending orders'),
                  value: _orderApprovals,
                  onChanged: (v) => setState(() => _orderApprovals = v),
                ),
                SwitchListTile(
                  title: const Text('Staff updates'),
                  subtitle: const Text('Notify staff about restock requests and notes'),
                  value: _staffNotifications,
                  onChanged: (v) => setState(() => _staffNotifications = v),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Data & exports', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Use the export buttons in each section (Bar, Warehouse, Orders, History) to copy data. '
                  'Printing/export from this screen will be added later.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveCompany({required String companyId, required bool isOwner}) async {
    if (!isOwner) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Only owners can edit company settings.')));
      return;
    }
    final name = _nameCtrl.text.trim();
    final code = _codeCtrl.text.trim().toUpperCase();
    if (name.isEmpty || code.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Name and Business ID are required.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final data = {
        'name': name,
        'companyCode': code,
        'notificationLowStock': _lowStockAlerts,
        'notificationOrderApprovals': _orderApprovals,
        'notificationStaff': _staffNotifications,
      };
      await FirebaseFirestore.instance.collection('companies').doc(companyId).set(
            data,
            SetOptions(merge: true),
          );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Company settings saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _invitePartner(String companyId, String email) async {
    final trimmed = email.trim().toLowerCase();
    if (trimmed.isEmpty || !trimmed.contains('@')) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Enter a valid email')));
      }
      return;
    }
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .update({
        'partnerEmails': FieldValue.arrayUnion([trimmed]),
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Partner invited')));
        _inviteEmailCtrl.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Invite failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmLeaveCompany(String companyId, String? uid) async {
    if (uid == null || uid.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave company?'),
        content: const Text('You will lose access until re-invited. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .update({
        'ownerIds': FieldValue.arrayRemove([uid]),
        'partnerEmails':
            FieldValue.arrayRemove([FirebaseAuth.instance.currentUser?.email?.toLowerCase()]),
      });
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const CompanyListScreen()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not leave: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
