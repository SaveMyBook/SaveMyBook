# savemybook.today 系統介紹網站

單頁、以捲動推進的介紹網站：three.js 繪製的手機、書與智慧書櫃隨捲動演出，畫面上的 App 介面由 Flutter 直接渲染。開啟「減少動態效果」或瀏覽器不支援 WebGL 時，自動改為靜態的長頁版本。

## 開發

```bash
npm install
npm run dev        # http://127.0.0.1:5280/
```

- 文案在 `index.html`；書架示意書目與七項 AI 功能在 `src/data/content.ts`。
- 各章節的捲動演出在 `src/app.ts`（每章一個函式，以 0–1 的進度插值關鍵影格）。
- 3D 模型：`src/three/phone.ts`（手機）、`book.ts`（序章的書）、`cabinet.ts`（書櫃，造型比照介紹動畫）。

## 素材

| 素材 | 來源與產生方式 |
|---|---|
| App 畫面 `public/screens/` | 在 `savemybook_app` 執行 `flutter test tool/web_shots/web_shots_test.dart`，輸出到 `assets-src/screens/`，再執行 `npm run assets -- screens` 轉成 WebP。執行後 `pubspec.lock` 會被 Flutter 改寫，記得還原。 |
| 圖示 `public/*.png`、`public/brand/` | `npm run assets -- icons`，取自 `branding/Logo Design`。 |
| 介紹影片 `public/media/` | `npm run assets -- video`，由介紹動畫成品壓縮（1080p30），字幕由 `字幕_中英.srt` 轉成 WebVTT。 |
| 分享預覽圖 `public/og.jpg` | 開著 `npm run dev` 時執行 `node scripts/og.mjs`。 |
| 字型 `src/styles/fonts.css` | `npm run build` 會先依頁面實際用字挑選思源宋體／黑體的分片，只打包需要的 woff2。 |

## 檢查

```bash
npm run check      # 需先 npm run dev；沿各章節逐格截圖，總覽在 .shots/sheet-1440.png 與 sheet-390.png
npx tsc --noEmit
```

## 建置與部署

```bash
npm run build      # 產出 dist/
```

把 `dist/` **裡面的檔案**以 SFTP 上傳到主網域的網站根目錄（目前為 `/var/www/savemybook/`），覆蓋舊的首頁檔案即可。

**注意：** 同一目錄下的 `.well-known/`（通行密鑰與 App 關聯檔）不可刪除。上傳時不要選「同步刪除遠端多餘檔案」，否則 App 的通行密鑰登入會失效。

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
