#!/bin/sh
# 下載影片截圖用到的正式站照片（僅對 api.savemybook.today 做唯讀 GET，不登入）。
# 用法：sh tool/video_shots/fetch_photos.sh [資料夾]（預設與 video_host.dart 的 VIDEO_DATA 相同）
#   orig/：劇情書《HTML & CSS》（book 150）三張實拍照片的原檔，相機觀景窗與上架照片使用。
#   img/ ：real_data.g.dart 中所有書籍照片與頭像，縮至 900px 的 JPEG。
set -e
DIR="${1:-${VIDEO_DATA:-/private/tmp/claude-501/-Users-xukaijun-Desktop-SaveMyBook/a06bcee0-3b01-4abe-8aa7-42d6d03a9aa5/scratchpad/video_data}}"
API=https://api.savemybook.today
cd "$(dirname "$0")/../.."
mkdir -p "$DIR/orig" "$DIR/img"
for f in 1791302896072-6d924564a7d3648a 1791302896084-fdb0d922892321d0 1791302896096-aba5bdb957dd5b47; do
  out="$DIR/orig/uploads_books_$f.png"
  [ -f "$out" ] || curl -sf -m 90 "$API/uploads/books/$f.png" -o "$out"
done
grep -oE '/uploads/(books|avatars)/[A-Za-z0-9._-]+' tool/manual_shots/real_data.g.dart | sort -u | while read -r u; do
  stem="$DIR/img/$(echo "$u" | sed 's#^/##; s#/#_#g')"
  jpg="${stem%.*}.jpg"
  [ -f "$jpg" ] && continue
  curl -sf -m 90 "$API$u" -o "$stem" && sips -s format jpeg -s formatOptions 85 -Z 900 "$stem" --out "$jpg" >/dev/null 2>&1 && rm -f "$stem"
done
echo "照片已存於 $DIR"
