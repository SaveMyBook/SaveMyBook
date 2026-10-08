#!/bin/zsh
# 子任務 D2 的 GIF／影片：錄製前把測試的時區調成「當下即 11:21」，畫面上的相對時間與時刻才會和狀態列的 11:22 一致；
# 逐段錄製後以 d2_build.py 合成。
# 用法：tool/deck_gifs/d2_run.sh [--video] [ai_recommend ai_advisor ai_support ai_dispute]
#   預設以 25 fps 錄製並輸出 GIF 到 素材/gif/；--video 以 60 fps 錄製並輸出 MP4 到 素材/video/。
set -e
export PYTHONDONTWRITEBYTECODE=1
cd "$(dirname "$0")/../.."
PY=/Users/xukaijun/Desktop/SaveMyBook/documents/系統手冊/產生工具/.venv/bin/python
ROOT=/private/tmp/claude-501/-Users-xukaijun-Desktop-SaveMyBook-savemybook-app/f52b6347-17b0-4b79-95e7-263531604b33/scratchpad/deck_gif/d2
video=0
if [[ "$1" == "--video" ]]; then video=1; shift; fi
if (( $# )); then names=("$@"); else names=(ai_recommend ai_advisor ai_support ai_dispute); fi
for name in $names; do
  now=$(date -u +%H:%M)
  diff=$(( (11 * 60 + 21) - (10#${now%:*} * 60 + 10#${now#*:}) ))
  (( diff > 840 )) && diff=$(( diff - 1440 ))
  (( diff <= -720 )) && diff=$(( diff + 1440 ))
  sign='-'; (( diff < 0 )) && { sign='+'; diff=$(( -diff )); }
  tz=$(printf 'GIF%s%02d:%02d' $sign $(( diff / 60 )) $(( diff % 60 )))
  echo "== $name（TZ=$tz）"
  if (( video )); then
    TZ=$tz D2_FPS=60 flutter test tool/deck_gifs/d2_gifs_test.dart --plain-name "$name" -r compact
    $PY tool/deck_gifs/d2_build.py "$ROOT/$name/frames60" "/Users/xukaijun/Desktop/SaveMyBook/presentation/複評/素材/video/$name.mp4" --video
  else
    TZ=$tz flutter test tool/deck_gifs/d2_gifs_test.dart --plain-name "$name" -r compact
    $PY tool/deck_gifs/d2_build.py "$ROOT/$name/frames" "/Users/xukaijun/Desktop/SaveMyBook/presentation/複評/素材/gif/$name.gif"
  fi
done
