"""第 12 章使用手冊截圖：依 um_plan.py 改名為「表12-節-表 小標.PNG」，並產生第 7 節的深色模式截圖。

- 實機截圖在原資料夾內改名，對照表寫入 使用手冊截圖/檔名對照.csv（可用 --undo 還原）。
- 第 7 節：App 截圖工具以深色模式輸出到暫存資料夾（SHOTS_OUT），再補上 iOS 狀態列後存入新資料夾。
用法：.venv/bin/python um_rename.py <深色截圖資料夾> | --undo
"""
import csv
import os
import sys

from PIL import Image

from um_plan import SECTIONS

# UM_SHOTS 可改用其他截圖資料夾（例如淺色版 使用手冊截圖_淺色），資料夾結構與檔名相同
ROOT = os.environ.get('UM_SHOTS', '/Users/xukaijun/Desktop/SaveMyBook/documents/使用手冊截圖')
MAP = os.path.join(ROOT, '檔名對照.csv')
SECTION7 = '7. 智慧書櫃存書與取書'
# 狀態列（時間、訊號、電池）取自同批實機截圖，白色圖示疊在產生的畫面上
STATUS_SRC = ('6. 加入購物車與結帳', 'IMG_7175.PNG', '表12-6-1 購物車.PNG')
STATUS_BAND = (40, 135)


def folders():
    return {int(d.split('.')[0]): d for d in os.listdir(ROOT) if os.path.isdir(os.path.join(ROOT, d)) and d[0].isdigit()}


def target_name(si, ti, caption):
    return f'表12-{si}-{ti} {caption}.PNG'


def status_source():
    folder, old, new = STATUS_SRC
    path = os.path.join(ROOT, folder, old)
    return Image.open(path if os.path.exists(path) else os.path.join(ROOT, folder, new)).convert('L')


def add_status_bar(img, src):
    out = img.convert('RGB')
    bg = src.getpixel((5, STATUS_BAND[0]))
    y0, y1 = STATUS_BAND
    for y in range(y0, y1):
        for x in range(src.width):
            v = src.getpixel((x, y))
            if v <= bg + 4:
                continue
            a = min(1.0, (v - bg) / (255 - bg))
            r, g, b = out.getpixel((x, y))
            out.putpixel((x, y), (round(r + (255 - r) * a), round(g + (255 - g) * a), round(b + (255 - b) * a)))
    return out


def rename(dark_dir):
    fs = folders()
    rows = []
    status = status_source()
    for si, (_, tables) in enumerate(SECTIONS, 1):
        for ti, (_, _, images, _) in enumerate(tables, 1):
            for src, caption in images:
                name = target_name(si, ti, caption)
                if si == 7:
                    os.makedirs(os.path.join(ROOT, SECTION7), exist_ok=True)
                    add_status_bar(Image.open(os.path.join(dark_dir, f'{src}.png')), status).save(os.path.join(ROOT, SECTION7, name))
                    rows.append((SECTION7, f'（App 截圖工具產生：{src}）', name))
                    continue
                folder = os.path.join(ROOT, fs[si])
                sub, _, base = src.rpartition('/')
                old = os.path.join(folder, sub, base + '.PNG')
                new = os.path.join(folder, sub, name)
                if os.path.exists(new) and not os.path.exists(old):
                    rows.append((fs[si], os.path.join(sub, base + '.PNG'), os.path.join(sub, name)))
                    continue
                assert not os.path.exists(new), new
                os.rename(old, new)
                rows.append((fs[si], os.path.join(sub, base + '.PNG'), os.path.join(sub, name)))
    with open(MAP, 'w', newline='', encoding='utf-8-sig') as f:
        w = csv.writer(f)
        w.writerow(['資料夾', '原檔名', '新檔名'])
        w.writerows(rows)
    print(f'改名 {len(rows)} 張，對照表：{MAP}')


def undo():
    with open(MAP, encoding='utf-8-sig') as f:
        rows = list(csv.reader(f))[1:]
    for folder, old, new in rows:
        if folder == SECTION7:
            continue
        a, b = os.path.join(ROOT, folder, new), os.path.join(ROOT, folder, old)
        if os.path.exists(a):
            os.rename(a, b)
    print('已還原')


def path_of(si, ti, caption):
    """改名後的檔案路徑（供 um_build.py 使用）。"""
    fs = {**folders(), 7: SECTION7}
    for dirpath, _, files in os.walk(os.path.join(ROOT, fs[si])):
        if target_name(si, ti, caption) in files:
            return os.path.join(dirpath, target_name(si, ti, caption))
    raise FileNotFoundError(target_name(si, ti, caption))


if __name__ == '__main__':
    undo() if sys.argv[1] == '--undo' else rename(sys.argv[1])
