# 社群登入與簡訊登入設定手冊

App 端（`lib/features/auth`、`lib/services/social_auth_service.dart`）與 API 端（`routes/auth.js`）的程式碼已完成，但下列項目必須由專案擁有者在各家主控台手動完成。**未完成前，對應渠道在登入頁不會出現，或按下後會失敗。**

支援的渠道與驗證方式：

| 渠道 | App 端 | 伺服器驗證 |
| --- | --- | --- |
| Google | google_sign_in → firebase_auth | Firebase ID Token |
| Apple | sign_in_with_apple → firebase_auth | Firebase ID Token |
| 手機號碼 | firebase_auth 簡訊驗證 | Firebase ID Token |
| LINE | App 內瀏覽器授權，伺服器交換權杖 | LINE Login OAuth 2.1 |
| Discord | App 內瀏覽器授權，伺服器交換權杖 | Discord OAuth2 |

登入按鈕的品牌標誌取自 Font Awesome Free（`font_awesome_flutter` 套件，圖示為 CC BY 4.0、
字型為 SIL OFL 1.1），不需另外準備圖檔。打包時請保留套件授權（Flutter 會自動把各套件的
LICENSE 收進「開放原始碼授權」頁面），不要在 `flutter build` 加上會移除授權資訊的設定。

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

兩個 Info.plist 已填入正式的 Google Client ID，一般情況不需修改：

| 檔案 | 相關設定 |
| --- | --- |
| `ios/Runner/Info.plist` | `GIDClientID` 與 `CFBundleURLSchemes` 中的 `com.googleusercontent.apps.…` |
| `macos/Runner/Info.plist` | `GIDClientID` 與 `CFBundleURLSchemes` 中的 `com.googleusercontent.apps.…` |

確認方式：與 Firebase 主控台下載的 `GoogleService-Info.plist` 比對。

- `GIDClientID` 須等於該檔的 `CLIENT_ID`（形如 `1234-abcd.apps.googleusercontent.com`）。
- URL scheme 須等於該檔的 `REVERSED_CLIENT_ID`（形如 `com.googleusercontent.apps.1234-abcd`）。

更換 Firebase 專案或重新建立 OAuth 用戶端時，以新檔案的兩個值**整段**取代上述設定；兩者不一致時，Google 登入授權後無法返回 App。

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

---

## 七、後台開關

管理端 →「系統維運 → 登入方式」（需要 `system` 權限，儲存時需以管理員的登入密碼或通行密鑰通過 `admin` 範圍驗證）：

- 總開關：關閉後登入頁不再顯示任何社群與簡訊登入。
- 各渠道「開放此方式登入與綁定」：控制登入與帳號安全頁的綁定。
- 各渠道「允許以這個方式直接建立新帳號」：關閉時只有已存在的帳號能用該方式登入或綁定，新使用者會看到「此登入方式僅供既有帳號使用」。
- 伺服器沒有該渠道憑證時，該渠道的卡片整張淡化、標示「未設定」並列出要補的環境變數，開關無法打開。

## 八、不自動建立帳號

第三方身分尚未綁定任何帳號時，`POST /api/auth/social` 與 `POST /api/auth/oauth/exchange`
一律回 404 `NO_ACCOUNT_FOR_PROVIDER`，不會自動註冊。App 詢問使用者後，只有在選擇
「以這個身分建立新帳號」時才帶 `create: true` 重送；LINE／Discord 會沿用同一組一次性碼，
不必再開一次授權頁。

---

## 九、驗收清單

完成上述設定後，依序確認：

1. 登入頁只顯示已啟用且本平台支援的按鈕（Apple 只在 iOS／macOS 出現）。
2. Google 登入可取得帳號並直接進入首頁。
3. Apple 登入在首次授權時可選擇隱藏信箱，仍能建立帳號。
4. 手機號碼登入可收到簡訊，輸入錯誤驗證碼會顯示錯誤並可重新輸入，倒數結束後可重新傳送。
5. 以手機號碼註冊新帳號時，會出現「完成帳號資料」畫面要求填寫信箱、暱稱並勾選同意條款。
6. 使用已註冊信箱的第三方帳號登入時，出現「此電子郵件已註冊」對話框，提示改以密碼登入後再綁定。
7. LINE／Discord 會在 App 內開啟瀏覽器（iOS 為 SFSafariViewController、Android 為 Custom Tabs），
   授權後自動返回 App、瀏覽器自動關閉，且不會重複開窗。中途取消或逾時都直接回到登入頁。
8. 以尚未綁定的第三方帳號登入時，出現「此登入方式尚未綁定帳號」對話框，三個選項分別可
   回到登入頁綁定、直接建立新帳號，或取消；取消後伺服器不會留下任何新帳號。
9. 帳號安全 →「登入方式」可綁定與解除綁定（需通過敏感操作驗證），沒有密碼的帳號會先要求設定密碼。
10. 沒有密碼的帳號在「變更密碼」與「刪除帳號」會被提示先設定密碼。
