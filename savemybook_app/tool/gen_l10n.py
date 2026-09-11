#!/usr/bin/env python3
"""從 lib/i18n/*.arb 產生 lib/i18n/app_localizations.dart。

不使用 Flutter 的 gen_l10n：它在 synthetic package 與輸出位置上的行為
隨版本變動，升級 Flutter 時很容易整個建置掛掉。這裡產生的是一份普通
的 Dart 檔，任何版本都能編譯。

放在 lib/i18n 而不是 lib/l10n：後者是 Flutter 工具鏈預設的產出目錄，
即使關掉 generate 旗標，flutter pub get 仍會清掉它認得的檔名。

改完 ARB 後執行：  python3 tool/gen_l10n.py
"""
import json, glob, os, re

ARB_DIR = 'lib/i18n'
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


# Dart 保留字不能當成員名。撞到就往前補 action，讓產生器直接爆掉比編譯期才炸好。
RESERVED = {
    'assert', 'break', 'case', 'catch', 'class', 'const', 'continue', 'default', 'do', 'else',
    'enum', 'extends', 'false', 'final', 'finally', 'for', 'if', 'in', 'is', 'new', 'null',
    'rethrow', 'return', 'super', 'switch', 'this', 'throw', 'true', 'try', 'var', 'void',
    'while', 'with', 'hashCode', 'toString', 'runtimeType', 'noSuchMethod',
}


def main():
    files = {}
    for path in sorted(glob.glob(f'{ARB_DIR}/*.arb')):
        tag = re.search(r'app_(.+)\.arb$', path).group(1)
        files[tag] = json.load(open(path, encoding='utf-8'))

    if TEMPLATE not in files:
        raise SystemExit(f'找不到模板 app_{TEMPLATE}.arb')

    keys = [k for k in files[TEMPLATE] if not k.startswith('@')]
    bad = sorted(k for k in keys if k in RESERVED)
    if bad:
        raise SystemExit(f'key 撞到 Dart 保留字，請改名：{bad}')

    # @key 的 placeholders 決定它是 getter 還是帶參數的方法
    params = {}
    for key in keys:
        meta = files[TEMPLATE].get('@' + key) or {}
        names = sorted((meta.get('placeholders') or {}).keys())
        if names:
            params[key] = names

    def signature(key):
        names = params.get(key)
        if not names:
            return f'String get {key}'
        args = ', '.join(f'Object {n}' for n in names)
        return f'String {key}({args})'

    def body(key, value):
        names = params.get(key)
        text = value
        if names:
            # ARB 的 {p0} 換成 Dart 的 $p0
            for n in names:
                text = text.replace('{' + n + '}', '\x00' + n + '\x00')
        out = dart_string(text)
        if names:
            for n in names:
                out = out.replace('\x00' + n + '\x00', '${' + n + '}')
        return out

    # 缺 key 會在執行時變成空字串，寧可在這裡就擋下來。
    for tag, data in files.items():
        missing = [k for k in keys if k not in data]
        if missing:
            raise SystemExit(f'app_{tag}.arb 缺少 {len(missing)} 個 key：{missing[:5]}')

    lines = [
        '// 由 tool/gen_l10n.py 從 lib/i18n/*.arb 產生，請不要手動編輯。',
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
        '  /// 還沒有 Localizations 可用時的預設值，讓 S 永遠有值。',
        f'  static const AppLocalizations fallback = _L{TEMPLATE.capitalize()}();',
        '',
        '  static const List<Locale> supportedLocales = <Locale>[',
    ]
    for tag in files:
        lines.append(f'    {locale_expr(tag)},')
    lines += ['  ];', '']
    for key in keys:
        lines.append(f'  {signature(key)};')
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
            lines.append(f'  {signature(key)} => {body(key, data[key])};')
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
