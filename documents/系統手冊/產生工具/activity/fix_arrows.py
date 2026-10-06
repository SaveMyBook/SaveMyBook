"""產生活動圖 PNG 並刪除線段中間多餘的箭頭。

PlantUML 的判斷式一邊以 stop 結束、另一邊是空分支（或兩邊在合併點交會）時，會在合併點多畫一個箭頭，
同一條線上就出現兩個箭頭；調整 .puml 寫法無法避免。做法：同時輸出 SVG 找出「箭頭尖端沒有碰到任何節點」者，
在 PNG 上以箭頭上方同一條線的像素覆蓋。往上的箭頭是 repeat 迴圈回頭線的方向標示，保留。

用法：../.venv/bin/python fix_arrows.py [uc03 uc20 ...]（不指定時處理全部 ucNN.puml）
"""
import glob
import os
import re
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
JAR = os.path.join(HERE, '..', 'plantuml.jar')
NS = '{http://www.w3.org/2000/svg}'


def _pts(s):
    v = [float(x) for x in re.split(r'[ ,]+', s.strip()) if x]
    return list(zip(v[0::2], v[1::2]))


def stray_arrows(svg_path):
    """回傳多餘箭頭的四個頂點（SVG 座標）。"""
    root = ET.parse(svg_path).getroot()
    nodes, arrows = [], []
    for el in root.iter():
        tag = el.tag.replace(NS, '')
        if tag == 'rect' and el.get('rx'):
            x, y, w, h = (float(el.get(k)) for k in ('x', 'y', 'width', 'height'))
            nodes.append((x, y, x + w, y + h))
        elif tag == 'ellipse':
            cx, cy, rx, ry = (float(el.get(k)) for k in ('cx', 'cy', 'rx', 'ry'))
            nodes.append((cx - rx, cy - ry, cx + rx, cy + ry))
        elif tag == 'polygon':
            p = _pts(el.get('points'))
            if el.get('fill') == '#181818' and len(p) == 4:
                arrows.append(p)
            elif el.get('fill') == '#F1F1F1':
                xs, ys = [a for a, _ in p], [b for _, b in p]
                nodes.append((min(xs), min(ys), max(xs), max(ys)))
    out = []
    for a in arrows:
        (tx, ty), back = a[1], a[3]
        if ty < back[1] - 3:
            continue
        if any(x0 - 4 <= tx <= x1 + 4 and y0 - 4 <= ty <= y1 + 4 for x0, y0, x1, y1 in nodes):
            continue
        out.append(a)
    return out


M = 6  # 箭頭外框加線寬與反鋸齒約多 2 像素，取寬一點才不會留下殘點


def erase(img, arrow, sx, sy):
    """以箭頭前後同一條線的一列（或一欄）像素重複鋪滿箭頭範圍，線條粗細與反鋸齒都和原圖相同。
    前後兩端的像素須完全相同（該段只有一條直線），否則不處理並回傳 False。"""
    xs = [x * sx for x, _ in arrow]
    ys = [y * sy for _, y in arrow]
    (tx, ty), (bx, by) = (arrow[1][0] * sx, arrow[1][1] * sy), (arrow[3][0] * sx, arrow[3][1] * sy)
    x0, x1 = int(min(xs)) - M, int(max(xs)) + M + 1
    y0, y1 = int(min(ys)) - M, int(max(ys)) + M + 1
    if abs(ty - by) >= abs(tx - bx):
        before, after = img.crop((x0, y0 - 2, x1, y0 - 1)), img.crop((x0, y1 + 1, x1, y1 + 2))
        if before.tobytes() != after.tobytes():
            return False
        for y in range(y0, y1):
            img.paste(before, (x0, y))
    else:
        before, after = img.crop((x0 - 2, y0, x0 - 1, y1)), img.crop((x1 + 1, y0, x1 + 2, y1))
        if before.tobytes() != after.tobytes():
            return False
        for x in range(x0, x1):
            img.paste(before, (x, y0))
    return True


def fix(name, tmp):
    puml = os.path.join(HERE, f'{name}.puml')
    for fmt in ('-tsvg', '-tpng'):
        subprocess.run(['java', '-jar', JAR, fmt, '-o', tmp, puml], check=True, capture_output=True)
    svg = os.path.join(tmp, f'{name}.svg')
    img = Image.open(os.path.join(tmp, f'{name}.png')).convert('RGB')
    root = ET.parse(svg).getroot()
    vb = [float(v) for v in root.get('viewBox').split()]
    sx, sy = img.width / vb[2], img.height / vb[3]
    arrows = stray_arrows(svg)
    skipped = [a for a in arrows if not erase(img, a, sx, sy)]
    for a in skipped:
        print(f'{name}: 箭頭 ({a[1][0]:.0f}, {a[1][1]:.0f}) 附近不是單純的直線，未處理')
    img.save(os.path.join(HERE, f'{name}.png'))
    return len(arrows) - len(skipped)


def main():
    names = sys.argv[1:] or sorted(os.path.basename(p)[:-5] for p in glob.glob(os.path.join(HERE, 'uc[0-9][0-9].puml')))
    total = 0
    with tempfile.TemporaryDirectory() as tmp:
        for n in names:
            k = fix(n, tmp)
            total += k
            if k:
                print(f'{n}: 刪除 {k} 個多餘箭頭')
    print(f'共 {len(names)} 張圖、刪除 {total} 個')


if __name__ == '__main__':
    main()
