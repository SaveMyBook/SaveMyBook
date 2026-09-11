#!/usr/bin/env python3
"""從 lib/l10n/*.arb 產生 lib/l10n/app_localizations.dart。

不使用 Flutter 的 gen_l10n：它在 synthetic package 與輸出位置上的行為
隨版本變動，升級 Flutter 時很容易整個建置掛掉。這裡產生的是一份普通
的 Dart 檔，任何版本都能編譯。

改完 ARB 後執行：  python3 tool/gen_l10n.py
"""
import json, glob, os, re

ARB_DIR = 'lib/l10n'
OUT = os.path.join(ARB_DIR, 'app_localizations.dart')
TEMPLATE = 'zh'


def locale_expr(tag):
    if '_' in tag:
        lang, script = tag.split('_', 1)
        return f"Locale.fromSubtags(languageCode: '{lang}', scriptCode: '{script}')"
    return f"Locale('{tag}')"


def dart_string(value):
    escaped = value.replace('\\', '\\\\').replace("'", "\\'").replace('\n', '\\n').replace('$', '\\$')
    return f"'{escaped}'"


def main():
    files = {}
    for path in sorted(glob.glob(f'{ARB_DIR}/*.arb')):
        tag = re.search(r'app_(.+)\.arb$', path).group(1)
        files[tag] = json.load(open(path, encoding='utf-8'))

    if TEMPLATE not in files:
        raise SystemExit(f'找不到模板 app_{TEMPLATE}.arb')

    keys = [k for k in files[TEMPLATE] if not k.startswith('@')]

    # 缺 key 會在執行時變成空字串，寧可在這裡就擋下來。
    for tag, data in files.items():
        missing = [k for k in keys if k not in data]
        if missing:
            raise SystemExit(f'app_{tag}.arb 缺少 {len(missing)} 個 key：{missing[:5]}')

    lines = [
        '// 由 tool/gen_l10n.py 從 lib/l10n/*.arb 產生，請不要手動編輯。',
        '',
        "import 'package:flutter/widgets.dart';",
        '',
        'abstract class AppLocalizations {',
        '  const AppLocalizations();',
        '',
        '  static const LocalizationsDelegate<AppLocalizations> delegate =',
        '      _AppLocalizationsDelegate();',
        '',
        '  static AppLocalizations of(BuildContext context) =>',
        '      Localizations.of<AppLocalizations>(context, AppLocalizations)!;',
        '',
        '  static const List<Locale> supportedLocales = <Locale>[',
    ]
    for tag in files:
        lines.append(f'    {locale_expr(tag)},')
    lines += ['  ];', '']
    for key in keys:
        lines.append(f'  String get {key};')
    lines += ['}', '']

    for tag, data in files.items():
        cls = '_L' + ''.join(p.capitalize() for p in tag.split('_'))
        lines += [
            f'class {cls} extends AppLocalizations {{',
            f'  const {cls}();',
            '',
        ]
        for key in keys:
            lines.append('  @override')
            lines.append(f'  String get {key} => {dart_string(data[key])};')
            lines.append('')
        lines += ['}', '']

    lines += [
        'class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {',
        '  const _AppLocalizationsDelegate();',
        '',
        '  @override',
        '  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(',
        '        (l) => l.languageCode == locale.languageCode,',
        '      );',
        '',
        '  @override',
        '  Future<AppLocalizations> load(Locale locale) async {',
        '    switch (_tagOf(locale)) {',
    ]
    for tag in files:
        if tag == TEMPLATE:
            continue
        cls = '_L' + ''.join(p.capitalize() for p in tag.split('_'))
        lines.append(f"      case '{tag}':")
        lines.append(f'        return const {cls}();')
    default_cls = '_L' + TEMPLATE.capitalize()
    lines += [
        '      default:',
        f'        return const {default_cls}();',
        '    }',
        '  }',
        '',
        '  /// 帶書寫系統時優先比對完整標籤；沒有對應的變體才退回語言本身。',
        '  static String _tagOf(Locale locale) {',
        '    final script = locale.scriptCode;',
        '    if (script != null) {',
        "      final full = '${locale.languageCode}_$script';",
        '      if (AppLocalizations.supportedLocales.any(',
        '          (l) => l.scriptCode == script && l.languageCode == locale.languageCode)) {',
        '        return full;',
        '      }',
        '    }',
        '    return locale.languageCode;',
        '  }',
        '',
        '  @override',
        '  bool shouldReload(_AppLocalizationsDelegate old) => false;',
        '}',
        '',
    ]

    open(OUT, 'w', encoding='utf-8').write('\n'.join(lines))
    print(f'產生 {OUT}：{len(keys)} 個 key × {len(files)} 語')


if __name__ == '__main__':
    main()
