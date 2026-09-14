import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPalette {
  final String id;
  final Color primary;

  const AppPalette(this.id, this.primary);

  Color _shift(double lightness, {double saturation = 0}) {
    final hsl = HSLColor.fromColor(primary);
    return hsl
        .withLightness((hsl.lightness + lightness).clamp(0.0, 1.0))
        .withSaturation((hsl.saturation + saturation).clamp(0.0, 1.0))
        .toColor();
  }

  Color get primaryDark => _shift(0.2, saturation: -0.05);
  Color get headerDark => _shift(-0.27, saturation: -0.1);
  Color get bubbleDark => _shift(-0.12, saturation: -0.08);

  static const all = <AppPalette>[
    AppPalette('mist', Color(0xFF627D8D)),
    AppPalette('forest', Color(0xFF4F7A63)),
    AppPalette('ocean', Color(0xFF3E6A9E)),
    AppPalette('lavender', Color(0xFF75689C)),
    AppPalette('terracotta', Color(0xFFA45F4B)),
    AppPalette('amber', Color(0xFFA7792C)),
    AppPalette('rose', Color(0xFF9E5A76)),
    AppPalette('graphite', Color(0xFF4B5563)),
  ];

  static AppPalette byId(String? id) => all.firstWhere((p) => p.id == id, orElse: () => all.first);
}

class PaletteProvider extends ValueNotifier<AppPalette> {
  static const _key = 'theme_palette';

  PaletteProvider(super.value);

  static Future<PaletteProvider> init() async {
    final prefs = await SharedPreferences.getInstance();
    return PaletteProvider(AppPalette.byId(prefs.getString(_key)));
  }

  Future<void> select(AppPalette palette) async {
    value = palette;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, palette.id);
  }
}

PaletteProvider paletteProvider = PaletteProvider(AppPalette.all.first);
