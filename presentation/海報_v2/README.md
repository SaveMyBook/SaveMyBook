# 展版海報（第 115414 組　救「舊」我的書）

2026-10-13 定稿。舊版海報在 `../海報/`，這一版是重新設計，沒有沿用舊版版面。

## 交件檔案（`成品/`）

| 資料夾 | 內容 |
|---|---|
| `含出血/` | `115414－海報1／2／3` 的 PDF 與 300 dpi PNG（每邊多 3 mm 出血） |
| `不含出血/` | 同上，完成尺寸 |
| `Logo與圖檔/` | 規範要求另附的圖檔：Logo（SVG＋PNG）、官網 QR（SVG＋PNG）、智慧書櫃 3D 示意、主控板 3D 示意 |

| 海報 | 完成尺寸 | 內容範圍 | 位置 |
|---|---|---|---|
| 海報 1 | 95 × 30 cm | 91 × 26 cm | 最上方（電腦螢幕上方） |
| 海報 2 | 95 × 65 cm | 91 × 61 cm | 螢幕下方，視線高度 |
| 海報 3 | 46 × 196 cm | 42 × 192 cm | 右側直式 |

PDF 文字為向量、字型內嵌，並寫入 TrimBox／BleedBox；文字與圖片都在距完成邊 2 cm 的內容範圍內，只有背景延伸到出血。

## 設計

依指導老師建議「海報應該凸顯你們如何用技術解決了這些問題」，三張海報串成一問一答：

- **海報 1**：組號、題目、Logo、組員、指導老師。書名放到最大，「「舊」」用強調色。
- **海報 2**：大標「二手書交易，難在哪裡？」＋書櫃 3D 圖；01 專題動機與目的；02 四個問卷痛點，每個用 10×10 方格把比例畫出來，再以綠色箭頭接到對應的技術解法。
- **海報 3**：大標「我們怎麼解決？」接著四段解法，每段開頭標出海報 2 的同一個問題與數據；03 方法（主控板、存書六步與四道驗證、先驗收後撥款的時間軸、AI 元件）；04 成效；頁尾標語與官網 QR。

視覺規則：
- **淺色底**：白色漸層到 App 的淺灰藍，背後襯一圈主色的淡柔光。
- **配色全部出自 App**：

  | 色值 | 用途 | 出處 |
  |---|---|---|
  | `#151E27` | 文字 | App 文字色 |
  | `#627D8D` | 主色、標籤 | App 主色 mist |
  | `#2E749E` | 強調色：數據、大標的強調字 | mist 同色相，提高彩度並壓深 |
  | `#2E9E5B` | 「技術解法」與成效 | App success |

- **字型與字級**：Noto Sans TC 加 Inter。字級以 1–3 公尺可讀為準，內文多在 28pt 以上。
- **不用網頁 UI 元素**：不放卡片框、膠囊標籤、等寬大寫小標；分組靠字級、留白和粗分隔線。
- **App 畫面**：不放截圖，只把關鍵元件（AI 建議卡片、ISBN 欄位）依 App 實際畫面以向量重繪。
- **3D 圖**：由專案模型 `cabinet.glb`、`pcb.glb` 重新算圖，見 `tools/3d/`。

文字出處見 [文案.md](文案.md)；大標「難在哪裡？」出自官網與影片，「我們怎麼解決？」是對應它的區塊標題。

## 結構

```
海報_v2/
├── src/
│   ├── poster1.html / poster2.html / poster3.html
│   ├── system.css     紙張、出血、內容範圍、字型（底層）
│   ├── brand.css      色票與共用元件：.lab .hl .k .num .to .sol .tech .txt .ruled
│   ├── brand.js       10×10 方格（.waffle）、綠色箭頭（.flow）
│   ├── base.js        出血旗標、內嵌 SVG、等字型與圖片載入，最後呼叫 window.__beforeReady
│   └── assets/        3d/（cabinet.png、pcb.png）、model/（.glb 原始模型）、brand/（logo、QR）
├── tools/
│   ├── render.mjs         輸出 PDF／PNG／預覽，並檢查字型、內容範圍、PDF 尺寸
│   ├── export-assets.mjs  輸出 成品/Logo與圖檔/
│   ├── peek.mjs           審稿用：低 dpi 輸出後切段（會覆寫 成品/不含出血 的 PNG，交件前要重跑 render）
│   └── 3d/                render3d.mjs＋scene.html：three.js 在無頭 Chrome 算 3D 圖
├── fonts/             Noto Sans TC、Inter（OFL）
├── 文案.md            文字與出處
└── 預覽/              審稿用 JPG（-guides 版疊有完成線與內容範圍）
```

## 指令（在 `海報_v2/` 下執行）

```bash
npm install
npm run render
npm run assets
```

- `npm run render`：三張海報都輸出含出血、不含出血兩版的 PDF、300 dpi PNG 與預覽。單張用 `node tools/render.mjs poster2 --both --pdf --png --preview --guides`。
- `npm run assets`：重新輸出 `成品/Logo與圖檔/`。
- 重算 3D 圖：`node tools/3d/render3d.mjs <輸出.png> '<JSON 設定>'`，可設定 model、cam、fov、light、rim 等，詳見檔頭註解。
- 用瀏覽器直接看：在 `海報_v2/` 起一個靜態伺服器，開 `src/poster2.html?guides=1`；加 `?bleed=0` 看完成尺寸。

## 交印前待確認

- 官網（QR 連結）上的成效數字仍是 300 / 1,557 / 2,570，海報用的是複評簡報的 301 / 1,563 / 2,815。
- 海報 3 的主控板圖是「自製主控板 Rev A」的 3D 設計，實體目前仍在打樣。
