import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Android options from `android/app/google-services.json` (pathwise-aedc5).
/// Run `flutterfire configure` to regenerate for all platforms.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Web FirebaseOptions not configured. Run flutterfire configure.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'iOS FirebaseOptions not configured. Run flutterfire configure.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBYstC9FSwCssYIcZEoiLm3yHogd0BdhSQ',
    appId: '1:477245821723:android:fd5c0b6a463dff1f61b9be',
    messagingSenderId: '477245821723',
    projectId: 'pathwise-aedc5',
    storageBucket: 'pathwise-aedc5.firebasestorage.app',
  );
}
