"""找出圖中文字互相重疊、文字壓在類別框或動作框邊線、以及連線穿過文字之處。
以 PlantUML 輸出 SVG 後，依 <text> 的 x、y、textLength、font-size 估算文字外框。"""
import os, re, subprocess, sys, glob, math, tempfile
import xml.etree.ElementTree as ET

NS = '{http://www.w3.org/2000/svg}'
FRAGMENT_TAGS = {'alt', 'opt', 'loop', 'par', 'break', 'critical', 'group', 'ref'}
HERE = os.path.dirname(os.path.abspath(__file__))
JAR = os.environ.get('PLANTUML_JAR') or os.path.join(HERE, 'plantuml.jar')


def figure_sources():
    return sorted(glob.glob(os.path.join(os.path.dirname(HERE), '*', 'v3', '*.puml')))


def render_svg(puml, outdir):
    subprocess.run(['java', '-jar', JAR, '-tsvg', '-o', outdir, puml], check=True, capture_output=True)
    svg = os.path.join(outdir, os.path.basename(puml)[:-5] + '.svg')
    s = open(svg, encoding='utf-8').read()
    if 'data-diagram-type="SEQUENCE"' in s:
        import render_seq
        open(svg, 'w', encoding='utf-8').write(render_seq.lift_texts(s, render_seq.divider_labels(open(puml, encoding='utf-8').read())))
    elif 'render_class.py' in open(puml, encoding='utf-8').read():
        import render_class
        open(svg, 'w', encoding='utf-8').write(render_class.fix(s))
    return svg


def boxes(svg):
    root = ET.parse(svg).getroot()
    texts, rects, segs = [], [], []
    edge_segs, heads = [], []
    prev = None
    for el in root.iter():
        if el.tag == NS + 'text' and (el.text or '').strip():
            t = el
            x, y = float(t.get('x', 0)), float(t.get('y', 0))
            fs = float(t.get('font-size', 12))
            w = float(t.get('textLength') or len(t.text) * fs * 0.6)
            shielded = prev is not None and prev.tag == NS + 'rect' and prev.get('data-shield') == '1'
            texts.append((x, y - fs * 0.78, x + w, y + fs * 0.12, t.text.strip(), shielded))
        prev = el
    for r in root.iter(NS + 'rect'):
        w, h = float(r.get('width', 0)), float(r.get('height', 0))
        if w > 20 and h > 12 and r.get('data-shield') != '1':
            x, y = float(r.get('x', 0)), float(r.get('y', 0))
            rects.append((x, y, x + w, y + h))
    for pth in root.iter(NS + 'path'):
        d = pth.get('d', '')
        try:
            ss = _segments(d)
        except (IndexError, ValueError, TypeError):
            ss = []
        segs.extend(ss)
        edge_segs.append(ss)
    for ln in root.iter(NS + 'line'):
        segs.append((float(ln.get('x1')), float(ln.get('y1')), float(ln.get('x2')), float(ln.get('y2'))))
    for pl in root.iter(NS + 'polyline'):
        pts = [float(v) for v in re.findall(r'-?\d+\.?\d*', pl.get('points', ''))]
        for i in range(0, len(pts) - 3, 2):
            segs.append((pts[i], pts[i + 1], pts[i + 2], pts[i + 3]))
    for pg in root.iter(NS + 'polygon'):
        pts = [float(v) for v in re.findall(r'-?\d*\.?\d+', pg.get('points', ''))]
        xs, ys = pts[0::2], pts[1::2]
        if xs and (max(xs) - min(xs)) * (max(ys) - min(ys)) < 500:
            heads.append((min(xs), min(ys), max(xs), max(ys)))
        elif xs:
            n = len(xs)
            segs.extend((xs[k], ys[k], xs[(k + 1) % n], ys[(k + 1) % n]) for k in range(n))
    return texts, rects, segs, edge_segs, heads


def _collinear_overlap(a, b):
    ax1, ay1, ax2, ay2 = a; bx1, by1, bx2, by2 = b
    la = math.hypot(ax2 - ax1, ay2 - ay1); lb = math.hypot(bx2 - bx1, by2 - by1)
    if la < 6 or lb < 6: return 0
    ux, uy = (ax2 - ax1) / la, (ay2 - ay1) / la
    vx, vy = (bx2 - bx1) / lb, (by2 - by1) / lb
    if abs(ux * vy - uy * vx) > 0.05: return 0
    dist = abs((bx1 - ax1) * uy - (by1 - ay1) * ux)
    if dist > 14: return 0
    t1 = (bx1 - ax1) * ux + (by1 - ay1) * uy; t2 = (bx2 - ax1) * ux + (by2 - ay1) * uy
    lo, hi = max(0, min(t1, t2)), min(la, max(t1, t2))
    return hi - lo


def _segments(d):
    toks = re.findall(r'[MLCQZAHVmlcqzahv]|-?\d*\.?\d+(?:e-?\d+)?', d)
    segs, i, cur, start, cmd = [], 0, None, None, None
    def num():
        nonlocal i
        v = float(toks[i]); i += 1; return v
    while i < len(toks):
        if re.match(r'[A-Za-z]', toks[i]):
            cmd = toks[i]; i += 1
            if cmd in 'Zz':
                if cur and start: segs.append((*cur, *start))
                cur = start
                continue
        if cmd == 'M':
            cur = (num(), num()); start = cur; cmd = 'L'
        elif cmd == 'L':
            nxt = (num(), num()); segs.append((*cur, *nxt)); cur = nxt
        elif cmd == 'C':
            p1 = (num(), num()); p2 = (num(), num()); p3 = (num(), num())
            prev = cur
            for k in range(1, 9):
                t = k / 8
                x = (1-t)**3*cur[0] + 3*(1-t)**2*t*p1[0] + 3*(1-t)*t*t*p2[0] + t**3*p3[0]
                y = (1-t)**3*cur[1] + 3*(1-t)**2*t*p1[1] + 3*(1-t)*t*t*p2[1] + t**3*p3[1]
                segs.append((*prev, x, y)); prev = (x, y)
            cur = p3
        elif cmd == 'A':
            for _ in range(5): num()
            nxt = (num(), num()); segs.append((*cur, *nxt)); cur = nxt
        elif cmd == 'H':
            nxt = (num(), cur[1]); segs.append((*cur, *nxt)); cur = nxt
        elif cmd == 'V':
            nxt = (cur[0], num()); segs.append((*cur, *nxt)); cur = nxt
        elif cmd == 'Q':
            p1 = (num(), num()); p2 = (num(), num()); segs.append((*cur, *p2)); cur = p2
        else:
            i += 1
    return segs


def inter(a, b):
    w = min(a[2], b[2]) - max(a[0], b[0]); h = min(a[3], b[3]) - max(a[1], b[1])
    return (w, h) if w > 0 and h > 0 else None


def seg_hits_box(s, b, pad=1.0):
    """線段與（內縮 pad 後之）矩形是否相交；pad 為負值時為外擴。以 Liang–Barsky 精確裁切，短字（如「1」）也不會漏判。"""
    x1, y1, x2, y2 = s
    bx1, by1, bx2, by2 = b[0] + pad, b[1] + pad, b[2] - pad, b[3] - pad
    if bx2 <= bx1 or by2 <= by1: return False
    dx, dy = x2 - x1, y2 - y1
    t0, t1 = 0.0, 1.0
    for p, q in ((-dx, x1 - bx1), (dx, bx2 - x1), (-dy, y1 - by1), (dy, by2 - y1)):
        if p == 0:
            if q <= 0: return False
        else:
            t = q / p
            if p < 0:
                if t > t1: return False
                t0 = max(t0, t)
            else:
                if t < t0: return False
                t1 = min(t1, t)
    return t0 < t1


def check(svg):
    texts, rects, segs, edge_segs, heads = boxes(svg)
    issues = []
    n = len(edge_segs)
    for i in range(n):
        for j in range(i + 1, n):
            ov = 0
            for a in edge_segs[i]:
                for b in edge_segs[j]:
                    ov = max(ov, _collinear_overlap(a, b))
                    if ov > 20: break
                if ov > 20: break
            if ov > 20:
                issues.append(f'連線重疊或過近：第{i + 1}條與第{j + 1}條')
    for i, a in enumerate(heads):
        for b in heads[i + 1:]:
            gap = max(a[0] - b[2], b[0] - a[2], a[1] - b[3], b[1] - a[3])
            if gap < 6:
                issues.append('箭頭重疊或相連')
    for i, a in enumerate(texts):
        for b in texts[i + 1:]:
            r = inter(a, b)
            if r and r[0] > 2 and r[1] > 2:
                issues.append(f'文字重疊：「{a[4]}」與「{b[4]}」')
        if a[4] in FRAGMENT_TAGS or a[5]:
            continue
        for rc in rects:
            r = inter(a, rc)
            inside = a[0] >= rc[0] - 1 and a[2] <= rc[2] + 1 and a[1] >= rc[1] - 1 and a[3] <= rc[3] + 1
            if r and not inside and r[0] > 2 and r[1] > 2:
                issues.append(f'文字壓到框線：「{a[4]}」')
                break
        for s in segs:
            if seg_hits_box(s, a, pad=2.0):
                issues.append(f'連線穿過文字：「{a[4]}」')
                break
    return sorted(set(issues))


if __name__ == '__main__':
    sys.path.insert(0, HERE)
    srcs = [os.path.abspath(p) for p in sys.argv[1:]] or figure_sources()
    total = 0
    with tempfile.TemporaryDirectory() as outdir:
        for puml in srcs:
            iss = check(render_svg(puml, outdir))
            if iss:
                total += 1
                print(f'== {os.path.relpath(puml)} ({len(iss)})')
                for x in iss[:40]:
                    print('   ', x)
    print('diagrams with issues:', total, '/', len(srcs))
