"""ER 圖改以 SVG 轉 PNG。Graphviz 正交走線的貝茲控制點常越過轉角（轉角處多出一小段），
線端也常緊貼轉角，使鴉爪、圓圈擠在轉角上；此處把每條關聯線改為折線，線端符號依 PlantUML 原尺寸重畫並貼齊邊框，
符號後直線不足、離框角太近、穿過其他實體或與其他線重疊者，另以直線、L 形、Z 形候選路徑重新走線。
puml 內含 MARK 者才適用；PNG 內嵌 iTXt「plantuml」原始碼供 selfcheck 比對。"""
import math, os, re, subprocess, sys, tempfile
from PIL import Image, PngImagePlugin

HERE = os.path.dirname(os.path.abspath(__file__))
JAR = os.path.join(HERE, 'plantuml.jar')
MARK = 'render_er.py'
U = 9.1667                      # PlantUML 線端符號單位（dpi 220 時之圓半徑）
SYM_LEN = {'one': 2 * U, 'zero_or_one': 3.75 * U, 'zero_or_many': 4.5 * U}
STYLE = 'stroke:#181818;stroke-width:2.2917;'
MIN_RUN = 25                    # 符號外緣到第一個轉角之最短直線
CORNER = 26                     # 線端離實體框角之最短距離（含圓角與鴉爪張開寬度）
PORT_GAP = 40                   # 同一邊上兩個線端之最短間距
CLEAR = 16                      # 線與其他實體、其他平行線之最短間距
NS = '{http://www.w3.org/2000/svg}'
NORMAL = {'left': (-1, 0), 'right': (1, 0), 'top': (0, -1), 'bottom': (0, 1)}


def _f(tag, name):
    m = re.search(rf'\b{name}="([^"]*)"', tag)
    return float(m.group(1)) if m else None


def _corners(d):
    """path → 折線頂點（取各段起訖點，不用控制點；合併共線點）"""
    toks = re.findall(r'[MLCZmlcz]|-?\d*\.?\d+(?:e-?\d+)?', d)
    pts, i, cmd = [], 0, None
    while i < len(toks):
        if re.match(r'[A-Za-z]', toks[i]):
            cmd = toks[i]; i += 1; continue
        if cmd in 'ML':
            pts.append((float(toks[i]), float(toks[i + 1]))); i += 2; cmd = 'L'
        elif cmd == 'C':
            pts.append((float(toks[i + 4]), float(toks[i + 5]))); i += 6
        else:
            i += 1
    return _simplify(pts)


def _simplify(pts):
    out = []
    for q in pts:
        if out and math.dist(q, out[-1]) < 0.3: continue
        if len(out) >= 2:
            a, b = out[-2], out[-1]
            if abs((b[0] - a[0]) * (q[1] - b[1]) - (b[1] - a[1]) * (q[0] - b[0])) < 1e-3 * max(1.0, math.dist(a, b) * math.dist(b, q)):
                out[-1] = q; continue
        out.append(q)
    return out


def _classify(lines, ells, end, other):
    """依裝飾圖形判斷線端符號（同 svglinks）"""
    near = lambda q: math.dist(q, end) < math.dist(q, other)
    ls = [l for l in lines if near(((l[0][0] + l[1][0]) / 2, (l[0][1] + l[1][1]) / 2))]
    ne = sum(1 for c in ells if near(c))
    cnt = {}
    for a, b in ls:
        for q in (a, b):
            k = (round(q[0], 1), round(q[1], 1)); cnt[k] = cnt.get(k, 0) + 1
    crow = any(v >= 3 for v in cnt.values())
    if crow and ne == 1: return 'zero_or_many'
    if crow: return 'one_or_many'
    perp = 0
    pts = [q for l in ls for q in l]
    far = max(pts, key=lambda q: math.dist(q, end)) if pts else end
    ux, uy = far[0] - end[0], far[1] - end[1]
    n = math.hypot(ux, uy) or 1
    for a, b in ls:
        vx, vy = b[0] - a[0], b[1] - a[1]
        if math.hypot(vx, vy) and abs(vx * ux + vy * uy) / (math.hypot(vx, vy) * n) < 0.1: perp += 1
    if ne == 1 and perp == 1: return 'zero_or_one'
    if ne == 0 and perp == 2: return 'one'
    raise ValueError(f'無法辨識之線端符號 crow={crow} ellipse={ne} bars={perp}')


def _decoration(border, side, sym):
    """依 PlantUML 原尺寸畫線端符號；border 為邊框上的接點，side 為所在邊"""
    nx, ny = NORMAL[side]
    px, py = -ny, nx
    at = lambda d, s=0: (border[0] + nx * d + px * s, border[1] + ny * d + py * s)
    ln = lambda a, b: f'<line style="{STYLE}" x1="{a[0]:.4f}" x2="{b[0]:.4f}" y1="{a[1]:.4f}" y2="{b[1]:.4f}"/>'
    el = lambda c: f'<ellipse cx="{c[0]:.4f}" cy="{c[1]:.4f}" fill="none" rx="{U:.4f}" ry="{U:.4f}" style="{STYLE}"/>'
    if sym == 'one':
        return [ln(at(U, -U), at(U, U)), ln(at(1.75 * U, -U), at(1.75 * U, U)), ln(at(2 * U), at(0))]
    if sym == 'zero_or_one':
        return [ln(at(0), at(2.75 * U)), el(at(2.75 * U)), ln(at(U, -U), at(U, U))]
    if sym == 'zero_or_many':
        tip = at(2 * U)
        return [ln(tip, at(0, 1.5 * U)), ln(tip, at(0, -1.5 * U)), ln(tip, at(0)), el(at(3.5 * U))]
    raise ValueError(sym)


def _side_of(pt, r):
    d = {'left': abs(pt[0] - r[0]), 'right': abs(pt[0] - r[2]), 'top': abs(pt[1] - r[1]), 'bottom': abs(pt[1] - r[3])}
    return min(d, key=d.get)


def _border(r, side, t):
    return {'left': (r[0], t), 'right': (r[2], t), 'top': (t, r[1]), 'bottom': (t, r[3])}[side]


def _span(r, side):
    return (r[1], r[3]) if side in ('left', 'right') else (r[0], r[2])


def _seg_in_rect(a, b, r, pad):
    """線段是否進入（外擴 pad 之）矩形"""
    x1, y1, x2, y2 = r[0] - pad, r[1] - pad, r[2] + pad, r[3] + pad
    if abs(a[0] - b[0]) < 1e-6:
        lo, hi = sorted((a[1], b[1]))
        return x1 < a[0] < x2 and lo < y2 and hi > y1
    lo, hi = sorted((a[0], b[0]))
    return y1 < a[1] < y2 and lo < x2 and hi > x1


def _cross(a, b, c, d):
    """兩條水平／垂直線段是否在內部交叉，回傳交點"""
    av, cv = abs(a[0] - b[0]) < 1e-6, abs(c[0] - d[0]) < 1e-6
    if av == cv: return None
    if av: a, b, c, d = c, d, a, b
    lo, hi = sorted((a[0], b[0])); vlo, vhi = sorted((c[1], d[1]))
    if lo < c[0] < hi and vlo < a[1] < vhi: return (c[0], a[1])
    return None


def _parallel_close(a, b, c, d, gap):
    av, cv = abs(a[0] - b[0]) < 1e-6, abs(c[0] - d[0]) < 1e-6
    if av != cv: return False
    if av:
        if abs(a[0] - c[0]) >= gap: return False
        lo, hi = sorted((a[1], b[1])); lo2, hi2 = sorted((c[1], d[1]))
    else:
        if abs(a[1] - c[1]) >= gap: return False
        lo, hi = sorted((a[0], b[0])); lo2, hi2 = sorted((c[0], d[0]))
    return min(hi, hi2) - max(lo, lo2) > 0


class Link:
    def __init__(self, gtag, path_tag, e1, e2, s1, s2, route):
        self.gtag, self.path_tag, self.e = gtag, path_tag, (e1, e2)
        self.sym = (s1, s2)
        self.route = route          # [邊框接點, 轉角..., 邊框接點]
        self.sides = None

    def segs(self):
        return list(zip(self.route, self.route[1:]))

    def runs(self):
        r = self.route
        return (math.dist(r[0], r[1]) - SYM_LEN[self.sym[0]], math.dist(r[-1], r[-2]) - SYM_LEN[self.sym[1]])


def parse(svg):
    ents = {}
    for m in re.finditer(r'<g class="entity" data-entity="([^"]+)"[^>]*>(<rect [^>]*>)', svg):
        r = m.group(2)
        x, y, w, h = (_f(r, k) for k in ('x', 'y', 'width', 'height'))
        ents[m.group(1)] = (x, y, x + w, y + h)
    links = []
    for m in re.finditer(r'(<g class="link"[^>]*>)(.*?)</g>', svg, re.S):
        gtag, body = m.group(1), m.group(2)
        e1, e2 = re.search(r'data-entity-1="([^"]+)"', gtag).group(1), re.search(r'data-entity-2="([^"]+)"', gtag).group(1)
        ptag = re.search(r'<path [^>]*/>', body).group(0)
        pts = _corners(re.search(r'\bd="([^"]*)"', ptag).group(1))
        lines = [((_f(t, 'x1'), _f(t, 'y1')), (_f(t, 'x2'), _f(t, 'y2'))) for t in re.findall(r'<line [^>]*/>', body)]
        ells = [(_f(t, 'cx'), _f(t, 'cy')) for t in re.findall(r'<ellipse [^>]*/>', body)]
        s1 = _classify(lines, ells, pts[0], pts[-1]); s2 = _classify(lines, ells, pts[-1], pts[0])
        # 兩端延伸到邊框：沿端段方向退回符號長度，並貼齊所在邊
        route = list(pts)
        for k, (ename, sym) in enumerate(((e1, s1), (e2, s2))):
            r = ents[ename]
            end, nxt = (route[0], route[1]) if k == 0 else (route[-1], route[-2])
            dx, dy = end[0] - nxt[0], end[1] - nxt[1]
            n = math.hypot(dx, dy) or 1
            guess = (end[0] + dx / n * SYM_LEN[sym], end[1] + dy / n * SYM_LEN[sym])
            side = _side_of(guess, r)
            t = guess[1] if side in ('left', 'right') else guess[0]
            b = _border(r, side, t)
            if k == 0: route[0] = b
            else: route[-1] = b
        links.append(Link(gtag, ptag, e1, e2, s1, s2, route))
    return ents, links


def _orthogonal(route):
    return all(abs(a[0] - b[0]) < 0.5 or abs(a[1] - b[1]) < 0.5 for a, b in zip(route, route[1:]))


def _end_sides(L, ents):
    out = []
    for k in (0, -1):
        out.append(_side_of(L.route[k], ents[L.e[0 if k == 0 else 1]]))
    return out


def _problems(L, links, ents):
    """回傳此線之問題（空串列表示合格）"""
    p = []
    if not _orthogonal(L.route): p.append('非正交')
    if len(L.route) > 2 and min(L.runs()) < MIN_RUN: p.append('符號後直線太短')
    if len(L.route) == 2 and math.dist(*L.route) < SYM_LEN[L.sym[0]] + SYM_LEN[L.sym[1]] + MIN_RUN: p.append('兩端符號之間直線太短')
    for k, side in zip((0, 1), _end_sides(L, ents)):
        r = ents[L.e[k]]
        pt = L.route[0 if k == 0 else -1]
        t = pt[1] if side in ('left', 'right') else pt[0]
        lo, hi = _span(r, side)
        if t - lo < CORNER or hi - t < CORNER: p.append('線端太靠近框角')
        # 端段須垂直離開邊框
        a, b = (L.route[0], L.route[1]) if k == 0 else (L.route[-1], L.route[-2])
        nx, ny = NORMAL[side]
        if (b[0] - a[0]) * nx + (b[1] - a[1]) * ny <= 0 or abs((b[0] - a[0]) * ny - (b[1] - a[1]) * nx) > 0.5: p.append('未垂直離開邊框')
    for name, r in ents.items():
        for i, (a, b) in enumerate(L.segs()):
            if name in L.e:
                own_end = (i == 0 and name == L.e[0]) or (i == len(L.route) - 2 and name == L.e[1])
                if L.e[0] == L.e[1] and i in (0, len(L.route) - 2): own_end = True
                if not own_end and _seg_in_rect(a, b, r, -1): p.append(f'進入所接實體 {name}')
                continue
            if _seg_in_rect(a, b, r, 6): p.append(f'穿過或貼近實體 {name}')
    for o in links:
        if o is L: continue
        for a, b in L.segs():
            for c, d in o.segs():
                if _parallel_close(a, b, c, d, CLEAR): p.append(f'與 {o.e} 平行過近')
    return sorted(set(p))


def _ports_taken(links, ents, skip):
    taken = {}
    for o in links:
        if o is skip: continue
        for k, side in zip((0, 1), _end_sides(o, ents)):
            pt = o.route[0 if k == 0 else -1]
            taken.setdefault((o.e[k], side), []).append(pt[1] if side in ('left', 'right') else pt[0])
    return taken


def _grid(lo, hi, step=10):
    if hi < lo: return []
    n = max(1, int((hi - lo) / step))
    return [lo + (hi - lo) * i / n for i in range(n + 1)]


def _candidates(L, ents):
    A, B = ents[L.e[0]], ents[L.e[1]]
    sA, sB = L.sym
    need = (SYM_LEN[sA] + MIN_RUN, SYM_LEN[sB] + MIN_RUN)
    cands = []
    if L.e[0] == L.e[1]:  # 自我關聯：同一邊出、回，ㄈ字形
        for side in NORMAL:
            lo, hi = _span(A, side)
            nx, ny = NORMAL[side]
            d = max(need) + 20
            for t1 in _grid(lo + CORNER, hi - CORNER, 12):
                for t2 in _grid(lo + CORNER, hi - CORNER, 12):
                    if abs(t1 - t2) < 2.5 * PORT_GAP: continue
                    b1, b2 = _border(A, side, t1), _border(A, side, t2)
                    c1 = (b1[0] + nx * d, b1[1] + ny * d); c2 = (b2[0] + nx * d, b2[1] + ny * d)
                    cands.append([b1, c1, c2, b2])
        return cands
    sides = list(NORMAL)
    for a_side in sides:
        for b_side in sides:
            na, nb = NORMAL[a_side], NORMAL[b_side]
            loA, hiA = _span(A, a_side); loB, hiB = _span(B, b_side)
            ga = _grid(loA + CORNER, hiA - CORNER); gb = _grid(loB + CORNER, hiB - CORNER)
            if na[0] == -nb[0] and na[1] == -nb[1]:
                # 相對之兩邊：直線或 Z 形
                for ta in ga:
                    pa = _border(A, a_side, ta)
                    for tb in gb:
                        pb = _border(B, b_side, tb)
                        horiz = na[1] == 0
                        if (horiz and abs(pa[1] - pb[1]) < 0.01) or (not horiz and abs(pa[0] - pb[0]) < 0.01):
                            cands.append([pa, pb]); continue
                        if horiz:
                            for xm in _grid(min(pa[0], pb[0]), max(pa[0], pb[0]), 12):
                                cands.append([pa, (xm, pa[1]), (xm, pb[1]), pb])
                        else:
                            for ym in _grid(min(pa[1], pb[1]), max(pa[1], pb[1]), 12):
                                cands.append([pa, (pa[0], ym), (pb[0], ym), pb])
                    # 直線：兩邊投影重疊時
                    if na[1] == 0:
                        for t in ga:
                            if loB + CORNER <= t <= hiB - CORNER:
                                cands.append([_border(A, a_side, t), _border(B, b_side, t)])
                    else:
                        for t in ga:
                            if loB + CORNER <= t <= hiB - CORNER:
                                cands.append([_border(A, a_side, t), _border(B, b_side, t)])
            elif na[0] * nb[0] + na[1] * nb[1] == 0:
                # 互相垂直之兩邊：L 形
                for ta in ga:
                    pa = _border(A, a_side, ta)
                    for tb in gb:
                        pb = _border(B, b_side, tb)
                        corner = (pa[0], pb[1]) if na[0] == 0 else (pb[0], pa[1])
                        cands.append([pa, corner, pb])
    return cands


def _score(route, L, links, ents, taken):
    """不合格回傳 None；否則回傳分數（越小越好）"""
    route = _simplify(route)
    if len(route) < 2 or not _orthogonal(route): return None
    tmp = Link(L.gtag, L.path_tag, L.e[0], L.e[1], L.sym[0], L.sym[1], route)
    if len(route) > 2 and min(tmp.runs()) < MIN_RUN: return None
    if len(route) == 2 and math.dist(*route) < SYM_LEN[L.sym[0]] + SYM_LEN[L.sym[1]] + 2 * MIN_RUN: return None
    sides = _end_sides(tmp, ents)
    for k, side in zip((0, 1), sides):
        pt = route[0 if k == 0 else -1]
        t = pt[1] if side in ('left', 'right') else pt[0]
        for u in taken.get((L.e[k], side), []):
            if abs(u - t) < PORT_GAP: return None
        a, b = (route[0], route[1]) if k == 0 else (route[-1], route[-2])
        nx, ny = NORMAL[side]
        if (b[0] - a[0]) * nx + (b[1] - a[1]) * ny <= 0: return None
    if L.e[0] == L.e[1] and sides[0] == sides[1]:
        pt0, pt1 = route[0], route[-1]
        if math.dist(pt0, pt1) < 2 * PORT_GAP: return None
    # 不得穿過實體
    for name, r in ents.items():
        for i, (a, b) in enumerate(tmp.segs()):
            own = name in L.e and ((i == 0 and name == L.e[0]) or (i == len(route) - 2 and name == L.e[1]))
            if own:
                continue
            if _seg_in_rect(a, b, r, -1 if name in L.e else CLEAR - 4): return None
    others = [o for o in links if o is not L]
    for a, b in tmp.segs():
        for o in others:
            for c, d in o.segs():
                if _parallel_close(a, b, c, d, CLEAR): return None
    syms = []
    for o in others:
        for k in (0, -1):
            sd = _side_of(o.route[k], ents[o.e[0 if k == 0 else 1]])
            nx, ny = NORMAL[sd]
            ln = SYM_LEN[o.sym[0 if k == 0 else 1]]
            syms.append((o.route[k], (o.route[k][0] + nx * ln, o.route[k][1] + ny * ln)))
    crossings = 0
    for a, b in tmp.segs():
        for s0, s1 in syms:  # 不得經過其他線之符號
            box = (min(s0[0], s1[0]) - 15, min(s0[1], s1[1]) - 15, max(s0[0], s1[0]) + 15, max(s0[1], s1[1]) + 15)
            if _seg_in_rect(a, b, box, 0): return None
        for o in others:
            for c, d in o.segs():
                x = _cross(a, b, c, d)
                if x:
                    crossings += 1
                    if any(math.dist(x, q) < 30 for q in o.route[1:-1] + route[1:-1]): return None
    # 自己的符號也不得被其他線經過
    for k in (0, -1):
        side = sides[0 if k == 0 else 1]
        nx, ny = NORMAL[side]
        ln = SYM_LEN[L.sym[0 if k == 0 else 1]]
        s0 = route[k]; s1 = (s0[0] + nx * ln, s0[1] + ny * ln)
        box = (min(s0[0], s1[0]) - 15, min(s0[1], s1[1]) - 15, max(s0[0], s1[0]) + 15, max(s0[1], s1[1]) + 15)
        for o in others:
            for c, d in o.segs():
                if _seg_in_rect(c, d, box, 0): return None
    length = sum(math.dist(a, b) for a, b in tmp.segs())
    corner = 0  # 線端離框角越近扣分越多，使符號留在邊的中段
    for k, side in zip((0, 1), sides):
        pt = route[0 if k == 0 else -1]
        t = pt[1] if side in ('left', 'right') else pt[0]
        lo, hi = _span(ents[L.e[k]], side)
        corner += max(0, 70 - min(t - lo, hi - t))
    return crossings * 1000 + (len(route) - 2) * 120 + length * 0.2 + corner


def reroute(L, links, ents):
    taken = _ports_taken(links, ents, L)
    best = None
    for c in _candidates(L, ents):
        s = _score(c, L, links, ents, taken)
        if s is not None and (best is None or s < best[0]):
            best = (s, _simplify(c))
    if best is None:
        raise RuntimeError(f'找不到合格路徑：{L.e}')
    L.route = best[1]


def _reroute_all(links, ents):
    """逐條重新走線：先走兩實體距離近者，後走者避開已走好的線"""
    def key(L):
        a, b = ents[L.e[0]], ents[L.e[1]]
        return math.dist(((a[0] + a[2]) / 2, (a[1] + a[3]) / 2), ((b[0] + b[2]) / 2, (b[1] + b[3]) / 2))
    done = []
    for L in sorted(links, key=key):
        done.append(L)
        reroute(L, done, ents)


def fix(svg):
    ents, links = parse(svg)
    try:
        for _ in range(3):
            bad = [L for L in links if _problems(L, links, ents)]
            if not bad: break
            for L in sorted(bad, key=lambda L: -len(_problems(L, links, ents))):
                if _problems(L, links, ents):
                    reroute(L, links, ents)
    except RuntimeError:
        _reroute_all(links, ents)
    left = {L.e: _problems(L, links, ents) for L in links if _problems(L, links, ents)}
    if left: raise RuntimeError(f'仍有問題之關聯線：{left}')
    out = svg
    for L, m in zip(links, list(re.finditer(r'(<g class="link"[^>]*>)(.*?)</g>', svg, re.S))):
        sides = _end_sides(L, ents)
        r = L.route
        n0, n1 = NORMAL[sides[0]], NORMAL[sides[1]]
        start = (r[0][0] + n0[0] * SYM_LEN[L.sym[0]], r[0][1] + n0[1] * SYM_LEN[L.sym[0]])
        end = (r[-1][0] + n1[0] * SYM_LEN[L.sym[1]], r[-1][1] + n1[1] * SYM_LEN[L.sym[1]])
        pts = [start] + r[1:-1] + [end]
        d = 'M' + ' L'.join(f'{x:.4f},{y:.4f}' for x, y in pts)
        path = re.sub(r'\bd="[^"]*"', f'd="{d}"', L.path_tag)
        deco = _decoration(r[0], sides[0], L.sym[0]) + _decoration(r[-1], sides[1], L.sym[1])
        out = out.replace(m.group(0), m.group(1) + path + ''.join(deco) + '</g>', 1)
    return out


def fixed_svg(puml):
    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run(['java', '-Djava.awt.headless=true', '-jar', JAR, '-charset', 'UTF-8', '-tsvg', '-o', tmp, puml], check=True, capture_output=True)
        return fix(open(os.path.join(tmp, os.path.basename(puml)[:-5] + '.svg'), encoding='utf-8').read())


def render(puml):
    src = open(puml, encoding='utf-8').read()
    assert MARK in src, puml
    svg = fixed_svg(puml)
    with tempfile.TemporaryDirectory() as tmp:
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
