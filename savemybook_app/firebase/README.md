# Firebase 設定檔

把從 Firebase 主控台下載的兩個檔案放在這個資料夾：

- `GoogleService-Info.plist`（iOS App）
- `google-services.json`（Android App）

然後在 `savemybook_app/` 底下執行：

```bash
python3 tool/firebase_setup.py
```

它會產生 `lib/firebase_options.dart`。這兩個檔案與產生出來的程式碼只含公開的用戶端設定，
可以進版控；伺服器用的「服務帳戶金鑰」才是機密，絕對不要放進這裡。
