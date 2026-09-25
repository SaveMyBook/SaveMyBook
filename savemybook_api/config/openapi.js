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
| \`admin\` | 登入密碼、通行密鑰 | 5 分鐘 | 有效期內可重複使用 | 後台高風險操作：錢包調整、重設會員密碼、設定管理員權限、產生備份下載網址、刪除備份、立即匿名化、還原操作、修改 AI 與登入方式設定 |

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
| \`DISPUTE_WINDOW_PASSED\` | 400 | 取書已超過 24 小時或訂單已完成，依服務條款不可再提出爭議 | 隱藏申訴入口 |
| \`ORDER_NOT_CANCELLABLE\` | 400 | 賣家已存書，買賣雙方都不能自行取消訂單 | 隱藏取消按鈕，引導提出交易申訴 |
| \`BOOK_HELD\` | 409 | 書籍預約保留中，賣家不能編輯或下架 | 顯示保留到期時間，停用編輯與下架 |
| \`BOOK_LOCKED\` | 409 | 書籍訂單已成立或已完成，賣家不能編輯內容、照片或下架已完成的書 | 停用編輯與下架 |
| \`BOOK_NOT_APPROVED\` | 403 | 書籍因違規下架，賣家無法自行重新上架 | 引導使用者開立客服工單 |
| \`BOOK_NOT_FOUND\` | 404 | 書籍不存在或已被刪除，或尚未公開且請求者不是賣家 | 自本機快取（最近瀏覽、收藏、購物車）移除該書並返回上一頁 |
| \`LISTING_REJECTED\` | 422 | 編輯書籍或新增照片的內容未通過 AI 上架審核，變更未儲存 | 顯示 \`message\` 中的原因，引導使用者修改內容 |
| \`AI_DISABLED\` | 503 | AI 功能目前未開放 | 隱藏 AI 功能入口 |
| \`AI_NOT_CONFIGURED\` | 503 | 此 AI 功能使用的服務商尚未設定 API 金鑰 | 隱藏 AI 功能入口 |
| \`AI_BUDGET_EXCEEDED\` | 503 | AI 功能本月用量已達上限 | 提示稍後再試 |
| \`AI_CONSENT_REQUIRED\` | 403 | 使用者尚未同意將資料提供給 AI 服務商處理 | 顯示 AI 資料處理同意說明 |
| \`AI_DAILY_LIMIT\` | 429 | 使用者今日 AI 使用次數已達上限 | 提示明日再試 |
| \`AI_PROVIDER_ERROR\` | 502 | AI 服務商錯誤、逾時或回應格式不正確 | 提示稍後再試 |
| \`AI_UNAVAILABLE\` | 503 | AI 功能目前未開放或尚未完成設定（交易申訴分析） | 隱藏 AI 分析入口 |
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
| \`PASSKEY_VERIFICATION_FAILED\`、\`PASSKEY_INVALID_RESPONSE\` | 400 | 通行密鑰的簽章、來源或格式驗證未通過 | 提示改用密碼 |
| \`PASSKEY_NOT_RECOGNIZED\` | 400 | 伺服器沒有這組通行密鑰，可能已刪除 | 提示改用密碼，並請使用者至系統設定移除該通行密鑰 |
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
| \`POST /api/security/verify\`、\`POST /api/security/verify/passkey/options\` | 每位使用者 15 分鐘合計 30 次 |
| \`POST /api/auth/passkeys/login/options\` | 同 IP 15 分鐘 60 次 |
| \`POST /api/auth/passkeys/login\` | 同 IP 15 分鐘 30 次 |
| \`POST /api/users/me/passkeys/options\`、\`POST /api/users/me/passkeys\`、\`PATCH /api/users/me/passkeys/{id}\` | 每位使用者 15 分鐘合計 20 次 |
| \`POST /api/users\` | 同 IP 每小時 30 次 |
| \`PUT /api/users/me/password\`、\`POST /api/users/me/deletion\` | 每位使用者 15 分鐘 10 次 |
| \`POST /api/uploads\` | 每位使用者 10 分鐘 30 次 |
| \`POST /api/uploads/chat-image\`、\`POST /api/uploads/voice\` | 每位使用者 10 分鐘合計 60 次 |
| \`POST /api/chat/rooms/{roomId}/messages\`、\`POST /api/chat/rooms/{roomId}/reservations\` | 每位使用者每分鐘合計 60 次 |
| \`POST /api/chat/rooms/{roomId}/typing\` | 每位使用者每分鐘 40 次 |
| \`GET /api/chat/link-preview\` | 每位使用者每分鐘 30 次 |
| \`GET /api/chat/link-preview/image\` | 每位使用者每分鐘 120 次 |
| \`GET /api/books/isbn/{isbn}\` | 每位使用者每分鐘 30 次 |
| \`POST /api/ai/support/messages\`、\`POST /api/ai/support/session/escalate\`、\`POST /api/ai/listing-assist\` | 每位使用者每分鐘合計 20 次（另有管理員設定的每日次數上限） |
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
始行入帳，期間於賣家端顯示為待定收益（\`GET /api/wallet/pending\`）。

\`\`\`
              結帳（扣除買家代幣）
                     ↓
pending_payment → pending_deposit → deposited → pending_pickup → completed
                     │         （賣家存書）              （買家取件）   ↑
                     │                                        （賣家代幣入帳）
                     ├──→ cancelled（退款予買家）
                     └──→ refunding ──→ refunded（爭議裁決退款；已撥款則先向賣家收回）
                                   └──→ 駁回／調解：回到申訴前的狀態
\`\`\`

| 狀態 | 意義 |
| --- | --- |
| \`pending_payment\` | 訂單已建立，尚未付款 |
| \`pending_deposit\` | 已付款，等待賣家存入書櫃 |
| \`deposited\` | 賣家已完成存書 |
| \`pending_pickup\` | 等待買家取件 |
| \`completed\` | 買家已取件，款項匯入賣家錢包 |
| \`cancelled\` | 已取消，代幣退回買家 |
| \`refunding\` | 買家提出爭議，等待管理員仲裁 |
| \`refunded\` | 仲裁結果為退款並已完成 |

單次結帳若涵蓋多位賣家的商品，將依賣家拆分為多筆訂單，回應為陣列。

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
    { name: '交易', tags: ['cart', 'orders', 'wallet'] },
    { name: '互動', tags: ['chat', 'notifications', 'push', 'announcements'] },
    { name: '客服與申訴', tags: ['support', 'reports', 'disputes'] },
    { name: 'AI', tags: ['ai'] },
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
