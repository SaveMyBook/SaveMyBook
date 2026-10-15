"""下載手冊／簡報錄製用到的正式站照片（僅對 api.savemybook.today 的公開 /uploads 做唯讀 GET，不登入），
與 tool/video_shots/fetch_photos.sh 的 img/ 相同：real_data.g.dart 中所有書籍照片與頭像，縮至長邊 900px 的 JPEG（品質 85）。
fetch_photos.sh 以 macOS 的 sips 轉檔，這支改用 Pillow，Windows 也能執行。

用法：python fetch_photos.py <資料夾>     照片存到 <資料夾>/img/，即 manual_host.dart 的 MANUAL_DATA
"""
import io
import os
import re
import sys
import urllib.request

from PIL import Image, ImageOps

API = 'https://api.savemybook.today'
HERE = os.path.dirname(os.path.abspath(__file__))
REAL_DATA = os.path.join(HERE, '..', 'manual_shots', 'real_data.g.dart')


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    out = os.path.join(sys.argv[1], 'img')
    os.makedirs(out, exist_ok=True)
    with open(REAL_DATA, encoding='utf-8') as f:
        urls = sorted(set(re.findall(r'/uploads/(?:books|avatars)/[A-Za-z0-9._-]+', f.read())))
    got = skipped = failed = 0
    for u in urls:
        stem = u.lstrip('/').replace('/', '_')
        jpg = os.path.join(out, os.path.splitext(stem)[0] + '.jpg')
        if os.path.exists(jpg):
            skipped += 1
            continue
        try:
            # 正式站擋 Python 預設的 User-Agent（403），比照 fetch_photos.sh 以 curl 的 User-Agent 請求
            req = urllib.request.Request(API + u, headers={'User-Agent': 'curl/8.9.1'})
            with urllib.request.urlopen(req, timeout=90) as r:
                data = r.read()
        except Exception as e:  # noqa: BLE001
            print(f'略過 {u}：{e}')
            failed += 1
            continue
        im = ImageOps.exif_transpose(Image.open(io.BytesIO(data))).convert('RGB')
        k = 900 / max(im.size)
        if k != 1:
            im = im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)
        im.save(jpg, quality=85)
        got += 1
    print(f'照片存於 {out}：新下載 {got}、已存在 {skipped}、失敗 {failed}（共 {len(urls)}）')


if __name__ == '__main__':
    main()
