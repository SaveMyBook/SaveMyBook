# API 測試

```bash
npm test          # 執行所有測試組
node test/ai/run-all.js     # 只跑 AI
node test/auth/run-all.js   # 只跑登入
```

測試不連資料庫、不連外部服務：以假的 Prisma Client 取代 `@prisma/client`，並攔截 `fetch` 回傳預錄的回應，直接驅動 Express 路由。因此可在任何機器上執行，不需要 `.env` 或 `prisma generate`。

每一組（`test/<組名>/`）是獨立的行程，各自有自己的假 Prisma 與假 fetch，彼此不互相污染；新增一組時建立資料夾並提供 `run-all.js` 即可，`npm test` 會自動納入。

- `test/ai`：AI 設定與用量、同意機制、客服、推薦、上架輔助（書目欄位、日期精度、簡介清理）、書籍顧問、三家服務商轉接器。
- `test/auth`：Firebase ID Token 驗證、社群登入與註冊、綁定與解除、LINE／Discord OAuth 流程、管理端設定。
- `test/chat`：聊天室、訊息與編輯收回、靜音封鎖、群組與管理員、歷史可見範圍、@提及、聊天室轉帳、推播內容。
- `test/link-preview`：聊天連結預覽的 SSRF 防護（私有與中繼資料位址、轉址、DNS rebinding、連接埠與協定）、大小與逾時限制、壓縮與編碼、OG 解析與後備、HTML 清除、站內書籍連結、快取與合併請求、限流、圖片代理簽章與格式檢查。以假的 node:dns 與 node:http(s) 取代對外連線。
- `test/commerce`：書籍上下架與違規鎖定、ISBN 查詢、AI 上架審核、管理員書籍管理、訂單與結算、預約、購物車與錢包、客服與爭議。
- `test/uploads`：上傳檔案遺失時的回應處理與資料庫清理。
- `test/passkeys`：通行密鑰的註冊、登入與身分驗證（以 node:crypto 模擬真實驗證器產生 attestation 與簽章）、挑戰值單次使用與逾時、用途與範圍綁定、來源與 RP ID 檢查、簽章計數倒退、帳號列舉防護、最後一個登入方式、後台範圍接受通行密鑰權杖、未執行 016 的行為、應用程式關聯檔案。
- `test/platform`：狀態與中介層、帳號安全、帳號資料與刪除、通知與推播、後台權限、操作紀錄、備份（含一次性下載網址）、加密編號、輸入驗證。
