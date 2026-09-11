import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 介面語言。null 代表跟隨系統。
class LocaleProvider extends ValueNotifier<Locale?> {
  static const _key = 'app_locale';

  LocaleProvider(super.value);

  /// 支援的語言。順序即語言選單的顯示順序。
  static const supported = <Locale>[
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    Locale('en'),
    Locale('ja'),
    Locale('ko'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
  ];

  /// 各語言用自己的文字標示，使用者看不懂目前語言時才找得到自己的。
  /// 正因如此這裡刻意不翻譯——翻了就違背這份清單存在的目的。
  static const nativeNames = <String, String>{
    'zh_Hant': '繁體中文',
    'en': 'English',
    'ja': '日本語',
    'ko': '한국어',
    'zh_Hans': '简体中文',
  };

  static String tagOf(Locale locale) =>
      locale.scriptCode == null ? locale.languageCode : '${locale.languageCode}_${locale.scriptCode}';

  static String nameOf(Locale? locale) =>
      locale == null ? '' : (nativeNames[tagOf(locale)] ?? locale.languageCode);

  static Future<LocaleProvider> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved == null || saved.isEmpty) return LocaleProvider(null);

    final match = supported.where((l) => tagOf(l) == saved);
    return LocaleProvider(match.isEmpty ? null : match.first);
  }

  Future<void> setLocale(Locale? locale) async {
    value = locale;
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, tagOf(locale));
    }
  }

  /// 系統語言不在支援清單時要落到哪一個。
  ///
  /// 預設的 basicLocaleListResolution 在 zh-Hant 與 zh-Hans 之間常常挑錯，
  /// 因為它只比對 languageCode。這裡先自己比對 script。
  static Locale resolve(List<Locale>? deviceLocales, Iterable<Locale> _) {
    for (final device in deviceLocales ?? const <Locale>[]) {
      for (final candidate in supported) {
        if (candidate.languageCode != device.languageCode) continue;
        if (candidate.languageCode != 'zh') return candidate;
        // 中文再看書寫系統；沒帶 script 時用地區推斷。
        final script = device.scriptCode ??
            (const ['TW', 'HK', 'MO'].contains(device.countryCode) ? 'Hant' : 'Hans');
        if (candidate.scriptCode == script) return candidate;
      }
    }
    return supported.first;
  }
}

late LocaleProvider localeProvider;
