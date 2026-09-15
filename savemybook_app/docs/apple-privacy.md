# Apple 隱私權申報對照

本文件整理 App 向 Apple 申報的權限用途、隱私權清單（Privacy Manifest）與 App Store Connect「App 隱私權」問卷答案。修改權限、第三方套件或伺服器蒐集的資料時，須同步更新本文件、`Info.plist` 與 `PrivacyInfo.xcprivacy`。

## 一、系統權限對照

| 權限 | Info.plist 鍵值 | App 內使用位置 | 平台 |
| --- | --- | --- | --- |
| 相機 | `NSCameraUsageDescription` | 上架書籍掃描 ISBN 條碼（`features/books/barcode_scanner_screen.dart`）、取書掃描書櫃 QR Code（`features/orders/pickup_book_screen.dart`）、拍攝書籍／大頭貼／爭議佐證照片（`services/photo_service.dart`）、聊天室拍照（`features/chat/chat_room_screen.dart`） | iOS、macOS |
| 相簿（讀取） | `NSPhotoLibraryUsageDescription` | 選取書籍照片、大頭貼、聊天圖片、爭議佐證照片（image_picker）；iOS 14 以上使用系統照片挑選器，平常不會跳出授權，但套件仍引用相簿 API，須保留此鍵值 | iOS |
| 相簿（寫入） | `NSPhotoLibraryAddUsageDescription` | 將個人檔案 QR Code 儲存至相簿（`features/account/share_profile_screen.dart` → `AppDelegate.swift` `saveImage`） | iOS |
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
| 客服支援（CustomerSupport） | 客服工單內容 | App 功能 |
| 其他使用者內容（OtherUserContent） | 書籍刊登內容、自我介紹、檢舉、交易爭議 | App 功能 |
| 購買記錄（PurchaseHistory） | 訂單、購物車 | App 功能、產品個人化 |
| 其他財務資訊（OtherFinancialInfo） | App 內代幣錢包餘額與交易紀錄（不含信用卡或銀行帳號） | App 功能 |
| 產品互動（ProductInteraction） | 收藏清單；推薦書籍時送出的最近瀏覽書籍編號 | App 功能、產品個人化 |
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
- **送審前檢查**：Xcode → Product → Archive → Organizer 右鍵 Archive →「Generate Privacy Report」，確認報告與第三節答案一致。
