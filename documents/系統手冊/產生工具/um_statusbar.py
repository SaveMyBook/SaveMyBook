"""第 12 章淺色截圖補上 iOS 狀態列與 Home 指示條（截圖工具不會畫系統列）。

狀態列圖示（時間、訊號、5G、電池）取自同批實機截圖的白色圖示當遮罩，依背景深淺改成白色或黑色疊上；
勿擾模式的月亮圖示移除。Home 指示條依底部背景深淺畫黑色或白色。
用法：.venv/bin/python um_statusbar.py <淺色截圖根目錄或單一檔案>
"""
import os
import sys

from PIL import Image, ImageDraw

ROOT = '/Users/xukaijun/Desktop/SaveMyBook/documents/使用手冊截圖'
STATUS_SRC = os.path.join(ROOT, '6. 加入購物車與結帳', '表12-6-1 購物車.PNG')
BAND = 180            # 狀態列高度（像素，3x）
MOON = (255, 320)     # 月亮圖示的橫向範圍
BG_LUMA = 50          # 實機截圖狀態列背景亮度


def status_mask():
    band = Image.open(STATUS_SRC).convert('L').crop((0, 0, 1179, BAND))
    mask = band.point(lambda v: max(0, min(255, round((v - BG_LUMA) * 255 / (255 - BG_LUMA)))))
    ImageDraw.Draw(mask).rectangle((MOON[0], 0, MOON[1], BAND), fill=0)
    return mask


def luma(im, box):
    small = im.crop(box).convert('L').resize((40, 8))
    data = list(small.getdata())
    return sum(data) / len(data)


def apply(path, mask):
    im = Image.open(path).convert('RGB')
    w, h = im.size
    if (w, h) != (1179, 2556):
        print('略過（尺寸不符）', path)
        return
    top = luma(im, (0, 0, w, BAND))
    color = (255, 255, 255) if top < 150 else (0, 0, 0)
    im.paste(Image.new('RGB', (w, BAND), color), (0, 0), mask)
    bottom = luma(im, (300, h - 60, w - 300, h - 6))
    pill = (255, 255, 255) if bottom < 110 else (0, 0, 0)
    ImageDraw.Draw(im).rounded_rectangle(((w - 402) // 2, h - 39, (w + 402) // 2, h - 24), radius=8, fill=pill)
    im.save(path)


def main():
    target = sys.argv[1]
    mask = status_mask()
    paths = [target] if os.path.isfile(target) else [
        os.path.join(d, f) for d, _, fs in os.walk(target) for f in fs if f.upper().endswith('.PNG')]
    for p in sorted(paths):
        apply(p, mask)
    print(f'已補上狀態列：{len(paths)} 張')


if __name__ == '__main__':
    main()
