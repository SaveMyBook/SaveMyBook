import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../i18n/strings.dart';

class BiometricService {
  static const _enabledKey = 'biometric_login_enabled';

  static final LocalAuthentication _auth = LocalAuthentication();

  static bool _isEnabled = false;
  static bool get isEnabled => _isEnabled;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool(_enabledKey) ?? false;
  }

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

  static Future<({bool hardware, bool usable, bool faceId})> probe() async {
    try {
      final hardware = await _auth.canCheckBiometrics;
      final types = hardware ? await _auth.getAvailableBiometrics() : const <BiometricType>[];
      return (hardware: hardware, usable: types.isNotEmpty, faceId: types.contains(BiometricType.face));
    } catch (_) {
      return (hardware: false, usable: false, faceId: false);
    }
  }

  static Future<String> label() async {
    try {
      final types = await _auth.getAvailableBiometrics();
      if (types.contains(BiometricType.face)) return 'Face ID';
      if (types.contains(BiometricType.fingerprint)) return S.fingerprint;
      if (types.contains(BiometricType.iris)) return S.iris;
      return S.biometrics;
    } catch (_) {
      return S.biometrics;
    }
  }

  static Future<void> setEnabled(bool value) async {
    _isEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  static Future<bool> authenticate({String? reason, bool biometricOnly = false}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason ?? S.verifyIdentityContinue,
        options: AuthenticationOptions(
          stickyAuth: true,
          // 解鎖 App 要允許退回裝置密碼，否則沒設生物辨識的人會進不去；付款則由交易密碼當退路。
          biometricOnly: biometricOnly,
        ),
      );
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
