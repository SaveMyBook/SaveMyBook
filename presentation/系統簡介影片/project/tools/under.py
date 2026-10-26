"""對話框浮出時原位顯示的畫面：把對話框從截圖中去掉，只留半透明遮罩下的頁面。

  .venv/bin/python ../tools/under.py <有對話框的畫面> <同一頁沒有對話框的畫面> <對話框的 cut>
  例：.venv/bin/python ../tools/under.py v_pay_done v_ov_detail cut_pay_done   → public/v2/screens/v_pay_done_under.webp

遮罩的透明度與顏色由兩張截圖在對話框以外的像素逐色版擬合（App 的遮罩為黑色約 50%）；
對話框與其陰影的範圍改用「沒有對話框的頁面加上同一層遮罩」，邊緣以高斯模糊漸變，範圍外完全沿用原截圖。
"""
import json, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "public", "v2")
with_dialog, page, cut = sys.argv[1:4]
r = json.load(open(os.path.join(ROOT, "cuts.json"), encoding="utf-8"))[cut]
p = np.asarray(Image.open(os.path.join(ROOT, "screens", f"{with_dialog}.webp")).convert("RGB")).astype(float)
d = np.asarray(Image.open(os.path.join(ROOT, "screens", f"{page}.webp")).convert("RGB")).astype(float)
H, W, _ = p.shape
k = W / 393
x0, y0, x1, y1 = (int(v * k) for v in (r["x"], r["y"], r["x"] + r["w"], r["y"] + r["h"]))

# 擬合用的像素：對話框外擴 40pt（避開陰影）與頂端狀態列以外
fit = np.ones((H, W), bool)
pad = int(40 * k)
fit[max(0, y0 - pad):y1 + pad, max(0, x0 - pad):x1 + pad] = False
fit[:int(60 * k)] = False
dimmed = np.empty_like(d)
for ch in range(3):
    a = np.vstack([d[..., ch][fit], np.ones(fit.sum())]).T
    (s, b), *_ = np.linalg.lstsq(a, p[..., ch][fit], rcond=None)
    dimmed[..., ch] = d[..., ch] * s + b
err = np.abs(dimmed - p)[fit].mean()
print(f"遮罩透明度約 {1 - s:.3f}，對話框外平均誤差 {err:.2f}（超過 2 表示兩張截圖的頁面不同）")

mask = Image.new("L", (W, H), 0)
ImageDraw.Draw(mask).rectangle((x0 - int(26 * k), y0 - int(26 * k), x1 + int(26 * k), y1 + int(34 * k)), fill=255)
w = np.asarray(mask.filter(ImageFilter.GaussianBlur(6 * k))).astype(float)[..., None] / 255
out = np.clip(np.round(p * (1 - w) + dimmed * w), 0, 255).astype(np.uint8)
Image.fromarray(out).save(os.path.join(ROOT, "screens", f"{with_dialog}_under.webp"), lossless=True)
print(f"→ public/v2/screens/{with_dialog}_under.webp")
