"""類別圖改以 SVG 轉 PNG：Graphviz 把多重性固定放在線端一側，斜線常穿過自己的多重性文字；
此處把被連線穿過或與其他文字重疊的連線文字，就近移到不碰線、不碰框、不疊字的位置。
puml 內含 RENDER_MARK 者才適用；PNG 內嵌 iTXt「plantuml」原始碼供 selfcheck 比對。"""
import os, re, subprocess, sys, tempfile
from PIL import Image, PngImagePlugin

HERE = os.path.dirname(os.path.abspath(__file__))
JAR = os.path.join(HERE, 'plantuml.jar')
RENDER_MARK = 'render_class.py'
LINK = re.compile(r'<g class="link"[^>]*>.*?</g>', re.S)
TEXT = re.compile(r'<text\b[^>]*>[^<]*</text>')
CLEAR = 7.0
TEXT_GAP = 5.0
OFFSETS = sorted(((dx, dy) for dx in range(-200, 201, 4) for dy in range(-30, 31, 2)), key=lambda d: d[0] ** 2 + d[1] ** 2)


def _num(tag, name):
    m = re.search(rf'\b{name}="([^"]*)"', tag)
    return float(m.group(1)) if m else None


def _shift(box, dx, dy):
    return (box[0] + dx, box[1] + dy, box[2] + dx, box[3] + dy, *box[4:])


def _rect_edges(rects):
    return [e for x1, y1, x2, y2 in rects for e in ((x1, y1, x2, y1), (x2, y1, x2, y2), (x2, y2, x1, y2), (x1, y2, x1, y1))]


def fix(svg_text):
    sys.path.insert(0, HERE)
    import overlap_check as O
    with tempfile.NamedTemporaryFile('w', suffix='.svg', delete=False, encoding='utf-8') as f:
        f.write(svg_text)
    try:
        texts, rects, segs, _, heads = O.boxes(f.name)
    finally:
        os.unlink(f.name)
    link_tags = [t.group(0) for g in LINK.finditer(svg_text) for t in TEXT.finditer(g.group(0))]
    boxes = list(texts)

    def bad(i, b):
        if any(O.seg_hits_box(s, b, pad=-CLEAR) for s in segs) or any(O.inter(_shift(b, 0, 0)[:4], (h[0] - CLEAR, h[1] - CLEAR, h[2] + CLEAR, h[3] + CLEAR)) for h in heads):
            return True
        if any(O.inter(_shift(b, 0, 0)[:4], r) for r in rects) or any(O.seg_hits_box(e, b, pad=-CLEAR) for e in _rect_edges(rects)):
            return True
        g = (b[0] - TEXT_GAP, b[1], b[2] + TEXT_GAP, b[3])
        return any(j != i and O.inter(g, o) for j, o in enumerate(boxes))

    out = svg_text
    for tag in link_tags:
        x, y = _num(tag, 'x'), _num(tag, 'y')
        i = next((k for k, b in enumerate(boxes) if abs(b[0] - x) < 0.01 and abs(b[3] - (y + (_num(tag, 'font-size') or 12) * 0.12)) < 0.01), None)
        if i is None or not bad(i, boxes[i]):
            continue
        for dx, dy in OFFSETS:
            nb = _shift(boxes[i], dx, dy)
            if not bad(i, nb):
                boxes[i] = nb
                new = re.sub(r'\bx="[^"]*"', f'x="{x + dx:.2f}"', tag, count=1)
                new = re.sub(r'\by="[^"]*"', f'y="{y + dy:.2f}"', new, count=1)
                out = out.replace(tag, new, 1)
                break
    return out


def render(puml):
    src = open(puml, encoding='utf-8').read()
    assert RENDER_MARK in src, puml
    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run(['java', '-jar', JAR, '-tsvg', '-o', tmp, puml], check=True, capture_output=True)
        svg = fix(open(os.path.join(tmp, os.path.basename(puml)[:-5] + '.svg'), encoding='utf-8').read())
        fixed = os.path.join(tmp, 'fixed.svg')
        open(fixed, 'w', encoding='utf-8').write(svg)
        png_tmp = os.path.join(tmp, 'out.png')
        subprocess.run(['rsvg-convert', '-z', '1', '-b', 'white', fixed, '-o', png_tmp], check=True)
        info = PngImagePlugin.PngInfo()
        info.add_itxt('plantuml', src, zip=True)
        png = puml[:-5] + '.png'
        Image.open(png_tmp).save(png, pnginfo=info, dpi=(220, 220))
        return png


if __name__ == '__main__':
    for p in sys.argv[1:]:
        print(render(p))
