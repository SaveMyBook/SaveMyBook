# 通行密鑰（Passkey）設定手冊

App 端（`lib/services/passkey_service.dart`、`lib/features/security/passkeys_card.dart`、
`lib/features/security/passkey_sign_in_button.dart`）與 API 端（`routes/passkeys.js`、
`routes/user-passkeys.js`、`services/passkeys.js`）的程式碼已完成，下列項目必須由專案擁有者完成。
**未完成前，登入頁與帳號安全不會出現通行密鑰入口，或按下後系統回報「App 與網站的關聯設定尚未生效」。**

| 項目 | 值 |
| --- | --- |
| RP ID（網域） | `savemybook.today` |
| RP 名稱 | `救「舊」我的書` |
| iOS Bundle ID | `today.savemybook.app` |
| Apple Team ID | `Q929JXJ8S7`（取自 Xcode 專案的 `DEVELOPMENT_TEAM`，請於 Apple Developer 帳號確認） |
| Android 套件名稱 | `today.savemybook.app` |
| 系統需求 | iOS 16 以上；Android 9 以上且有 Google Play 服務 |

> RP ID 一經使用就不可更換，否則所有使用者已建立的通行密鑰都會失效。

---

## 一、取得 Android 簽署金鑰指紋

通行密鑰只認**正式發布時實際簽署 APK／AAB 的金鑰**。

- 使用 Google Play 應用程式簽署：Play Console → 測試與發布 → 設定 → 應用程式完整性 →
  「應用程式簽署金鑰憑證」的 **SHA-256 憑證指紋**。
- 自行簽署：

  ```bash
  keytool -list -v -keystore <keystore 路徑> -alias <別名> | grep SHA256
  ```

得到的格式為 `AA:BB:CC:...`（32 組）。另外需要把同一個指紋轉成 base64url，供第四節的
`PASSKEY_ORIGINS` 使用：

```bash
echo 'AA:BB:CC:...' | tr -d ':' | xxd -r -p | base64 | tr '+/' '-_' | tr -d '='
# 輸出 43 個字元，例如 47DEQpj8HBSa-_TImW-5JCeuQeRkm5NMpJWZG3hSuFU
```

開發期間以 debug 金鑰安裝的 App 若也要測試，請把 debug 金鑰的指紋一併加入（兩處都要）。

---

## 二、準備兩個關聯檔案

### `apple-app-site-association`（無副檔名）

```json
{
  "webcredentials": {
    "apps": ["<TEAM_ID>.today.savemybook.app"]
  }
}
```

`<TEAM_ID>` 換成 Apple Team ID（目前專案為 `Q929JXJ8S7`）。

### `assetlinks.json`

```json
[
  {
    "relation": [
      "delegate_permission/common.handle_all_urls",
      "delegate_permission/common.get_login_creds"
    ],
    "target": {
      "namespace": "android_app",
      "package_name": "today.savemybook.app",
      "sha256_cert_fingerprints": ["<SHA256_指紋，AA:BB:CC:... 格式>"]
    }
  }
]
```

兩個檔案都必須：

- 以 `https://savemybook.today/.well-known/<檔名>` 直接回應 **200**；
- **不可轉址**（包含導向 `www`、`api` 子網域或加上斜線）；
- `Content-Type` 為 `application/json`；`apple-app-site-association` **不可有副檔名**。

---

## 三、nginx 設定（主網域與 API 同一台主機）

以下兩種做法擇一。兩者都寫在 **`savemybook.today` 的 443 server 區塊**，不是 `api.savemybook.today`。

> 若主網域的 server 區塊在最外層寫了 `return 301 ...` 或 `rewrite ... redirect`，它會比 `location`
> 先執行，請改寫進 `location / { ... }` 內，否則 `.well-known` 也會被轉址。
> 若有 `location ~ /\. { deny all; }` 之類禁止點開頭路徑的規則，下列 `location =` 為精確比對，優先權較高，不受影響。

### 做法 A：由 nginx 直接提供靜態檔案（建議）

```bash
sudo mkdir -p /var/www/savemybook/.well-known
sudo cp apple-app-site-association assetlinks.json /var/www/savemybook/.well-known/
sudo chmod 644 /var/www/savemybook/.well-known/*
```

```nginx
server {
    listen 443 ssl http2;
    server_name savemybook.today;
    # ...既有的 ssl_certificate 等設定...

    location = /.well-known/apple-app-site-association {
        alias /var/www/savemybook/.well-known/apple-app-site-association;
        types { }
        default_type application/json;
        add_header Cache-Control "public, max-age=3600";
    }

    location = /.well-known/assetlinks.json {
        alias /var/www/savemybook/.well-known/assetlinks.json;
        types { }
        default_type application/json;
        add_header Cache-Control "public, max-age=3600";
    }

    # ...既有的 location / 等設定...
}
```

`types { }` 會清空副檔名對應，確保沒有副檔名的檔案也以 `application/json` 回應。

### 做法 B：反向代理到 API

API 已提供這兩個路徑，內容由環境變數組成（見第四節的 `APPLE_TEAM_ID` 等），缺少設定時回 404。

```nginx
server {
    listen 443 ssl http2;
    server_name savemybook.today;

    location ^~ /.well-known/ {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_redirect off;
    }
}
```

`proxy_pass` 後面不要加路徑或斜線，否則請求路徑會被改寫。資料庫還原期間 API 暫停服務，
此做法會讓關聯檔案暫時無法取得，因此仍建議做法 A。

套用設定：

```bash
sudo nginx -t && sudo systemctl reload nginx
```

### 驗證

```bash
# 狀態碼須為 200，content-type 為 application/json，且不可出現 location 標頭
curl -sI https://savemybook.today/.well-known/apple-app-site-association
curl -sI https://savemybook.today/.well-known/assetlinks.json

# 不跟隨轉址時仍為 200（有轉址會看到 301/302）
curl -s -o /dev/null -w '%{http_code} %{content_type} %{redirect_url}\n' https://savemybook.today/.well-known/apple-app-site-association
curl -s -o /dev/null -w '%{http_code} %{content_type} %{redirect_url}\n' https://savemybook.today/.well-known/assetlinks.json

# 內容是合法 JSON
curl -s https://savemybook.today/.well-known/apple-app-site-association | python3 -m json.tool
curl -s https://savemybook.today/.well-known/assetlinks.json | python3 -m json.tool

# Apple 的 CDN 快取（首次部署後可能需要數小時才更新）
curl -s https://app-site-association.cdn-apple.com/a/v1/savemybook.today

# Google 的驗證服務
curl -s 'https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://savemybook.today&relation=delegate_permission/common.get_login_creds'
```

---

## 四、API 伺服器

1. 安裝新增的相依套件（`@simplewebauthn/server`）：

   ```bash
   cd savemybook_api && npm install
   ```

2. 執行資料庫更新 016（可重複執行）：

   ```bash
   mysql -u <帳號> -p <資料庫名稱> < migrations/016_passkeys.sql
   mysql -u <帳號> -p <資料庫名稱> < migrations/check_state.sql   # 確認 user_passkeys、webauthn_challenges 為「已存在」
   ```

3. 在 `.env` 加入：

   ```bash
   PASSKEY_RP_ID="savemybook.today"
   PASSKEY_RP_NAME="救「舊」我的書"
   # iOS 與網頁使用 https 來源；Android 為 android:apk-key-hash:<第一節轉出的 base64url>
   PASSKEY_ORIGINS="https://savemybook.today,https://api.savemybook.today,android:apk-key-hash:<BASE64URL_指紋>"

   # 僅在採用第三節做法 B 時需要
   APPLE_TEAM_ID="Q929JXJ8S7"
   IOS_BUNDLE_ID="today.savemybook.app"
   ANDROID_PACKAGE_NAME="today.savemybook.app"
   ANDROID_CERT_SHA256="<AA:BB:CC:... 格式，多組以逗號分隔>"
   ```

4. 檢查並重啟：

   ```bash
   npm run verify      # 「資料庫結構」與「通行密鑰 RP ID 與來源」皆須通過
   pm2 restart savemybook-api   # 或實際使用的重啟方式
   curl -s https://api.savemybook.today/api/auth/passkeys/status   # data.enabled 應為 true
   ```

---

## 五、iOS（Xcode）

`ios/Runner/Runner.entitlements` 已加入 `com.apple.developer.associated-domains`，值為
`webcredentials:savemybook.today`。請在 Xcode 確認：

1. 開啟 `ios/Runner.xcworkspace` → 左側選 **Runner** 專案 → TARGETS 選 **Runner** →
   **Signing & Capabilities**。
2. 應看到 **Associated Domains**，內含 `webcredentials:savemybook.today`。若沒有，按
   **+ Capability** 加入 Associated Domains，再新增這一行。
3. 採用自動簽署時 Xcode 會替 App ID 開啟 Associated Domains；手動簽署需到
   Apple Developer → Identifiers → `today.savemybook.app` 勾選 **Associated Domains** 並重新產生描述檔。
4. 執行 `cd ios && pod install` 後重新建置。

開發期間若 Apple CDN 尚未更新，可暫時改成 `webcredentials:savemybook.today?mode=developer`，
並在測試裝置的「設定 → 開發者 → Associated Domains Development」開啟；**正式上架前務必改回**。

---

## 六、Android

`passkeys` 套件透過 Credential Manager 運作，`AndroidManifest.xml` 不需要額外設定。
只要第二、三節的 `assetlinks.json` 可正確取得，且 `PASSKEY_ORIGINS` 含有對應的 `android:apk-key-hash`，即可使用。
裝置需登入 Google 帳號並開啟 Google 密碼管理工具（或其他支援通行密鑰的密碼管理工具），且已設定螢幕鎖定。

---

## 七、上線後檢查

1. 以已設定密碼的帳號登入 → 帳號安全 → 「通行密鑰」→ 新增通行密鑰 → 驗證身分 → 系統跳出建立畫面。
2. 登出 → 登入頁按「使用通行密鑰登入」→ 以 Face ID／指紋完成登入。
3. 帳號安全的敏感操作（例如登出其他裝置）預設顯示通行密鑰驗證，可改用登入密碼。
4. 管理員執行後台高風險操作時可用通行密鑰驗證；付款仍只接受交易密碼與生物辨識付款。

常見錯誤：

| App 顯示的訊息 | 原因 |
| --- | --- |
| App 與網站的關聯設定尚未生效 | 關聯檔案無法取得、有轉址、Team ID／指紋錯誤，或 Apple CDN 尚未更新 |
| 通行密鑰驗證失敗（伺服器 `PASSKEY_VERIFICATION_FAILED`） | `PASSKEY_ORIGINS` 未包含該平台的來源（Android 最常見），或 RP ID 不符 |
| 登入頁沒有通行密鑰按鈕 | 伺服器未執行 016、`PASSKEY_ORIGINS` 為空，或裝置不支援 |
