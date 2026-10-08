#!/usr/bin/env bash
# 合成成品：音量標準化到 -16 LUFS 後與 4K 畫面合成，再輸出 1080p、中英字幕版與分軌。
# 需先有 out/render4k.mp4、out/mix.wav、out/字幕_中英.ass（由 build.sh 產生）。
set -e
cd "$(dirname "$0")"
PY=.venv/bin/python
FF=$($PY -c "import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())")
DST="../成品"
BASE="四技第115414組-救「舊」我的書-介紹動畫"
mkdir -p "$DST/分軌"
I=$("$FF" -hide_banner -i out/mix.wav -af loudnorm=I=-16:TP=-1.5:print_format=json -f null - 2>&1 | grep input_i | grep -o '\-[0-9.]*')
GAIN=$($PY -c "print(round(-16 - ($I), 2))")
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
