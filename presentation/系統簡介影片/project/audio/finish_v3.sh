#!/usr/bin/env bash
# v3 成品合成：混音標準化到 -14 LUFS（真峰值 -1.5 dBTP），與 4K 畫面合成並燒入 v3 字幕（深色字、字重 500、極淡白色柔光）。
# 產出：4K（中文字幕）、1080p（中文字幕）、1080p 與 4K 中英字幕版、中文與中英 SRT、分軌。1080p 由 4K 以 lanczos 縮圖。
# 需先有 out/render4k_v3.mp4、out/mix.wav、out/subs_v3_zh.ass、out/subs_v3_zhen.ass（由 build_v3.sh 產生）。
set -e
cd "$(dirname "$0")"
PY=.venv/bin/python
FF=$($PY -c "import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())")
DST="../../成品"
BASE="四技第115414組-救「舊」我的書-系統簡介影片"
# 字幕字型：蘋方（macOS 內建，以連結放在 out/ 下，不進版控）
PF=$(ls /System/Library/AssetsV2/com_apple_MobileAsset_Font*/*/AssetData/PingFang.ttc 2>/dev/null | head -1)
[ -n "$PF" ] || { echo "找不到 PingFang.ttc"; exit 1; }
mkdir -p out/fonts_v3 "$DST/分軌"
ln -sf "$PF" out/fonts_v3/PingFang.ttc
I=$("$FF" -hide_banner -i out/mix.wav -af loudnorm=I=-14:TP=-1.5:print_format=json -f null - 2>&1 | grep input_i | grep -o '\-[0-9.]*')
GAIN=$($PY -c "print(round(-14 - ($I), 2))")
"$FF" -hide_banner -loglevel error -y -i out/mix.wav -af "volume=${GAIN}dB,alimiter=limit=0.84:level=false" -ar 48000 -c:a pcm_s16le out/master.wav
TAGS="-colorspace bt709 -color_primaries bt709 -color_trc bt709 -color_range tv -movflags +faststart"
ENC4K="-c:v libx264 -preset slow -crf 14 -level 5.2 -r 60 -threads 3"
ENC1080="-c:v libx264 -preset slow -crf 15 -r 60 -threads 3"
AUD="-map 1:a -c:a aac -b:a 320k -ar 48000 -shortest"
# 同一種字幕的 4K 與 1080p 在同一個程序輸出（4K 畫面只解碼一次）；先寫到 out/final/，全部完成後才搬進成品資料夾，中斷時成品資料夾不會留下殘檔。
# 降低優先權、每個編碼器限 3 執行緒（兩個編碼器同時跑，8 核心的電腦 1 分鐘負載約 8），算圖期間電腦仍可正常操作。
mkdir -p out/final
mk() {  # mk <字幕檔> <4K 輸出> <1080p 輸出>
  nice -n 10 "$FF" -hide_banner -loglevel error -y -threads 2 -i out/render4k_v3.mp4 -i out/master.wav -filter_threads 2 -filter_complex \
    "[0:v]split=2[a][b];[a]ass=$1:fontsdir=out/fonts_v3,format=yuv420p[v4];[b]scale=1920:1080:flags=lanczos,ass=$1:fontsdir=out/fonts_v3,format=yuv420p[v2]" \
    -map "[v4]" $AUD $ENC4K $TAGS "$2" \
    -map "[v2]" $AUD $ENC1080 $TAGS "$3"
}
mk out/subs_v3_zh.ass "out/final/$BASE-4K.mp4" "out/final/$BASE.mp4"
mk out/subs_v3_zhen.ass "out/final/$BASE-4K-中英字幕.mp4" "out/final/$BASE-中英字幕.mp4"
for f in "$BASE-4K.mp4" "$BASE.mp4" "$BASE-中英字幕.mp4" "$BASE-4K-中英字幕.mp4"; do mv -f "out/final/$f" "$DST/$f"; done
cp out/subs_v3_zh.srt "$DST/$BASE-字幕.srt"
cp out/subs_v3_zhen.srt "$DST/$BASE-中英字幕.srt"
for f in 旁白 配樂 音效; do "$FF" -hide_banner -loglevel error -y -i "out/$f.wav" -c:a pcm_s16le "$DST/分軌/$f.wav"; done
for f in "$DST/$BASE-4K.mp4" "$DST/$BASE.mp4" "$DST/$BASE-中英字幕.mp4" "$DST/$BASE-4K-中英字幕.mp4"; do "$FF" -hide_banner -i "$f" 2>&1 | grep -E "Duration|Video:"; done
nice -n 10 "$FF" -hide_banner -threads 4 -i "$DST/$BASE.mp4" -af ebur128=peak=true -f null - 2>&1 | grep -E "^\s+(I|Peak):" | head -3
echo "完成：$DST"
