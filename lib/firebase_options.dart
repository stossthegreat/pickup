// Hand-generated Firebase options. The standard FlutterFire CLI
// output, recreated here so we don't need to run the CLI inside the
// remote dev box. Values pulled from:
//   ios/Runner/GoogleService-Info.plist
//   android/app/google-services.json
//
// Wired into Firebase.initializeApp(options: DefaultFirebaseOptions
// .currentPlatform) in analytics_service.dart — that's the path that
// actually works without the iOS plist being registered as a bundled
// resource in the Xcode project.

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
    apiKey:            'AIzaSyBhh92Jk2g8zuuQDvZxGLImcM497e8jNtM',
    appId:             '1:826053971859:ios:1737c2df07e4c84d85a266',
    messagingSenderId: '826053971859',
    projectId:         'imhim-75991',
    storageBucket:     'imhim-75991.firebasestorage.app',
    iosBundleId:       'com.imhim.app',
  );

  static const _android = FirebaseOptions(
    apiKey:            'AIzaSyBJDHSki94CSv_vkOb9yGkBldRBfLtlFDU',
    appId:             '1:826053971859:android:c0ff8bb707e3f4c485a266',
    messagingSenderId: '826053971859',
    projectId:         'imhim-75991',
    storageBucket:     'imhim-75991.firebasestorage.app',
  );
}
