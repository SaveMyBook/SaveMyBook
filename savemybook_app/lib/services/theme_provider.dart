import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ValueNotifier<ThemeMode> {
  static const _key = 'theme_mode';

  ThemeProvider(super.value);

  static Future<ThemeProvider> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    ThemeMode mode;
    switch (saved) {
      case 'dark':
        mode = ThemeMode.dark;
        break;
      case 'light':
        mode = ThemeMode.light;
        break;
      default:
        mode = ThemeMode.system;
    }
    return ThemeProvider(mode);
  }

  Future<void> setMode(ThemeMode mode) async {
    value = mode;
    final prefs = await SharedPreferences.getInstance();
    switch (mode) {
      case ThemeMode.dark:
        await prefs.setString(_key, 'dark');
        break;
      case ThemeMode.light:
        await prefs.setString(_key, 'light');
        break;
      case ThemeMode.system:
        await prefs.remove(_key);
        break;
    }
  }

  Future<void> toggle() async {
    await setMode(value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }

  bool isDark(BuildContext context) {
    if (value == ThemeMode.system) {
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
    return value == ThemeMode.dark;
  }
}

late final ThemeProvider themeProvider;