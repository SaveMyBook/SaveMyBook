# API 測試

```bash
npm test          # 執行所有測試組
node test/ai/run-all.js     # 只跑 AI
node test/auth/run-all.js   # 只跑登入
```

測試不連資料庫、不連外部服務：以假的 Prisma Client 取代 `@prisma/client`，並攔截 `fetch` 回傳預錄的回應，直接驅動 Express 路由。因此可在任何機器上執行，不需要 `.env` 或 `prisma generate`。

每一組（`test/<組名>/`）是獨立的行程，各自有自己的假 Prisma 與假 fetch，彼此不互相污染；新增一組時建立資料夾並提供 `run-all.js` 即可，`npm test` 會自動納入。

- `test/ai`：AI 設定與用量、同意機制、客服（含知識庫與政策常數、服務條款的一致性）、推薦、上架輔助（書目欄位、日期精度、簡介清理）、書籍顧問、三家服務商轉接器、結構化輸出與伺服器端查證（`ai-structured.js`）、決策紀錄與降級（`ai-decisions.js`、`ai-degrade.js`）、書目比對與 ISBN 快取（`ai-bibliography.js`）、客服語系（`ai-support-locale.js`）、使用者評價與品質報表（`ai-feedback.js`），以及固定答案評測（見下節）。
- `test/auth`：Firebase ID Token 驗證、社群登入與註冊、綁定與解除、LINE／Discord OAuth 流程、管理端設定。
- `test/chat`：聊天室、訊息與編輯收回、靜音封鎖、群組與管理員、歷史可見範圍、@提及、聊天室轉帳、推播內容。
- `test/link-preview`：聊天連結預覽的 SSRF 防護（私有與中繼資料位址、轉址、DNS rebinding、連接埠與協定）、大小與逾時限制、壓縮與編碼、OG 解析與後備、HTML 清除、站內書籍連結、快取與合併請求、限流、圖片代理簽章與格式檢查。以假的 node:dns 與 node:http(s) 取代對外連線。
- `test/commerce`：書籍上下架與違規鎖定、ISBN 查詢、AI 上架審核、管理員書籍管理、上架後存書與逾期提醒、訂單與結算、預約、購物車與錢包、客服與爭議。
- `test/uploads`：上傳檔案遺失時的回應處理與資料庫清理。
- `test/passkeys`：通行密鑰的註冊、登入與身分驗證（以 node:crypto 模擬真實驗證器產生 attestation 與簽章）、挑戰值單次使用與逾時、用途與範圍綁定、來源與 RP ID 檢查、簽章計數倒退、帳號列舉防護、最後一個登入方式、後台範圍接受通行密鑰權杖、未設定 RP ID 時停用、應用程式關聯檔案。
- `test/kiosk`：模擬書櫃頁面（`/kiosk`）的開關、安全標頭與資產白名單，書櫃螢幕沒有可點擊元素，以及 `device-core.js` 以假時鐘與假 fetch 驗證的裝置行為：開機與輪詢、申請與輪詢配對碼、比對碼顯示、開鎖時序與往返時間檢查、本機開門模式與倒數、手機完成或取消的 close 指令與門磁拒絕、離線佇列與重送、重新開機與憑證失效、內嵌 QR 產生器。
- `test/platform`：狀態與中介層、帳號安全、帳號資料與刪除、通知與推播、後台權限、操作紀錄、備份（含一次性下載網址）、加密編號、輸入驗證。

## AI 固定答案評測

`test/ai/golden/` 存放客服、書籍顧問與推薦的檢索題庫，由 `test/ai/ai-golden.js` 隨 AI 測試組執行，不呼叫模型、不產生費用。測試環境關閉語意向量，量到的是純關鍵字檢索。

- `support.json`：客服提問與可接受的知識段落（平台主題代號或 `faq:編號`），涵蓋口語、錯字、英文、易混淆詞與應轉接的題目；政策關鍵題另設 `max_rank`（名次上限）。
- `catalog.json`：測試書目，含維修中的書櫃、他人預約保留中與非在售的書；`book-chat.json` 為書籍顧問查詢，`recommend.json` 為推薦的使用者人設。兩者的 `must_show` 為依規則可購買、必須出現的書（已過期或待回覆的預約、本人的保留）。
- `baseline.json`：題庫雜湊值、前 k 名命中率（hit@k）、平均排名倒數（MRR）、門檻、各題名次與弱點清單。
- `bibliography.json`：書名比對題庫（副標、版次、套書與簡繁差異須判定相符，ISBN 屬於另一本書須判定不符），由 `ai-bibliography.js` 驗證書名比對結果，以及錯誤 ISBN 經書目補齊後的誤寫率為 0。

書籍顧問的 `search` 是對照書目撰寫的理想搜尋條件，「依條件模式」等於假設第一段條件完美，只量排序與過濾，不代表第一段模型的實際表現；「只用原話模式」較接近條件品質不佳時的下限。命中率與 `recall@retrieved` 只計入檢索命中的書，不含補位的其他在售書與未命中時的熱門書。

以下情況測試即失敗：
- 整體指標低於門檻。
- 政策關鍵題超過 `max_rank`，或基準中排在前 3 名的題目變成未找到（題庫未變動時）。
- 結果出現維修中、他人保留中、本人上架、非在售、超出預算或書況不符的書，或 `must_show` 的書被排除。
- 題庫檔的雜湊值與基準不符（修改題庫後未重新產生基準）。

修改檢索、知識庫或題庫後：

```bash
GOLDEN_VERBOSE=1 node test/ai/run-all.js   # 另列出排在第 3 名之後或未找到的題目
GOLDEN_UPDATE=1 node test/ai/run-all.js    # 重新產生 baseline.json
```

更新基準時先判定再寫檔，未通過的結果不會覆寫基準。題庫未變動時門檻只會調高；題庫變動時門檻依新題庫重新計算，請在變更說明中註明。若題庫未變動而須調低門檻，請手動修改 `baseline.json` 的 `thresholds` 並說明原因。

## 結構化輸出的實際模型驗證

`lib/ai/schema.js` 的規格同時產生 OpenAI 嚴格模式的 JSON Schema（`strict`）與伺服器端驗證器（`check`）。
單元測試只驗證轉換結果與驗證規則，服務商是否接受這份 Schema、小模型能否穩定遵守，必須以真實金鑰確認：

1. 在有金鑰的環境逐一送出各功能的規格（`support.OUTPUT`、`bookChat.PLAN_OUTPUT`、`bookChat.PICK_OUTPUT`、`recommend.OUTPUT`、
   `disputeAssist.OUTPUT`、`moderation.OUTPUT`），以 `lib/ai` 的 `generate(provider, { json: true, schema: X.strict, ... })` 呼叫 OpenAI。
   回傳 400 `BAD_REQUEST` 代表 Schema 含服務商不支援的關鍵字，須先修正 `toStrict`。
2. 以 P6 的評測題庫（B 層）分別在 DeepSeek、Gemini、OpenAI 上執行，比較 `check` 的失敗率與修復重試的次數。
3. 上線後在後台 AI 功能頁「處理結果」分頁的「輸出格式錯誤」檢視各功能與服務商的格式錯誤比例；書籍顧問的回覆查證旗標
   （書名與書卡不符、提及價格、有書卡但回覆稱無相關書籍）累積足夠樣本、確認誤判率後，才把 `REPLY_CHECK_ENFORCED` 改為 true。
