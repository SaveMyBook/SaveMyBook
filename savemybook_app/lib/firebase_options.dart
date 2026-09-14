import 'package:firebase_core/firebase_core.dart';

/// 由 tool/firebase_setup.py 讀取 firebase/ 資料夾裡的設定檔產生，不要手動修改。
///
/// 還沒放設定檔時回傳 null，App 會停用推播，其他功能照常。
class DefaultFirebaseOptions {
  static FirebaseOptions? get currentPlatform => null;
}
