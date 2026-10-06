# 智慧書櫃韌體（ESP32-S3）

一片 ESP32-S3 控制四扇櫃門的電磁鎖與 2.8 吋橫向螢幕，透過 HTTPS 與後端同步。協定見 `savemybook_api/docs/device.yaml`。

裝置邏輯從模擬書櫃 `savemybook_api/views/kiosk/device-core.js` 移植，兩邊行為一致，包含以微動開關偵測櫃門開關（門磁）。

![各畫面預覽](docs/screens.png)

## 硬體

| 元件 | 規格 | 數量 |
|---|---|---|
| 開發板 | GOOUUU ESP32-S3（與 YD-ESP32-S3、ESP32-S3-DevKitC-1 同腳位，Flash 4 MB 以上） | 1 |
| 螢幕 | 2.8 吋 SPI TFT 240×320，ST7789（排線印 TPM408-2.8，TN 面板）；附觸控與 SD 卡座，兩者都不接 | 1 |
| 電磁鎖 | 12V 0.6A，通電開鎖、斷電上鎖 | 4 |
| 四路繼電器模組 | 5V 線圈、光耦隔離，低電平觸發 | 1 |
| 24V 電源供應器 | 3A | 1 |
| 穩壓 IC | 7812（24V 轉 12V，供電磁鎖與 7805）、7805（12V 轉 5V，供開發板、繼電器與螢幕），各加散熱片 | 各 1 |
| 陶瓷電容 | 0.33µF（7812、7805 輸入端）、0.1µF（輸出端），貼近腳位 | 各 2 |
| 整流二極體 | 1N4007 | 4 |
| 保險絲與座 | 2A 慢熔 | 1 |
| 電解電容 | 1000µF 50V（24V 端，耐壓須 35V 以上）、470µF 10V（5V 端） | 各 1 |
| 微動開關 | MATRIX 微動開關 V3（MS-004V3，JST，GND／VCC／OUT／反相 OUT），門關上時壓下 | 4 |

## 接線

| 元件 | 模組腳位 | 接到 | 說明 |
|---|---|---|---|
| 7812 | IN／GND／OUT | 24V＋（保險絲後）／GND／12V＋ | 12V＋ 供繼電器 COM 與 7805；電磁鎖通電時約 7W 熱，須加散熱片 |
| 7805 | IN／GND／OUT | 12V＋／GND／5V | 5V 接開發板 5V、繼電器 VCC、螢幕 VCC；持續約 2W 熱，須加散熱片 |
| 四路繼電器 | VCC、JD-VCC | 5V | JD-VCC 跳帽保留 |
| | GND | GND | |
| | IN1–IN4 | GPIO4、5、6、7 | 對應櫃門 A01–A04 |
| | COM1–COM4 | 12V＋（7812 輸出） | |
| | NO1–NO4 | 電磁鎖 1–4 正極 | NC 不接 |
| 電磁鎖 | 負極 | GND | 每顆並聯 1N4007，有白線的一端（陰極）接正極 |
| TFT | VCC／GND | 5V／GND | 模組上有 3.3V 穩壓；只插 USB 測試時改接 3V3 |
| | CS／DC／RESET | GPIO10／9／8 | |
| | SDI（MOSI）／SCK | GPIO11／12 | |
| | LED | GPIO13 | 背光以 PWM 調亮度（管理後台設定）；模組 LED 腳沒有電晶體（板上標 Q1）時要另加電晶體，背光電流超過 GPIO 上限 |
| | SDO、觸控 T_*、SD 卡 | 不接 | 書櫃螢幕只顯示、不提供操作 |
| 微動開關 ×4 | VCC／GND | 3V3／GND | **不可接 5V**，ESP32 腳位只能承受 3.3V |
| | OUT | GPIO39、40、41、42 | 對應櫃門 A01–A04，在右側排針；反相 OUT 不接 |

- 所有 GND 接在一起：24V 負極、7812、7805、開發板、繼電器、螢幕、微動開關。
- 7812 與 7805 是線性穩壓，多出的電壓都變成熱：兩顆都要加散熱片，櫃體內要留通風，散熱片不可碰到其他線路。
- 用到的腳位都在有 5V、3V3 的那一排排針上。
- 避開的腳位：
  - GPIO0、3、45、46（開機設定）
  - GPIO19、20（USB）
  - GPIO26–37（Flash 與 PSRAM）
  - GPIO43、44（序列埠）
- 開發板的 5V 腳預設只能輸入，不要短接板上的 IN-OUT 焊點：短接後 7805 的 5V 會倒灌進電腦的 USB。

### 安全設計

- **一次只讓一顆鎖通電**：韌體逐扇開鎖，前一扇斷電 300 毫秒後才對下一扇通電，12V 只需扛一顆鎖的 0.6A。
- **用 NO 接點**：停電或繼電器故障時，門維持上鎖。
- **開機不誤開**：GPIO4–7 在重開機期間是高阻抗，低電平觸發的繼電器不會吸合。韌體開機第一件事是先把腳位寫成斷電，再切成輸出。看門狗重置時也一樣。
- **通電時間**：每次開鎖通電 3 秒，以 `unlock_pulse_ms` 回報後端。櫃門沒有彈簧，使用者要在這段時間內拉開；韌體把通電限制在 100–3000 毫秒，避免線圈過熱。
- **反向二極體與電容**：吸收鎖斷電時的反向電壓，鎖通電的瞬間也不會讓 ESP32 掉電重開。

## 開發環境

使用 PlatformIO 加 ESP-IDF 6.1。
- 可以裝 VS Code 的 PlatformIO 擴充套件，或用命令列 `pio`。
- 第一次編譯會自動下載 ESP-IDF 與編譯器，約 6.6 GB，放在 `~/.platformio`。
- 燒錄與看紀錄用板子上標 COM 的那個 USB-C（CH343 序列埠）。

```bash
pio run -e esp32s3
```

| 指令 | 用途 |
|---|---|
| `pio run -e hwtest -t upload` | 燒錄硬體測試版 |
| `pio run -e esp32s3 -t upload` | 燒錄正式版 |
| `pio device monitor` | 看序列埠紀錄 |
| `pio run -e esp32s3 -t menuconfig` | 修改設定（在「SaveMyBook cabinet」選單） |

設定選項：

| 選項 | 預設 | 說明 |
|---|---|---|
| Device API base URL | `https://api.savemybook.today/api/device/v1` | 後端位址 |
| Relay module is low-level triggered | 開 | 繼電器若為高電平觸發，關閉此項 |
| Screen rotation | 3 | 橫向為 1 或 3，依螢幕排針朝哪一側裝設；畫面上下顛倒時改另一個 |
| Panel controller is ILI9341 | 關 | 目前的螢幕是 ST7789；換成 ILI9341 的螢幕時開啟。晶片設錯時畫面不會轉成橫向，下方四分之一是雜訊 |
| Invert panel colors | 關 | 顏色反相（黑底變白底）時切換；IPS 面板通常要開 |
| Mirror the screen horizontally | 開 | 字左右相反時切換 |
| Screen SPI clock (MHz) | 10 | 杜邦線接到 40 MHz 會整面亂碼；改用短排線或焊接後可調高 |
| Door switches installed | 開 | 沒有裝微動開關時關閉，否則空腳位會被當成門開著 |
| Door switch output level when the door is closed | 0 | 門關上時 OUT 的電位；門磁測試版顯示相反時改成 1 |

## 第一次上機

1. **硬體測試**（不連網路）：燒錄 `hwtest`。
   - 開機後 5 秒內繼電器都不能吸合。
   - 接著 IN1 到 IN4 逐顆通電 0.8 秒。
   - 之後螢幕輪播各畫面，確認方向、顏色與中文字。
   - 螢幕碰到就黑掉或變白是接觸不良，電磁鎖動作時變白是突波：韌體在電磁鎖動作後與每 10 秒會重送螢幕設定並整面重畫，會自己恢復。根本解法是每顆鎖都並聯二極體、鎖的線不要和螢幕的線綁在一起，長期安裝改成焊接或用有卡榫的端子。
   - 繼電器若在開機時就吸合，或燈微亮，表示模組不適合直接用 3.3V 驅動：有 H/L 跳帽就切到 H，並關閉「Relay module is low-level triggered」。
2. **接上電磁鎖再測一次**：量 12V 在通電時的壓降，確認開發板不會重開。
   - 建議先只接一顆。只測單一櫃門時，用下面的指令燒錄（數字為櫃門 1–4）。每約 7 秒開鎖 0.8 秒，不輪播畫面：
     ```bash
     PLATFORMIO_BUILD_FLAGS="-DSMB_HW_TEST_DOOR=1" pio run -e hwtest -t upload
     ```
   - 四扇輪流但不輪播畫面（約 12 秒一輪，方便觀察繼電器）：
     ```bash
     PLATFORMIO_BUILD_FLAGS="-DSMB_HW_TEST_RELAY_ONLY=1" pio run -e hwtest -t upload
     ```
   - 門磁測試（不開鎖，即時顯示四個微動開關的狀態與原始電位）：
     ```bash
     PLATFORMIO_BUILD_FLAGS="-DSMB_HW_TEST_DOORS=1" pio run -e hwtest -t upload
     ```
3. **燒錄正式版並設定 Wi-Fi**：
   - 螢幕會顯示 Wi-Fi 設定用的 QR Code。
   - 用手機安裝 Espressif 官方的「ESP BLE Provisioning」App，掃描後選擇網路並輸入密碼。
   - 設定密碼每次開機隨機產生，只出現在螢幕上，必須在書櫃前才能設定。
   - 已設定的網路連不上超過 2 分鐘，螢幕會自動顯示 Wi-Fi 設定的 QR Code（櫃體封起來後不必按按鈕），同時每分鐘再試一次原本的網路，連回去就自動結束設定。
   - 也可以按住板上的 BOOT 鍵 5 秒，清除 Wi-Fi 設定並重新開機，裝置憑證保留。
4. **配對**：
   - 連上網路後，螢幕顯示 8 位數配對碼。
   - 管理員在後台「書櫃裝置」輸入配對碼即可，書櫃上不需操作。
   - 配對成功後螢幕改顯示書櫃 QR Code。

## 在電腦上檢查

兩個工具都直接使用 `src/` 的程式碼，需先執行過一次 `pio run`，讓 `managed_components` 下載 cJSON 與 qrcode 元件。

```bash
bash tools/preview/run.sh
```

- **`tools/preview/run.sh`**：輸出各畫面的實際像素到 `tools/preview/out/sheet.png`，需要 Python 的 Pillow。
- **`tools/devtest/run.sh`**：書櫃邏輯測試。`device.cpp` 原封不動，接上依協定寫的模擬伺服器，以真實時間執行。涵蓋的情境：
  - 配對
  - 逐扇開鎖與 300 毫秒間隔
  - 重複指令不重複執行
  - 手機完成或取消
  - 倒數逾時
  - 往返超過 3 秒不開鎖
  - 憑證撤銷後重新配對
  - 開門中斷電重開
  - 斷線與恢復

```bash
bash tools/devtest/run.sh
```

修改 `src/messages.h` 的字串後，要執行 `python3 tools/make_fonts.py` 重新產生 `src/fonts.c`。字型只收錄用到的字，取自 App 的 Noto Sans TC。

## 程式結構

| 檔案 | 內容 |
|---|---|
| `src/main.cpp` | 開機順序、畫面工作、BOOT 鍵、硬體測試 |
| `src/device.cpp` | 書櫃邏輯：配對、開機代碼、輪詢、事件佇列、開鎖、倒數與結束作業 |
| `src/http.cpp` | HTTPS 長連線，以 ESP-IDF 內建憑證套件驗證伺服器 |
| `src/wifi.cpp` | Wi-Fi 與藍牙設定（Security 2） |
| `src/store.cpp` | NVS：憑證放 `nvs` 分區，事件佇列放獨立的 `evq` 分區分散磨耗 |
| `src/relay.cpp` | 繼電器；門磁顯示門已拉開時提早斷電 |
| `src/door.cpp` | 微動開關（門磁）去彈跳 |
| `src/clock.cpp` | 以後端回應的 Date 標頭校時，標題列顯示臺灣時間 |
| `src/display.cpp`、`src/canvas.cpp`、`src/ui.cpp` | 螢幕驅動、繪圖與各畫面版面 |
| `src/messages.h` | 螢幕字串表（與模擬書櫃相同） |

## 尚未啟用

協定要求的 **Flash 加密** 與 **NVS 加密** 還沒有開。開啟後會燒錄 ESP32-S3 的 eFuse，無法復原，也會限制之後重新燒錄的方式。實機測試穩定、準備上線時再啟用。
