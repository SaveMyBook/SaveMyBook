import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePreferences {
  const HomePreferences._();

  static const _discoveryKey = 'home_show_discovery';

  static final ValueNotifier<bool> showDiscovery = ValueNotifier<bool>(true);

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      showDiscovery.value = prefs.getBool(_discoveryKey) ?? true;
    } catch (_) {}
  }

  static Future<void> setShowDiscovery(bool value) async {
    showDiscovery.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_discoveryKey, value);
    } catch (_) {}
  }
}
