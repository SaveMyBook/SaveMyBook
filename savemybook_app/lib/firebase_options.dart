import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// 由 tool/firebase_setup.py 讀取 firebase/ 資料夾裡的設定檔產生，不要手動修改。
class DefaultFirebaseOptions {
  static FirebaseOptions? get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.android:
        return android;
      default:
        return null;
    }
  }

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCoYusNaMTbUUeusMx9YnrZAH9LwwJzOQI',
    appId: '1:385756357856:ios:a2a1efc482591ab5739c85',
    messagingSenderId: '385756357856',
    projectId: 'savemybook',
    storageBucket: 'savemybook.firebasestorage.app',
    iosBundleId: 'today.savemybook.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCPTfeG_yipmakEeCUOmloez9sKwdW9nmo',
    appId: '1:385756357856:android:b8c48bdd8890dc3c739c85',
    messagingSenderId: '385756357856',
    projectId: 'savemybook',
    storageBucket: 'savemybook.firebasestorage.app',
  );
}
