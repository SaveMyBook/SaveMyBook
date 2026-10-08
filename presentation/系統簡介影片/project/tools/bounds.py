"""量測 App 截圖上元件（圓角卡片）的精確邊界：從卡片內一點以顏色相近做填滿，取外框（含邊線）。
用法：python3 tools/bounds.py <畫面名> <x> <y> [容差]；x、y 為 App 邏輯座標（393×852），輸出邏輯座標的 x、y、w、h 與圓角。"""
import sys
from collections import deque
from PIL import Image
name, sx, sy = sys.argv[1], float(sys.argv[2]), float(sys.argv[3])
tol = float(sys.argv[4]) if len(sys.argv) > 4 else 6
import os
src = next((f for f in (f"assets-src/screens/{name}.png", f"public/screens/{name}.webp") if os.path.exists(f)), None)
if not src: sys.exit(f"找不到畫面 {name}")
im = Image.open(src).convert("RGB")
W, H = im.size; S = W / 393
px = im.load()
x0, y0 = int(sx * S), int(sy * S)
c0 = px[x0, y0]
near = lambda c: max(abs(c[i] - c0[i]) for i in range(3)) <= tol
seen = bytearray(W * H); q = deque([(x0, y0)]); seen[y0 * W + x0] = 1
minx = maxx = x0; miny = maxy = y0
while q:
    x, y = q.popleft()
    minx, maxx, miny, maxy = min(minx, x), max(maxx, x), min(miny, y), max(maxy, y)
    for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
        if 0 <= nx < W and 0 <= ny < H and not seen[ny * W + nx] and near(px[nx, ny]):
            seen[ny * W + nx] = 1; q.append((nx, ny))
# 邊線：往外找第一個與背景不同的像素寬度（最多 3 px）
def edge(x, y, dx, dy):
    n = 0
    while n < 4 and 0 <= x + dx * (n + 1) < W and 0 <= y + dy * (n + 1) < H and not near(px[x + dx * (n + 1), y + dy * (n + 1)]): n += 1
    return n
cy = (miny + maxy) // 2; cx = (minx + maxx) // 2
b = max(edge(minx, cy, -1, 0), edge(maxx, cy, 1, 0), edge(cx, miny, 0, -1), edge(cx, maxy, 0, 1))
b = min(b, 3)
L, T, R, B = minx - b, miny - b, maxx + b, maxy + b
# 圓角：最上面一列填滿區的左端與整體左緣的距離
row = [x for x in range(minx, maxx) if seen[miny * W + x]]
r = (row[0] - minx) if row else 0
print(f"{name}: x {L / S:.1f} y {T / S:.1f} w {(R - L + 1) / S:.1f} h {(B - T + 1) / S:.1f} r≈{(r + b) / S * 2.2:.1f} 填色 {c0} 邊線 {b}px")
