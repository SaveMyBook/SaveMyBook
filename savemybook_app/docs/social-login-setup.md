# 社群登入與簡訊登入設定手冊

App 端（`lib/features/auth`、`lib/services/social_auth_service.dart`）與 API 端（`routes/auth.js`）的程式碼已完成，但下列項目必須由專案擁有者在各家主控台手動完成。**未完成前，對應渠道在登入頁不會出現，或按下後會失敗。**

本機無法編譯原生程式，iOS／macOS 的 plist 與 entitlement 只放了佔位字串，請依第二節替換。

支援的渠道與驗證方式：

| 渠道 | App 端 | 伺服器驗證 |
| --- | --- | --- |
| Google | google_sign_in → firebase_auth | Firebase ID Token |
| Apple | sign_in_with_apple → firebase_auth | Firebase ID Token |
| 手機號碼 | firebase_auth 簡訊驗證 | Firebase ID Token |
| LINE | 開啟瀏覽器授權，伺服器交換權杖 | LINE Login OAuth 2.1 |
| Discord | 開啟瀏覽器授權，伺服器交換權杖 | Discord OAuth2 |

---

## 一、Firebase 主控台（Google／Apple／手機號碼共用）

專案：`savemybook`（`lib/firebase_options.dart` 已指向此專案）。

1. **Authentication → Sign-in method**，啟用需要的提供者：
   - Google：啟用後記下自動產生的「Web 用戶端 ID」（Web SDK 設定區塊）。
   - Apple：啟用並填入第三節取得的 Service ID、Team ID、Key ID 與私密金鑰。
   - 電話：啟用，並在「簡訊測試號碼」加入測試用號碼，避免開發期間耗用配額。
2. **專案設定 → 一般 → 您的應用程式**
   - Android 應用程式加入 **SHA-1 與 SHA-256** 憑證指紋（debug 與正式簽章各一組）。取得方式：
     ```
     keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android -keypass android
     keytool -list -v -alias <正式別名> -keystore <正式 keystore 路徑>
     ```
     若使用 Google Play 應用程式簽署，另需加入 Play Console →「應用程式完整性」顯示的簽署金鑰 SHA-1／SHA-256。
     **沒有登錄 SHA 指紋時，Android 的 Google 登入與簡訊驗證都會失敗。**
   - 重新下載 `google-services.json` 與 `GoogleService-Info.plist`，放回 `firebase/` 後執行 `python3 tool/firebase_setup.py`。
3. **Authentication → Settings → 授權網域**：加入 `api.savemybook.today`（Apple 的網頁授權流程會用到）。
4. 電話驗證的 iOS 端需要 APNs 金鑰（推播已設定則不需再做）；Android 端會使用 Play Integrity，模擬器上請改用測試號碼。

### Android 的 Google ID Token

google_sign_in 7.x 在 Android 需要 **Web 用戶端 ID**（`serverClientId`）才會回傳 ID Token。建置時以編譯參數帶入：

```
flutter build apk --dart-define=GOOGLE_SERVER_CLIENT_ID=<Firebase Web 用戶端 ID>.apps.googleusercontent.com
```

未帶入時，Android 的 Google 登入會取不到憑證並顯示「登入憑證無效或已過期」。iOS／macOS 由 `Info.plist` 的 `GIDClientID` 取得，不需這個參數。

---

## 二、Xcode（iOS 與 macOS）

以下檔案已預先加入設定，**佔位字串必須替換**：

| 檔案 | 需要替換的內容 |
| --- | --- |
| `ios/Runner/Info.plist` | `GIDClientID` 與 URL scheme 中的 `REPLACE_WITH_IOS_CLIENT_ID` |
| `macos/Runner/Info.plist` | `GIDClientID` 與 URL scheme 中的 `REPLACE_WITH_MACOS_CLIENT_ID` |

替換值取自 Firebase 下載的 `GoogleService-Info.plist`：

- `GIDClientID` = 該檔的 `CLIENT_ID`（形如 `1234-abcd.apps.googleusercontent.com`）。
- URL scheme = 該檔的 `REVERSED_CLIENT_ID`（形如 `com.googleusercontent.apps.1234-abcd`），**整段**取代 `com.googleusercontent.apps.REPLACE_WITH_IOS_CLIENT_ID`。

其他步驟：

1. Xcode → Runner target → **Signing & Capabilities → + Capability → Sign in with Apple**。
   entitlement 檔已加入 `com.apple.developer.applesignin`（`ios/Runner/Runner.entitlements`、`macos/Runner/DebugProfile.entitlements`、`macos/Runner/Release.entitlements`），但仍須在 Xcode 加入 capability，Apple Developer 的描述檔才會帶上這項權限。
2. Apple Developer → Certificates, Identifiers & Profiles → Identifiers，為 iOS 與 macOS 的 App ID 勾選 **Sign In with Apple**，再重新產生描述檔。
3. macOS 為沙箱應用程式，`com.apple.security.network.client` 已開啟，不需額外調整。
4. `savemybook://` scheme 兩個平台都已設定（OAuth 回呼與分享連結共用）。

---

## 三、Apple（Sign in with Apple）

Firebase 需要 Service ID 與私密金鑰才能驗證 Apple 憑證：

1. Apple Developer → Identifiers → **Services IDs**，新增一組（例如 `today.savemybook.app.signin`），勾選 Sign In with Apple → Configure：
   - Primary App ID：`today.savemybook.app`
   - Domains：`api.savemybook.today`
   - Return URLs：`https://savemybook.firebaseapp.com/__/auth/handler`（以 Firebase 主控台 Apple 設定頁顯示的網址為準）
2. Keys → 新增 Key，勾選 **Sign in with Apple**，下載 `.p8`（只能下載一次），記下 Key ID 與 Team ID。
3. 回到 Firebase → Authentication → Apple，填入 Service ID、Apple Team ID、Key ID 與 `.p8` 內容。

注意：Apple 只在**第一次**授權時提供姓名與電子郵件；使用者若選擇隱藏信箱，會取得 `@privaterelay.appleid.com` 轉寄信箱，這是正常結果。

---

## 四、LINE Login

1. [LINE Developers](https://developers.line.biz/) 建立 Provider 與 **LINE Login** channel。
2. Channel 基本設定：
   - Callback URL：`https://api.savemybook.today/api/auth/oauth/line/callback`
   - App type：勾選 Web app（伺服器交換權杖）
3. **必須另外申請「電子郵件地址取得權限」**（channel 頁面的 OpenID Connect → Email address permission → Apply），並上傳說明用途的畫面截圖，等待 LINE 審核。未通過前 LINE 不會回傳 email，使用者會被導向「完成帳號資料」畫面自行填寫。
4. 記下 Channel ID 與 Channel secret，填入伺服器環境變數。

---

## 五、Discord OAuth2

1. [Discord Developer Portal](https://discord.com/developers/applications) 建立 Application。
2. OAuth2 → Redirects 加入：`https://api.savemybook.today/api/auth/oauth/discord/callback`
3. Scopes 使用 `identify email`（伺服器已在授權網址帶入，不需在後台設定）。
4. 記下 Client ID 與 Client secret。

---

## 六、伺服器環境變數

於 API 的 `.env` 設定（參考 `savemybook_api/.env.example`）：

| 變數 | 用途 | 未設定時 |
| --- | --- | --- |
| `LINE_CHANNEL_ID`、`LINE_CHANNEL_SECRET` | LINE Login | 後台顯示「未設定」，該渠道強制停用 |
| `DISCORD_CLIENT_ID`、`DISCORD_CLIENT_SECRET` | Discord OAuth2 | 同上 |
| `OAUTH_REDIRECT_BASE` | OAuth 回呼網址前綴，預設沿用 `PUBLIC_WEB_URL` | LINE／Discord 無法啟動授權 |
| `FCM_SERVICE_ACCOUNT_FILE` 或 `FIREBASE_PROJECT_ID` | 驗證 Firebase ID Token 所需的專案 id | Google／Apple／手機號碼全部顯示「未設定」 |

金鑰只放伺服器環境變數，不進資料庫、不回傳 App。

執行資料庫更新 `migrations/014_auth_identities.sql`。未執行前 `GET /api/auth/providers` 會回 `social_enabled: false`，App 不顯示任何社群登入按鈕，後台設定頁會提示「伺服器尚未執行資料庫更新 014」。

---

## 七、後台開關

管理端 →「系統維運 → 登入方式」（需要 `system` 權限，儲存時需通過敏感操作驗證）：

- 總開關：關閉後登入頁不再顯示任何社群與簡訊登入。
- 各渠道「開放此方式登入與綁定」：控制登入與帳號安全頁的綁定。
- 各渠道「允許以這個方式直接建立新帳號」：關閉時只有已存在的帳號能用該方式登入或綁定，新使用者會看到「此登入方式僅供既有帳號使用」。
- 伺服器沒有該渠道憑證時顯示「未設定」並強制停用，開關無法打開。

---

## 八、驗收清單

完成上述設定後，依序確認：

1. 登入頁只顯示已啟用且本平台支援的按鈕（Apple 只在 iOS／macOS 出現）。
2. Google 登入可取得帳號並直接進入首頁。
3. Apple 登入在首次授權時可選擇隱藏信箱，仍能建立帳號。
4. 手機號碼登入可收到簡訊，輸入錯誤驗證碼會顯示錯誤並可重新輸入，倒數結束後可重新傳送。
5. 以手機號碼註冊新帳號時，會出現「完成帳號資料」畫面要求填寫信箱、暱稱並勾選同意條款。
6. 使用已註冊信箱的第三方帳號登入時，出現「此電子郵件已註冊」對話框，提示改以密碼登入後再綁定。
7. LINE／Discord 會開啟瀏覽器，授權後自動返回 App 並完成登入。
8. 帳號安全 →「登入方式」可綁定與解除綁定（需通過敏感操作驗證），沒有密碼的帳號會先要求設定密碼。
9. 沒有密碼的帳號在「變更密碼」與「刪除帳號」會被提示先設定密碼。
