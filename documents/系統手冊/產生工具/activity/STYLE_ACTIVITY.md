# 5-3 使用個案活動圖規範（比照初評版三泳道黑白活動圖）

範例：`uc05.puml`（UC-05 賣家實體書櫃存書），已通過 A4 檢查。

1. 開頭固定：
```
@startuml
skinparam monochrome true
skinparam shadowing false
skinparam dpi 220
skinparam defaultFontName "PingFang TC"
skinparam defaultFontSize 13
skinparam swimlaneWidth same
```
2. 泳道：第一條為「使用者（角色）」，例如「使用者（賣家）」「使用者（買家）」「使用者（會員）」「管理員」；第二條為「系統」（App 與伺服器合併視為系統）；必要時第三條為「實體書櫃」「AI服務」「第三方登入服務」等外部參與者。最多三條，非必要不加。
3. 分支標籤一律寫成 `([是])`、`([否])`，或 `([退款])` 這類以中括號包住的條件；判斷框內寫簡短問句，例如「數字相符？」。
4. 內容：主要流程完整呈現；例外只畫最重要的一到三個（例如驗證失敗、逾時、取消），其餘例外不畫。每個動作框每行不超過約 14 個中文字，最多兩行。
5. 禁止：title、note、legend、顏色、檔名、函式名、程式變數、API 路徑以外的技術細節（活動圖不需要 API 路徑）。用語為正式繁體中文，與 App 畫面名稱一致（例如「取消上架」「申請爭議」「先行存書」「待取書」）。
6. 必須符合現行系統：以 `use_cases.md` 中對應之使用個案描述表為準；描述不清楚時可唯讀查閱 `/Users/xukaijun/Desktop/SaveMyBook/savemybook_api` 與 `savemybook_app` 的程式碼確認。
7. 版面：以 `java -jar ../plantuml.jar -tpng ucNN.puml` 產生 PNG，再以 `../docenv/bin/python ../a4check.py ucNN.png` 檢查，必須沒有「字太小」警告（放入 Word 後寬 ≤ 18 cm、高 ≤ 23 cm、字級 ≥ 9 pt）。不通過就合併步驟、縮短文字或減少例外，直到通過。
8. 檔名：`ucNN.puml`、`ucNN.png`（NN 為兩位數之使用個案編號，例如 uc01、uc34）。只在本資料夾建立自己負責的檔案，不修改其他任何檔案。
