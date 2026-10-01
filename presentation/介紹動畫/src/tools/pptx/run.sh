#!/bin/bash
# 由介紹動畫產生可編輯的 PowerPoint：bash tools/pptx/run.sh [輸出檔]
# 流程：建置帶文字標記的 SVG → 量測畫面變化 → 挑選投影片時間點 → 定格讀出物件 → 轉成 .pptx
set -euo pipefail
cd "$(dirname "$0")/../.."
OUT="${1:-../四技第115414組-救「舊」我的書-介紹動畫.pptx}"
WORK="${WORK:-$(mktemp -d)}"
mkdir -p "$WORK"
SVG_TAG_TEXT=1 SVG_OUT="$WORK/tagged.svg" node build.js full
node tools/pptx/motion.js "$WORK/tagged.svg" "$WORK/motion.json" 10
node tools/pptx/keyframes.js "$WORK/motion.json" "$WORK/keys.json"
node tools/pptx/extract.js "$WORK/tagged.svg" "$WORK/keys.json" "$WORK/frames.json"
node tools/pptx/build.js "$WORK/frames.json" "$WORK/keys.json" "$OUT"
