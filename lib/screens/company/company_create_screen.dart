import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/app_controller.dart';
import '../../ui/screens/home/home_screen.dart';

class CompanyCreateScreen extends StatefulWidget {
  const CompanyCreateScreen({super.key});

  @override
  State<CompanyCreateScreen> createState() => _CompanyCreateScreenState();
}

class _CompanyCreateScreenState extends State<CompanyCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  bool _creating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _creating = true);
    final app = context.read<AppController>();
    try {
      final result = await app.createCompany(
        name: _nameController.text.trim(),
        companyCode: _codeController.text.trim().toUpperCase(),
      );
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Invite your team'),
            content: Text(
              'Company created. Share the company code (${result.companyCode}) and add staff from the Users screen to generate their PINs.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Got it'),
              ),
            ],
          ),
        );
      }
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (_) => false,
        );
      }
    } catch (e) {
      final uid = app.ownerUser?.uid ?? 'none';
      final emailLower = app.ownerUser?.email?.toLowerCase() ?? '';
      debugPrint(
        'CompanyCreate error uid=$uid email=$emailLower code=${_codeController.text.trim().toUpperCase()} error=$e',
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not create company: $e')));
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create company')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Company details',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Company name',
                    prefixIcon: Icon(Icons.store_mall_directory_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Business ID (required)',
                    hintText: 'e.g. BAR-12345',
                    prefixIcon: Icon(Icons.qr_code_2_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Business ID is required';
                    }
                    if (value.trim().length < 4) {
                      return 'Business ID should be at least 4 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: _creating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: const Text('Create'),
                    onPressed: _creating ? null : _submit,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
