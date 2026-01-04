import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Centralized helper to turn Firebase/Firestore errors into user-friendly text.
class FirestoreErrorHandler {
  static String friendlyMessage(
    Object error, {
    String? operation,
    String? path,
  }) {
    if (error is FirebaseException) {
      final code = error.code;
      _logDiagnostics(operation: operation, path: path, code: code, message: error.message);
      final base = switch (code) {
        'permission-denied' =>
          'Access denied. Please check your permissions or ask a manager.',
        'unavailable' => 'Service temporarily unavailable. Please try again.',
        'not-found' => 'Item not found or no longer exists.',
        _ => 'Something went wrong. Please try again.',
      };
      return base;
    }
    _logDiagnostics(operation: operation, path: path, code: 'unknown', message: error.toString());
    return 'Something went wrong. Please try again.';
  }

  static void _logDiagnostics({
    String? operation,
    String? path,
    String? code,
    String? message,
  }) {
    try {
      final app = Firebase.apps.isNotEmpty ? Firebase.apps.first : null;
      final projectId = app?.options.projectId ?? 'unknown-project';
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid ?? 'none';
      final isAnon = user?.isAnonymous ?? false;
      debugPrint(
          '[FirestoreDiag] project=$projectId uid=$uid isAnon=$isAnon op=$operation path=$path code=$code message=$message');
    } catch (_) {
      // best-effort logging; ignore secondary failures
    }
  }

  /// Wrap a Firestore/Firebase call to ensure consistent diagnostics and typed errors.
  static Future<T> guard<T>({
    required String operation,
    required String path,
    required Future<T> Function() run,
  }) async {
    try {
      return await run();
    } on FirebaseException catch (e) {
      _logDiagnostics(operation: operation, path: path, code: e.code, message: e.message);
      rethrow;
    } catch (e) {
      _logDiagnostics(operation: operation, path: path, code: 'unknown', message: e.toString());
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unknown',
        message: e.toString(),
      );
    }
  }
}
