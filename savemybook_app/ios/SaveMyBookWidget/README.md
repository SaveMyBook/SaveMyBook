# 桌面小工具（取書與訊息）設定說明

小工具顯示：待取書數量（中尺寸另顯示第一筆的取書碼與櫃點）、待存書數量、未讀訊息數、代幣餘額與最後更新時間；未登入時顯示「登入以查看」。資料由 App 內的 `HomeWidgetService.sync()` 寫入，小工具本身不連網，App 同步後才會更新。

- App Group：`group.today.savemybook.app`
- iOS 小工具 kind：`SaveMyBookSummaryWidget`
- Android Provider：`com.example.savemybook_app.SaveMyBookWidgetProvider`

---

## Android

不需要任何手動設定，原生程式碼與資源都已在專案內：

- `android/app/src/main/kotlin/com/example/savemybook_app/SaveMyBookWidgetProvider.kt`
- `android/app/src/main/res/layout/savemybook_widget.xml`
- `android/app/src/main/res/xml/savemybook_widget_info.xml`
- `android/app/src/main/res/drawable/smb_widget_*.xml`
- `android/app/src/main/res/values*/smb_widget_*.xml`
- `AndroidManifest.xml` 內的 `<receiver android:name=".SaveMyBookWidgetProvider">`

步驟：

1. `flutter pub get`
2. 重新建置並安裝：`flutter run`（或 `flutter build apk`）。
3. 在桌面長按 → 小工具 → 找到「救舊我的書」→ 拖曳「取書與訊息」到桌面，可自由調整大小。
4. 開啟 App 並登入一次，小工具就會出現資料。

---

## iOS（需要在 Xcode 手動加入 Widget Extension target）

此資料夾內的檔案：

| 檔案 | 用途 |
| --- | --- |
| `SaveMyBookWidget.swift` | 小工具全部程式碼（含 `@main` 的 WidgetBundle） |
| `Info.plist` | Extension 設定 |
| `SaveMyBookWidget.entitlements` | App Group 權限 |
| `README.md` | 本說明 |

### 0. 事前準備

```sh
cd savemybook_app
flutter pub get
cd ios && pod install && cd ..
```

### 1. 先把這個資料夾暫時改名

Xcode 建立 target 時會在 `ios/` 底下建立同名的 `SaveMyBookWidget` 資料夾，已經存在會衝突，所以先改名：

```sh
mv ios/SaveMyBookWidget ios/SaveMyBookWidget_src
```

### 2. 建立 Widget Extension target

1. 用 Xcode 開啟 `ios/Runner.xcworkspace`（不是 `.xcodeproj`）。
2. 選單 **File › New › Target…**
3. 平台選 **iOS**，選 **Widget Extension**，按 **Next**。
4. 填寫：
   - **Product Name**：`SaveMyBookWidget`（大小寫必須一致）
   - **Team**：與 Runner 相同的開發團隊
   - **取消勾選** `Include Live Activity`
   - **取消勾選** `Include Control`（Xcode 16 以上才有）
   - **取消勾選** `Include Configuration App Intent`（舊版 Xcode 叫 `Include Configuration Intent`）
   - **Project**：`Runner`
   - **Embed in Application**：`Runner`
5. 按 **Finish**。
6. 跳出「Activate "SaveMyBookWidgetExtension" scheme?」時選 **Don't Activate**（Flutter 一律使用 Runner scheme）。

### 3. 用專案內的檔案取代 Xcode 產生的檔案

1. 在 Xcode 左側 Project Navigator 的 `SaveMyBookWidget` 群組中，對下列 Xcode 產生的檔案按右鍵 › **Delete** › **Move to Trash**（有哪個就刪哪個）：
   - `SaveMyBookWidgetBundle.swift`（一定要刪，否則會有兩個 `@main`）
   - `AppIntent.swift`
   - `SaveMyBookWidgetLiveActivity.swift`
   - `SaveMyBookWidgetControl.swift`
   保留 `SaveMyBookWidget.swift`、`Info.plist`、`Assets.xcassets`。
2. 在終端機用專案內的版本覆蓋，並刪掉暫存資料夾：

   ```sh
   cp ios/SaveMyBookWidget_src/SaveMyBookWidget.swift ios/SaveMyBookWidget/SaveMyBookWidget.swift
   cp ios/SaveMyBookWidget_src/Info.plist ios/SaveMyBookWidget/Info.plist
   cp ios/SaveMyBookWidget_src/SaveMyBookWidget.entitlements ios/SaveMyBookWidget/SaveMyBookWidget.entitlements
   cp ios/SaveMyBookWidget_src/README.md ios/SaveMyBookWidget/README.md
   rm -r ios/SaveMyBookWidget_src
   ```

3. 回到 Xcode，確認 `SaveMyBookWidget.swift` 的 **File Inspector › Target Membership** 只勾選 `SaveMyBookWidgetExtension`（不要勾 Runner）。
4. Xcode 15 以前（一般群組，不是自動同步資料夾）：若 Navigator 看不到 `SaveMyBookWidget.entitlements`，在 `SaveMyBookWidget` 群組按右鍵 › **Add Files to "Runner"…** 加入，**Targets 全部不要勾**。
5. Xcode 16 以上（自動同步資料夾）：若 `README.md` 出現在 extension 的 Target Membership，取消勾選即可（不取消也不影響執行）。

### 4. 設定 extension target 的 Build Settings

在 Project Navigator 點最上方的 `Runner` 專案 › TARGETS 選 **SaveMyBookWidgetExtension** › **Build Settings**（上方切到 **All** 與 **Combined**）：

| 設定 | 值 |
| --- | --- |
| **iOS Deployment Target** | `15.5`（與 Runner 相同；Xcode 預設是最新版，太高的話舊版 iOS 看不到小工具） |
| **Code Signing Entitlements** | `SaveMyBookWidget/SaveMyBookWidget.entitlements`（Debug、Release、Profile 三個組態都要） |
| **Info.plist File** | `SaveMyBookWidget/Info.plist`（通常已自動設定） |
| **Product Bundle Identifier** | `today.savemybook.app.SaveMyBookWidget`（必須以 `today.savemybook.app.` 開頭） |

### 5. 兩個 target 都加入 App Group

App 與小工具必須在同一個 App Group 才能共用資料，**Runner 與 SaveMyBookWidgetExtension 兩個都要加**。

1. TARGETS 選 **Runner** › **Signing & Capabilities** › 上方選 **All**。
2. 按左上 **+ Capability** › 雙擊 **App Groups**。
3. 在 App Groups 區塊按 **+**，輸入 `group.today.savemybook.app` › OK，並確認已勾選。
   （Xcode 會把它寫進 `Runner/Runner.entitlements`，原本的推播設定會保留。）
4. TARGETS 改選 **SaveMyBookWidgetExtension** › **Signing & Capabilities** › **All**：
   - 勾選 **Automatically manage signing**，**Team** 與 Runner 相同。
   - 若尚未出現 App Groups，同樣 **+ Capability › App Groups**，勾選 `group.today.savemybook.app`。
   - 群組名稱若顯示紅字，按旁邊的重新整理圖示讓 Xcode 向 Apple 註冊。

### 6. 調整 Runner 的 Build Phases 順序

Flutter 專案加入 extension 後，Xcode 常會出現 `Cycle inside Runner; building could produce unreliable results` 錯誤。預先處理：

1. TARGETS 選 **Runner** › **Build Phases**。
2. 把 **Embed Foundation Extensions**（舊版 Xcode 叫 **Embed App Extensions**）拖到 **Run Script** 的正上方（也就是在 `Thin Binary` 之前）。

### 7. 建置與執行

1. Xcode 上方 scheme 選 **Runner**，選擇實機或模擬器。
2. 在專案根目錄執行 `flutter run`（或在 Xcode 按 Run）。
3. 開啟 App 並登入一次，讓 App 寫入資料。
4. 回到桌面長按 › 左上角 **+** › 搜尋「救舊我的書」› 選小或中尺寸 › **加入小工具**。

### 常見問題

- **登入後小工具仍顯示「登入以查看」**：確認 Runner 與 extension 兩個 target 都有 App Group `group.today.savemybook.app`，且拼字完全一致；再開一次 App 讓它重新同步。
- **小工具清單裡找不到**：確認 extension 的 iOS Deployment Target 不高於裝置版本；刪除 App 後重新安裝，必要時重新開機。
- **簽署錯誤（provisioning profile 不含 App Groups）**：兩個 target 都要使用同一個 Team 並開啟自動簽署；到 Signing & Capabilities 按一次 App Groups 旁的重新整理。
- **上傳 App Store 時出現 `CFBundleShortVersionString Mismatch` 警告**：把 extension target 的 **Marketing Version** 與 **Current Project Version** 設成與 `pubspec.yaml` 的版本相同（例如 `1.2.0` 與 `5`）。
- **`flutter build ipa` 失敗並提到 extension 簽署**：確認 extension 在 Release 與 Profile 組態也設定了 Team 與 Code Signing Entitlements。
