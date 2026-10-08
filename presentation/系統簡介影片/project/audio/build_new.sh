#!/usr/bin/env bash
# 救「舊」我的書 系統簡介影片：旁白、時間軸、字幕、配樂、音效、混音、4K 算圖與成品的完整產生流程。
# 需求：project 目錄已 npm install 並開著 npm run dev（5291 埠）；本目錄已有 .venv（requirements.txt）。
# 用法：在此目錄執行 bash build_new.sh（已有 out/render4k.mp4 時跳過算圖；要重算請先刪除）
set -e
cd "$(dirname "$0")"
PY=.venv/bin/python
export FFMPEG=$($PY -c "import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())")
mkdir -p stems out

$PY tts_new.py                                       # 1. 旁白（Seraphina，語速 +5%；文字在 narration.json，未變更的句子沿用快取）
$PY timeline_new.py                                  # 2. 時間軸 → ../src/timeline.json、out/line_starts.json
$PY subs_new.py --timeline out/line_starts.json      # 3. 字幕（微軟正黑體 Bold，白字黑框，置底）→ out/subs.ass、out/subs.srt
$PY tts_meta_new.py                                  # 4. 旁白片段與起訖時間 → tts/meta.json（給 mix.py）
node ../tools/cues.mjs                               # 5. 各場景登記的卡點音效時間 → cues.json
$PY music.py                                         # 6. 配樂：曲風切換點對準章節換場
rm -f cue_boost.json                                 # 7. 音效＋混音，逐一檢查音效是否被音樂蓋住並補強
for i in 1 2 3; do $PY sfx.py; $PY mix.py; $PY autobal.py; done
$PY sfx.py; $PY mix.py

# 8. 4K60 畫面（pixelRatio 2；4K 每個分頁約占 1GB 顯示記憶體，只開 2 個；動態模糊取樣上限 24）
[ -f out/render4k.mp4 ] || node ../tools/render.mjs out/render4k.mp4 0 999 2 2 24

bash finish_new.sh                                   # 9. 合成成品（4K 與 1080p，皆燒入字幕）
