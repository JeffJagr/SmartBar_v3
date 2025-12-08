import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
        title: const Text('Staff / Worker Login'),
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
                // TODO: add "Need help? Contact your manager" link or support CTA.
              ],
            ),
          ),
        ),
      ),
    );
  }
}
