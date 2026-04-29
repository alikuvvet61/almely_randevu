import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
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
    apiKey: 'AIzaSyC55S5CY0E_WxTmwq-TvpF2Tp_yrBdrQb8',
    appId: '1:1013564598824:web:ae03d69dd700b7df86a31d',
    messagingSenderId: '1013564598824',
    projectId: 'almely-randevu',
    authDomain: 'almely-randevu.firebaseapp.com',
    storageBucket: 'almely-randevu.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDxHfuKhd_DHX0UFMBFDb92LSSDy9g90FQ',
    appId: '1:1013564598824:android:d8062a8fa901c1a386a31d',
    messagingSenderId: '1013564598824',
    projectId: 'almely-randevu',
    storageBucket: 'almely-randevu.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDxHfuKhd_DHX0UFMBFDb92LSSDy9g90FQ', // Genellikle Android ile aynıdır veya iOS için olanı eklenir
    appId: '1:1013564598824:ios:ae03d69dd700b7df86a31d', // Projenize göre güncellenmesi gerekebilir
    messagingSenderId: '1013564598824',
    projectId: 'almely-randevu',
    storageBucket: 'almely-randevu.firebasestorage.app',
    iosBundleId: 'com.example.almelyRandevu',
  );
}
