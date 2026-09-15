# Apple 隱私權申報對照

本文件整理 App 向 Apple 申報的權限用途、隱私權清單（Privacy Manifest）與 App Store Connect「App 隱私權」問卷答案。修改權限、第三方套件或伺服器蒐集的資料時，須同步更新本文件、`Info.plist` 與 `PrivacyInfo.xcprivacy`。

## 一、系統權限對照

| 權限 | Info.plist 鍵值 | App 內使用位置 | 平台 |
| --- | --- | --- | --- |
| 相機 | `NSCameraUsageDescription` | 上架書籍掃描 ISBN 條碼（`features/books/barcode_scanner_screen.dart`）、取書掃描書櫃 QR Code（`features/orders/pickup_book_screen.dart`）、拍攝書籍／大頭貼／爭議佐證照片（`services/photo_service.dart`）、聊天室拍照（`features/chat/chat_room_screen.dart`） | iOS、macOS |
| 相簿（讀取） | `NSPhotoLibraryUsageDescription` | 選取書籍照片、大頭貼、聊天圖片、爭議佐證照片（image_picker）；iOS 14 以上使用系統照片挑選器，平常不會跳出授權，但套件仍引用相簿 API，須保留此鍵值 | iOS |
| 相簿（寫入） | `NSPhotoLibraryAddUsageDescription` | 將個人檔案 QR Code 儲存至相簿（`features/account/share_profile_screen.dart`）、儲存聊天室圖片（`widgets/image_viewer.dart` 的儲存按鈕與訊息長按選單 → `services/image_save_service.dart`），皆經由 `AppDelegate.swift` `saveImage` 寫入 | iOS |
| 下載項目資料夾（寫入） | entitlement `com.apple.security.files.downloads.read-write` | macOS 儲存聊天室圖片時直接寫入「下載項目」（`MainFlutterWindow.swift` `saveImage`），不需相簿權限 | macOS |
| 麥克風 | `NSMicrophoneUsageDescription` | 錄製聊天室語音訊息（`services/voice_service.dart`） | iOS、macOS |
| 定位（使用 App 期間） | `NSLocationWhenInUseUsageDescription`（macOS 另有 `NSLocationUsageDescription`） | 書籍詳情顯示與智慧書櫃的距離（`features/books/book_detail_screen.dart`）、選擇書櫃時依距離排序（`widgets/app_forms.dart`） | iOS、macOS |
| Face ID | `NSFaceIDUsageDescription` | 開啟 App 解鎖、快速登入、生物辨識付款（`services/biometric_service.dart`） | iOS |
| 推播通知 | 無用途說明鍵值；`UIBackgroundModes` 含 `remote-notification`，entitlement `aps-environment` | 訂單、聊天、公告推播（`services/push_service.dart`，Firebase Cloud Messaging） | iOS |
| 深層連結 | `CFBundleURLTypes`（`savemybook://`） | 個人檔案與書籍分享連結（`services/deep_link_service.dart`） | iOS、macOS |
| App Group | entitlement `com.apple.security.application-groups`（`group.today.savemybook.app`） | 主 App 與桌面小工具共用資料（`services/home_widget_service.dart`、`SaveMyBookWidget`） | iOS |

保留：`NSLocationAlwaysUsageDescription`、`NSLocationAlwaysAndWhenInUseUsageDescription`。App 只在使用期間取得位置，但 geolocator 的 iOS 程式碼會引用「永遠允許」的 API，缺少這兩個鍵值時 App Store Connect 會以 ITMS-90683 退件（本專案曾發生過），因此保留並寫明「不會在背景取得位置」。

App 內「設定 → 帳號 → App 權限」列出上述權限的目前狀態，可直接請求授權或前往系統設定。

## 二、隱私權清單（PrivacyInfo.xcprivacy）

| 檔案 | 所屬 target |
| --- | --- |
| `ios/Runner/PrivacyInfo.xcprivacy` | Runner（已加入 Copy Bundle Resources） |
| `ios/SaveMyBookWidget/PrivacyInfo.xcprivacy` | SaveMyBookWidgetExtension（資料夾同步群組，自動納入） |
| `macos/Runner/PrivacyInfo.xcprivacy` | macOS Runner（已加入 Copy Bundle Resources） |

共同設定：`NSPrivacyTracking = false`，`NSPrivacyTrackingDomains` 為空。

### 必要理由 API（Required Reason API）

| 類別 | 理由代碼 | 說明 | 宣告位置 |
| --- | --- | --- | --- |
| UserDefaults | CA92.1 | App 讀寫自身設定 | iOS Runner、macOS Runner |
| UserDefaults | 1C8F.1 | 主 App 與小工具透過 App Group 共用資料（home_widget 套件未附隱私權清單） | iOS Runner、小工具 |
| File timestamp | C617.1 | 清除快取時讀取 App 暫存檔資訊 | iOS Runner、macOS Runner |

Flutter 引擎、shared_preferences、firebase_messaging、permission_handler 等套件已自帶隱私權清單，不在 App 清單中重複宣告。未使用磁碟空間（Disk space）及開機時間（System boot time）API；Flutter 引擎自身的開機時間用途由 Flutter.framework 的清單宣告。

### 蒐集的資料類型（App 本身）

以下皆為「與使用者身分連結：是」、「用於追蹤：否」。

| 資料類型（清單鍵值） | 實際內容 | 用途 |
| --- | --- | --- |
| 電子郵件地址（EmailAddress） | 註冊與登入帳號 | App 功能 |
| 姓名（Name） | 暱稱 | App 功能 |
| 電話號碼（PhoneNumber） | 個人資料選填 | App 功能 |
| 使用者 ID（UserID） | 帳號編號 | App 功能 |
| 裝置 ID（DeviceID） | App 自行產生的安裝識別碼、推播權杖（非 IDFA／IDFV） | App 功能 |
| 照片或影片（PhotosorVideos） | 書籍照片、大頭貼、聊天圖片、爭議佐證照片 | App 功能 |
| 音訊資料（AudioData） | 聊天語音訊息 | App 功能 |
| 電子郵件或文字訊息（EmailsOrTextMessages） | 聊天室訊息 | App 功能 |
| 客服支援（CustomerSupport） | 客服工單內容、AI 客服對話紀錄 | App 功能 |
| 其他使用者內容（OtherUserContent） | 書籍刊登內容、自我介紹、檢舉、交易爭議 | App 功能 |
| 購買記錄（PurchaseHistory） | 訂單、購物車；使用者同意後，AI 客服會帶入本人最近訂單與預約狀態，AI 推薦會帶入購買過的書籍資訊 | App 功能、產品個人化 |
| 其他財務資訊（OtherFinancialInfo） | App 內代幣錢包餘額與交易紀錄（不含信用卡或銀行帳號） | App 功能 |
| 產品互動（ProductInteraction） | 收藏清單；推薦書籍時送出的最近瀏覽書籍編號；使用者同意後，AI 推薦會帶入收藏書籍資訊 | App 功能、產品個人化 |
| 其他資料類型（OtherDataTypes） | 個人資料選填的生日、性別 | App 功能 |

未宣告的項目與理由：

- 位置：座標只隨查詢書櫃的請求送出，伺服器僅即時計算距離，不寫入資料庫也不記錄，依 Apple 定義不屬於「蒐集」。
- 搜尋記錄、瀏覽記錄：搜尋關鍵字僅用於當次篩選；最近瀏覽與搜尋紀錄只存在裝置上。
- 付款資訊：無信用卡或第三方金流，錢包儲值由客服作業處理。
- 當機與效能資料：App 未整合 Crashlytics、Sentry 等工具。

## 三、App Store Connect「App 隱私權」問卷答案

1. 是否蒐集資料：**是**。
2. 追蹤（Tracking）：**否**。App 不與第三方資料結合進行廣告或資料仲介，不需 App Tracking Transparency。
3. 依第二節表格逐項勾選資料類型，每項設定：
   - 與使用者身分連結：是
   - 用於追蹤：否
   - 用途：勾選「App 功能」；「購買記錄」及「產品互動」另勾選「產品個人化」
4. 第三方 SDK（Firebase Cloud Messaging）另外宣告的資料，須一併勾選（以 Xcode Archive 產生的 Privacy Report 為準）：
   - 裝置 ID：未連結身分、不追蹤、App 功能
   - 其他診斷資料：未連結身分、不追蹤、App 功能／分析
   - 其他資料類型：未連結身分、不追蹤、分析

   同一資料類型若 App 本身已勾選「與身分連結」，以連結為準，並補勾 SDK 的用途。
5. 隱私權政策網址：`https://api.savemybook.today/privacy`（由 API `routes/public.js` 提供，內容來自後台法律文件）。

## 四、其他審核注意事項

- **刪除帳號**：「設定 → 帳號管理」可自行申請刪除（`features/account/account_privacy_screen.dart`，驗證密碼後呼叫 `POST /users/me/deletion`），30 天內可登入取消，期滿後由排程匿名化帳號，符合審核指南 5.1.1(v)。同一頁面也提供個人資料匯出。
- **刪除後保留的資料**：匿名化後仍保留訂單、錢包紀錄、客服工單、檢舉與爭議，以及登入紀錄與工作階段中的 IP 位址。隱私權政策須載明保留範圍與期間。
- **隱私權政策內容待更新**：後台法律文件（初始內容見 API `migrations/003_restore_legal_content.sql`）仍寫刪除帳號須聯繫客服、提及 Cookie，也未說明 IP／裝置紀錄、推播權杖、語音訊息及 30 天緩衝期。送審前請於後台更新。
- **IP 位址**：伺服器為帳號安全記錄登入 IP，未用於推算位置，因此未申報為位置資料。若日後用於地區判斷，須改申報「大略位置」。
- **推播 entitlement**：`Runner.entitlements` 的 `aps-environment` 為 `development`；以 App Store 發佈方式封存時，Xcode 會依描述檔自動改為 production，請於 Archive 後確認。
- **通知服務擴充功能**：`SaveMyBookNotificationService` 若讀寫 UserDefaults、檔案時間戳等必要理由 API，須在該資料夾另加 `PrivacyInfo.xcprivacy`。
- **第三方 AI（審核指南 5.1.2(i)）**：詳見第五節。審核備註可說明 AI 功能的同意畫面位置，並提供可觸發同意畫面的測試帳號。
- **送審前檢查**：Xcode → Product → Archive → Organizer 右鍵 Archive →「Generate Privacy Report」，確認報告與第三節答案一致。

## 五、第三方 AI 服務

伺服器依後台「AI 設定」呼叫 DeepSeek、Google Gemini 或 OpenAI。App 只與自家 API 通訊，API 金鑰僅存放於伺服器，App 不直接連線 AI 服務商。

### 提供給 AI 服務商的資料

| 功能 | 送出的資料 | 需要使用者同意 | 未同意時 |
| --- | --- | --- | --- |
| AI 客服 | 使用者輸入的訊息、同一對話最近 12 則紀錄、本人最近 5 筆訂單（訂單編號、狀態、金額、書名）與預約狀態 | 是 | API 回傳 403 `AI_CONSENT_REQUIRED`，App 顯示同意畫面；仍可轉接真人客服 |
| 上架輔助 | ISBN、書名、書況說明、使用者選擇的照片（最多 4 張，送出前移除 EXIF／XMP 等含拍攝位置的中繼資料，不儲存） | 是 | 同上；手動填寫與 ISBN 查詢不受影響 |
| 個人推薦 | 收藏與購買紀錄中的書名、作者、分類，以及候選書籍資訊；以臨時代號取代資料庫編號 | 是 | 首頁改用既有推薦，不呼叫 AI 服務商，也不跳出同意畫面 |
| 上架審核 | 公開刊登的書名、作者、分類、售價、描述與前 2 張照片 | 否 | 屬平台對公開刊登內容的安全審核，不含賣家暱稱、Email、電話或帳號編號 |

所有請求都不帶使用者帳號、Email、裝置識別碼或 IP；伺服器端的用量紀錄（`ai_usage_logs`）保留使用者編號，只用於費用統計與每日次數上限。

### 同意流程

- 第一次傳送 AI 客服訊息、第一次按「AI 帶入」前，若尚未同意，App 顯示「AI 資料處理說明」（`features/account/ai_consent_sheet.dart`）：列出啟用中功能會送出的資料、實際使用的服務商名稱（API `GET /api/ai/status` 的 `providers_in_use`）、使用目的、不用於廣告或追蹤，以及撤回方式；按鈕為「同意並繼續」與「不同意」。
- 同意紀錄存於伺服器 `ai_consents`（`PUT /api/ai/consent`），跨裝置有效。「設定 → 帳號管理 → AI 資料處理」可隨時開關；關閉後伺服器立即停止送出上述資料，並刪除該使用者的 AI 推薦快取。
- 刪除帳號（匿名化）時刪除同意紀錄、AI 客服對話與推薦快取；個人資料匯出包含這三類資料。
- 後台變更功能使用的服務商後，同意畫面與設定頁顯示的服務商名稱會隨之更新。若新增的服務商未曾向使用者揭露，建議評估是否要求使用者重新同意。

### App Store Connect 問卷影響

AI 服務商依使用者指示處理資料，視為 App 蒐集的資料，不另列為追蹤。上表資料已涵蓋於第二節的資料類型，送審前確認下列項目皆已勾選：

| 資料類型 | 與身分連結 | 用於追蹤 | 用途 |
| --- | --- | --- | --- |
| 客服支援（CustomerSupport） | 是 | 否 | App 功能 |
| 其他使用者內容（OtherUserContent） | 是 | 否 | App 功能 |
| 照片或影片（PhotosorVideos） | 是 | 否 | App 功能 |
| 購買記錄（PurchaseHistory） | 是 | 否 | App 功能、產品個人化 |
| 產品互動（ProductInteraction） | 是 | 否 | App 功能、產品個人化 |

`PrivacyInfo.xcprivacy` 的 `NSPrivacyCollectedDataTypes` 已含上述類型，不需新增；`NSPrivacyTracking` 維持 `false`。

### 送審前須由營運方確認

- **服務商資料政策**：確認各服務商 API 條款中，傳入內容是否會用於訓練或改善模型、保存期間與資料所在地，並與隱私權政策一致。Google Gemini API 的免費層級條款允許 Google 將內容用於改善服務，正式環境應使用已啟用付費帳單的專案；DeepSeek 的資料可能在中華人民共和國境內處理，須於隱私權政策揭露跨境傳輸。
- **隱私權政策**：於後台法律文件新增下列段落（依實際啟用的服務商調整）。

### 隱私權政策建議增訂段落

> **第三方 AI 服務**
>
> 本平台提供 AI 客服、上架輔助與個人化書籍推薦功能。經您於 App 內同意後，我們會將下列資料提供給第三方 AI 服務商處理：
>
> 1. AI 客服：您輸入的訊息、同一對話的近期紀錄，以及您本人最近的訂單與預約狀態。
> 2. 上架輔助：您提供的 ISBN、書名、書況說明與您選擇的照片。照片送出前會移除拍攝位置等中繼資料，且不會由本平台保存。
> 3. 個人化推薦：您的收藏與購買紀錄中的書籍資訊。
>
> 目前合作的 AI 服務商為 DeepSeek、Google（Gemini API）及 OpenAI，實際使用的服務商以 App 內「AI 資料處理說明」顯示為準。上述資料僅用於產生回覆、整理上架資料與推薦書籍，不會用於廣告或跨平台追蹤，傳送時亦不包含您的帳號名稱、電子郵件、電話或裝置識別碼。部分服務商可能於中華民國境外（包括美國及中華人民共和國）處理資料，並依其服務條款保存一定期間。
>
> 您可隨時於 App「設定 → 帳號管理 → AI 資料處理」撤回同意，撤回後我們將停止提供上述資料，AI 客服、上架輔助與個人化推薦功能將無法使用，其他服務不受影響。
>
> 為維護交易安全，本平台會以 AI 服務審核公開刊登的書籍內容（書名、作者、分類、售價、描述與照片），此項審核不包含您的個人資料，不需另行同意。
