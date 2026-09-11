const fs = require('fs');
const path = require('path');
const YAML = require('yaml');

const port = process.env.PORT || 3000;
const docsDir = path.join(__dirname, '../docs');

// ==========================================
// OpenAPI 文件組裝
// ------------------------------------------
// docs/ 底下每個 .yaml 各自描述一組端點，啟動時合併成一份完整的
// OpenAPI 文件。拆檔是為了讓每個路由檔都有對應的文件檔，改路由時
// 一眼就知道要改哪一份，不用在一個上萬行的巨檔裡找。
// ==========================================

const description = `
SaveMyBook 是一個結合**智慧書櫃**的二手書交易平台。買賣雙方不需碰面：
賣家把書存進書櫃、買家憑取貨碼取書，平台以站內代幣（虛擬貨幣）完成金流。

這份文件涵蓋 App、管理後台會用到的**全部**端點。

---

## 快速開始

1. 用 \`POST /api/users\` 建立帳號，或直接用既有帳號。
2. 用 \`POST /api/auth/login\` 取得 JWT Token。
3. 點右上角 **Authentication**，把 Token 填進 Bearer 欄位（不用自己加 \`Bearer \` 前綴）。
4. 之後所有標記 🔒 的端點都會自動帶上這個 Token。

\`\`\`bash
curl -X POST http://localhost:${port}/api/auth/login \\
  -H 'Content-Type: application/json' \\
  -d '{"email":"test@example.com","password":"your_password123"}'
\`\`\`

---

## 回應格式

**所有** JSON 端點都遵循同一個外層結構，前端只要檢查 \`success\` 就能分流：

\`\`\`jsonc
// 成功
{ "success": true, "message": "登入成功", "data": { ... } }

// 失敗
{ "success": false, "message": "密碼錯誤", "code": "INVALID_PASSWORD" }
\`\`\`

| 欄位 | 說明 |
| --- | --- |
| \`success\` | 一定會有。\`true\` / \`false\` |
| \`message\` | 可直接顯示給使用者的繁體中文訊息。部分純查詢端點不帶這個欄位 |
| \`data\` | 主要內容。可能是物件或陣列 |
| \`code\` | 只有需要前端**分流處理**的錯誤才會帶（見下方錯誤代碼表） |
| \`pagination\` | 有分頁的列表端點會在**外層**帶這個物件，不在 \`data\` 裡面 |

分頁物件長這樣：

\`\`\`json
{ "total": 137, "page": 2, "limit": 20, "total_pages": 7 }
\`\`\`

---

## 認證與帳號狀態

Token 由 \`POST /api/auth/login\` 簽發，**有效期 24 小時**，用
\`Authorization: Bearer <token>\` 夾帶。

驗證中介層每次請求都會回資料庫確認帳號狀態，**不是只驗簽章**。
這代表帳號被停權或黑名單後會**立即**失效，不必等 Token 過期；
管理員被降級為一般會員也同樣立刻生效。代價是每個請求多一次 DB 查詢。

| 狀況 | HTTP | \`code\` |
| --- | --- | --- |
| 沒帶 Token | 401 | － |
| Token 過期或簽章錯誤 | 403 | － |
| 帳號已被刪除 | 401 | \`ACCOUNT_NOT_FOUND\` |
| 帳號被列入黑名單 | 401 | \`ACCOUNT_BLACKLISTED\` |
| 帳號被停權 | 401 | \`ACCOUNT_INACTIVE\` |

> 前端收到上述任何一種，都應該清掉本機 Token 並導回登入頁。

---

## 錯誤代碼

除了認證相關的代碼外，這些是業務邏輯會回的：

| \`code\` | HTTP | 意義 | 建議處理 |
| --- | --- | --- | --- |
| \`INVALID_PASSWORD\` | 401 | 登入密碼錯誤 | 只在密碼欄位顯示錯誤，不要清空 Email |
| \`INSUFFICIENT_BALANCE\` | 400 | 代幣餘額不足以結帳 | 導去儲值頁 |
| \`BOOK_NOT_APPROVED\` | 403 | 書籍因違規被下架，賣家不能自行重新上架 | 引導開客服工單 |

沒有 \`code\` 的錯誤直接把 \`message\` 顯示出來即可。

---

## 權限層級

| 層級 | 說明 |
| --- | --- |
| 公開 | 不需要 Token |
| 🔒 會員 | 需要有效 Token |
| 🔒 本人 / 管理員 | 只能操作自己的資料，管理員可跨帳號 |
| 🔒 管理員 | \`role = admin\`，且該功能的細部權限為開啟 |

管理員的細部權限存在 \`admin_permissions\`，共 11 個開關。
**沒有**那筆資料的管理員視為全部開啟（這是為了讓舊帳號不會突然被鎖住）。
權限不足回 403 \`{ "success": false, "message": "您沒有這項功能的權限" }\`。

| 權限欄位 | 管到哪些端點 |
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

---

## 金流與訂單生命週期

站內用**代幣**計價，1 代幣 = 1 元。結帳當下就從買家錢包扣款，
賣家的錢則要等訂單完成才入帳，中間這段在賣家端顯示為「待定收益」
（\`GET /api/wallet/pending\`）。

\`\`\`
              結帳（扣買家代幣）
                     ↓
pending_payment → pending_deposit → deposited → pending_pickup → completed
                     │                                               ↑
                     │                                        （賣家代幣入帳）
                     ├──→ cancelled（退款回買家）
                     └──→ refunding ──→ refunded（爭議裁決退款）
\`\`\`

| 狀態 | 意義 |
| --- | --- |
| \`pending_payment\` | 已建立、尚未付款（目前流程不會停在這） |
| \`pending_deposit\` | 已付款，等賣家把書存進書櫃 |
| \`deposited\` | 賣家已存書 |
| \`pending_pickup\` | 等買家取書 |
| \`completed\` | 買家已取書，款項入賣家錢包 |
| \`cancelled\` | 已取消，代幣原路退回買家 |
| \`refunding\` | 買家提出爭議，等管理員仲裁 |
| \`refunded\` | 仲裁結果為退款，已完成 |

一次結帳若購物車跨多個賣家，會**依賣家拆成多筆訂單**，回傳的是陣列。

---

## 檔案上傳

需要上傳圖片的端點用 \`multipart/form-data\`，其餘一律 \`application/json\`。
上傳後回傳的是**相對路徑**（例如 \`/uploads/books/1736...jpg\`），
前端要自己接上 API 的 origin 才能顯示。

| 用途 | 端點 | 存放位置 |
| --- | --- | --- |
| 書籍照片 | \`POST /api/books\`、\`POST /api/books/{id}/images\` | \`/uploads/books/\` |
| 個人頭像 | \`POST /api/users/me/avatar\` | \`/uploads/avatars/\` |
| 檢舉／爭議佐證 | \`POST /api/uploads\` | \`/uploads/evidence/\` |

---

## 分頁、排序與篩選

有分頁的端點一律吃 \`page\`（預設 1）與 \`limit\`，兩者都是 query string。
超出範圍不會報錯，只會回空陣列。
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
  // Scalar 用這個把左側選單分組，沒有分組時所有 tag 會平鋪成很長一條。
  'x-tagGroups': [
    { name: '開始使用', tags: ['認證 (Auth)', '使用者 (Users)'] },
    { name: '商品', tags: ['書籍 (Books)', '分類 (Categories)', '收藏 (Favorites)', '智慧書櫃 (Cabinets)'] },
    { name: '交易', tags: ['購物車 (Cart)', '訂單 (Orders)', '錢包 (Wallet)'] },
    { name: '互動', tags: ['聊天室 (Chat)', '通知 (Notifications)', '系統公告 (Announcements)'] },
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
        '後台：客服與條款'
      ]
    }
  ]
};

/// 只往下合併兩層（components.schemas 這種），路徑本身不需要深層合併。
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
      // 一份文件寫壞不該讓整個 API 起不來，跳過並留下訊息就好。
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

  // 讓側欄順序跟 x-tagGroups 一致，沒被分組的排最後。
  const order = spec['x-tagGroups'].flatMap((g) => g.tags);
  spec.tags.sort((a, b) => {
    const ai = order.indexOf(a.name);
    const bi = order.indexOf(b.name);
    return (ai === -1 ? 999 : ai) - (bi === -1 ? 999 : bi);
  });

  return spec;
};

module.exports = { buildSpec };
