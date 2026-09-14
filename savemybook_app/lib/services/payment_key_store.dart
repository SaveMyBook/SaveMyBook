import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PaymentKeyStore {
  static const _storage = FlutterSecureStorage();
  static const _keyName = 'biometric_pay_key';
  static const _ownerName = 'biometric_pay_owner';

  static Future<String?> read(int userId) async {
    try {
      final owner = await _storage.read(key: _ownerName);
      if (owner != '$userId') return null;
      return await _storage.read(key: _keyName);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(int userId, String key) async {
    try {
      await _storage.write(key: _ownerName, value: '$userId');
      await _storage.write(key: _keyName, value: key);
    } catch (_) {}
  }

  static Future<void> clear() async {
    try {
      await _storage.delete(key: _keyName);
      await _storage.delete(key: _ownerName);
    } catch (_) {}
  }
}
