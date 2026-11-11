
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;


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
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError('DefaultFirebaseOptions are not supported for this platform.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBjFzazWErnjxxH5z_TwdwynN3paNvRhSI',
    appId: '1:1025085588389:web:4194894a6c461861589e4c',
    messagingSenderId: '1025085588389',
    projectId: 'myabahtartlejen',
    authDomain: 'myabahtartlejen.firebaseapp.com',
    storageBucket: 'myabahtartlejen.firebasestorage.app',
    measurementId: 'G-FJH4TTHYBW',
  );                                                                                                                                      

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDaB2m0UeTPdV53xbcDh6ZyZc7Qi7k62u0',
    appId: '1:1025085588389:android:a7e00108bd88ec12589e4c',
    messagingSenderId: '1025085588389',
    projectId: 'myabahtartlejen',
    storageBucket: 'myabahta3rtlejen.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA1zRWPnNi_CDtySTMrrsvsbMVBtAZkeok',
    appId: '1:1025085588389:ios:91754087951a9d0e589e4c',
    messagingSenderId: '1025085588389',
    projectId: 'myabahtartlejen',
    storageBucket: 'myabahtartlejen.firebasestorage.app',
    iosBundleId: 'com.example.myabahtartlejen',
  );
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyA1zRWPnNi_CDtySTMrrsvsbMVBtAZkeok',
    appId: '1:1025085588389:ios:91754087951a9d0e589e4c',
    messagingSenderId: '1025085588389',
    projectId: 'myabahtartlejen',
    storageBucket: 'myabahtartlejen.firebasestorage.app',
    iosBundleId: 'com.example.myabahtartlejen',
  );
  static const FirebaseOptions windows = FirebaseOptions(

    apiKey: 'AIzaSyBjFzazWErnjxxH5z_TwdwynN3paNvRhSI',
    appId: '1:1025085588389:web:4194894a6c461861589e4c',
    messagingSenderId: '1025085588389',
    projectId: 'myabahtartlejen',
    authDomain: 'myabahtartlejen.firebaseapp.com',
    storageBucket: 'myabahtartlejen.firebasestorage.app',
    measurementId: 'G-FJH4TTHYBW',


  );
}
