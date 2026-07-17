// File generated for the SeeNet Firebase project (seenet-3fdb2).
// Values pulled from android/app/google-services.json,
// ios/Runner/GoogleService-Info.plist and `firebase apps:sdkconfig WEB`.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCEDz4kn7nM9QoSaeZJncxRoFXV00R6ubc',
    appId: '1:877316843670:web:4926ee87656ca6d3cefab7',
    messagingSenderId: '877316843670',
    projectId: 'seenet-3fdb2',
    authDomain: 'seenet-3fdb2.firebaseapp.com',
    storageBucket: 'seenet-3fdb2.firebasestorage.app',
    measurementId: 'G-8Z254JJ7S0',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyACbTjhb14bM5D6k148FFdhTCOS0h-sUl4',
    appId: '1:877316843670:android:71078a3bcbd4bd78cefab7',
    messagingSenderId: '877316843670',
    projectId: 'seenet-3fdb2',
    storageBucket: 'seenet-3fdb2.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDxCHrOyBK00meZga6KN3PHjr9H5FpOCwA',
    appId: '1:877316843670:ios:6563773228bb8451cefab7',
    messagingSenderId: '877316843670',
    projectId: 'seenet-3fdb2',
    storageBucket: 'seenet-3fdb2.firebasestorage.app',
    iosBundleId: 'com.seenet.diagnostico',
  );
}
