import 'dart:io';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceIdentity {
  static const _idKey = 'device_install_id';

  static String? _id;
  static String? _name;

  static String get platform => Platform.isIOS ? 'ios' : Platform.isAndroid ? 'android' : Platform.operatingSystem;

  static Future<String> id() async {
    if (_id != null) return _id!;
    final prefs = await SharedPreferences.getInstance();
    var value = prefs.getString(_idKey);
    if (value == null || value.length < 16) {
      final rng = Random.secure();
      value = List.generate(24, (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      await prefs.setString(_idKey, value);
    }
    return _id = value;
  }

  static Future<String> name() async {
    if (_name != null) return _name!;
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isIOS) {
        final ios = await info.iosInfo;
        _name = ios.utsname.machine.isNotEmpty ? _appleModelName(ios.utsname.machine, ios.model) : ios.model;
      } else if (Platform.isAndroid) {
        final android = await info.androidInfo;
        final brand = android.manufacturer.isEmpty ? '' : '${android.manufacturer[0].toUpperCase()}${android.manufacturer.substring(1)} ';
        _name = '$brand${android.model}'.trim();
      }
    } catch (_) {}
    return _name ??= platform;
  }

  static Future<Map<String, String>> describe() async => {
        'device_id': await id(),
        'device_name': await name(),
        'platform': platform,
      };

  static String _appleModelName(String machine, String fallback) {
    const names = {
      'iPhone14,4': 'iPhone 13 mini', 'iPhone14,5': 'iPhone 13', 'iPhone14,2': 'iPhone 13 Pro', 'iPhone14,3': 'iPhone 13 Pro Max',
      'iPhone14,6': 'iPhone SE (3rd generation)', 'iPhone14,7': 'iPhone 14', 'iPhone14,8': 'iPhone 14 Plus',
      'iPhone15,2': 'iPhone 14 Pro', 'iPhone15,3': 'iPhone 14 Pro Max', 'iPhone15,4': 'iPhone 15', 'iPhone15,5': 'iPhone 15 Plus',
      'iPhone16,1': 'iPhone 15 Pro', 'iPhone16,2': 'iPhone 15 Pro Max', 'iPhone17,3': 'iPhone 16', 'iPhone17,4': 'iPhone 16 Plus',
      'iPhone17,1': 'iPhone 16 Pro', 'iPhone17,2': 'iPhone 16 Pro Max', 'iPhone17,5': 'iPhone 16e',
      'iPhone18,1': 'iPhone 17 Pro', 'iPhone18,2': 'iPhone 17 Pro Max', 'iPhone18,3': 'iPhone 17', 'iPhone18,4': 'iPhone Air',
    };
    if (names.containsKey(machine)) return names[machine]!;
    if (machine.startsWith('iPad')) return 'iPad';
    if (machine == 'x86_64' || machine == 'arm64') return '$fallback (Simulator)';
    return fallback;
  }
}
