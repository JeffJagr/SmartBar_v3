import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase configuration for all supported platforms.
/// Generated from the provided Android google-services.json, iOS GoogleService-Info.plist,
/// and Web config shared in the project context.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        // TODO: add macOS config if we decide to support it.
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macOS.',
        );
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDa_6fZVuDgYLAb9m_ttkwsKKzdqPm67rc',
    appId: '1:554482574580:web:feafdbb45deabcfe53eaa1',
    messagingSenderId: '554482574580',
    projectId: 'smartbar-v3',
    authDomain: 'smartbar-v3.firebaseapp.com',
    storageBucket: 'smartbar-v3.firebasestorage.app',
    measurementId: 'G-NV798QZ7H5',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBaV__3_MHbeYvU2oxNZhGtXah6NP7SaaE',
    appId: '1:554482574580:android:bee79def0186885953eaa1',
    messagingSenderId: '554482574580',
    projectId: 'smartbar-v3',
    storageBucket: 'smartbar-v3.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAxTBpm-aA2RQZlgNioDLNXF7pakteE-iM',
    appId: '1:554482574580:ios:b8d1bb9ec3c1f10053eaa1',
    messagingSenderId: '554482574580',
    projectId: 'smartbar-v3',
    storageBucket: 'smartbar-v3.firebasestorage.app',
    iosBundleId: 'com.example.smartBarAppV3',
  );
}
