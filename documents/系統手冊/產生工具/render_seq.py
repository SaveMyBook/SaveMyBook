"""循序圖改以 SVG 轉 PNG：訊息文字與片段條件移到最上層並墊白底，生命線與啟動框線條不再穿過文字。
PNG 內嵌與 PlantUML 相同之 iTXt「plantuml」原始碼，供 selfcheck 比對。"""
import html, os, re, subprocess, sys, tempfile
from PIL import Image, PngImagePlugin

HERE = os.path.dirname(os.path.abspath(__file__))
JAR = os.path.join(HERE, 'plantuml.jar')
TEXT = re.compile(r'<text\b[^>]*>.*?</text>', re.S)


def _attr(tag, name):
    m = re.search(rf'\b{name}="([^"]*)"', tag)
    return float(m.group(1)) if m else None


def _box(text_el):
    x, y = _attr(text_el, 'x'), _attr(text_el, 'y')
    fs = _attr(text_el, 'font-size') or 13
    w = _attr(text_el, 'textLength') or 0
    return (f'<rect fill="#FFFFFF" height="{fs * 1.3:.2f}" style="stroke:none;" width="{w + fs * 0.5:.2f}" '
            f'x="{x - fs * 0.25:.2f}" y="{y - fs * 1.02:.2f}" data-shield="1"/>')


KEYWORDS = {'alt', 'else', 'opt', 'loop', 'par', 'break', 'critical', 'group', 'ref'}


def lift_texts(svg, labels=()):
    """參與者名稱以外的文字（訊息、條件、分隔線、ref 說明）一律移到最上層並墊白底；片段關鍵字（alt、opt…）留在原位。"""
    protected = set()
    for m in re.finditer(r'<g class="participant[^"]*"[^>]*>.*?</g>', svg, re.S):
        protected.update(t.group(0) for t in TEXT.finditer(m.group(0)))
    targets = []
    for t in TEXT.finditer(svg):
        inner = html.unescape(re.sub(r'<[^>]+>', '', t.group(0))).strip()
        if t.group(0) in protected or inner in KEYWORDS or not inner:
            continue
        targets.append(t.group(0))
    seen, out, lifted = set(), svg, []
    for t in targets:
        if t in seen:
            continue
        seen.add(t)
        n = out.count(t)
        out = out.replace(t, '')
        lifted.extend([_box(t) + t] * n)
    k = out.rfind('</g>')
    return out[:k] + ''.join(lifted) + out[k:]


def divider_labels(src):
    return {m.group(1).strip() for m in re.finditer(r'^\s*==\s*(.+?)\s*==\s*$', src, re.M)}


def render(puml):
    src = open(puml, encoding='utf-8').read()
    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run(['java', '-jar', JAR, '-tsvg', '-o', tmp, puml], check=True, capture_output=True)
        svg_path = os.path.join(tmp, os.path.basename(puml)[:-5] + '.svg')
        svg = lift_texts(open(svg_path, encoding='utf-8').read(), divider_labels(src))
        fixed = os.path.join(tmp, 'fixed.svg')
        open(fixed, 'w', encoding='utf-8').write(svg)
        png_tmp = os.path.join(tmp, 'out.png')
        subprocess.run(['rsvg-convert', '-z', '1', '-b', 'white', fixed, '-o', png_tmp], check=True)
        im = Image.open(png_tmp)
        info = PngImagePlugin.PngInfo()
        info.add_itxt('plantuml', src, zip=True)
        png = puml[:-5] + '.png'
        im.save(png, pnginfo=info, dpi=(220, 220))
        return png, fixed


if __name__ == '__main__':
    for p in sys.argv[1:]:
        print(render(p)[0])
