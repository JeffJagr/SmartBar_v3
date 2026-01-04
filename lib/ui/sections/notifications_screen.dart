import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/app_controller.dart';
import '../../models/user_role.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  bool _saving = false;
  Map<String, bool> _prefs = {};

  final Map<String, String> _labels = const {
    'newNote': 'New note',
    'noteDone': 'Note done',
    'noteDeleted': 'Note deleted',
    'lowStock': 'Low stock alert',
    'orderCreated': 'Order created',
    'orderConfirmed': 'Order confirmed',
    'orderReceived': 'Order received',
    'newStaff': 'New staff member',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final app = context.read<AppController>();
    final uid = app.ownerUser?.uid ?? app.currentStaff?.id ?? '';
    final companyId = app.activeCompany?.id ?? '';
    if (uid.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      Map<String, bool> map = {};
      if (companyId.isNotEmpty) {
        final memberSnap = await FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .collection('members')
            .doc(uid)
            .get();
        map = (memberSnap.data()?['notificationPrefs'] as Map?)?.cast<String, bool>() ?? {};
      }
      if (map.isEmpty) {
        final doc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        map =
            (doc.data()?['notificationPrefs'] as Map?)?.cast<String, bool>() ??
                {};
      }
      setState(() {
        _prefs = {..._defaultsForRole(app), ...map};
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _prefs = _defaultsForRole(app);
        _loading = false;
      });
    }
  }

  Map<String, bool> _defaultsForRole(AppController app) {
    if (app.isOwner) {
      return {
        'newNote': true,
        'noteDone': true,
        'noteDeleted': true,
        'lowStock': true,
        'orderCreated': true,
        'orderConfirmed': true,
        'orderReceived': true,
        'newStaff': true,
      };
    }
    final role = app.role;
    if (role == UserRole.manager) {
      return {
        'newNote': true,
        'noteDone': true,
        'noteDeleted': true,
        'lowStock': true,
        'orderCreated': true,
        'orderConfirmed': true,
        'orderReceived': true,
        'newStaff': true,
      };
    }
    // staff
    return {
      'newNote': true,
      'noteDone': true,
      'lowStock': true,
      'orderConfirmed': true,
      'orderReceived': true,
    };
  }

  List<String> _keysForRole(AppController app) {
    if (app.isOwner || app.role == UserRole.manager) {
      return [
        'newNote',
        'noteDone',
        'noteDeleted',
        'lowStock',
        'orderCreated',
        'orderConfirmed',
        'orderReceived',
        'newStaff',
      ];
    }
    return [
      'newNote',
      'noteDone',
      'lowStock',
      'orderConfirmed',
      'orderReceived',
    ];
  }

  Future<void> _save() async {
    final app = context.read<AppController>();
    final uid = app.ownerUser?.uid ?? app.currentStaff?.id ?? '';
    final companyId = app.activeCompany?.id ?? '';
    if (uid.isEmpty) return;
    setState(() => _saving = true);
    try {
      final data = {'notificationPrefs': _prefs};
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
            data,
            SetOptions(merge: true),
          );
      if (companyId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .collection('members')
            .doc(uid)
            .set({
          ...data,
          'companyId': companyId,
        }, SetOptions(merge: true));
        await app.messagingService.syncTopics(
          companyId: companyId,
          preferences: _prefs,
        );
        await _persistToken(app, uid, companyId);
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Notification preferences saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _persistToken(
    AppController app,
    String uid,
    String companyId,
  ) async {
    final token = await app.messagingService.fetchToken();
    if (token == null || token.isEmpty) return;
    final tokenData = {'fcmToken': token};
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
          tokenData,
          SetOptions(merge: true),
        );
    await FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('members')
        .doc(uid)
        .set({
      ...tokenData,
      'companyId': companyId,
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final keys = _keysForRole(app);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: keys
            .map(
              (k) => SwitchListTile(
                title: Text(_labels[k] ?? k),
                value: _prefs[k] ?? false,
                onChanged: (v) => setState(() => _prefs[k] = v),
              ),
            )
            .toList(),
      ),
    );
  }
}
