#!/usr/bin/env bash
# 救「舊」我的書 介紹動畫第二版：音效時間、配音、配樂、混音、字幕與成品影片的完整產生流程
# 需求：先在 project 目錄 npm install 並開著 npm run dev（5291 埠）；本目錄建立 .venv（python3 -m venv .venv && .venv/bin/pip install -r requirements.txt）
# 用法：在此目錄執行 bash build.sh；成品輸出到 ../成品/（確認後再取代上層 成品/ 的第一版）
set -e
cd "$(dirname "$0")"
PY=.venv/bin/python
FF=$($PY -c "import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())")
DST="../成品"
BASE="四技第115414組-救「舊」我的書-介紹動畫"
mkdir -p stems out "$DST/分軌"

node ../tools/collide.mjs 0 999 1/60 | tail -1     # 1. 穿模檢查（必須 0 筆）
node ../tools/cues.mjs                               # 2. 各場景登記的卡點音效時間 → cues.json
$PY tts.py                                           # 3. 旁白（文字與時間在 ../src/timeline.json；沿用第一版錄音，新句子才產生）
$PY music.py                                         # 4. 配樂：曲風切換點對準換場
rm -f cue_boost.json                                 # 5. 音效＋混音，逐一檢查音效是否被音樂蓋住並補強
for i in 1 2 3; do $PY sfx.py; $PY mix.py; $PY autobal.py; done
$PY sfx.py; $PY mix.py
$PY make_fonts.py; $PY subs.py                       # 6. 中英字幕（ASS／SRT）

# 7. 4K60 畫面（逐格算圖）
# 4K 每個分頁約占 1GB 顯示記憶體，同時開 4 個會讓分頁當掉，所以只用 2 個
[ -f out/render4k.mp4 ] || node ../tools/render.mjs out/render4k.mp4 0 999 2 2

bash finish.sh                                       # 8. 合成成品
