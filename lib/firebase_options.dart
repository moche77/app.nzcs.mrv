// File generated from the user-provided google-services.json for the
// `nzcsmrvmobile` Firebase project. Provides multi-platform Firebase
// initialization configuration. Web/iOS/macOS configurations can be
// populated later when those platforms are activated in Firebase Console.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      // Web configuration must be added in Firebase Console > Project Settings
      // > General > Your apps > Add app (Web). Until then, Web falls back to
      // the Android config (read-only mode acceptable for preview).
      return android;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        // iOS not yet provisioned in Firebase Console.
        return android;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCTB9gOdnTV_WO0C_6RD-i61YnEfHDP6K0',
    appId: '1:649373538088:android:d251c500785d01c234221d',
    messagingSenderId: '649373538088',
    projectId: 'nzcsmrvmobile',
    storageBucket: 'nzcsmrvmobile.firebasestorage.app',
  );
}
