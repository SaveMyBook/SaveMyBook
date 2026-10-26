#!/usr/bin/env bash
# v3（NTUB_SIS 風格）成品流程：檢查、卡點音效、混音、字幕、4K60 逐段算圖、合成。旁白、時間軸與配樂沿用 build_new.sh 的結果（不重產）。
# 需求：project 目錄已 npm install 並開著 npm run dev（5291 埠）；本目錄已有 .venv（requirements.txt）。
# 用法（在本目錄）：
#   bash build_v3.sh                 全部：檢查 → 音效與混音 → 字幕 → 逐段算圖 → 合成
#   bash build_v3.sh audio           只重做卡點音效、混音與字幕
#   bash build_v3.sh render [段落…]  只重算指定段落（例如 render cabinet after），再接成整片
#   bash build_v3.sh finish          只合成成品
# 4K 畫面以段落為單位存在 out/v3seg/（每段一個檔，交界依 60fps 取整，前後相接），修改某段後只需重算該段。
set -e
cd "$(dirname "$0")"
PY=.venv/bin/python
MODE=${1:-all}
Q4K='v3&nosub&sh=180'

audio() {
  Q=v3 node ../tools/cues.mjs                                # 各段登記的卡點音效（v3 場景）→ cues.json
  rm -f cue_boost.json                                       # 音效＋混音，逐一檢查音效是否被音樂蓋住並補強
  for i in 1 2 3; do $PY sfx.py; $PY mix.py; $PY autobal.py; done
  $PY sfx.py; $PY mix.py
  $PY subs_v3.py                                             # 中文、中英字幕（v3 樣式）→ out/subs_v3_*.ass／srt
}

render() {
  mkdir -p out/v3seg
  local ids=("$@")
  # 段落起訖取自 timeline.json；render.mjs 以 round(秒 × 60) 取格，相鄰兩段的交界取同一格，接起來不重複也不缺格
  $PY - "${ids[@]}" <<'PY' > out/v3seg/plan.txt
import json, sys
tl = json.load(open('../src/timeline.json', encoding='utf-8'))
want = set(sys.argv[1:])
secs = tl['sections']
for i, s in enumerate(secs):
    end = secs[i + 1]['start'] if i + 1 < len(secs) else tl['duration']
    if not want or s['id'] in want:
        print(f"{i:02d}_{s['id']} {s['start']} {end}")
PY
  while read -r name a b; do
    echo "算圖 $name（$a–$b 秒）"
    Q="$Q4K" node ../tools/render.mjs "out/v3seg/$name.mp4" "$a" "$b" 2 2 24
  done < out/v3seg/plan.txt
  FF=$($PY -c "import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())")
  ls out/v3seg/*.mp4 | sort | sed "s/^/file '/; s/$/'/" | sed "s#file 'out/v3seg/#file '#" > out/v3seg/list.txt
  (cd out/v3seg && "$FF" -hide_banner -loglevel error -y -f concat -safe 0 -i list.txt -c copy -movflags +faststart ../render4k_v3.mp4)
  "$FF" -hide_banner -i out/render4k_v3.mp4 2>&1 | grep -E "Duration|Video:"
}

case "$MODE" in
  all)
    Q=v3 node ../tools/collide.mjs 0 999 1/60 | tail -1        # 穿模檢查（必須 0 筆）
    audio
    rm -f out/v3seg/*.mp4
    render
    bash finish_v3.sh ;;
  audio) audio ;;
  render) shift; render "$@" ;;
  finish) bash finish_v3.sh ;;
  *) echo "未知的模式：$MODE"; exit 1 ;;
esac
