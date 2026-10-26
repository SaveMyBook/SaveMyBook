# savemybook.today 系統介紹網站

單頁介紹網站，版面比照 NTUB_SIS 產品網站：白底、單一重點色霧藍，每個功能區由 kicker、兩行標題、說明與兩個補充點組成，旁邊放一支手機或 3D 書櫃，並從畫面浮出一個介面元素。智慧書櫃區以固定捲動呈現掃碼、比對、開門、完成四步。開啟「減少動態效果」或瀏覽器不支援 WebGL 時，3D 書櫃改用靜態算圖。

## 開發

```bash
npm install
npm run dev        # http://127.0.0.1:5280/
```

- 文案在 `index.html`。標題與說明以 `.nw` 片語控制斷行，句子內的數字只能使用專題調查與系統實際的數字。
- 中文斷行：`vite.config.ts` 在建置時於詞組之間插入 `<wbr>`（ICU 斷詞與 BudouX 都認定的詞界才斷，另有不可拆的詞表 `KEEP`），並把「24 小時」「QR Code」這類空格改成不斷行空格；`.nw` 片語內不再插入。新增專有名詞若被拆開，加進 `KEEP`。
- 捲動與互動在 `src/app.ts`：首頁輪播問句、各區浮出元素（`[data-vp]` 依可見程度設定 `--e`）、智慧書櫃固定捲動、服務費試算與影片視窗。
- 浮出元素：`src/ui/lift.ts`。原位留下空位（`.slot`），元素依自身邊界去背後放大浮起，位置限制在該區的安全範圍內。
- 3D 書櫃：`src/three/cabinet.ts`（造型比照實機）、`textures.ts`（書櫃螢幕，版面同韌體畫面）、`view.ts`（每個區塊一組畫布，依投影範圍自動取景，只在可見且有變動時重繪）。

## 素材

| 素材 | 來源與產生方式 |
|---|---|
| App 畫面 `public/screens/` | 在 `savemybook_app` 執行 `flutter test tool/web_shots/web_shots_test.dart`，輸出到 `assets-src/screens/`，再執行 `npm run assets -- screens` 轉成 WebP。執行後 `pubspec.lock` 會被 Flutter 改寫，記得還原。 |
| 浮出元素 `public/pops/` | `node scripts/pops.mjs`：由 `assets-src/screens/` 的 3 倍截圖依元素邊界與圓角去背，輸出 @1x／@2x／@3x WebP，並產生 `src/data/pops.ts`（座標與空位底色）。換了截圖後要重跑。 |
| 算圖 `public/renders/` | `npm run assets -- renders`：來源在 `assets-src/renders/`（書櫃正面、3/4 視角，主控板有、無開發板兩張）。主控板的開發板由兩張算圖的差異去背，並產生 `src/data/pcb.ts`。 |
| 鉸鏈護蓋 `public/model/hinge-cover.stl` | 書櫃模型載入的實體零件。 |
| 圖示 `public/*.png`、`public/brand/` | `npm run assets -- icons`，取自 `branding/Logo Design`。 |
| 介紹影片 `public/media/` | `npm run assets -- video`，由系統簡介影片的 1080p 中英字幕版壓縮（1080p30，字幕已燒在畫面上），封面取 15.5 秒那一格。換片時改 `scripts/prepare-assets.mjs` 的 `VIDEO` 檔名，並同步改 `index.html`，避免快取播到舊檔。 |
| 分享預覽圖 `public/og.jpg` | 開著 `npm run dev` 時執行 `node scripts/og.mjs`。 |
| 字型 `src/styles/fonts.css`、`src/styles/fonts/` | `npm run fonts`（`npm run build` 會先執行）：依頁面實際用字挑選思源黑體與 IBM Plex Mono 的分片，再把每片裁到只剩用到的字。改了文案後要重跑。 |

## 檢查

```bash
npm run check -- http://127.0.0.1:5280/ 1440 1024x900 1024x768 390   # 需先 npm run dev；沿各區逐格截圖，總覽在 .shots/sheet-<尺寸>.png
npm run perf                                                         # 以真實滾輪從頭捲到尾，列出超過 20 ms 的影格與各區慢格比例
npx tsc --noEmit
```

- 平滑捲動用 Lenis，由主迴圈呼叫 `lenis.raf()` 推進；少了這一步滾輪會被攔下而完全無法捲動（觸控不受影響，手機上看不出來）。
- `scripts/shoot.mjs` 的 `PLAN` 列出各區與截圖位置（固定捲動區以 0–1 的進度表示）；新增區塊時要一併加入。
- 圖片在接近畫面前就預先解碼，書櫃螢幕的各狀態在載入時先畫過一次，捲動時才不會出現慢格。

## 建置與部署

```bash
npm run build      # 產出 dist/
```

網站根目錄是伺服器上的 `/var/www/html/`。只能放 `dist/` 裡的檔案，不可把整個專案（`src/`、原始碼版 `index.html`、`package.json` 等）傳上去，否則首頁會載入 `/src/main.ts` 而整頁沒有樣式，原始碼也會公開。

1. 以 SFTP 把整個 `dist/` 資料夾上傳到伺服器的 `~/dist`。
2. 在伺服器上同步到網站根目錄，舊的建置檔會一併清掉：

```bash
sudo rsync -a --delete --exclude='.well-known' --exclude='phpmyadmin' --exclude='index.nginx-debian.*' ~/dist/ /var/www/html/
```

`.well-known`（通行密鑰與 App 關聯檔）不可刪除。`phpmyadmin` 是連結而不是資料夾，排除規則結尾不可加斜線。第一次可以先加 `-n --itemize-changes` 試跑，確認刪除清單裡只有舊檔。

3. Cloudflare 會快取圖片約 4 小時。檔名不變但內容更新的圖片（`screens/`、`og.jpg`），上傳後要在 Cloudflare 清除快取。

上傳後檢查：

```bash
curl -sI https://savemybook.today/ | head -1
curl -sI https://savemybook.today/.well-known/apple-app-site-association | head -1
```

兩個都應為 `HTTP/2 200`。

### nginx 建議設定（主網域的 443 server 區塊）

既有的 `.well-known` 設定保持不動，另加：

```nginx
root /var/www/savemybook;
index index.html;

location / {
    try_files $uri $uri/ =404;
}

# 檔名含雜湊，可長期快取
location /assets/ {
    add_header Cache-Control "public, max-age=31536000, immutable";
}

location = /index.html {
    add_header Cache-Control "no-cache";
}

location /media/ {
    add_header Cache-Control "public, max-age=604800";
}
```

改完執行 `sudo nginx -t && sudo systemctl reload nginx`。Cloudflare 若有快取首頁，上傳後請在 Cloudflare 清除 `https://savemybook.today/` 的快取。
