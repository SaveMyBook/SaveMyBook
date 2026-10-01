#!/bin/zsh
# 用法：cabdiag/render.sh 檔.puml ...（於任一目錄執行）；繪製 PNG 並以 a4check 檢查，ER 圖用 --font 12
SP=/private/tmp/claude-501/-Users-xukaijun-Desktop-SaveMyBook-savemybook-app/b64bf336-665e-4e2b-bbb0-e6a209798611/scratchpad
java -Djava.awt.headless=true -jar $SP/plantuml.jar -charset UTF-8 -tpng "$@" 2>&1 | grep -v '^$'
for f in "$@"; do
  png=${f%.puml}.png
  if grep -q 'defaultFontSize 12' "$f"; then font=12; elif grep -q 'defaultFontSize 14' "$f"; then font=14; else font=13; fi
  $SP/docenv/bin/python $SP/a4check.py --font $font "$png" | sed "s#$SP/##"
done
