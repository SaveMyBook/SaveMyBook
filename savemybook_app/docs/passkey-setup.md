# 通行密鑰（Passkey）設定手冊

App 端（`lib/services/passkey_service.dart`、`lib/features/security/passkeys_card.dart`、
`lib/features/security/passkey_sign_in_button.dart`）與 API 端（`routes/passkeys.js`、
`routes/user-passkeys.js`、`services/passkeys.js`）的程式碼已完成，下列項目必須由專案擁有者完成。
**未完成前，登入頁與帳號安全不會出現通行密鑰入口，或操作時顯示「目前無法使用通行密鑰，請改用密碼」。**

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

## 一、Android 簽署金鑰與指紋

Android 以**簽署 APK／AAB 的憑證**識別 App：`assetlinks.json` 比對憑證的 SHA-256，API 則以
`android:apk-key-hash:<同一個 SHA-256 的 base64url>` 比對來源。以不同金鑰簽署的 APK 對系統而言是不同的 App，
在其中一個版本建立的通行密鑰，換裝另一把金鑰簽署的版本後無法使用。

### 1. 建立全組共用的 release keystore（只做一次）

由專案擁有者建立一次，之後所有人打包正式版都使用同一個檔案：

```bash
keytool -genkeypair -v -keystore ~/savemybook-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

- keystore 與密碼一律透過版控以外的管道（例如密碼管理工具）交付給負責打包的人。遺失後無法再以同一把金鑰發布，
  使用者既有的通行密鑰也將無法在新版本使用。
- 在 `android/key.properties` 填入下列內容（此檔與 `*.jks`、`*.keystore` 已列入 `.gitignore`，不可提交）：

  ```properties
  storeFile=/Users/<使用者>/savemybook-release.jks
  storePassword=<keystore 密碼>
  keyAlias=upload
  keyPassword=<金鑰密碼>
  ```

  `storeFile` 建議使用絕對路徑；相對路徑以 `android/` 為基準。缺少任一欄位時建置會直接失敗並指出欄位名稱。
- `android/app/build.gradle.kts` 在 `android/key.properties` 存在時以它簽署 release。檔案不存在時退回本機 debug 金鑰，
  僅供本機建置，**這樣打包的 APK 無法使用通行密鑰**，Gradle 會顯示警告。
- 可用 `cd android && ./gradlew :app:signingReport` 確認 `Variant: release` 的 `Config` 為 `release`。

### 2. 列出所有會安裝到手機上的簽署憑證

每一把會實際簽署使用者或測試人員所安裝版本的金鑰，都要取得 SHA-256（`AA:BB:CC:...`，32 組）：

- 共用 release keystore：

  ```bash
  keytool -list -v -keystore ~/savemybook-release.jks -alias upload | grep SHA256
  ```

- 上架 Google Play 並啟用 Play 應用程式簽署時，從 Play 安裝的版本由 Google 的金鑰簽署：Play Console → 測試與發布 →
  設定 → 應用程式完整性 → 「應用程式簽署金鑰憑證」的 **SHA-256 憑證指紋**。此時上述 release keystore 成為上傳金鑰，
  只有另外直接安裝以它簽署的 APK 時才需要保留它的指紋。
- 需要以 debug 版測試通行密鑰的組員，各自的 debug 金鑰（每台電腦不同）：

  ```bash
  keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android | grep SHA256
  ```

每一組指紋都要轉成 base64url，供第四節的 `PASSKEY_ORIGINS` 使用：

```bash
echo 'AA:BB:CC:...' | tr -d ':' | xxd -r -p | base64 | tr '+/' '-_' | tr -d '='
# 輸出 43 個字元，例如 47DEQpj8HBSa-_TImW-5JCeuQeRkm5NMpJWZG3hSuFU
```

### 3. 兩份清單必須逐一對應

同一組指紋必須同時出現在 `assetlinks.json` 的 `sha256_cert_fingerprints`（第二節）與 `PASSKEY_ORIGINS` 的
`android:apk-key-hash:<base64url>`（第四節）。任一處缺漏，該金鑰簽署的版本就無法使用通行密鑰；
第四節的 `npm run verify` 會實際抓取正式站的 `assetlinks.json`，並列出 `PASSKEY_ORIGINS` 缺少的項目。

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
      "sha256_cert_fingerprints": ["<第一節的指紋 1，AA:BB:CC:... 格式>", "<指紋 2>"]
    }
  }
]
```

`sha256_cert_fingerprints` 列出第一節取得的每一組指紋，並保留 `get_login_creds` 與 `handle_all_urls` 兩個 relation。
範本中的佔位字串必須換成實際指紋，否則 Android 一律無法使用通行密鑰。

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

# Google 的驗證服務；每組指紋都應回傳 "linked": true
curl -s 'https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://savemybook.today&relation=delegate_permission/common.get_login_creds'
curl -s 'https://digitalassetlinks.googleapis.com/v1/assetlinks:check?source.web.site=https://savemybook.today&relation=delegate_permission/common.get_login_creds&target.android_app.package_name=today.savemybook.app&target.android_app.certificate.sha256_fingerprint=<AA:BB:CC:... 指紋>'
```

Google 的驗證結果約有 10 分鐘快取，裝置上的 Google Play 服務另有快取；更新檔案後請稍候再以實機測試。

---

## 四、API 伺服器

1. 安裝新增的相依套件（`@simplewebauthn/server`）：

   ```bash
   cd savemybook_api && npm install
   ```

2. 在 `.env` 加入：

   ```bash
   PASSKEY_RP_ID="savemybook.today"
   PASSKEY_RP_NAME="救「舊」我的書"
   # iOS 使用 https://savemybook.today；Android 為 android:apk-key-hash:<第一節轉出的 base64url>，每組指紋一筆
   PASSKEY_ORIGINS="https://savemybook.today,android:apk-key-hash:<BASE64URL_指紋 1>,android:apk-key-hash:<BASE64URL_指紋 2>"

   # 僅在採用第三節做法 B 時需要
   APPLE_TEAM_ID="Q929JXJ8S7"
   IOS_BUNDLE_ID="today.savemybook.app"
   ANDROID_PACKAGE_NAME="today.savemybook.app"
   ANDROID_CERT_SHA256="<AA:BB:CC:... 格式，多組以逗號分隔>"
   ```

   - `PASSKEY_ORIGINS` 請明確設定，不要加入 `https://api.savemybook.today`：未設定時程式預設值包含 api 子網域，
     該子網域的網頁一旦遭植入腳本，就能以主網域的 RP ID 取得使用者的通行密鑰驗證。
   - 採用做法 A 時，`ANDROID_CERT_SHA256` 不影響正式站的 `assetlinks.json`，指紋須直接更新 nginx 上的靜態檔。
   - `JWT_SECRET` 同時決定通行密鑰的使用者代號。更換後既有通行密鑰仍可使用，但之後新增的會與舊的並存於使用者的鑰匙圈。

3. 檢查並重啟：

   ```bash
   npm run verify      # 「資料庫結構」與所有「通行密鑰」、assetlinks.json、apple-app-site-association 項目皆須通過
   pm2 restart savemybook-api   # 或實際使用的重啟方式
   curl -s https://api.savemybook.today/api/auth/passkeys/status
   # data.enabled、data.platforms.ios、data.platforms.android 皆應為 true，data.rp_id 為 savemybook.today
   ```

   `platforms.android` 為 false（`PASSKEY_ORIGINS` 沒有任何 `android:apk-key-hash`）時，Android App 不顯示通行密鑰入口；
   `platforms.ios` 同理。

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

iOS 17.4 以下不支援排除已註冊的憑證，同一帳號在同一個 Apple 帳號下再次新增，會覆蓋 iCloud 鑰匙圈中原有的通行密鑰。
App 在這些版本會先說明風險，使用者確認後才繼續。

---

## 六、Android

`passkeys` 套件透過 Credential Manager 運作，`AndroidManifest.xml` 不需要額外設定。需同時符合：

1. 正式版以第一節的共用 keystore 簽署（`android/key.properties` 已就緒）；
2. 該簽署憑證的指紋已列入正式站的 `assetlinks.json`，且 `PASSKEY_ORIGINS` 含有對應的 `android:apk-key-hash`；
3. 裝置已登入 Google 帳號並開啟 Google 密碼管理工具（或其他支援通行密鑰的密碼管理工具），且已設定螢幕鎖定。

---

## 七、上線後檢查

1. 以已設定密碼的帳號登入 → 帳號安全 → 「通行密鑰」→ 新增通行密鑰 → 驗證身分 → 系統跳出建立畫面。
2. 登出 → 登入頁按「使用通行密鑰登入」→ 以 Face ID／指紋完成登入。
3. 帳號安全的敏感操作（例如登出其他裝置）預設顯示通行密鑰驗證，可改用登入密碼。
4. 管理員執行後台高風險操作時可用通行密鑰驗證；付款仍只接受交易密碼與生物辨識付款。

刪除通行密鑰後，App 會通知系統移除裝置上的同一把通行密鑰。此功能僅在 Android（密碼管理工具支援 Signal API）與
iOS 26.2 以上（且以 Xcode 26.2 以上建置）有效；其他版本需由使用者至系統的密碼設定自行刪除。帳號匿名化不會通知裝置。

常見錯誤：

| App 顯示的訊息 | 原因 |
| --- | --- |
| 目前無法使用通行密鑰，請改用密碼 | App 與網域的關聯驗證失敗（iOS 的 domain-not-associated、Android 的 SecurityError）：關聯檔案無法取得、有轉址、Team ID 或指紋錯誤，或 Apple CDN、Google 驗證服務尚未更新 |
| 此裝置目前無法使用通行密鑰，請改用其他方式（`PASSKEY_ORIGIN_NOT_ALLOWED`） | `PASSKEY_ORIGINS` 沒有這個 APK 的 `android:apk-key-hash`；API 日誌 `[通行密鑰驗證未通過]` 會列出實際來源 |
| 通行密鑰驗證失敗，請重新操作或改用其他方式（`PASSKEY_VERIFICATION_FAILED`） | RP ID 不符、未經使用者驗證或簽章錯誤；原因見 API 日誌 `[通行密鑰驗證未通過]` |
| 通行密鑰操作已中斷，請再試一次 | Android 的憑證請求被中斷（App 切到背景或同時有其他請求），重試即可 |
| 未能以此裝置的通行密鑰完成驗證，請改用其他方式 | Android 裝置上沒有此帳號已註冊的任何一把通行密鑰（例如只在 iPhone 註冊過），或使用者略過了生物辨識 |
| 通行密鑰操作失敗，請改用密碼 | 系統未分類的錯誤。以 `adb logcat \| grep passkey`（Android）或在 Xcode 主控台搜尋 `[passkey]`（iOS）查看原始錯誤碼 |
| 登入頁沒有通行密鑰按鈕 | `/api/auth/passkeys/status` 回報 `enabled` 為 false（伺服器未執行 016、`PASSKEY_ORIGINS` 為空）、該平台的 `platforms` 為 false，或裝置不支援。狀態暫時無法取得時按鈕仍會顯示 |
