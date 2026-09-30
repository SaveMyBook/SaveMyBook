#!/usr/bin/env bash
# 救「舊」我的書 介紹動畫：配音、配樂、卡點音效、字幕與成品影片的完整產生流程
# 需求：Python（pip install -r requirements.txt）、Node（上層 src 已 npm install）
# 用法：在此目錄執行 bash build.sh；成品輸出到 ../../成品/
set -e
cd "$(dirname "$0")"
FF=$(python -c "import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())")
SVG="../../四技第115414組-救「舊」我的書-介紹動畫.svg"
DST="../../成品"
BASE="四技第115414組-救「舊」我的書-介紹動畫"
mkdir -p stems out "$DST/分軌"

node cues.js                                   # 1. 由動畫原始碼推導 375 個音效時間點
[ -f tts/meta.json ] || python tts.py          # 2. 旁白（旁白稿在 script.py；已有 mp3 就沿用）
python music.py                                # 3. 配樂（MIXPOP：10 段曲風，切換點對準換場）
rm -f cue_boost.json                           # 4. 音效 + 混音，逐一檢查音效是否被音樂蓋住並補強
for i in 1 2 3; do python sfx.py; python mix.py; python autobal.py; done
python sfx.py; python mix.py
python make_fonts.py; python subs.py           # 5. 中英字幕（ASS／SRT）

# 6. 4K60 畫面（逐格算圖，約 10 分鐘）
[ -f out/render4k.mp4 ] || node ../tools/render.js "$SVG" out/render4k.mp4 6 60

# 7. 成品：音量標準化到 -16 LUFS 後合成，再輸出 1080p 與字幕版
I=$("$FF" -hide_banner -i out/mix.wav -af loudnorm=I=-16:TP=-1.5:print_format=json -f null - 2>&1 | grep input_i | grep -o '\-[0-9.]*')
GAIN=$(python -c "print(round(-16 - ($I), 2))")
TAGS="-colorspace bt709 -color_primaries bt709 -color_trc bt709 -color_range tv -movflags +faststart"
"$FF" -hide_banner -loglevel error -y -i out/render4k.mp4 -i out/mix.wav -map 0:v -map 1:a -c:v copy \
  -af "volume=${GAIN}dB,alimiter=limit=0.84:level=false" -c:a aac -b:a 320k -ar 48000 -movflags +faststart -shortest "$DST/$BASE-4K60.mp4"
"$FF" -hide_banner -loglevel error -y -i "$DST/$BASE-4K60.mp4" -map 0 -vf "scale=1920:1080:flags=lanczos,format=yuv420p" \
  -c:v libx264 -preset slow -crf 16 -r 60 $TAGS -c:a copy "$DST/$BASE-1080p60.mp4"
cp "out/字幕_中英.ass" out/subs.ass
"$FF" -hide_banner -loglevel error -y -i "$DST/$BASE-4K60.mp4" -map 0 -vf "scale=1920:1080:flags=lanczos,ass=out/subs.ass:fontsdir=fonts,format=yuv420p" \
  -c:v libx264 -preset slow -crf 16 -r 60 $TAGS -c:a copy "$DST/$BASE-1080p60-中英字幕.mp4"
"$FF" -hide_banner -loglevel error -y -i "$DST/$BASE-4K60.mp4" -map 0 -vf "ass=out/subs.ass:fontsdir=fonts,format=yuv420p" \
  -c:v libx264 -preset medium -crf 16 -level 5.2 -r 60 $TAGS -c:a copy "$DST/$BASE-4K60-中英字幕.mp4"
cp "out/字幕_中英.srt" "$DST/"
for f in 旁白 配樂 音效; do "$FF" -hide_banner -loglevel error -y -i "out/$f.wav" -c:a pcm_s16le "$DST/分軌/$f.wav"; done
echo "完成：$DST"
