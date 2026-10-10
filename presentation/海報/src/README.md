# 海報原始檔（src/）

第 115414 組「救「舊」我的書」展版海報。以 HTML/CSS 排版、真實公制單位（mm／pt），由 Chrome 輸出可印刷的 PDF（文字向量、字型內嵌）與 300 dpi PNG。規格以 `../規劃.md` 為準，視覺沿用 `../../介紹動畫/v2`。

## 結構

```
海報/
├── package.json / node_modules/   依賴：puppeteer-core、sharp、pdf-lib、qrcode-generator、jsqr、@fontsource/ibm-plex-mono
├── fonts/                         Noto Sans TC 400/500/700/900（TTF）、IBM Plex Mono 500（woff2，只含 latin）＋授權檔
├── src/
│   ├── poster.css                 共用設計系統（色票、字型、紙張、元件）；檔頭註解有完整字級表
│   ├── poster.js                  共用腳本：?bleed=0、?guides=1、寫入 @page、內嵌 SVG、等字型後設定 window.__ready
│   ├── poster1.html               海報 1（95×30 cm）
│   ├── poster2.html / poster3.html（待建）
│   └── assets/
│       ├── logo.svg               向量 logo（由 tools/build-assets.mjs 從 介紹動畫/v2/src/lib/logo.ts 轉出，勿手改）
│       └── qr-site.svg            https://savemybook.today/ 的 QR（ECC Q、4 模組留白，已解碼驗證）
├── tools/
│   ├── render.mjs                 輸出 PDF／PNG／預覽
│   ├── build-assets.mjs           產生 logo.svg、qr-site.svg、成品/Logo與圖檔/115414－Logo.svg/.png
│   └── shadows.mjs                產生 poster.css 的疊層陰影變數
├── 成品/含出血/  成品/不含出血/  成品/Logo與圖檔/
└── 預覽/                          低解析預覽 JPG（審稿用，不交付）
```

## 指令（在 `海報/` 下執行）

```bash
npm install                                         # 第一次
node tools/build-assets.mjs                         # logo / QR / Logo 交付檔
node tools/render.mjs poster1                       # 兩版 × PDF＋PNG＋預覽（全部）
node tools/render.mjs poster1 --bleed --preview --guides   # 只看含出血預覽＋輔助線版
node tools/render.mjs poster3 --trim --png --dpi 300
```

- `--bleed | --trim | --both`（預設 both）；`--pdf`、`--png`、`--preview`（都沒給＝三者都做）；`--guides` 另出一張帶完成線／內容範圍的預覽；`--dpi N`（預設 300）。
- 輸出命名：`posterN.html` → `成品/含出血/115414－海報N.pdf|.png`、`成品/不含出血/115414－海報N.pdf|.png`；預覽 `預覽/posterN-bleed.jpg`、`-trim.jpg`、`-bleed-guides.jpg`。
- 輸出前自動檢查並印出：每段文字實際使用的字型（不可出現「系統字型」）、所有元素是否在 `.safe` 內、內容外框到 `.safe` 邊的距離。
- PDF：Chrome 先以進位到 0.01 inch 的紙張列印，再用 pdf-lib 把 MediaBox 裁成精確尺寸，並寫入 TrimBox（含出血版＝內縮 3mm）／BleedBox。輸出後驗證頁數＝1、尺寸誤差 < 0.01mm、字型皆內嵌、點陣影像數。
- PNG：deviceScaleFactor＝dpi/96，視窗固定為一塊（300 dpi 時 2048 CSS px＝6400 device px），平移 `.sheet` 逐塊截圖，以 sharp 拼接並寫入 dpi。海報 3 含出血＝5504 × 23220 px，已實測可行。
- 瀏覽器直接看：在 `海報/` 起任一靜態伺服器（字型需走 http），開 `src/poster1.html?guides=1`。頁面以實際 mm 排版，95 cm 寬約 3600 CSS px，用瀏覽器縮放檢視。

## 新增一張海報

```html
<!doctype html>
<html lang="zh-Hant-TW">
<head>
  <meta charset="utf-8">
  <title>115414－海報2</title>
  <link rel="icon" href="data:,">
  <link rel="stylesheet" href="poster.css">
  <style>
    :root { --trim-w: 950mm; --trim-h: 650mm; }   /* 完成尺寸，一定要用 mm */
    /* 本張專用樣式以 .p2__* 命名 */
  </style>
</head>
<body>
  <div class="sheet">
    <div class="bg"></div>                 <!-- 背景漸層，延伸到出血 -->
    <main class="safe">…全部內容…</main>   <!-- 距完成邊 20mm；內容不可超出 -->
  </div>
  <script src="poster.js"></script>
</body>
</html>
```

規則：
- 文字、圖片、卡片全部放在 `.safe` 內（render 會檢查）。只有背景可延伸到出血。
- 尺寸一律用 mm／pt（或 em）。不要用 px（1 CSS px＝0.2646 mm，會讓人誤以為是螢幕像素）。
- 向量素材用 `<div class="inline-svg" data-src="assets/xxx.svg"></div>` 內嵌（PDF 內保持向量，id 自動加前綴）；容器要給寬高。
- 點陣圖（3D 示意、App 畫面）用 `<img>`，解析度至少達印刷尺寸 × 300 dpi ÷ 2（約 150 dpi 以上），3D 書櫃、手機旁一律加 `<span class="tag-3d">3D 示意</span>`。
- 不要用帶模糊的 `box-shadow`／`filter: drop-shadow`：Chrome 會在 PDF 內轉成 JPEG 遮罩，各閱讀器呈現不一。要陰影請用 `var(--shadow-card|chip|badge|tile)`（向量疊層）。
- 品牌名：`<span class="brand">救<i>「舊」</i>我的書</span>`（「「舊」」含括號用 slate）。
- 櫃門號 A01–A04 才用 `.door-no`（IBM Plex Mono 500），其他文字一律 Noto Sans TC。

## 設計變數（poster.css :root）

| 類別 | 變數 |
|---|---|
| 色票 | `--ink #16222B`、`--deep #2F4552`、`--slate #627D8D`、`--muted #5B6770`、`--success #2E9E5B`、`--soft #EEF2F5`、`--line #D3DADF`；輔助 `--success-soft`、`--idle` |
| 紙張 | `--trim-w`、`--trim-h`（每張設定）、`--bleed`（3mm／?bleed=0 時 0）、`--margin 20mm`、`--sheet-w/h`、`--safe-w/h` |
| 字級 | `--fs-display 260pt`、`--fs-h1 110pt`、`--fs-h1-en 54pt`、`--fs-stat 190pt`、`--fs-h2 64pt`、`--fs-h3 44pt`、`--fs-lead 36pt`、`--fs-body 28pt`、`--fs-note 22pt`、`--fs-meta 18pt`（最小） |
| 單位 | `--px 0.5mm`＝動畫 1px 放大到 95 cm 寬；`--r-card 12mm`、`--r-tile 14mm` |
| 陰影 | `--shadow-card`、`--shadow-chip`、`--shadow-badge`、`--shadow-tile` |

## 元件

| class | 用途／寫法 |
|---|---|
| `.eyebrow` | 前置 slate 短線的小眉標。`<p class="eyebrow">第 115414 組</p>` |
| `.brand`、`.brand--display` | 品牌名；display 版字重 900、行高 1.04 |
| `.section-head` | `<h2 class="section-head"><span class="section-head__no">01</span><span class="section-head__zh">專題動機與目的</span><span class="section-head__en">Project Purpose</span></h2>`；其後可接 `<div class="section-rule"></div>` |
| `.lead` `.body` `.note` `.meta` `.accent` | 文字層級 |
| `.footnote` | 註腳，自動加「註」；`.footnote--src` 改為「資料來源」；`.footnote--plain` 不加前綴 |
| `.card`（`.card--soft`） | 白卡、大圓角、淡雙層陰影；內含 `.card__eyebrow`、`.card__title`、`.card__body` |
| `.chip`（`--soft`、`--ok`）、`.chips` | 膠囊標籤；`.chips` 為換行排列容器；chip 內可放 `<svg>` 線條圖示 |
| `.cbadge`（`--slate`） | 綠勾徽章：`<span class="cbadge"><i></i>存書完成</span>` |
| `.tag-3d` | 「3D 示意」小標籤：`<span class="tag-3d">3D 示意</span>` |
| `.icon-tile` | 白色圓角方塊＋slate 線條 icon（stroke 1.6、round）＋名稱＋說明；`--tile` 控制方塊大小（預設 40mm）。icon 路徑可取自 `介紹動畫/v2/src/lib/content.ts` 的 `AI_FEATURES` |
| `.icon` | 單獨使用的線條 icon（大小＝1em） |
| `.stat`（`.stat--left`） | `.stat__num`（slate 大數字，`<small>%</small>` 單位）、`.stat__key`、`.stat__note` |
| `.stepbar` | 橫向膠囊步驟列：`<ol class="stepbar"><li class="is-done"><i>01</i>掃碼</li><li class="is-on"><i>02</i>比對</li><li><i>03</i>開門</li></ol>` |
| `.steps`（`.steps--row`） | 編號圓圈＋細線串連的步驟清單：`<li class="is-done"><i>1</i><div><b>標題</b><span>說明</span></div></li>`；完成為綠色 |
| `.leader`（`.leader--rev`） | 水平引線標註：文字＋slate 細線（長度 `--len`）＋白底 slate 描邊圓點；斜線請用 inline SVG 的 `.xline`／`.xdot` |
| `.divider`（`--v`）、`.qr` | 分隔線、QR 白底卡（`<div class="qr" style="width:60mm"><div class="inline-svg" data-src="assets/qr-site.svg"></div></div>`） |
| `.mono` `.door-no` | IBM Plex Mono 500，只用於 A01–A04 |

字級建議（觀看距離 1–3 m）：海報 2、3 的內文不低於 `--fs-body`（28pt），說明不低於 `--fs-meta`（18pt）。
