// Hand-generated Firebase options. The standard FlutterFire CLI
// output, recreated here so we don't need to run the CLI inside the
// remote dev box. Values pulled from:
//   ios/Runner/GoogleService-Info.plist
//   android/app/google-services.json
//
// Wired into Firebase.initializeApp(options: DefaultFirebaseOptions
// .currentPlatform) in analytics_service.dart — that's the path that
// actually works without the iOS plist being registered as a bundled
// resource in the Xcode project. Which is exactly why the values below
// matter more than the two config files: THIS is what ships.
//
// ── PROJECT imhimrizz-cb182 (94590135779) ───────────────────────────
//
// Replaces imhim-75991, which had the iOS app registered under bundle
// id `com.imhim.app`. That bundle does not exist — the iOS target is
// and always was `com.imhimrizz.app` (see PRODUCT_BUNDLE_IDENTIFIER in
// project.pbxproj). So every iOS analytics event was being reported
// against an app registration that could never match a real install,
// and the numbers were dead for reasons no dashboard would explain.
//
// Android was fine on the old project — `com.imhim.app` is correct
// there and always has been. Only iOS was mis-registered.
//
// Both apps are now registered correctly in the new project:
//   android  com.imhim.app
//   ios      com.imhimrizz.app

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Web is not configured for ImHim Firebase. '
        'Drop in web options if/when a web build ships.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return _ios;
      case TargetPlatform.android:
        return _android;
      default:
        throw UnsupportedError(
          'ImHim Firebase is only configured for iOS + Android.',
        );
    }
  }

  static const _ios = FirebaseOptions(
    apiKey:            'AIzaSyBE-yQXmp6i26XPwE06Pyuy8ctPV5sMeoM',
    appId:             '1:94590135779:ios:052443ec916b79fab584d6',
    messagingSenderId: '94590135779',
    projectId:         'imhimrizz-cb182',
    storageBucket:     'imhimrizz-cb182.firebasestorage.app',
    // The one that was wrong. Must match PRODUCT_BUNDLE_IDENTIFIER.
    iosBundleId:       'com.imhimrizz.app',
  );

  static const _android = FirebaseOptions(
    apiKey:            'AIzaSyCtF-lM3TGwBJB-EpJ8QjELKV_cReVVOGk',
    appId:             '1:94590135779:android:daaa4e4145dbb29ab584d6',
    messagingSenderId: '94590135779',
    projectId:         'imhimrizz-cb182',
    storageBucket:     'imhimrizz-cb182.firebasestorage.app',
  );
}
