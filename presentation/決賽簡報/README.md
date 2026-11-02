# InnoServe 決賽簡報（2026-11-07）

兩組各一份 PPTX，現場說明與展示約 6 分鐘（之後另有約 7 分鐘詢答）。風格沿用易拉展（`../海報_v2/src/banner.html`）：`#F5F5F7` 底、置中大標＋漸層強調字、白色大圓角格子、Manrope 大數字、綠色「技術解法」。

## 成品（`成品/`）

| 檔案 | 頁數／時間 | 對應評分重點 |
|---|---|---|
| `救舊我的書－決賽簡報（資訊應用組）.pptx` | 16 頁／約 5:35 | 問題 → 技術解法 → 交易閉環 → 書櫃 → 四道驗證 → 存書、取書展示 → 先驗收後撥款 → 交易把關 → 七項 AI → 測試 → 故障備援 → 四層架構 → 擴充性 → 結尾 |
| `救舊我的書－決賽簡報（臺北生活好便利組）.pptx` | 19 頁／約 5:45 | 同上，另以「前往書櫃的最後一哩路」為主軸：12 筆臺北市資料大平臺資料集、交通指引展示、開放資料串接與備援、三端系統完整性 |
| `*－講稿.md` | — | 每頁逐字稿與目標秒數（同時寫在每頁的備忘稿） |

- **動畫**（同複評簡報，`tools/kit.js` 的 `timingXml`）：每頁轉場「淡出」；進入投影片後標題、副標、各區塊依序淡入上移（presetID 42，500 毫秒，錯開最多 120 毫秒）；影片自動播放並循環。
- **存書／取書展示**：比照複評簡報，左邊書櫃動畫、中間手機錄影、右邊六個步驟，三者同時開始、同週期循環。
  - 書櫃動畫（`素材/video/cabinet3d_*.mp4`）用官網現行模型逐格算出，螢幕畫面、A01 開關門與書本放入／取出的時間點對齊手機錄影的 `marks.txt`；重做：`node tools/cabinet-anim.js`（時間軸在 `../海報_v2/tools/3d/web/harness.ts` 的 seq 模式）。
  - 步驟亮起：每步的白底與實心圓依時間淡入淡出，時間點寫在 `tools/slides.js` 的 `FLOWS[].at`，後處理依影片長度展開 10 輪（約 2 分鐘）。
  - 手機錄影以 `DECK_BG=F5F5F7` 重新合成（`savemybook_app/tool/deck_gifs/gif_kit.py`），外框底色與投影片一致。
- **影片**：展示頁內嵌手機錄影，進入該頁就自動循環播放，不必點擊。`素材/video/` 有的影片優先使用，其餘取自 `../複評簡報/素材/video/`。
- **匿名版書櫃影片**（`素材/video/` 的 `cabinet_deposit`、`cabinet_pickup`、`cabinet_transit`）：2026-10-29 重錄，書櫃據點改成「示範書櫃／100臺北市中正區」；座標和周邊交通資訊不變。重錄方式：在 `savemybook_app/` 底下執行 `D3_OUT=<暫存資料夾> D3_FPS=60 MANUAL_DATA=<照片資料夾> flutter test tool/deck_gifs/d3_cabinet_test.dart --plain-name <名稱>`，再執行 `python tool/deck_gifs/d3_video.py <暫存資料夾>/<名稱>_60fps 素材/video/<名稱>.mp4`；結束後用 `git checkout` 還原 flutter test 改寫的 plugin 註冊檔。
- **字型**：Noto Sans TC（Black／Medium／Bold）、Manrope（ExtraBold／SemiBold）。簡報用的電腦要先安裝 `../複評簡報/簡報字體包.zip`，否則會被替換成其他字型，版面會跑掉。
- **匿名**：畫面上沒有組號、校名、組員或指導老師。
- **書櫃透視圖**（`素材/cabinet_xray.png`）：用官網現行模型算圖，螢幕在左上、木把手，與易拉展一致。重算方式：在 `../海報_v2/` 執行 `node tools/3d/render-web.mjs ../決賽簡報/素材/cabinet_xray.png '{"w":2400,"h":2640,"yaw":0.5,"pitch":0.18,"xray":0.6,"dist":44}'`，官網模型更新時先加 `--build` 重新打包。

- **封面 3D 模型**（`素材/cabinet.glb`）：官網現行書櫃模型匯出的 GLB，嵌在封面（`tools/kit.js` 的 `embedModel3d`）。
  - PowerPoint 2019／Microsoft 365 會即時算圖、可在編輯模式拖曳轉動；Office 2016 等舊版只顯示替代圖（`素材/cabinet-preview.png`，同一個相機算的）。
  - XML 結構照 PowerPoint 以 `Shapes.Add3DModel` 存出的檔案（[pptx-ts 的 model3d.pptx](https://github.com/shbernal/pptx-ts/blob/main/test/read/fixtures/model3d.pptx)）與 [MS-ODRAWXML model3d schema](https://learn.microsoft.com/en-us/openspecs/office_standards/ms-odrawxml/6c414e62-4825-4100-9ca1-88fefc5fb699)。相機距離、`viewportSz`、`meterPerModelUnit` 依 `素材/cabinet.json` 換算。
  - **這台電腦是 Office 2016，無法實際驗證 3D 畫面**；只驗證過檔案能開、替代圖正常。
  - **放映時要轉動，需在 Microsoft 365 上加一次「轉盤」動畫**（動畫 → 轉盤；開始：與前一個同時；預存時間 → 重複：直到投影片結束）。轉盤的 XML 沒有公開範例，所以沒有寫進產生流程。
  - 重新匯出：在 `../海報_v2/` 執行 `node tools/3d/render-web.mjs ../決賽簡報/素材/cabinet.glb '{"glb":true,"w":1600,"h":1600,"ay":0.5,"pitch":0.17}'`（同時寫出 `cabinet-preview.png`、`cabinet.json`），再跑 `node tools/assets.js`、`node build.js`。

## 待確認

1. **交通資訊仍是原據點周邊**（善導寺站、台北車站一帶）。影片裡已經沒有校名和地址，但熟悉的人看得出大致位置。
2. **官網數字仍是舊的**（300／1,557／2,570），簡報與易拉展用的是 301／1,563／2,815。結尾頁有官網 QR。

## 重新產生

```bash
npm install
node tools/assets.js
node build.js
```

- `tools/assets.js`：從易拉展裁出主視覺，並產生方格圖、書櫃透視圖（裁掉透明邊）、Logo、QR，輸出到 `build/assets/`。
- `build.js`：兩份簡報的頁序、秒數與講稿；各頁版面在 `tools/slides.js`，共用元件與後處理在 `tools/kit.js`。
- 後處理會寫入主題色與思源黑體（含東亞字型）、把記號色 `#2E749F` 換成漸層字、重新編號物件 id（pptxgenjs 會給影片重複的 id，PowerPoint 因此拒開），並加上影片自動循環播放。
- `powershell -ExecutionPolicy Bypass -File tools/render.ps1`：用本機 PowerPoint 把每頁輸出成 PNG（`build/render/`），檢查版面用。執行前先關掉 PowerPoint，腳本結束時會關閉 PowerPoint。
