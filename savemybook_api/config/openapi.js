const fs = require('fs');
const path = require('path');
const YAML = require('yaml');

const port = process.env.PORT || 3000;
const docsDir = path.join(__dirname, '../docs');

const description = `
SaveMyBook 為結合智慧書櫃的二手書交易平台。賣家將書籍存入書櫃，買家至書櫃掃描機台上的 QR Code 取件，
雙方無須當面交付，金流以站內代幣結算。

本文件涵蓋行動應用程式與管理後台所使用的全部端點。

---

## Quick Start

1. 呼叫 \`POST /api/users\` 建立帳號，或使用既有帳號。
2. 呼叫 \`POST /api/auth/login\` 取得 JWT Token。
3. 於右上角 **Authentication** 填入 Token（無須自行加上 \`Bearer \` 前綴）。
4. 後續所有需授權的端點將自動帶入該 Token。

\`\`\`bash
curl -X POST http://localhost:${port}/api/auth/login \\
  -H 'Content-Type: application/json' \\
  -d '{"email":"test@example.com","password":"your_password123"}'
\`\`\`

---

## Response Format

所有 JSON 端點均遵循相同的外層結構，用戶端依 \`success\` 判斷處理分支。

\`\`\`jsonc
// 成功
{ "success": true, "message": "登入成功", "data": { ... } }

// 失敗
{ "success": false, "message": "密碼錯誤", "code": "INVALID_PASSWORD" }
\`\`\`

| 欄位 | 說明 |
| --- | --- |
| \`success\` | 必定存在，值為 \`true\` 或 \`false\` |
| \`message\` | 可直接呈現給使用者的繁體中文訊息；部分查詢類端點不含此欄位 |
| \`data\` | 主要內容，型別為物件或陣列 |
| \`code\` | 僅需用戶端分支處理的錯誤帶此欄位，可能的值見錯誤代碼一節 |
| \`pagination\` | 分頁端點於**外層**帶此物件，並非置於 \`data\` 之內 |

分頁物件結構：

\`\`\`json
{ "total": 137, "page": 2, "limit": 20, "total_pages": 7 }
\`\`\`

---

## Authentication

Token 由 \`POST /api/auth/login\` 簽發，有效期 24 小時，以
\`Authorization: Bearer <token>\` 標頭傳遞。每次登入建立一筆裝置工作階段，
Token 到期後可憑同一裝置以 \`POST /api/auth/refresh\` 換發，裝置最近 30 天內使用過即可。

驗證中介層於每次請求查詢資料庫確認帳號狀態，不僅驗證簽章。因此帳號停權或列入黑名單後
立即失效，無須等待 Token 到期；管理員遭降級亦同步生效。此設計的成本為每次請求
增加一次資料庫查詢。

| 狀況 | HTTP | \`code\` |
| --- | --- | --- |
| 未提供 Token | 401 | － |
| Token 已過期 | 403 | \`TOKEN_EXPIRED\` |
| Token 簽章無效 | 403 | － |
| 帳號已刪除 | 401 | \`ACCOUNT_NOT_FOUND\` |
| 帳號列入黑名單 | 401 | \`ACCOUNT_BLACKLISTED\` |
| 帳號已停權 | 401 | \`ACCOUNT_INACTIVE\` |
| 密碼已變更（含客服重設），舊 Token 失效 | 401 | \`TOKEN_REVOKED\` |
| 裝置已登出（本機登出、遠端登出或登出所有裝置） | 401 | \`SESSION_REVOKED\` |
| \`POST /api/auth/refresh\` 無法換發 | 401 | \`REFRESH_FAILED\` |

收到 \`TOKEN_EXPIRED\` 時，先呼叫 \`POST /api/auth/refresh\` 換發 Token 並重送原請求；
換發失敗或收到其他回應時，應清除本機 Token 並導向登入流程。

---

## Verification

付款與敏感操作須在 Token 之外另行驗證身分。未帶入有效的 \`X-Verify-Token\` 標頭時回傳 403
\`VERIFICATION_REQUIRED\`，回應附帶 \`verification: { scope, methods }\`：

1. 依 \`verification.methods\` 讓使用者選擇驗證方式（登入密碼、通行密鑰、交易密碼或生物辨識）。
2. 呼叫 \`POST /api/security/verify\` 取得 \`verify_token\`。
3. 以 \`X-Verify-Token: <verify_token>\` 標頭重送原請求。

| \`scope\` | 可用方式 | 有效期 | 使用次數 | 適用端點 |
| --- | --- | --- | --- | --- |
| \`payment\` | 交易密碼、生物辨識 | 3 分鐘 | 單次；請求失敗（狀態碼大於等於 400）時恢復可用 | \`POST /api/orders/checkout\`、\`POST /api/chat/rooms/{roomId}/transfers\`、\`POST /api/chat/transfers/{id}/pay\` |
| \`sensitive\` | 登入密碼、通行密鑰、交易密碼、生物辨識 | 5 分鐘 | 有效期內可重複使用 | 匯出個人資料、交易密碼與登入裝置管理；後台刪除使用者（\`DELETE /api/users/{id}\`） |
| \`admin\` | 登入密碼、通行密鑰 | 5 分鐘 | 有效期內可重複使用 | 後台高風險操作：錢包調整、重設會員密碼、設定管理員權限、產生備份下載網址、刪除備份、立即匿名化、還原操作、修改 AI 與登入方式設定、遠端開啟書櫃櫃門、以配對碼綁定書櫃裝置 |

\`verify_token\` 記錄簽發時使用的驗證方式。\`admin\` 範圍只接受帳號的登入密碼或通行密鑰（兩者視為同等強度），
以交易密碼或生物辨識簽發的權杖不得用於後台端點；尚未設定登入密碼的帳號（社群註冊）
須先於「帳號安全」設定密碼，否則驗證回傳 403 \`PASSWORD_NOT_SET\`。

交易密碼規則、錯誤鎖定與生物辨識付款的運作方式見「帳號安全」一節。

---

## Error Codes

除認證相關代碼外，業務邏輯另定義下列代碼：

| \`code\` | HTTP | 意義 | 建議處理方式 |
| --- | --- | --- | --- |
| \`INVALID_PASSWORD\` | 401 | 登入密碼錯誤 | 保留已輸入的 Email，僅於密碼欄位提示錯誤 |
| \`INSUFFICIENT_BALANCE\` | 400 | 代幣餘額不足以完成結帳、轉帳或支付請款 | 導向儲值流程 |
| \`BOOK_RESERVED\` | 409 | 書籍已由其他買家預約保留，無法加入購物車或結帳 | 顯示保留期限，引導瀏覽其他書籍 |
| \`VERIFICATION_REQUIRED\` | 403 | 需要身分驗證，回應附帶 \`verification\` | 依 \`verification\` 驗證後帶 \`X-Verify-Token\` 重送 |
| \`PAYMENT_PIN_NOT_SET\` | 403 | 尚未設定交易密碼 | 引導設定交易密碼 |
| \`PASSWORD_NOT_SET\` | 403 | 帳號尚未設定登入密碼，無法以密碼驗證身分 | 引導前往設定登入密碼 |
| \`INVALID_PIN\` | 400 | 交易密碼錯誤，回應附帶 \`remaining_attempts\` | 提示剩餘可嘗試次數 |
| \`PIN_LOCKED\` | 423 | 交易密碼連續錯誤 5 次，鎖定 15 分鐘，回應附帶 \`locked_until\` | 顯示解除時間 |
| \`PIN_FORMAT\`、\`PIN_TOO_WEAK\` | 400 | 設定的交易密碼不是 6 位數字，或過於簡單 | 於輸入欄位提示規則 |
| \`BIOMETRIC_KEY_INVALID\` | 400 | 這台裝置的生物辨識付款金鑰已失效 | 清除本機金鑰，改用交易密碼 |
| \`SESSION_REQUIRED\` | 403 | Token 未綁定裝置工作階段 | 引導重新登入 |
| \`CHAT_BLOCKED\` | 403 | 請求者已封鎖對方，無法傳送或編輯訊息、建立預約、轉帳或請款 | 顯示解除封鎖的入口 |
| \`RECIPIENT_UNAVAILABLE\` | 400 | 對方帳號停用，或對方已封鎖請求者（兩者刻意不區分） | 停用輸入欄位 |
| \`PIN_LIMIT\` | 400 | 釘選的聊天室已達 10 個 | 提示先取消其他釘選 |
| \`EDIT_WINDOW_PASSED\` | 400 | 訊息送出已超過 15 分鐘，無法編輯 | 隱藏編輯選項 |
| \`RECALL_WINDOW_PASSED\` | 400 | 訊息送出已超過 1 小時，無法收回 | 隱藏收回選項 |
| \`GROUP_MEMBER_LIMIT\` | 400 | 群組成員將超過 100 人 | 提示減少邀請人數 |
| \`TRANSFER_STATE_CHANGED\` | 409 | 請款已被付款、婉拒、取消或已到期 | 重新取得訊息以更新轉帳卡片 |
| \`DISPUTE_WINDOW_PASSED\` | 400 | 取書已超過 24 小時或訂單已完成，依服務條款不可再申請爭議 | 隱藏爭議入口 |
| \`ORDER_NOT_CANCELLABLE\` | 400 | 賣家已存書（含下單前書已存入書櫃、成立即為 \`deposited\` 的訂單），買賣雙方都不能自行取消訂單 | 隱藏取消按鈕，引導申請交易爭議 |
| \`BOOK_HELD\` | 409 | 書籍預約保留中，賣家不能編輯或下架 | 顯示保留到期時間，停用編輯與下架 |
| \`BOOK_LOCKED\` | 409 | 書籍訂單已成立或已完成，賣家不能編輯內容、照片或下架已完成的書 | 停用編輯與下架 |
| \`BOOK_NOT_APPROVED\` | 403 | 書籍因違規下架，賣家無法自行重新上架 | 引導使用者開立客服工單 |
| \`BOOK_NOT_FOUND\` | 404 | 書籍不存在或已被刪除，或尚未公開且請求者不是賣家 | 自本機快取（最近瀏覽、收藏、購物車）移除該書並返回上一頁 |
| \`LISTING_REJECTED\` | 422 | 編輯書籍或新增照片的內容未通過 AI 上架審核，變更未儲存 | 顯示 \`message\` 中的原因，引導使用者修改內容 |
| \`AI_DISABLED\` | 503 | AI 功能目前未開放 | 隱藏 AI 功能入口 |
| \`AI_NOT_CONFIGURED\` | 503 | 此 AI 功能使用的服務商尚未設定 API 金鑰 | 隱藏 AI 功能入口 |
| \`AI_BUDGET_EXCEEDED\` | 503 | AI 功能本月用量已達上限 | 提示稍後再試 |
| \`AI_CONSENT_REQUIRED\` | 403 | 使用者尚未同意將資料提供給 AI 服務商處理，或隱私權政策重大更新後尚未重新同意 | 顯示 AI 資料處理同意說明 |
| \`AI_CONSENT_NOTICE_OUTDATED\` | 409 | 同意 AI 資料處理時未附上目前的說明版本（\`notice_version\`） | 提示更新 App |
| \`AI_DAILY_LIMIT\` | 429 | 使用者今日 AI 使用次數已達上限，或已計費但失敗的呼叫已達每日上限 | 提示明日再試 |
| \`AI_CONTENT_BLOCKED\` | 422 | 內容遭 AI 服務商的安全機制拒絕，重送相同內容仍會失敗 | 顯示 \`message\`，不提供重試；內容可由使用者修改時引導調整 |
| \`AI_PROVIDER_ERROR\` | 502 | AI 服務商錯誤、逾時或回應格式不正確，且沒有可降級的內容 | 提示稍後再試 |
| \`AI_REQUEST_IN_PROGRESS\` | 409 | 相同 \`client_id\` 的訊息仍在處理中 | 稍後以相同 \`client_id\` 重送，或重新讀取對話 |
| \`AI_UNAVAILABLE\` | 503 | AI 功能目前未開放或尚未完成設定（交易爭議分析） | 隱藏 AI 分析入口 |
| \`INVALID_ID_TOKEN\` | 401 | 第三方登入憑證無效、過期或簽章不符 | 重新取得登入憑證後再試 |
| \`PROVIDER_MISMATCH\` | 400 | 登入憑證的實際來源與請求的 \`provider\` 不符 | 檢查 App 的登入流程 |
| \`NO_ACCOUNT_FOR_PROVIDER\` | 404 | 此第三方帳號尚未綁定任何帳號，且請求未帶 \`create\`；可能附帶 \`provider_email\` | 詢問使用者要登入既有帳號並綁定（\`POST /api/auth/social/link-login\`）、建立新帳號，還是取消 |
| \`ACCOUNT_EXISTS_LINK_REQUIRED\` | 409 | 該電子郵件已有帳號，但尚未綁定此登入方式；附帶 \`provider_email\` | 在登入流程中請使用者登入該帳號，以 \`POST /api/auth/social/link-login\` 綁定並登入 |
| \`EMAIL_REQUIRED\` | 400 | 第三方未提供已驗證的電子郵件，無法建立帳號 | 收集電子郵件與暱稱後以相同憑證重送 |
| \`SIGN_IN_METHOD_DISABLED\` | 403 | 該登入方式目前未開放，或伺服器未設定其憑證 | 隱藏該登入按鈕 |
| \`SIGNUP_NOT_ALLOWED\` | 403 | 該登入方式僅供既有帳號使用 | 提示改以既有方式登入後再綁定 |
| \`IDENTITY_TAKEN\` | 409 | 此第三方身分已綁定其他帳號 | 提示改用該帳號登入 |
| \`ALREADY_LINKED\` | 409 | 本帳號已綁定此登入方式 | 重新載入登入方式列表 |
| \`LAST_SIGN_IN_METHOD\` | 400 | 解除綁定或刪除通行密鑰後將沒有任何登入方式 | 引導先設定密碼或綁定其他方式 |
| \`PASSWORD_NOT_SET\` | 400 | 帳號尚未設定密碼，不能使用需輸入目前密碼的流程 | 引導改用 \`POST /api/auth/password/set\` |
| \`PASSWORD_ALREADY_SET\` | 400 | 帳號已有密碼，不能重複設定 | 改用變更密碼 |
| \`OAUTH_STATE_INVALID\` | 400 | 授權連結已逾時、已使用或不屬於此渠道 | 重新開始授權流程 |
| \`OAUTH_CODE_INVALID\` | 400 | 一次性碼不存在、已使用或已逾時 | 重新開始授權流程 |
| \`AUTH_PROVIDER_ERROR\` | 502 | 無法連線至第三方登入服務或其回應不正確 | 提示稍後再試 |
| \`AUTH_SOCIAL_UNAVAILABLE\` | 503 | 伺服器尚未設定 Firebase 專案參數 | 隱藏 Google、Apple 與手機號碼登入入口 |
| \`PASSKEY_UNAVAILABLE\` | 503 | 伺服器未設定通行密鑰的 RP ID 與來源 | 隱藏通行密鑰入口 |
| \`PASSKEY_CHALLENGE_INVALID\`、\`PASSKEY_CHALLENGE_EXPIRED\` | 400 | 挑戰值已使用、逾時，或用途與範圍不符 | 重新取得 options 後再試 |
| \`PASSKEY_VERIFICATION_FAILED\`、\`PASSKEY_INVALID_RESPONSE\` | 400 | 通行密鑰的簽章、RP ID、使用者驗證或格式驗證未通過 | 提示改用密碼 |
| \`PASSKEY_ORIGIN_NOT_ALLOWED\` | 400 | 請求來源不在伺服器允許的通行密鑰來源（通常是 Android 簽署金鑰指紋未加入 \`PASSKEY_ORIGINS\`），重試不會成功 | 顯示 \`message\`，提示改用其他方式 |
| \`PASSKEY_NOT_RECOGNIZED\` | 400 | 伺服器查無這組通行密鑰（已刪除，或帳號已不存在）；身分驗證時憑證不屬於目前帳號亦回此代碼 | 提示改用密碼；登入時可透過系統的 Signal API 通知移除該通行密鑰 |
| \`PASSKEY_COUNTER_REGRESSED\` | 400 | 通行密鑰的簽章計數倒退，疑似遭複製 | 提示改用密碼並檢查帳號安全 |
| \`PASSKEY_NOT_REGISTERED\` | 400 | 帳號尚未註冊通行密鑰 | 改用登入密碼驗證 |
| \`PASSKEY_ALREADY_REGISTERED\` | 409 | 這組通行密鑰已經註冊 | 重新載入清單，並說明同一個密碼管理工具已有通行密鑰 |
| \`PASSKEY_LIMIT\` | 400 | 通行密鑰已達 10 組上限 | 引導刪除不再使用的裝置 |
| \`BOOK_IN_TRANSACTION\` | 409 | 管理員刪除書籍時，書籍交易中或有進行中的預約 | 提示先處理交易或預約 |
| \`BOOK_HAS_ORDERS\` | 409 | 管理員刪除書籍時，書籍已有訂單紀錄 | 改用強制下架 |
| \`OPEN_ORDERS\` | 400 | 尚有進行中的訂單，無法申請刪除帳號 | 引導使用者完成或取消訂單 |
| \`RATE_LIMITED\` | 429 | 短時間內嘗試次數過多 | 依 \`Retry-After\` 標頭等待後再試 |
| \`ROUTE_NOT_FOUND\` | 404 | 端點不存在 | 檢查路徑與 HTTP 方法 |
| \`MAINTENANCE\` | 503 | 資料庫還原中，暫停服務 | 顯示維護訊息，稍後以 \`GET /api/status\` 確認 |

409 代表資料在處理期間被其他請求變更（例如兩人同時結帳同一本書、同一筆訂單被重複取消），
重新整理後再試即可。

### Smart Cabinet

智慧書櫃相關代碼集中於下列各表。\`message\` 為回應中的實際文字，\`{…}\` 為依情況帶入的值。

**掃碼作業**（\`/api/cabinet-sessions\`）

| \`code\` | HTTP | \`message\` | 情況與建議處理方式 |
| --- | --- | --- | --- |
| \`CABINET_CODE_INVALID\` | 400 | 此 QR Code 並非 SaveMyBook 書櫃 QR Code | 掃描內容不是書櫃 QR Code；提示重新掃描 |
| \`CABINET_CODE_EXPIRED\` | 410 | 書櫃 QR Code 已更新，請重新掃描書櫃螢幕上的 QR Code | QR Code 每 30 秒更新、最長有效 45 秒，或已被使用；引導重新掃描 |
| \`CABINET_BUSY\` | 409 | 書櫃使用中，請稍候再掃描 | 書櫃有其他進行中的作業 |
| \`CABINET_UNAVAILABLE\` | 409 | 此書櫃暫停服務 | 書櫃已停用 |
| \`CABINET_MAINTENANCE\` | 409 | 此書櫃維修中，暫停服務 | 書櫃維修中或裝置故障 |
| \`CABINET_CLOSED\` | 409 | 目前非書櫃營業時間，營業時間為 {open_time}–{close_time} | 附 \`open_time\`、\`close_time\` |
| \`CABINET_OFFLINE\` | 409 | 書櫃目前連線中斷，暫時無法使用 | 附 \`manual_allowed\`，為 true 時提供手動回報 |
| \`CABINET_ACTIVE_SESSION\` | 409 | 您有進行中的書櫃作業，請先完成或取消 | 附 \`session_no\`，引導回到該作業 |
| \`CABINET_COOLDOWN\` | 429 | 您在此書櫃的作業多次未完成，請於 {n} 分鐘後再試 | 本人在此書櫃最近 2 次作業皆以確認逾時、比對逾時、數字不符或開門前取消結束，自最後一次起 10 分鐘內拒絕；附 \`retry_after_s\` |
| \`CABINET_LOCATION_REQUIRED\` | 403 | 使用書櫃須允許存取位置資訊，請於系統設定中開啟後再試 | \`location_status\` 為 \`denied\`；提供開啟設定 |
| \`CABINET_LOCATION_UNAVAILABLE\` | 403 | 目前無法確認您的位置，請開啟定位服務後再試 | \`location_status\` 為 \`unavailable\`，或精度超過 500 公尺、定位資料超過 60 秒；提供重試 |
| \`CABINET_TOO_FAR\` | 403 | 您目前的位置距離書櫃約 {n} 公尺，請於書櫃旁操作 | 距離扣除定位精度（最多 100 公尺）後超過 200 公尺；附 \`distance_m\` |
| \`CABINET_NOTHING_TO_DO\` | 404 | 您在此書櫃沒有待辦理的項目 | 附 \`other_cabinets\` |
| \`CABINET_ITEM_BLOCKED\` | 409 | 第一個項目的受阻原因（見下方說明） | 所有項目皆無法辦理；附 \`items\` |
| \`CABINET_WRONG_CABINET\` | 409 | 此訂單的指定書櫃為「{cabinet_name}」，請至該書櫃辦理（書籍為「此書籍的指定書櫃為…」） | 帶入作業情境 \`context\` 時掃描了其他書櫃；附 \`cabinet\` |
| \`CABINET_CONTEXT_CHANGED\` | 409 | 訂單狀態已變更，請重新整理後再試／書籍狀態已變更，請重新整理後再試 | 作業情境的訂單或書籍已無法辦理；重新載入 |
| \`CABINET_SESSION_NOT_FOUND\` | 404 | 找不到此書櫃作業 | 作業不存在或不是本人的作業 |
| \`CABINET_NO_SELECTION\` | 400 | 請至少選擇一個項目 | \`start\` 未選擇項目 |
| \`CABINET_ITEMS_CHANGED\` | 409 | 部分項目狀態已變更，請重新確認 | \`start\` 時項目已變更；附更新後的 \`session\`，回到確認步驟 |
| \`CABINET_FULL\` | 409 | 此書櫃可用的櫃門不足，請減少存書項目或稍後再試 | 附 \`available_doors\`、\`required_doors\`；先行存書須保留 1 扇櫃門給訂單；手動回報先行存書時亦適用 |
| \`PREDEPOSIT_LIMIT\` | 409 | 您在此書櫃的先行存書已達上限，請待售出或取回後再存入 | 每位賣家在同一台書櫃最多先行存放 1 本；手動回報存書時亦適用 |
| \`MATCH_CODE_INVALID\` | 400 | 請輸入兩位數字 | \`code\` 不是 10 至 99 的兩位半形數字字串；不消耗比對機會 |
| \`CABINET_SESSION_STATE\` | 409 | 櫃門已開啟，無法執行此操作／本次作業處理中，請稍候／目前無法執行此操作 | 作業狀態不允許此操作；附 \`session\`，以其更新畫面 |
| \`ORDER_IN_CABINET_SESSION\` | 409 | 此訂單正於書櫃辦理中，請稍後再試 | 取消訂單或申請爭議時，該訂單有進行中的書櫃作業 |

\`CABINET_ITEM_BLOCKED\` 的 \`message\` 與 \`items[].blocked.message\` 相同，依受阻原因為：
\`DOOR_UNKNOWN\`「無法確認此項目的櫃門，請聯絡客服」、\`DOOR_FAULT\`「此項目的櫃門故障，請聯絡客服」、
\`DOOR_CHECK\`「此項目的櫃門待客服確認，請聯絡客服」、\`DOOR_SHARED\`「此櫃門存放其他項目，請聯絡客服」、
\`CABINET_FULL\`「書櫃目前沒有可用的櫃門」、\`PREDEPOSIT_LIMIT\`「您在此書櫃的先行存書已達上限，請待售出或取回後再存入」。

**存書登記與手動回報**（\`/api/books\`、\`/api/orders\`、\`/api/users\`）

| \`code\` | HTTP | \`message\` | 情況與建議處理方式 |
| --- | --- | --- | --- |
| \`CABINET_SCAN_REQUIRED\` | 409 | 此書櫃已啟用掃碼存取，請至書櫃以 App 掃描 QR Code 辦理 | 書櫃為掃碼模式時（含裝置離線或故障未滿 2 分鐘，及裝置自行解除配對或疑遭複製而撤銷後 2 分鐘內）呼叫手動存書、取書或取回；附 \`cabinet_id\`，引導掃碼 |
| \`MANUAL_REPORT_PENDING\` | 409 | 此項目已有待客服確認的手動回報 | 同一項目已有待確認的手動回報 |
| \`DEPOSIT_NOT_ALLOWED\` | 409 | 書籍須為上架中且已公開販售，才能存入書櫃／此書籍已有進行中的訂單，請依訂單流程存書 | 隱藏存書按鈕；已有訂單時改依訂單流程存書 |
| \`CABINET_REQUIRED\` | 400 | 請先於書籍資料中指定存放的書櫃 | 引導編輯書籍選擇書櫃 |
| \`CABINET_UNAVAILABLE\` | 400 | 此書櫃已停用，請先變更存放的書櫃 | 存書時書櫃已停用；引導編輯書籍改選其他書櫃 |
| \`CABINET_MAINTENANCE\` | 400 | 此書櫃維修中，暫時無法存書／《{title}》存放的書櫃維修中，暫時無法購買，請先移除或稍後再試 | 存書時書櫃維修中；結帳時購物車中的書存放於維修中的書櫃（直接購買時結尾為「請稍後再試」） |
| \`CABINET_UNAVAILABLE\` | 409 | 此書櫃暫停服務 | 已配對裝置的書櫃停用時，手動回報取回、訂單存書或取書 |
| \`CABINET_MAINTENANCE\` | 409 | 此書櫃維修中，暫停服務 | 已配對裝置的書櫃維修中時，手動回報取回、訂單存書或取書 |
| \`BOOK_DEPOSITED\` | 409 | 此書籍已登記存放於書櫃／此書籍已存放於書櫃，無法變更書櫃；請先至書櫃取回書籍後再變更 | 重複登記存書，或存書期間變更書櫃；重新載入書籍 |
| \`RETRIEVAL_REQUIRED\` | 409 | 此書籍仍存放於書櫃，請先至書櫃以 App 掃描 QR Code 取回後再重新上架 | 書籍仍登記存放於書櫃（不論是否已暫停販售）時重新上架；引導掃碼取回 |
| \`NOT_DEPOSITED\` | 409 | 此書籍目前未登記存放於書櫃 | 手動回報取回時書籍未登記存書；重新載入書籍 |
| \`BOOK_SOLD_IN_CABINET\` | 409 | 此書籍已售出（訂單 {order_no}），… | 手動回報取回時書籍已轉入進行中的訂單，\`message\` 依情況說明請勿取回、改存入訂單書櫃或以掃碼辦理訂單存書；停用取回按鈕並引導至該筆訂單 |
| \`BOOKS_IN_CABINET\` | 400 | 尚有 {n} 本書籍存放於書櫃，請先至書櫃以 App 掃描 QR Code 取回後再申請刪除 | 申請刪除帳號時 |

**後台書櫃管理**（\`/api/admin\`，權限 \`cabinets\`）

| \`code\` | HTTP | \`message\` | 情況與建議處理方式 |
| --- | --- | --- | --- |
| \`DEVICE_NOT_PAIRED\` | 409 | 此書櫃尚未配對裝置 | 遠端開櫃、撤銷裝置或清除裝置故障時沒有有效裝置 |
| \`DEVICE_OFFLINE\` | 409 | 書櫃裝置目前離線，無法遠端開啟櫃門 | 遠端開櫃 |
| \`CABINET_BUSY\` | 409 | 書櫃使用中，請待目前作業結束後再試 | 遠端開櫃時書櫃有進行中的作業 |
| \`CABINET_COOLDOWN\` | 429 | 數字確認多次未完成，請於 {n} 分鐘後再試 | 同一位管理員 10 分鐘內有 2 個遠端開櫃作業以比對逾時或數字不符結束（不分書櫃）；附 \`retry_after_s\`；\`force: true\` 不受限 |
| \`RATE_LIMITED\` | 429 | 操作過於頻繁，請稍後再試（遠端開櫃）／嘗試次數過多，請稍後再試（配對裝置） | 每位管理員每 10 分鐘各 10 次 |
| \`MATCH_CODE_INVALID\` | 400 | 請輸入兩位數字 | 後台 \`match\`，規則同使用者端 |
| \`CABINET_SESSION_NOT_FOUND\` | 404 | 找不到此書櫃作業 | 後台 \`match\`、\`close\` 只限發起遠端開櫃的管理員本人 |
| \`CABINET_SESSION_STATE\` | 409 | 櫃門已開啟，無法執行此操作／本次作業處理中，請稍候／目前無法執行此操作 | 附 \`session\` |
| \`DOOR_NOT_FOUND\` | 404 | 找不到此櫃門 | |
| \`DOOR_NOT_EMPTY\` | 409 | 櫃門內有存放紀錄或待確認，須完成數字確認後開啟 | \`force: true\` 只能開啟無存放紀錄且無待確認的櫃門 |
| \`DOOR_HAS_ORDER\` | 409 | 此櫃門存放進行中訂單的書籍，請先於訂單管理調整訂單狀態 | 以「已取出」清空櫃門時 |
| \`DOOR_ASSIGN_INVALID\` | 409 | 此項目不在本書櫃、已有櫃門紀錄，或與櫃內其他項目不屬於同一筆訂單或同一本書 | 登記櫃門存放內容或確認手動回報時 |
| \`DOOR_REQUIRED\` | 400 | 請指定書籍存放的櫃門 | 確認存書的手動回報時未指定櫃門 |
| \`SESSION_NOT_REVIEWABLE\` | 409 | 此作業目前無法由客服處理 | |
| \`SESSION_SELF_REVIEW\` | 403 | 此書櫃作業與您本人相關，須由其他管理員處理 | |
| \`MANUAL_REPORT_NOT_FOUND\` | 404 | 找不到此手動回報 | |
| \`MANUAL_REPORT_NOT_PENDING\` | 409 | 此手動回報已處理 | |
| \`MANUAL_REPORT_STALE\` | 409 | 項目狀態已變更，此手動回報已失效 | 回報已作廢 |
| \`MANUAL_REPORT_SELF_REVIEW\` | 403 | 此手動回報與您本人相關，須由其他管理員處理 | |
| \`PAIRING_CODE_INVALID\` | 400 | 配對碼無效或已逾時 | 格式不符、查無、已逾時或已綁定（不區分原因） |
| \`DEVICE_DISABLED\` | 403 | 模擬書櫃目前未開放 | 模擬器關閉時配對模擬書櫃 |
| \`CABINET_HAS_DEPOSITS\` | 409 | 此書櫃仍有 {n} 本訂單成立前存放的書籍，請先於存書列表登記取出後再停用 | 停用書櫃時 |
| \`SLOT_STATUS_DERIVED\` | 409 | 此櫃門狀態由系統依存放內容判定，僅可設定或結束維修 | 手動變更櫃門狀態時 |
| \`BOOK_DEPOSITED\` | 409 | 此書籍仍存放於書櫃，請先於書櫃管理登記取出後再刪除／此使用者仍有書籍存放於書櫃，請先於書櫃管理登記取出，或改用匿名化 | 刪除仍在櫃中的書籍，或永久刪除仍有書籍在櫃中的使用者 |

**書櫃裝置**（\`/api/device\`）

| \`code\` | HTTP | \`message\` |
| --- | --- | --- |
| \`DEVICE_AUTH_REQUIRED\` | 401 | 缺少裝置憑證 |
| \`DEVICE_REVOKED\` | 401 | 裝置憑證已失效，請重新配對 |
| \`DEVICE_DISABLED\` | 403 | 模擬書櫃目前未開放 |
| \`DEVICE_PAYLOAD_INVALID\` | 400 | 資料格式不正確 |
| \`PAIRING_EXPIRED\` | 410 | 配對碼已逾時，請重新取得 |
| \`DEVICE_STALE_BOOT\` | 409 | 此請求來自裝置重新啟動前，已略過 |

### Validation

- 路徑與 body 中的編號必須是正整數，否則回傳 400，不會進到資料庫。
- 字串欄位超過資料庫欄位長度時回傳 400，並指出是哪個欄位。
- 列舉欄位（狀態、書況、類型等）只接受文件列出的值。
- 請求內容不是合法 JSON 時回傳 400，body 上限 1 MB。

### Rate Limits

| 端點 | 上限 |
| --- | --- |
| \`POST /api/auth/login\`、\`POST /api/auth/social/link-login\` | 同 IP 與 Email 組合 15 分鐘合計 10 次；同 IP 15 分鐘合計 100 次 |
| \`POST /api/auth/refresh\` | 同 IP 15 分鐘 60 次 |
| \`POST /api/auth/social\`、\`POST /api/auth/social/link-login\`、\`POST /api/auth/oauth/{provider}/start\`、\`POST /api/auth/oauth/exchange\` | 同 IP 15 分鐘合計 30 次 |
| \`POST /api/auth/link\`、\`POST /api/auth/password/set\` | 每位使用者 15 分鐘合計 20 次 |
| \`POST /api/security/verify\` | 每位使用者每種驗證方式（\`method\`）15 分鐘各 30 次 |
| \`POST /api/security/verify/passkey/options\` | 每位使用者 15 分鐘 30 次 |
| \`POST /api/auth/passkeys/login/options\` | 同 IP 15 分鐘 60 次 |
| \`POST /api/auth/passkeys/login\` | 同 IP 15 分鐘 30 次 |
| \`POST /api/users/me/passkeys/options\` | 每位使用者 15 分鐘 20 次（\`POST /api/users/me/passkeys\` 不另外限流） |
| \`PATCH /api/users/me/passkeys/{id}\` | 每位使用者 15 分鐘 30 次 |
| \`POST /api/users\` | 同 IP 每小時 30 次 |
| \`PUT /api/users/me/password\`、\`POST /api/users/me/deletion\` | 每位使用者 15 分鐘 10 次 |
| \`POST /api/uploads\` | 每位使用者 10 分鐘 30 次 |
| \`POST /api/uploads/chat-image\`、\`POST /api/uploads/voice\` | 每位使用者 10 分鐘合計 60 次 |
| \`POST /api/chat/rooms/{roomId}/messages\`、\`POST /api/chat/rooms/{roomId}/reservations\` | 每位使用者每分鐘合計 60 次 |
| \`POST /api/chat/rooms/{roomId}/typing\` | 每位使用者每分鐘 40 次 |
| \`GET /api/chat/link-preview\` | 每位使用者每分鐘 30 次 |
| \`GET /api/chat/link-preview/image\` | 每位使用者每分鐘 120 次 |
| \`GET /api/books/isbn/{isbn}\` | 每位使用者每分鐘 30 次 |
| \`POST /api/ai/support/messages\`、\`POST /api/ai/support/session/escalate\`、\`POST /api/ai/listing-assist\`、\`POST /api/ai/book-chat/messages\` | 每位使用者每分鐘合計 20 次（另有管理員設定的每日次數上限） |
| \`PUT /api/ai/support/messages/{messageNo}/feedback\`、\`PUT /api/ai/book-chat/messages/{messageNo}/feedback\`、\`POST /api/ai/recommendations/clicks\`、\`POST /api/ai/recommendations/dismissals\` | 每位使用者每分鐘合計 30 次 |
| \`GET /api/ai/recommendations\` | 每位使用者每分鐘 30 次 |
| \`POST /api/support/tickets\`、\`POST /api/support/tickets/{id}/messages\` | 每位使用者每分鐘合計 20 次 |
| \`POST /api/cabinet-sessions\` | 每位使用者每分鐘 10 次 |
| \`POST /api/cabinet-sessions/{sessionNo}/start\`、\`…/cancel\`、\`…/match\`、\`…/close\` | 每位使用者每分鐘合計 20 次 |
| \`GET /api/cabinet-sessions/active\`、\`GET /api/cabinet-sessions/{sessionNo}\` | 每位使用者每分鐘合計 120 次 |
| \`POST /api/device/v1/pair/request\` | 同 IP 每 10 分鐘 10 次；全站每分鐘 30 次 |
| \`POST /api/device/v1/pair/poll\` | 同 IP 每分鐘 60 次 |
| \`GET /api/device/v1/state\`、\`POST /api/device/v1/events\`、\`POST /api/device/v1/unpair\` | 每台裝置每分鐘各 240、120、10 次 |
| \`POST /api/admin/cabinets/{id}/doors/{slotId}/open\`、\`POST /api/admin/cabinets/{id}/device/pair\` | 每位管理員每 10 分鐘各 10 次 |
| \`POST /api/admin/disputes/{id}/ai-analysis\` | 每位管理員每 10 分鐘 30 次 |
| \`POST /api/admin/ai/test\` | 每位管理員每 10 分鐘 20 次 |
| \`POST /api/admin/backups/{id}/restore\` | 每位管理員 15 分鐘 5 次 |
| \`POST\`、\`DELETE /api/push/devices\` | 每位使用者每分鐘 20 次 |
| \`POST /api/push/test\` | 每位使用者 10 分鐘 5 次 |

計數保存在伺服器行程內，重啟後歸零。

未帶 \`code\` 的錯誤直接呈現 \`message\` 即可。

---

## Permissions

| 層級 | 說明 |
| --- | --- |
| 公開 | 無須 Token |
| 會員 | 需有效 Token |
| 本人或管理員 | 僅能操作自身資料，管理員不受此限 |
| 管理員 | \`role\` 為 \`admin\`，且該功能的細部權限為開啟 |

管理員的細部權限儲存於 \`admin_permissions\`，共 12 項開關。未建立該筆資料的管理員
視為全部開啟，唯獨 \`can_manage_system\` 預設關閉、必須明確開啟。
權限不足時回傳 403，\`code\` 為 \`ADMIN_PERMISSION_REQUIRED\`，\`message\` 會指出缺少哪一項權限。

管理員不能變更自己的權限，也不能開啟自己沒有的權限。第一位需要系統維運權限的管理員，
請在伺服器上執行 \`node scripts/grant-admin-permissions.js <Email> --all\`。

| 權限欄位 | 適用端點 |
| --- | --- |
| \`can_manage_members\` | 會員列表、停權、等級、細部權限 |
| \`can_manage_levels\` | 會員等級制度的增刪改 |
| \`can_manage_content\` | 書籍上下架、分類管理 |
| \`can_manage_reports\` | 檢舉審核 |
| \`can_manage_orders\` | 訂單列表與狀態調整 |
| \`can_manage_transactions\` | 交易爭議仲裁 |
| \`can_manage_wallets\` | 會員錢包查詢與調整 |
| \`can_manage_cabinets\` | 智慧書櫃與櫃位 |
| \`can_manage_announcements\` | 系統公告、法律文件、常見問題 |
| \`can_manage_support\` | 客服工單 |
| \`can_view_stats\` | 營運報表 |
| \`can_manage_system\` | 資料庫備份與下載（預設關閉） |

---

## Order Lifecycle

站內以代幣計價，1 代幣等值 1 元。結帳時即自買家錢包扣款，賣方款項則於訂單完成後
始行入帳，期間於賣家端顯示為待撥款項（\`GET /api/wallet/pending\`）。

\`\`\`
              結帳（扣除買家代幣）
                     ↓
pending_payment → pending_deposit → deposited → pending_pickup → completed
                     │         （賣家存書）              （買家取件）   ↑
                     │                                        （賣家代幣入帳）
                     ├──→ cancelled（退款予買家）
                     └──→ refunding ──→ refunded（爭議裁決退款；已撥款則先向賣家收回）
                                   └──→ 駁回／調解：回到申請爭議前的狀態
\`\`\`

| 狀態 | 意義 |
| --- | --- |
| \`pending_payment\` | 訂單已建立，尚未付款 |
| \`pending_deposit\` | 已付款，等待賣家存入書櫃 |
| \`deposited\` | 賣家已完成存書，或下單時書已存放於書櫃 |
| \`pending_pickup\` | 等待買家取件 |
| \`completed\` | 買家已取件，款項匯入賣家錢包 |
| \`cancelled\` | 已取消，代幣退回買家 |
| \`refunding\` | 買賣雙方任一方申請爭議，等待管理員仲裁 |
| \`refunded\` | 仲裁結果為退款並已完成 |

單次結帳若涵蓋多位賣家的商品，將依賣家拆分為多筆訂單，回應為陣列。

賣家可在上架後、訂單成立前先將書存入書櫃（先行存書），於書櫃以 App 掃碼辦理（見 \`cabinet-sessions\`）；書櫃沒有有效裝置，或裝置離線、故障持續 2 分鐘以上時，改以 \`POST /api/books/{id}/deposit\` 手動回報，經管理員確認後生效。訂單中每本書都已存於該訂單的書櫃時，
訂單直接以 \`deposited\` 成立，買家即可取書，且雙方即無法自行取消；其餘訂單以 \`pending_deposit\` 成立。
訂單在買家取書前取消或退款時，仍在櫃中的書恢復存書登記（已存書的訂單為每本書，尚未存書的為先行存書的書）。
存書滿 7 天仍未售出即暫停販售並提醒賣家取回，細節見「書籍」的 Pre-order Deposit。

每一步只能由對應的一方推進：賣家設為 \`deposited\`，買家設為 \`completed\`。
所有涉及金額的狀態變更都以「狀態仍為讀取時的值」作為更新條件，扣款以「餘額足夠」作為更新條件，
併發請求不會造成重複扣款、重複退款或同一本書被賣出兩次。

結算一律依錢包帳本中該訂單實際的收支計算：改為 \`completed\` 時補撥賣家未收到的貨款；
改為 \`cancelled\`、\`refunded\` 時先收回賣家已收到的貨款（餘額可為負，由之後的收入抵扣），
再退回買家實付的金額。使用者操作、客服手動調整與爭議裁決都走同一套邏輯。

---

## File Uploads

需上傳檔案的端點採用 \`multipart/form-data\`，其餘一律為 \`application/json\`。
圖片僅接受 JPG、PNG、GIF、WebP、HEIC，語音僅接受 M4A、AAC、MP3，
伺服器以檔頭判斷實際格式，檔名由伺服器產生。
上傳後回傳相對路徑（例如 \`/uploads/books/1736512345678-987654321.jpg\`），
用戶端須自行組合 API origin 後方可存取。

| 用途 | 端點 | 存放位置 |
| --- | --- | --- |
| 書籍照片 | \`POST /api/books\`、\`POST /api/books/{id}/images\` | \`/uploads/books/\` |
| 個人頭像 | \`POST /api/users/me/avatar\` | \`/uploads/avatars/\` |
| 檢舉與爭議佐證 | \`POST /api/uploads\` | \`/uploads/evidence/\` |
| 聊天圖片 | \`POST /api/uploads/chat-image\` | \`/uploads/chat/\` |
| 聊天語音 | \`POST /api/uploads/voice\` | \`/uploads/voice/\` |
| AI 上架輔助 | \`POST /api/ai/listing-assist\` | 不儲存，僅於記憶體中處理 |

| 用途 | 單檔上限 |
| --- | --- |
| 書籍照片 | 10 MB，每本書最多 10 張 |
| 個人頭像 | 5 MB |
| 檢舉與爭議佐證 | 8 MB |
| 聊天圖片 | 10 MB |
| 聊天語音 | 5 MB，長度上限 120 秒 |
| AI 上架輔助 | 5 MB，最多 4 張 |

---

## Pagination

分頁端點均接受 query string 參數 \`page\`（預設 1）與 \`limit\`（上限 100，超過以 100 計）。
頁碼超出總頁數時回傳空陣列，不視為錯誤。
`.trim();

const base = {
  openapi: '3.0.3',
  info: {
    title: 'SaveMyBook API',
    version: '1.0.0',
    description,
    contact: {
      name: 'SaveMyBook',
      url: 'https://savemybook.today'
    },
    license: { name: 'ISC' }
  },
  servers: [
    { url: 'https://api.savemybook.today', description: '正式環境' },
    { url: `http://localhost:${port}`, description: '本機開發環境' }
  ],
  components: {
    securitySchemes: {
      bearerAuth: {
        type: 'http',
        scheme: 'bearer',
        bearerFormat: 'JWT',
        description:
          '把 `POST /api/auth/login` 拿到的 Token 貼進來即可，不需要自己加 `Bearer ` 前綴。有效期 24 小時，到期後可用 `POST /api/auth/refresh` 換發。'
      }
    }
  },
  'x-tagGroups': [
    { name: '開始使用', tags: ['auth', 'auth-social', 'passkeys', 'users', 'account', 'security'] },
    { name: '商品', tags: ['books', 'categories', 'favorites', 'cabinets'] },
    { name: '交易', tags: ['cart', 'orders', 'cabinet-sessions', 'wallet'] },
    { name: '互動', tags: ['chat', 'notifications', 'push', 'announcements'] },
    { name: '客服、檢舉與爭議', tags: ['support', 'reports', 'disputes'] },
    { name: 'AI', tags: ['ai'] },
    { name: '書櫃裝置', tags: ['device'] },
    { name: '共用工具', tags: ['uploads', 'public', 'well-known', 'status'] },
    {
      name: '管理後台',
      tags: [
        'admin-overview',
        'admin-members',
        'admin-content',
        'admin-orders',
        'admin-moderation',
        'admin-cabinets',
        'admin-wallets',
        'admin-levels',
        'admin-support',
        'admin-system',
        'admin-ai',
        'admin-auth'
      ]
    }
  ]
};

const mergeInto = (target, source) => {
  for (const [key, value] of Object.entries(source)) {
    if (value && typeof value === 'object' && !Array.isArray(value) && target[key]) {
      mergeInto(target[key], value);
    } else {
      target[key] = value;
    }
  }
};

const buildSpec = () => {
  const spec = JSON.parse(JSON.stringify(base));
  spec.paths = {};
  spec.tags = [];

  const files = fs
    .readdirSync(docsDir)
    .filter((f) => f.endsWith('.yaml') || f.endsWith('.yml'))
    .sort();

  for (const file of files) {
    let doc;
    try {
      doc = YAML.parse(fs.readFileSync(path.join(docsDir, file), 'utf8'));
    } catch (err) {
      console.error(`[OpenAPI] 無法解析 docs/${file}：${err.message}`);
      continue;
    }
    if (!doc) continue;

    if (Array.isArray(doc.tags)) {
      for (const tag of doc.tags) {
        if (!spec.tags.some((t) => t.name === tag.name)) spec.tags.push(tag);
      }
    }
    if (doc.paths) mergeInto(spec.paths, doc.paths);
    if (doc.components) mergeInto(spec.components, doc.components);
  }

  const order = spec['x-tagGroups'].flatMap((g) => g.tags);
  spec.tags.sort((a, b) => {
    const ai = order.indexOf(a.name);
    const bi = order.indexOf(b.name);
    return (ai === -1 ? 999 : ai) - (bi === -1 ? 999 : bi);
  });

  return spec;
};

module.exports = { buildSpec };
