import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../controllers/app_controller.dart';
import '../../ui/screens/home/home_screen.dart';

class StaffLoginScreen extends StatefulWidget {
  const StaffLoginScreen({super.key});

  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyCodeController = TextEditingController();
  final _pinController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _companyCodeController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
    });
    final app = context.read<AppController>();
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
      await app.signInStaff(
        companyCode: _companyCodeController.text.trim(),
        pin: _pinController.text.trim(),
      );
      // Ensure auth is present after login.
      if (FirebaseAuth.instance.currentUser == null) {
        throw FirebaseAuthException(
          code: 'no-auth',
          message: 'Authentication failed; please try again.',
        );
      }
      // After staff login, go straight into the app for that company.
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (_) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      final message = e.message ?? 'Login failed. Please try again.';
      final current = FirebaseAuth.instance.currentUser;
      debugPrint(
          'StaffLogin error code=${e.code} message=${e.message} uid=${current?.uid ?? 'none'} email=${current?.email?.toLowerCase() ?? ''} companyCode=${_companyCodeController.text.trim().toUpperCase()}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            action: e.code == 'permission-denied'
                ? SnackBarAction(
                    label: 'Retry',
                    onPressed: () {
                      if (!_loading) {
                        _submit();
                      }
                    },
                  )
                : null,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onLongPress: () {
            _openDebugPanel();
          },
          child: const Text('Staff / Worker Login'),
        ),
      ),
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
                  'Enter your Company Code and PIN provided by your manager.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _companyCodeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Business ID (Company Code)',
                    hintText: 'e.g. BAR-12345',
                    prefixIcon: Icon(Icons.qr_code_2_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Company code is required';
                    }
                    if (value.trim().length < 4) {
                      return 'Company code looks too short';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'PIN',
                    hintText: '4-6 digits',
                    prefixIcon: Icon(Icons.vpn_key_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'PIN is required';
                    }
                    if (value.trim().length < 4) {
                      return 'PIN must be at least 4 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: const Text('Login'),
                    onPressed: _loading ? null : _submit,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  icon: const Icon(Icons.help_outline, size: 18),
                  label: const Text('Need help? Ask your manager for your code & PIN'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Reach out to your manager/owner to reset your PIN or code.'),
                    ));
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openDebugPanel() async {
    final app = context.read<AppController>();
    final current = FirebaseAuth.instance.currentUser;
    String? companyId = app.activeCompany?.id;
    String? authMapRole;
    bool authMapExists = false;
    bool canReadCompany = false;
    String? debugError;
    try {
      final code = _companyCodeController.text.trim().toUpperCase();
      if ((companyId == null || companyId.isEmpty) && code.isNotEmpty) {
        final pinDoc = await FirebaseFirestore.instance.collection('staffPins').doc(code).get();
        companyId = pinDoc.data()?['companyId'] as String?;
      }
      if (companyId != null && companyId.isNotEmpty && current != null) {
        final authMapDoc = await FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .collection('authMap')
            .doc(current.uid)
            .get();
        authMapExists = authMapDoc.exists;
        authMapRole = (authMapDoc.data() ?? {})['role'] as String?;
        final companyDoc =
            await FirebaseFirestore.instance.collection('companies').doc(companyId).get();
        canReadCompany = companyDoc.exists;
      }
    } catch (e) {
      debugError = e.toString();
    }

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Debug Access (temporary)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('uid: ${current?.uid ?? 'none'}'),
              Text('emailLower: ${current?.email?.toLowerCase() ?? ''}'),
              Text('companyId: ${companyId ?? 'unknown'}'),
              Text('authMap exists: $authMapExists'),
              Text('authMap role: ${authMapRole ?? 'n/a'}'),
              Text('can read company: $canReadCompany'),
              if (debugError != null) ...[
                const SizedBox(height: 8),
                Text('error: $debugError'),
              ],
              const SizedBox(height: 12),
              const Text('Long press this title later to remove.', style: TextStyle(fontSize: 12)),
            ],
          ),
        );
      },
    );
  }
}
