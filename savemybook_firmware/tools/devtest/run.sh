#!/usr/bin/env bash
# 在電腦上執行書櫃邏輯測試（需先執行過一次 pio run，讓 managed_components 下載 cJSON 元件）。
set -e
cd "$(dirname "$0")"
FW=../..
CJ=$FW/managed_components/espressif__cjson/cJSON
mkdir -p build
clang -c -O1 -I$CJ $CJ/cJSON.c -o build/cJSON.o
clang++ -std=c++20 -O1 -g -pthread -Istub -I$FW/src -I$CJ $FW/src/device.cpp host.cpp devtest.cpp build/cJSON.o -o build/devtest
clang++ -std=c++20 -O1 -g -pthread -DCONFIG_SMB_DOOR_SENSOR=1 -DCONFIG_SMB_DOOR_CLOSED_LEVEL=0 -Istub -I$FW/src -I$CJ \
  $FW/src/device.cpp host.cpp devtest.cpp build/cJSON.o -o build/devtest_sensor
status=0
for s in flow reboot offline; do ./build/devtest $s || status=1; done
./build/devtest_sensor sensor || status=1
exit $status
