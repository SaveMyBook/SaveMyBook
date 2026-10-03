"""把 out/*.ppm 排成 out/sheet.png（2 倍放大，便於檢查）。"""
import sys
from pathlib import Path

from PIL import Image

out = Path(sys.argv[1])
frames = sorted(out.glob("*.ppm"))
cols, scale, gap = 3, 2, 12
w, h = 320 * scale, 240 * scale
rows = (len(frames) + cols - 1) // cols
sheet = Image.new("RGB", (cols * w + (cols - 1) * gap, rows * h + (rows - 1) * gap), (40, 40, 40))
for i, path in enumerate(frames):
    img = Image.open(path).resize((w, h), Image.NEAREST)
    sheet.paste(img, ((i % cols) * (w + gap), (i // cols) * (h + gap)))
sheet.save(out / "sheet.png")
print(out / "sheet.png")
