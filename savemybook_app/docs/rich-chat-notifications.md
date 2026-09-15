# 聊天訊息通知（發送者大頭貼 ＋ App 圖示角標）

聊天訊息推播以「發送者大頭貼為主圖、右下角為 App 圖示」呈現：

- iOS 15 以上：Notification Service Extension 將通知轉為 Communication Notification（`INSendMessageIntent`）。
- Android 11 以上：原生 `NotificationCompat.MessagingStyle` ＋ 長效對話捷徑（Conversation）；Android 10 以下以大圖示顯示頭像。
- App 在前景時：應用程式內橫幅顯示發送者頭像，右下角為 App 圖示；聊天室開啟中不顯示橫幅。

頭像下載失敗、逾時或欄位缺漏時，一律退回伺服器原本的標題與內文，不會漏送通知。

---

## 一、推播資料欄位（伺服器 → App）

`data` 內所有值皆為字串：

| 欄位 | 說明 |
| --- | --- |
| `notification_id`、`type`、`related_type`、`related_id` | 既有欄位，點擊導頁使用 |
| `sender_id` | 發送者 ID（`type = message` 時必填，缺少則不套用頭像樣式） |
| `sender_name` | 發送者名稱（接收者自訂暱稱優先） |
| `sender_avatar` | 頭像絕對網址，可為空字串（iOS 僅接受 HTTPS） |
| `room_type` | `direct` 或 `group` |
| `room_title` | 群組名稱（一對一可為空） |
| `thread_id` | `chat_room-<room_id>`，iOS 對話識別與 Android 捷徑 ID |
| `title`、`body` | **Android 純 data 訊息專用**，內容與 notification.title / body 相同 |

---

## 二、伺服器需配合的變更（`savemybook_api/services/push/dispatcher.js` 的 `buildMessage`）

### iOS 裝置（`push_devices.platform = 'ios'`）

1. 保留 `notification.title` / `notification.body`（群組：title = 群組名稱、body = `發送者：預覽`；一對一：title = 發送者名稱、body = 預覽）。
2. `data` 加入上表的 `sender_id`、`sender_name`、`sender_avatar`、`room_type`、`room_title`、`thread_id`。
3. `type = message` 時 `apns.payload.aps` 加入 `"mutable-content": 1` 與 `"category": "CHAT_MESSAGE"`；`thread-id` 維持 `chat_room-<room_id>`。
4. `apns.headers` 維持 `apns-push-type: alert`、`apns-priority: 10`。

### Android 裝置（`push_devices.platform = 'android'`）

Android 在 App 位於背景時，含 `notification` 區塊的 FCM 訊息由系統直接顯示，App 無法改成頭像樣式，因此：

1. **`type = message` 時改送純 data 訊息**：
   - 不帶頂層 `notification`，也不帶 `android.notification`。
   - `data` 內加入 `title`、`body`（與 iOS 相同文字）以及上表所有聊天欄位。
   - `android.priority` 必須為 `'HIGH'`，否則裝置休眠（Doze）時會延遲送達。
2. 其他類型（訂單、客服等）可維持現狀（`notification` ＋ `android.notification.channel_id = savemybook_default`）。若日後也改為純 data，只要帶 `title`、`body`，App 會以一般樣式顯示。
3. 範例：

```js
{
  token,
  data: {
    notification_id: '123', type: 'message', related_type: 'chat_room', related_id: '45',
    title: '王小明', body: '請問書還在嗎？',
    sender_id: '88', sender_name: '王小明', sender_avatar: 'https://.../avatar.jpg',
    room_type: 'direct', room_title: '', thread_id: 'chat_room-45'
  },
  android: { priority: 'HIGH' }
}
```

App 端兩種格式都能處理：收到含 `notification` 的舊格式時仍由系統顯示（無頭像）；收到純 data 格式時由原生服務繪製頭像通知。伺服器可先部署，也可晚於 App 部署。

---

## 三、iOS

### 已加入專案的內容

| 項目 | 位置 |
| --- | --- |
| 擴充功能程式 | `ios/SaveMyBookNotificationService/NotificationService.swift` |
| 擴充功能 Info.plist | `ios/SaveMyBookNotificationService/Info.plist`（`com.apple.usernotifications.service`、`NSUserActivityTypes = INSendMessageIntent`） |
| Xcode Target | `SaveMyBookNotificationService`（已寫入 `Runner.xcodeproj/project.pbxproj`） |
| 主程式 Info.plist | `ios/Runner/Info.plist` 新增 `NSUserActivityTypes = [INSendMessageIntent]` |
| 主程式 Entitlement | `ios/Runner/Runner.entitlements` 新增 `com.apple.developer.usernotifications.communication = true` |

Target 設定摘要：

- Bundle ID：`today.savemybook.app.SaveMyBookNotificationService`
- Team：`Q929JXJ8S7`，Automatic Signing
- 最低版本：iOS 15.5（`UNNotificationContent.updating(from:)` 需要 iOS 15）
- 資料夾採 File System Synchronized Group，`Info.plist` 已列入 membership exception，避免「Multiple commands produce Info.plist」。
- 版本號取自 `Flutter/Generated.xcconfig`（`MARKETING_VERSION = $(FLUTTER_BUILD_NAME)`、`CURRENT_PROJECT_VERSION = $(FLUTTER_BUILD_NUMBER)`），與主程式一致；App Store 要求擴充功能版本與主程式相同。
- 已加入 Runner 的「Embed Foundation Extensions」階段與 Target Dependencies。
- 擴充功能不使用 CocoaPods，`Podfile` 無需修改。

### 第一次在 Xcode 開啟時請確認

1. `flutter pub get` 後以 Xcode 開啟 `ios/Runner.xcworkspace`。
2. 左側專案導覽應出現 `SaveMyBookNotificationService` 資料夾；TARGETS 清單應出現同名 Target。
3. 選取 `SaveMyBookNotificationService` Target → General：
   - Minimum Deployments：iOS 15.5
   - Frameworks and Libraries：空白即可（`Intents`、`UserNotifications` 為系統框架，Swift 匯入即連結）
4. Signing & Capabilities：
   - `SaveMyBookNotificationService`：Team 選 `Q929JXJ8S7`，勾選 Automatically manage signing，不需要額外 Capability。
   - `Runner`：確認已出現「Communication Notifications」；若未出現，按「+ Capability」加入（會寫入同一個 entitlement，不會重複）。
5. 選取 Runner Target → Build Phases → Embed Foundation Extensions，應包含 `SaveMyBookWidgetExtension.appex` 與 `SaveMyBookNotificationService.appex`，且此階段排在「Run Script」之前。
6. Product → Build（⌘B）。

### Apple Developer 帳號設定

Automatic Signing 通常會自動完成；若建置時出現描述檔（provisioning profile）錯誤，請手動確認：

1. [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list) → Identifiers → `today.savemybook.app` → 勾選 **Communication Notifications** → Save。
2. 確認存在 `today.savemybook.app.SaveMyBookNotificationService` 的 App ID（Automatic Signing 會自動建立；手動建立時不需勾選任何 Capability）。
3. 若使用手動描述檔，需為擴充功能另外建立 Development 與 App Store 描述檔，並重新產生主程式描述檔（加入 Communication Notifications 後舊描述檔失效）。
4. Xcode → Settings → Accounts → Download Manual Profiles，或刪除舊描述檔後重新建置。

### 若自動加入的 Target 無法使用（備援手動步驟）

僅在 Xcode 回報專案檔毀損或 Target 異常時執行：

1. 以 git 還原 `ios/Runner.xcodeproj/project.pbxproj` 至本次變更前版本，暫時將 `ios/SaveMyBookNotificationService` 資料夾移到專案外。
2. Xcode → File → New → Target → iOS → **Notification Service Extension** → Next。
3. Product Name：`SaveMyBookNotificationService`；Team：`Q929JXJ8S7`；Language：Swift；Embed in Application：Runner → Finish；詢問是否啟用 Scheme 時選 Cancel。
4. 刪除 Xcode 產生的 `NotificationService.swift` 與 `Info.plist` 內容，改放回本專案的兩個檔案（檔名相同）。
5. 擴充功能 Target → Build Settings：
   - `PRODUCT_BUNDLE_IDENTIFIER` = `today.savemybook.app.SaveMyBookNotificationService`
   - `IPHONEOS_DEPLOYMENT_TARGET` = `15.5`
   - `INFOPLIST_FILE` = `SaveMyBookNotificationService/Info.plist`
   - `MARKETING_VERSION` = `$(FLUTTER_BUILD_NAME)`、`CURRENT_PROJECT_VERSION` = `$(FLUTTER_BUILD_NUMBER)`
6. 專案 Info → Configurations：擴充功能 Target 的 Debug / Release / Profile 皆指定 `Generated`（`Flutter/Generated.xcconfig`）。
7. 在擴充功能資料夾上按右鍵 → 若為 Synchronized Folder，點選 Target Membership 旁的 Exceptions，將 `Info.plist` 排除，避免「Multiple commands produce Info.plist」。
8. Runner → Build Phases：將「Embed Foundation Extensions」拖到「Run Script」之前（否則 Flutter 會出現建置循環錯誤）。
9. Runner → Signing & Capabilities → + Capability → Communication Notifications。

### 呈現邏輯

- `type != message` 或缺少 `sender_id`：原樣顯示。
- 下載 `sender_avatar`（單次請求 8 秒、總計 12 秒逾時，上限 5 MB，需為可解碼圖片）；失敗時仍套用溝通通知，但以系統預設頭像（姓名縮寫）呈現。
- 建立 `INPerson`（名稱、頭像、以 `sender_id` 為 handle）、`INSendMessageIntent`（`conversationIdentifier = thread_id`；群組另設 `speakableGroupName = room_title` 與收件者），捐贈 `INInteraction` 後呼叫 `content.updating(from:)`。
- 群組內文若以「發送者：」開頭會去除，避免與系統顯示的發送者名稱重複。
- 任何錯誤或擴充功能時間即將用盡時，送出原始通知內容。

---

## 四、Android

### 已加入專案的內容

| 項目 | 位置 |
| --- | --- |
| 訊息服務 | `android/app/src/main/kotlin/com/example/savemybook_app/SaveMyBookMessagingService.kt` |
| 通知繪製 | `android/app/src/main/kotlin/com/example/savemybook_app/ChatNotifications.kt` |
| Manifest | 移除外掛的 `FlutterFirebaseMessagingService`，改註冊 `.SaveMyBookMessagingService` |
| Gradle | `android/app/build.gradle.kts` 新增 `firebase-bom:34.18.0`、`firebase-messaging`、`androidx.core:core:1.13.1` |
| 字串 | `res/values*/strings.xml` 新增 `notification_self_name` |

`firebase-bom` 版本需與 `firebase_core` 外掛 `android/gradle.properties` 的 `FirebaseSDKVersion` 一致；升級 `firebase_core` 時一併更新。

### 運作方式

- `SaveMyBookMessagingService` 繼承 firebase_messaging 的 `FlutterFirebaseMessagingService`，Token 更新沿用外掛行為。
- Flutter 端的 `onMessage`／背景處理由外掛的 BroadcastReceiver 觸發，與此服務無關，因此不會重複。
- 只在「純 data 訊息、含 `title` 或 `body`、App 不在前景（或螢幕鎖定）」時繪製通知；前景由 `PushService` 顯示應用程式內橫幅。
- 聊天訊息（`type = message` 且有 `sender_id`）：
  - 下載頭像（連線與讀取各 5 秒，上限 5 MB），失敗時以 App 主色底＋姓名首字產生頭像。
  - `Person` 圖示為圓形頭像；`MessagingStyle` 以 `thread_id` 為通知 tag，同一聊天室的新訊息會累加在同一則通知。
  - 發布長效動態捷徑（ID = `thread_id`），通知設定 `shortcutId` 與 `LocusId`，Android 11 以上顯示於「對話」區塊，頭像為主圖並帶 App 角標。
  - 頻道 `savemybook_default`（若尚未建立會以相同名稱與重要性建立）。
- 點擊通知開啟 `MainActivity`，Intent extras 帶有全部 data 欄位與 `google.message_id`；服務事先將訊息存入外掛的訊息暫存區，因此 `FirebaseMessaging.onMessageOpenedApp` 與 `getInitialMessage()` 會取得相同的 `data`，沿用 `PushService._open` 與 `NotificationRouter` 導頁。

---

## 五、Flutter（Dart）

- `lib/services/push_service.dart`：前景訊息若無 `notification` 區塊，改用 `data.title`／`data.body`；有 `sender_avatar` 時傳給橫幅。聊天室開啟中（`ChatRoomScreen.isShowing`）仍不顯示橫幅。
- `lib/widgets/in_app_banner.dart`：`showInAppBanner` 新增選填參數 `imageUrl`，顯示圓形頭像並於右下角疊加 App 圖示；圖片載入失敗時退回原本的類型圖示。

---

## 六、測試步驟

### iOS（建議使用實機測試）

1. 以 Xcode 安裝至實機並登入，允許通知。
2. 以另一帳號傳送一對一訊息，App 退到背景或鎖定畫面：通知主圖應為對方頭像，右下角為 App 圖示，標題為對方名稱。
3. 在群組傳送訊息：標題為群組名稱，顯示發送者名稱與頭像，內文不重複「發送者：」。
4. 將對方頭像設為空白或無效網址：通知仍正常送達（顯示姓名縮寫頭像）。
5. 點擊通知：開啟對應聊天室。
6. 除錯：Xcode → Debug → Attach to Process by PID or Name → `SaveMyBookNotificationService`，再發送推播即可中斷點除錯；主控台（Console.app）可篩選該程序名稱。

### Android（Android 11 以上可看到完整對話樣式）

1. 伺服器改為純 data 格式後，`flutter run` 安裝並登入。
2. App 退到背景：通知應顯示在「對話」區塊，頭像為主圖並帶 App 角標；連續訊息累加於同一則通知。
3. App 完全關閉（從最近使用清單滑掉）再傳訊息：仍應顯示，點擊後開啟對應聊天室。
4. App 在前景（非該聊天室）：只出現應用程式內橫幅（含頭像），不出現系統通知；在該聊天室內：兩者皆不出現。
5. 本機模擬純 data 訊息可使用 Firebase Admin SDK 或 FCM HTTP v1 API 送出第二節範例。
6. 除錯：`adb logcat | grep -i -E "FLTFireMsg|SaveMyBook"`。

---

## 七、已知限制

- Android 10 以下沒有「對話」區塊，改以大圖示顯示頭像。
- 使用者在系統設定將對話設為「非對話」或關閉頻道時，依系統設定顯示。
- 桌面小工具 Target（`SaveMyBookWidgetExtension`）目前 `MARKETING_VERSION = 1.0` 與主程式不一致，上傳 App Store 時可能出現版本不符警告，可比照本擴充功能改用 `$(FLUTTER_BUILD_NAME)`。
