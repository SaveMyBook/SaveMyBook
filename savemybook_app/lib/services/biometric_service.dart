import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Face ID／指紋快速登入。
///
/// Token 本來就存在本機，這裡做的是「開啟 App 時用生物辨識解鎖」，
/// 而不是把密碼另外存起來。
class BiometricService {
  static const _enabledKey = 'biometric_login_enabled';

  static final LocalAuthentication _auth = LocalAuthentication();

  static bool _isEnabled = false;
  static bool get isEnabled => _isEnabled;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool(_enabledKey) ?? false;
  }

  /// 裝置有沒有可用的生物辨識（或至少有螢幕鎖）。
  static Future<bool> isAvailable() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      return await _auth.canCheckBiometrics ||
          (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// 回傳裝置主要支援的辨識方式，用來決定按鈕文字。
  static Future<String> label() async {
    try {
      final types = await _auth.getAvailableBiometrics();
      if (types.contains(BiometricType.face)) return 'Face ID';
      if (types.contains(BiometricType.fingerprint)) return '指紋';
      if (types.contains(BiometricType.iris)) return '虹膜';
      return '生物辨識';
    } catch (_) {
      return '生物辨識';
    }
  }

  static Future<void> setEnabled(bool value) async {
    _isEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  /// 跳出系統的辨識畫面。使用者取消或失敗都回 false。
  static Future<bool> authenticate({String reason = '請驗證身分以繼續'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          // 允許退回裝置密碼，不然沒設生物辨識的人會完全進不去。
          biometricOnly: false,
        ),
      );
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
