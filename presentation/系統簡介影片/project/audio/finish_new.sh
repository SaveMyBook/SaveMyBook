#!/usr/bin/env bash
# 合成成品：混音標準化到 -14 LUFS（真峰值 -1.5 dBTP），與 4K 畫面合成並燒入字幕；1080p 版由 4K 以 lanczos 縮圖。
# 需先有 out/render4k.mp4、out/mix.wav、out/subs.ass（由 build_new.sh 產生）。
set -e
cd "$(dirname "$0")"
PY=.venv/bin/python
FF=$($PY -c "import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())")
DST="../../成品"
BASE="四技第115414組-救「舊」我的書-系統簡介影片"
mkdir -p "$DST/分軌"
I=$("$FF" -hide_banner -i out/mix.wav -af loudnorm=I=-14:TP=-1.5:print_format=json -f null - 2>&1 | grep input_i | grep -o '\-[0-9.]*')
GAIN=$($PY -c "print(round(-14 - ($I), 2))")
"$FF" -hide_banner -loglevel error -y -i out/mix.wav -af "volume=${GAIN}dB,alimiter=limit=0.84:level=false" -ar 48000 -c:a pcm_s16le out/master.wav
TAGS="-colorspace bt709 -color_primaries bt709 -color_trc bt709 -color_range tv -movflags +faststart"
# 4K（燒入字幕；ASS 以 1920×1080 為基準，libass 會等比放大）
"$FF" -hide_banner -loglevel error -y -i out/render4k.mp4 -i out/master.wav -map 0:v -map 1:a \
  -vf "ass=out/subs.ass:fontsdir=fonts,format=yuv420p" -c:v libx264 -preset slow -crf 14 -level 5.2 -r 60 $TAGS \
  -c:a aac -b:a 320k -ar 48000 -shortest "$DST/$BASE-4K.mp4"
# 1080p（由 4K 母帶縮圖後燒入字幕）
"$FF" -hide_banner -loglevel error -y -i out/render4k.mp4 -i out/master.wav -map 0:v -map 1:a \
  -vf "scale=1920:1080:flags=lanczos,ass=out/subs.ass:fontsdir=fonts,format=yuv420p" -c:v libx264 -preset slow -crf 15 -r 60 $TAGS \
  -c:a aac -b:a 320k -ar 48000 -shortest "$DST/$BASE.mp4"
cp out/subs.srt "$DST/$BASE-字幕.srt"
for f in 旁白 配樂 音效; do "$FF" -hide_banner -loglevel error -y -i "out/$f.wav" -c:a pcm_s16le "$DST/分軌/$f.wav"; done
for f in "$DST/$BASE.mp4" "$DST/$BASE-4K.mp4"; do "$FF" -hide_banner -i "$f" 2>&1 | grep -E "Duration|Video:" ; done
"$FF" -hide_banner -i "$DST/$BASE.mp4" -af ebur128=peak=true -f null - 2>&1 | grep -E "^\s+(I|True peak|Peak):" | head -3
echo "完成：$DST"
