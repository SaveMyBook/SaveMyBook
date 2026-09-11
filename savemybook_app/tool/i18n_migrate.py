#!/usr/bin/env python3
"""把原始碼裡的中文字串換成 S.<key>，並把譯文寫進 lib/i18n/*.arb。

翻譯表在 tool/i18n_table/*.py，格式：
    T = { '中文': ('English', '日本語', '한국어', '简体') , ... }

key 由英文譯文推導成 camelCase，所以原始碼裡看到的是 S.deleteAccount
而不是流水號。含 $ 插值的字串會產生帶參數的方法。
"""
import re, os, glob, json, sys, importlib.util, collections

ARB_DIR = 'lib/i18n'
LOCALES = ['zh', 'zh_Hant', 'en', 'ja', 'ko', 'zh_Hans']
SKIP = ('lib/i18n/', 'lib/utils/app_labels.dart')

STOP = {'the','a','an','to','of','is','are','and','or','for','in','on','at','your','you','this','that','it','be','will','has','have'}


def load_table():
    table = {}
    for path in sorted(glob.glob('tool/i18n_table/*.py')):
        spec = importlib.util.spec_from_file_location('t', path)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        table.update(mod.T)
    return table


def key_from_en(en, used):
    words = re.findall(r"[A-Za-z0-9]+", en)
    words = [w for w in words if w.lower() not in STOP] or words
    if not words:
        words = ['msg']
    head = words[0].lower()
    key = head + ''.join(w.capitalize() for w in words[1:6])
    key = re.sub(r'[^A-Za-z0-9]', '', key)
    if not key or key[0].isdigit():
        key = 'k' + key
    base, n = key, 2
    while key in used:
        key = f'{base}{n}'; n += 1
    used.add(key)
    return key


def mask(src):
    out, i, n = [], 0, len(src)
    while i < n:
        if src[i] == '/' and src[i+1:i+2] == '/':
            j = src.find('\n', i); j = n if j < 0 else j
            out.append(' ' * (j - i)); i = j; continue
        if src[i] == '/' and src[i+1:i+2] == '*':
            j = src.find('*/', i) + 2
            out.append(' ' * (j - i)); i = j; continue
        out.append(src[i]); i += 1
    return ''.join(out)


def enclosing_const(src, pos):
    """回傳最近一個未關閉的 const 關鍵字位置，沒有則 None。"""
    depth, i = 0, pos
    while i > 0:
        ch = src[i]
        if ch in ')]}':
            depth += 1
        elif ch in '([{':
            if depth == 0:
                head = src[max(0, i - 260):i]
                m = re.search(r'\bconst\b(\s+[\w.<>, ]*)?$', head)
                if m:
                    return max(0, i - 260) + m.start()
                i -= 1
                continue
            depth -= 1
        i -= 1
    return None


INTERP = re.compile(r'\$\{([^}]*)\}|\$(\w+)')


def unescape(text):
    """原始碼裡的 \\n 是換行，ARB 要存真正的換行。"""
    return text.replace('\\n', '\n').replace("\\'", "'").replace('\\\\', '\\')


def split_interp(text):
    """把 '還有 $days 天' 拆成 ('還有 {p0} 天', ['days'])"""
    parts, args, last = [], [], 0
    for m in INTERP.finditer(text):
        parts.append(text[last:m.start()])
        parts.append('{p%d}' % len(args))
        args.append(m.group(1) if m.group(1) is not None else m.group(2))
        last = m.end()
    parts.append(text[last:])
    return ''.join(parts), args


def main():
    table = load_table()
    arb = {loc: json.load(open(f'{ARB_DIR}/app_{loc}.arb', encoding='utf-8')) for loc in LOCALES}
    existing = {v: k for k, v in arb['zh'].items() if not k.startswith('@')}
    used = set(arb['zh'].keys())

    # 蒐集所有出現處
    rows = []
    for f in sorted(glob.glob('lib/**/*.dart', recursive=True)):
        if any(f.startswith(s) or f == s for s in SKIP):
            continue
        raw = open(f, encoding='utf-8').read()
        src = mask(raw)
        for m in re.finditer(r"'((?:[^'\\\n]|\\.)*[一-鿿](?:[^'\\\n]|\\.)*)'", src):
            rows.append({'file': f, 'start': m.start(), 'end': m.end(), 'text': m.group(1)})

    texts = list(collections.OrderedDict((r['text'], None) for r in rows))
    key_of, missing = {}, []
    for t in texts:
        if t in existing:
            key_of[t] = existing[t]
        elif t in table:
            key_of[t] = key_from_en(table[t][0], used)
        else:
            missing.append(t)

    if '--strict' in sys.argv and missing:
        print(f'還有 {len(missing)} 條沒有翻譯，前 10 條：')
        for t in missing[:10]:
            print('   ', t)
        return 1

    # 寫 ARB
    for t, key in key_of.items():
        if t in existing:
            continue
        en, ja, ko, hans = table[t]
        pattern_zh, args = split_interp(t)
        vals = {'zh': unescape(pattern_zh), 'zh_Hant': unescape(pattern_zh),
                'en': unescape(split_interp(en)[0] if '$' in en else en),
                'ja': unescape(split_interp(ja)[0] if '$' in ja else ja),
                'ko': unescape(split_interp(ko)[0] if '$' in ko else ko),
                'zh_Hans': unescape(split_interp(hans)[0] if '$' in hans else hans)}
        for loc in LOCALES:
            arb[loc][key] = vals[loc]
            if args:
                arb[loc]['@' + key] = {'placeholders': {f'p{i}': {} for i in range(len(args))}}

    for loc in LOCALES:
        with open(f'{ARB_DIR}/app_{loc}.arb', 'w', encoding='utf-8') as fh:
            json.dump(arb[loc], fh, ensure_ascii=False, indent=2)
            fh.write('\n')

    # 改寫原始碼：由後往前，位移才不會跑掉
    by_file = collections.defaultdict(list)
    for r in rows:
        if r['text'] in key_of:
            by_file[r['file']].append(r)

    changed = 0
    const_removed = 0
    for f, items in by_file.items():
        raw = open(f, encoding='utf-8').read()
        masked = mask(raw)
        const_spots = set()
        for r in items:
            c = enclosing_const(masked, r['start'])
            if c is not None:
                const_spots.add(c)

        edits = [(r['start'], r['end'], r) for r in items]
        # const 關鍵字也要移除，一起排序處理
        for c in const_spots:
            m = re.match(r'const\b\s*', raw[c:])
            if m:
                edits.append((c, c + m.end(), None))
                const_removed += 1

        for start, end, r in sorted(edits, key=lambda e: -e[0]):
            if r is None:
                raw = raw[:start] + raw[end:]
                continue
            key = key_of[r['text']]
            _, args = split_interp(r['text'])
            call = f'S.{key}' if not args else f'S.{key}({", ".join(args)})'
            raw = raw[:start] + call + raw[end:]
            changed += 1

        if 'i18n/strings.dart' not in raw:
            # lib/a/b.dart 要退回 lib/ 需要 1 層；lib/main.dart 則是 0 層
            rel = '../' * (f.count('/') - 1) + 'i18n/strings.dart'
            ms = list(re.finditer(r"^import '[^']+';$", raw, re.M))
            if ms:
                raw = raw[:ms[-1].end()] + f"\nimport '{rel}';" + raw[ms[-1].end():]
        open(f, 'w', encoding='utf-8').write(raw)

    print(f'已替換 {changed} 處，移除 {const_removed} 個 const，涉及 {len(by_file)} 個檔案')
    print(f'尚未翻譯 {len(missing)} 條（保持原樣）')
    return 0


if __name__ == '__main__':
    sys.exit(main())
