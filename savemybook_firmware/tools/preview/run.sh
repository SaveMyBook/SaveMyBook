#!/usr/bin/env bash
# 在電腦上編譯畫面預覽並輸出 out/sheet.png（需先執行過一次 pio run，讓 managed_components 下載 qrcode 元件）。
set -e
cd "$(dirname "$0")"
FW=../..
QR=$FW/managed_components/espressif__qrcode
mkdir -p out build
clang -c -O1 -I$FW/src $FW/src/fonts.c -o build/fonts.o
clang -c -O1 -Istub -I$QR $QR/qrcodegen.c -o build/qrcodegen.o
clang++ -std=c++20 -O1 -Istub -I$FW/src -I$QR/include -I$QR \
  $FW/src/canvas.cpp $FW/src/ui.cpp $FW/src/demo.cpp host_qrcode.cpp preview.cpp build/fonts.o build/qrcodegen.o -o build/preview
./build/preview out
python3 sheet.py out
