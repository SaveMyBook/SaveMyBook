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
SKIP = ('lib/i18n/',)

STOP = {'the','a','an','to','of','is','are','and','or','for','in','on','at','your','you','this','that','it','be','will','has','have'}


def load_table():
    table = {}
    for path in sorted(glob.glob('tool/i18n_table/*.py')):
        spec = importlib.util.spec_from_file_location('t', path)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        table.update(mod.T)
    return table


# Dart 保留字不能當成員名。撞到就往前補 action，讓產生器直接爆掉比編譯期才炸好。
RESERVED = {
    'assert', 'break', 'case', 'catch', 'class', 'const', 'continue', 'default', 'do', 'else',
    'enum', 'extends', 'false', 'final', 'finally', 'for', 'if', 'in', 'is', 'new', 'null',
    'rethrow', 'return', 'super', 'switch', 'this', 'throw', 'true', 'try', 'var', 'void',
    'while', 'with', 'hashCode', 'toString', 'runtimeType', 'noSuchMethod',
}


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
    if key in RESERVED:
        key = 'action' + key[0].upper() + key[1:]
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


def bracket_stack(src, pos):
    """由內而外列出 pos 所在的未關閉括號 [(字元, 位置), ...]。"""
    stack, depth, i = [], 0, pos
    while i > 0:
        ch = src[i]
        if ch in ')]}':
            depth += 1
        elif ch in '([{':
            if depth == 0:
                stack.append((ch, i))
            else:
                depth -= 1
        i -= 1
    return stack


def statement_head(src, pos):
    """往回取到本句開頭（上一個 ; { } 之後）。"""
    start = max(src.rfind(c, 0, pos) for c in ';{}')
    return src[start + 1:pos]


# const 宣告不必緊貼字串——'static const _x = [(a: 1, label: '中文')]' 的
# 字串離 = 還隔了好幾層，所以整句都要找。
CONST_DECL = re.compile(r'(?:^|[\s;{}])(?:static\s+)?const\s+[\w<>,\[\]() ]*\w+\s*=')


def skip_reason(raw, masked, start, end):
    """回傳不該搬動這條字串的理由，可以搬則回 None。

    這四種位置都要求編譯期常數（或會把前綴吃掉），搬進去一定編不過，
    上一輪就是踩在這裡：預設參數值、switch case、const 宣告、raw string。
    """
    if start > 0 and raw[start - 1] == 'r':
        return 'raw string'

    # 相鄰字串常值會自動併接（'前半' '後半'）。拆開來各自換成 S.x 之後
    # 中間少了運算子，語法直接壞掉——上一輪的 cart_screen 就是這樣炸的。
    if re.search(r"'\s*$", masked[:start]) or re.match(r"\s*'", masked[end:]):
        return '相鄰字串併接'

    # 插值裡若含引號（如 ${a.join('、')}），正則會在那個引號處收尾，
    # 切出半截字串。大括號數量對不上就是被切斷了。
    text = raw[start + 1:end - 1]
    if text.count('${') != text.count('}'):
        return '插值被切斷'

    head = statement_head(masked, start)
    if re.search(r'\bcase\s*$', head):
        return 'switch case'

    stack = bracket_stack(masked, start)

    # const 宣告可能隔著好幾層括號（static const x = <String, String>{ 'k': '中文' }）。
    # statement_head 會停在最近的 { ，所以每一層括號的開頭都要回頭看一次。
    for pos in [start] + [b for _, b in stack]:
        if CONST_DECL.search(statement_head(masked, pos)):
            return 'const 宣告'

    if stack and stack[0][0] == '{' and re.search(r'=\s*$', head):
        # 具名參數的 { 前面緊接著 (；方法主體的 { 前面是 )
        before = masked[:stack[0][1]].rstrip()
        if before.endswith('('):
            return '預設參數值'
    return None


# Dart 的識別字只有 ASCII。用 Python 的 \w 會連後面的中文一起吃掉，
# '$action書櫃' 會變成變數名 action書櫃，中文也從譯文裡消失。
INTERP = re.compile(r'\$\{([^}]*)\}|\$([A-Za-z_][A-Za-z0-9_]*)')


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
    rows, skipped = [], []
    for f in sorted(glob.glob('lib/**/*.dart', recursive=True)):
        if any(f.startswith(s) or f == s for s in SKIP):
            continue
        raw = open(f, encoding='utf-8').read()
        src = mask(raw)
        for m in re.finditer(r"'((?:[^'\\\n]|\\.)*[一-鿿](?:[^'\\\n]|\\.)*)'", src):
            reason = skip_reason(raw, src, m.start(), m.end())
            if reason:
                skipped.append((f, raw.count('\n', 0, m.start()) + 1, m.group(1), reason))
                continue
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

    if skipped:
        print(f'跳過 {len(skipped)} 處（需要編譯期常數或會吃掉前綴，得手動處理）：')
        for f, line, text, reason in skipped:
            print(f'   [{reason}] {f}:{line}  {text[:40]}')
        print()

    if '--report' in sys.argv:
        print(f'可搬動 {len(rows)} 處／{len(texts)} 條不重複')
        print(f'其中沒有譯文的有 {len(missing)} 條：')
        for t in missing:
            print('   ', t)
        return 0

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
