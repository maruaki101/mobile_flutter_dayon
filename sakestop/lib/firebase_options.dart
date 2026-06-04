// File generated based on Firebase console configuration.
// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBcBhWoMcGVcN6LsmgRcXRqeRFYJDpTeRE',
    appId: '1:1021590107540:web:0769fc1de203503771cb81',
    messagingSenderId: '1021590107540',
    projectId: 'sakestop-4ca0c',
    authDomain: 'sakestop-4ca0c.firebaseapp.com',
    storageBucket: 'sakestop-4ca0c.firebasestorage.app',
    databaseURL: 'https://sakestop-4ca0c-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBcBhWoMcGVcN6LsmgRcXRqeRFYJDpTeRE',
    appId: '1:1021590107540:web:0769fc1de203503771cb81',
    messagingSenderId: '1021590107540',
    projectId: 'sakestop-4ca0c',
    storageBucket: 'sakestop-4ca0c.firebasestorage.app',
    databaseURL: 'https://sakestop-4ca0c-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBcBhWoMcGVcN6LsmgRcXRqeRFYJDpTeRE',
    appId: '1:1021590107540:web:0769fc1de203503771cb81',
    messagingSenderId: '1021590107540',
    projectId: 'sakestop-4ca0c',
    authDomain: 'sakestop-4ca0c.firebaseapp.com',
    storageBucket: 'sakestop-4ca0c.firebasestorage.app',
    databaseURL: 'https://sakestop-4ca0c-default-rtdb.asia-southeast1.firebasedatabase.app',
  );
}
