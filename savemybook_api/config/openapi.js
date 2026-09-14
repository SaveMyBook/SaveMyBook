const fs = require('fs');
const path = require('path');
const YAML = require('yaml');

const port = process.env.PORT || 3000;
const docsDir = path.join(__dirname, '../docs');

const description = `
SaveMyBook 為結合智慧書櫃的二手書交易平台。賣家將書籍存入書櫃，買家憑取貨碼取件，
雙方無須當面交付，金流以站內代幣結算。

本文件涵蓋行動應用程式與管理後台所使用的全部端點。

---

## 快速開始

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

## 回應格式

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

## 認證與帳號狀態

Token 由 \`POST /api/auth/login\` 簽發，有效期 24 小時，以
\`Authorization: Bearer <token>\` 標頭傳遞。

驗證中介層於每次請求查詢資料庫確認帳號狀態，不僅驗證簽章。因此帳號停權或列入黑名單後
立即失效，無須等待 Token 到期；管理員遭降級亦同步生效。此設計的成本為每次請求
增加一次資料庫查詢。

| 狀況 | HTTP | \`code\` |
| --- | --- | --- |
| 未提供 Token | 401 | － |
| Token 過期或簽章無效 | 403 | － |
| 帳號已刪除 | 401 | \`ACCOUNT_NOT_FOUND\` |
| 帳號列入黑名單 | 401 | \`ACCOUNT_BLACKLISTED\` |
| 帳號已停權 | 401 | \`ACCOUNT_INACTIVE\` |
| 密碼已變更（含客服重設），舊 Token 失效 | 401 | \`TOKEN_REVOKED\` |

用戶端收到上述任一回應時，應清除本機 Token 並導向登入流程。

---

## 錯誤代碼

除認證相關代碼外，業務邏輯另定義下列代碼：

| \`code\` | HTTP | 意義 | 建議處理方式 |
| --- | --- | --- | --- |
| \`INVALID_PASSWORD\` | 401 | 登入密碼錯誤 | 保留已輸入的 Email，僅於密碼欄位提示錯誤 |
| \`INSUFFICIENT_BALANCE\` | 400 | 代幣餘額不足以完成結帳 | 導向儲值流程 |
| \`BOOK_NOT_APPROVED\` | 403 | 書籍因違規下架，賣家無法自行重新上架 | 引導使用者開立客服工單 |
| \`OPEN_ORDERS\` | 400 | 尚有進行中的訂單，無法申請刪除帳號 | 引導使用者完成或取消訂單 |
| \`RATE_LIMITED\` | 429 | 短時間內嘗試次數過多 | 依 \`Retry-After\` 標頭等待後再試 |
| \`ROUTE_NOT_FOUND\` | 404 | 端點不存在 | 檢查路徑與 HTTP 方法 |

409 代表資料在處理期間被其他請求變更（例如兩人同時結帳同一本書、同一筆訂單被重複取消），
重新整理後再試即可。

### 輸入驗證

- 路徑與 body 中的編號必須是正整數，否則回傳 400，不會進到資料庫。
- 字串欄位超過資料庫欄位長度時回傳 400，並指出是哪個欄位。
- 列舉欄位（狀態、書況、類型等）只接受文件列出的值。
- 請求內容不是合法 JSON 時回傳 400，body 上限 1 MB。

### 限流

| 端點 | 上限 |
| --- | --- |
| \`POST /api/auth/login\` | 同 IP 與 Email 組合 15 分鐘 10 次；同 IP 15 分鐘 100 次 |
| \`POST /api/users\` | 同 IP 每小時 30 次 |
| \`PUT /api/users/me/password\`、\`POST /api/users/me/deletion\` | 每位使用者 15 分鐘 10 次 |
| \`POST /api/uploads\` | 每位使用者 10 分鐘 30 次 |
| \`POST /api/chat/rooms/{roomId}/messages\` | 每位使用者每分鐘 60 則 |
| \`GET /api/books/isbn/{isbn}\` | 每位使用者每分鐘 30 次 |
| \`POST\`、\`DELETE /api/push/devices\` | 每位使用者每分鐘 20 次 |
| \`POST /api/push/test\` | 每位使用者 10 分鐘 5 次 |

計數保存在伺服器行程內，重啟後歸零。

未帶 \`code\` 的錯誤直接呈現 \`message\` 即可。

---

## 權限層級

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

## 金流與訂單生命週期

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

## 檔案上傳

需上傳圖片的端點採用 \`multipart/form-data\`，其餘一律為 \`application/json\`。
僅接受 JPG、PNG、GIF、WebP、HEIC，伺服器以檔頭判斷實際格式，檔名由伺服器產生。
上傳後回傳相對路徑（例如 \`/uploads/books/1736512345678-987654321.jpg\`），
用戶端須自行組合 API origin 後方可存取。

| 用途 | 端點 | 存放位置 |
| --- | --- | --- |
| 書籍照片 | \`POST /api/books\`、\`POST /api/books/{id}/images\` | \`/uploads/books/\` |
| 個人頭像 | \`POST /api/users/me/avatar\` | \`/uploads/avatars/\` |
| 檢舉與爭議佐證 | \`POST /api/uploads\` | \`/uploads/evidence/\` |

| 用途 | 單檔上限 |
| --- | --- |
| 書籍照片 | 10 MB，每本書最多 10 張 |
| 個人頭像 | 5 MB |
| 檢舉與爭議佐證 | 8 MB |

---

## 分頁

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
          '把 `POST /api/auth/login` 拿到的 Token 貼進來即可，不需要自己加 `Bearer ` 前綴。有效期 24 小時。'
      }
    }
  },
  // x-tagGroups 是 Scalar 的擴充欄位，不在 OpenAPI 規格內。
  'x-tagGroups': [
    { name: '開始使用', tags: ['認證 (Auth)', '使用者 (Users)', '帳號與隱私 (Account)'] },
    { name: '商品', tags: ['書籍 (Books)', '分類 (Categories)', '收藏 (Favorites)', '智慧書櫃 (Cabinets)'] },
    { name: '交易', tags: ['購物車 (Cart)', '訂單 (Orders)', '錢包 (Wallet)'] },
    { name: '互動', tags: ['聊天室 (Chat)', '通知 (Notifications)', '推播 (Push)', '系統公告 (Announcements)'] },
    { name: '客服與申訴', tags: ['客服中心 (Support)', '檢舉 (Reports)', '交易爭議 (Disputes)'] },
    { name: '共用工具', tags: ['檔案上傳 (Uploads)', '公開頁面 (Public)'] },
    {
      name: '管理後台',
      tags: [
        '後台：總覽與報表',
        '後台：會員管理',
        '後台：內容管理',
        '後台：訂單管理',
        '後台：檢舉與爭議',
        '後台：書櫃管理',
        '後台：錢包管理',
        '後台：會員等級',
        '後台：客服與條款',
        '後台：系統維運'
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
      // 單一文件解析失敗只跳過該檔，不讓整個 API 起不來。
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
