# 救「舊」我的書 介紹動畫（第二版）

以 three.js 繪製立體手機與智慧書櫃，App 畫面取自 Flutter 實際渲染，文字疊在畫面上方；每一格由瀏覽器依時間算圖後交給 ffmpeg 編碼成 4K60。

## 開發與預覽

```bash
npm install
npm run dev        # http://127.0.0.1:5290/ ，下方有播放鍵與時間軸，可加 ?t=秒數 直接跳到某一格
```

- 敘事：跟著一本書走完交易（上架→找書→預約防詐→付款暫管→存書→前往書櫃→取書撥款→售後→系統）。左邊賣家侖娥、右邊買家海嫄，必要時加入管理員手機。
- 上架照 App 的兩個步驟：第 1 步輸入 ISBN 由 AI 帶入書目，第 2 步依照片判斷書況與建議售價（AI 建議 $220，侖娥定價 $222）。
- 放大特寫時，上方標題與手機下方的身分標籤會自動淡出；各段都先讓標題收起再推近，標示框不附文字標籤，避免蓋住介面。
- 段落與旁白時間：`src/timeline.json`（旁白文字、所屬段落、段落內秒數；段落長度）。
- 各段落：`src/scenes/`（intro、list、find、deal、pay、deposit、transit、pickup、after、system、fee、end），左上角款項進度在 `escrow.ts`。
- 共用工具：`src/scenes/kit.ts`
  - `frame()`：依介面區塊的實際大小決定放大倍率與位置。
  - `seq()`：畫面切換，可淡化、推入、返回或底部展開。
  - `scrollKeys()`：長截圖捲動。
  - `Mark`／`Tap`／`Tag`／`Banner`：標示框、點擊、身分標籤與推播。
- 書櫃透視標註、比對數字飛行、步驟列：`src/scenes/rig.ts`。
- 各畫面重點區塊的座標：`src/scenes/story.ts`，依實際截圖量測。
- 卡點音效：各場景以 `cue()`／`fly()`／`roll()` 登記，只對應畫面上真的發生的動作。
- App 畫面：在 `savemybook_app` 執行 `flutter test tool/web_shots/intro_shots_test.dart`，輸出到 `assets-src/screens/`，再轉成 WebP 放到 `public/screens/`。
  - 資料說明見 `assets-src/screens/README.md`。
  - 交通資料來自 data.taipei 的實際快照 `assets-src/transit_nearby.json`。
  - 執行後 `pubspec.lock` 會被 Flutter 改寫，記得還原。

## 檢查（交付前必做）

```bash
node tools/review.mjs <輸出前綴> <起秒> <迄秒> 0.5   # 每 0.5 秒一格、半尺寸總覽，逐張看
node tools/collide.mjs 0 999 1/60                      # 手機穿模檢查，必須 0 筆
node tools/overlap.mjs 0 999 0.25                      # 文字互相重疊、出界、壓在手機上
node tools/wrap.mjs                                    # 斷行後末行只剩一兩個字、側邊說明標題換行
```

`overlap.mjs` 目前固定剩 4 項，屬於刻意的設計：片頭兩句標題交接的那一格、上架書卡從賣家手機送出與飛進買家手機、系統段手機縮成 App 節點。`wrap.mjs` 剩下的是數字滾動中的寬度與服務費列（版面本身就是多欄），不是斷行問題。

## 輸出

```bash
cd audio && bash build.sh
```

依序產生：穿模檢查、音效時間、旁白、配樂、音效與混音、中英字幕、4K60 畫面，最後合成 4K、1080p 與中英字幕版到 `成品/`。4K 檔超過 GitHub 單檔上限，不進版控。

音訊需要 Python 環境：`cd audio && python3 -m venv .venv && .venv/bin/pip install -r requirements.txt`。
