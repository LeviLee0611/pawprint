import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web not supported.');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('Unsupported platform.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBRzgYfHMBjF3ML_YSDLAs4Rlq45mdMb9k',
    appId: '1:363899757652:android:d6268f2e889f94ee2679c1',
    messagingSenderId: '363899757652',
    projectId: 'pawprint-9bc0f',
    storageBucket: 'pawprint-9bc0f.firebasestorage.app',
  );
}
