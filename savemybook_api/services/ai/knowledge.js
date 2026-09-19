const prisma = require('../../lib/prisma');
const { clip } = require('../../lib/text');
const lexical = require('./lexical');

// AI 客服的檢索增強（RAG）：把平台說明、常見問題與條款切成段落建索引，
// 每次提問只把最相關的段落放進提示詞，避免整包塞入時模型抓錯重點或被截斷的內容誤導。
// 排序使用 lexical.js 的 BM25。

const INDEX_TTL_MS = 2 * 60 * 1000;
const LEGAL_CHUNK_CHARS = 420;
const FAQ_ANSWER_CHARS = 1200;
const DEFAULT_TOP_K = 6;
const DEFAULT_BUDGET = 4200;
const RELATIVE_CUTOFF = 0.3;

// 平台說明依主題拆開；keywords 是使用者常用的口語說法，只參與檢索、不送給模型。
const PLATFORM_TOPICS = [
  {
    id: 'about',
    title: '平台簡介',
    keywords: '平台 是什麼 介紹 代幣 台幣 匯率 智慧書櫃 二手書',
    text: 'SaveMyBook 是結合智慧書櫃的二手書交易平台。站內以代幣結算，1 代幣等值新臺幣 1 元。賣家把書存入智慧書櫃，買家到書櫃取書，雙方不需要當面交付。'
  },
  {
    id: 'listing',
    title: '上架販售',
    keywords: '上架 賣書 刊登 販售 賣東西 新增書籍 ISBN 條碼 照片 書況 售價 定價 價格 多少錢 編輯 修改 下架 刪除 重新上架',
    text: '賣家在 App 填寫書名、售價（大於 0 且不超過 99999 代幣）、書況並上傳照片（每本最多 10 張）即可上架，輸入或掃描 ISBN 可自動帶入書目資料。賣家可隨時編輯或下架自己的書籍。因違規遭管理員下架的書籍無法自行重新上架，須聯絡客服。'
  },
  {
    id: 'review',
    title: '上架審核',
    keywords: '審核 審核中 送審 待審核 沒有上架 看不到 搜尋不到 被下架 未通過 駁回 違規 多久 為什麼',
    text: '上架後系統會自動檢查內容。售價明顯高於同書行情或一般二手書價格（例如 3000 代幣以上）、疑似圖書館館藏或非賣品、非書籍商品、留下站外聯絡方式等情況，書籍會先送交人工審核，審核期間不會公開販售，賣家會收到「書籍已送交審核」通知。管理員核准後自動公開；未通過會下架並通知原因。審核時間依管理員處理進度而定，平台沒有承諾固定時限。'
  },
  {
    id: 'buying',
    title: '購買與付款',
    keywords: '購買 買書 結帳 付款 購物車 扣款 交易密碼 生物辨識 指紋 臉部 多位賣家 拆單',
    text: '買家將書加入購物車後結帳，結帳時立即從錢包扣除代幣，並需以交易密碼或生物辨識驗證。購物車包含多位賣家的書籍時，會依賣家拆成多筆訂單。錢包餘額不足時無法結帳。'
  },
  {
    id: 'order-flow',
    title: '訂單流程',
    keywords: '訂單 狀態 進度 待付款 待存書 已存書 待取貨 已完成 什麼時候 多久 撥款 收款 入帳 待定收益',
    text: '訂單狀態依序為：待付款 → 待存書（等待賣家把書存入智慧書櫃）→ 已存書 → 待取貨 → 已完成。買家取書完成後，款項才會撥入賣家錢包；撥款前在賣家端顯示為待定收益。其他狀態：已取消、退款處理中（爭議處理中）、已退款。'
  },
  {
    id: 'cabinet',
    title: '智慧書櫃存書與取書',
    keywords: '書櫃 櫃子 置物櫃 存書 放書 取書 拿書 取件 取貨 QR Code 掃描 取件碼 密碼 營業時間 地點 位置 在哪',
    text: '賣家到訂單指定的智慧書櫃存書；買家到書櫃以 App 掃描機台上的 QR Code 取書。平台沒有取件碼，請勿向任何人索取或提供取件碼。書櫃位置與營業時間可在 App 選擇書櫃時查看。書櫃故障或無法開啟時請轉接客服人員。'
  },
  {
    id: 'wallet',
    title: '錢包與代幣',
    keywords: '錢包 代幣 餘額 儲值 加值 充值 提領 提現 領錢 轉出 匯款 銀行 入帳 收入 紀錄 明細',
    text: '錢包餘額來源包含：售出入帳、取消退款、爭議退款、管理員調整與聊天室轉帳。App 目前沒有自助儲值與提領功能，需要儲值或提領請轉接客服人員處理。錢包頁可查看每筆收支明細。'
  },
  {
    id: 'reservation',
    title: '預約保留',
    keywords: '預約 保留 留書 先幫我留 等我 幾小時 期限 逾期 取消預約',
    text: '買家可在與賣家的一對一聊天室預約書籍，保留時間可選 24、48 或 72 小時。賣家 24 小時內未回覆，預約會自動失效。賣家接受後，書籍在期限內只保留給該買家，買家須在期限內完成購買，逾期自動取消。每位買家同時最多 5 筆進行中的預約。'
  },
  {
    id: 'cancel',
    title: '取消訂單與退款',
    keywords: '取消 取消訂單 不想買 退款 退錢 退費 退回 多久退 買錯',
    text: '訂單在完成前可取消，已付的代幣會退回買家錢包；若賣家已收到款項會先收回。已完成、已取消或已退款的訂單無法取消；爭議處理中的訂單無法自行取消，須等候管理員裁決。'
  },
  {
    id: 'dispute',
    title: '交易爭議',
    keywords: '爭議 申訴 客訴 書況不符 破損 缺頁 不一樣 沒收到 貨不對 退貨 糾紛 仲裁',
    text: '書況與描述不符或未收到書籍時，買家可對訂單提出爭議。已完成的訂單須在取書後 24 小時內提出。提出後訂單轉為退款處理中，由管理員裁決退款、駁回或協調結案。同一訂單同時只能有一筆處理中的爭議；已取消或已退款的訂單無法提出爭議。'
  },
  {
    id: 'chat-transfer',
    title: '聊天室轉帳與請款',
    keywords: '聊天 聊天室 轉帳 請款 付款給 群組 收款 私訊 封鎖 靜音',
    text: '一對一或群組聊天室可轉帳代幣或向成員請款，付款需交易密碼或生物辨識驗證。單筆金額上限 100000 代幣，請款 72 小時內未付款會失效。可對聊天對象靜音或封鎖。'
  },
  {
    id: 'report',
    title: '檢舉',
    keywords: '檢舉 舉報 違規 詐騙 騷擾 假貨 不當',
    text: '可檢舉違規的使用者、商品或訊息。審核期間商品照常販售，管理員確認違規成立才會下架或處置。'
  },
  {
    id: 'account',
    title: '帳號與安全',
    keywords: '帳號 註冊 登入 登不進去 忘記密碼 改密碼 交易密碼 通行密鑰 Passkey 綁定 Google LINE 刪除帳號 註銷 停權 黑名單 個資 資料匯出',
    text: '可使用 Email 密碼、社群帳號或通行密鑰登入，並可在設定中綁定或解除社群帳號、變更密碼與交易密碼、登出其他裝置、匯出個人資料。可在 App 申請刪除帳號，有 30 天緩衝期可隨時取消；仍有進行中的訂單時無法申請。帳號遭停權或登入異常請轉接客服人員。'
  },
  {
    id: 'level',
    title: '會員等級',
    keywords: '會員 等級 積分 點數 升級 徽章',
    text: '會員等級依積分計算，每完成一筆訂單可獲得 10 點積分。各等級門檻可在 App 的會員等級頁查看。'
  },
  {
    id: 'ai',
    title: 'AI 功能',
    keywords: 'AI 人工智慧 機器人 客服 推薦 書籍顧問 上架輔助 同意',
    text: 'App 內的 AI 功能包含：AI 客服、上架輔助（依照片或 ISBN 產生書目與描述）、個人化推薦與書籍顧問。使用前需同意 AI 服務條款，每日使用次數有上限。AI 客服無法處理的問題可轉接客服人員。'
  },
  {
    id: 'handoff',
    title: '轉接客服人員',
    keywords: '真人 客服 人工 轉接 聯絡 客服人員 工單 提問 回覆 多久回',
    text: '使用者可在 AI 客服畫面轉接客服人員，系統會建立提問紀錄並附上對話內容，客服人員回覆後會通知使用者，可在「客服中心」查看提問紀錄與回覆。'
  }
];

// 常見同義說法：查詢含左邊任一詞時補上右邊的詞，提高召回率。
const SYNONYMS = [
  [['退錢', '退費', '退回來'], '退款'],
  [['拿書', '取件', '取貨', '領書'], '取書'],
  [['放書', '放進', '寄放'], '存書'],
  [['加值', '充值', '買代幣', '儲值'], '儲值'],
  [['提現', '領錢', '領出', '轉出', '換現金'], '提領'],
  [['賣書', '刊登', '販售'], '上架'],
  [['櫃子', '置物櫃', '櫃位'], '書櫃'],
  [['申訴', '客訴', '糾紛', '書況不符'], '爭議'],
  [['舉報'], '檢舉'],
  [['註銷', '刪帳', '刪除帳號'], '刪除帳號'],
  [['真人', '人工', '專人'], '客服人員'],
  [['留書', '幫我留'], '預約'],
  [['錢包', '餘額'], '代幣'],
  [['審核中', '送審', '待審'], '審核']
];

const expandQuery = (text) => {
  const s = lexical.normalize(text);
  const extra = [];
  for (const [variants, canonical] of SYNONYMS) {
    if (variants.some((v) => s.includes(v))) extra.push(canonical);
  }
  return extra.length ? `${text} ${extra.join(' ')}` : text;
};

// 條款依「第 X 條」或空行切段，過長的段落再以句號切成固定長度，每段都帶標題以免失去脈絡。
const splitLegal = (title, content) => {
  const text = String(content ?? '').replace(/\r\n?/g, '\n').trim();
  if (!text) return [];
  const blocks = text
    .split(/\n\s*\n|(?=\n\s*第\s*[一二三四五六七八九十百\d]+\s*條)|(?=\n\s*[一二三四五六七八九十]+、)/)
    .map((b) => b.replace(/\s+/g, ' ').trim())
    .filter(Boolean);
  const chunks = [];
  let current = '';
  const push = () => {
    if (current.trim()) chunks.push(current.trim());
    current = '';
  };
  for (const block of blocks) {
    if (block.length > LEGAL_CHUNK_CHARS) {
      push();
      const sentences = block.split(/(?<=[。；！？])/);
      for (const sentence of sentences) {
        if (current.length + sentence.length > LEGAL_CHUNK_CHARS) push();
        current += sentence;
      }
      push();
    } else {
      if (current.length + block.length + 1 > LEGAL_CHUNK_CHARS) push();
      current += `${current ? ' ' : ''}${block}`;
    }
  }
  push();
  return chunks.map((c, i) => ({ id: `legal:${title}:${i}`, source: 'legal', title: `《${title}》`, text: c }));
};

const loadDocuments = async () => {
  const [faqs, legal] = await Promise.all([
    prisma.faqs.findMany({
      where: { is_visible: true },
      orderBy: [{ category: 'asc' }, { sort_order: 'asc' }, { faq_id: 'asc' }],
      select: { faq_id: true, category: true, question: true, answer: true }
    }),
    prisma.legal_documents.findMany({ select: { title: true, content: true }, orderBy: { doc_id: 'asc' }, take: 20 })
  ]);

  const docs = PLATFORM_TOPICS.map((t) => ({
    id: `platform:${t.id}`, source: 'platform', title: t.title, text: t.text, keywords: t.keywords
  }));
  for (const f of faqs) {
    docs.push({
      id: `faq:${f.faq_id}`,
      source: 'faq',
      title: `常見問題（${clip(String(f.category ?? ''), 30)}）`,
      text: `問：${clip(String(f.question), 200)}\n答：${clip(String(f.answer), FAQ_ANSWER_CHARS)}`,
      // 問題本身最能代表這筆 FAQ，重複一次提高權重。
      keywords: clip(String(f.question), 200)
    });
  }
  for (const d of legal) docs.push(...splitLegal(clip(String(d.title), 100), d.content));
  return docs;
};

const buildIndex = (docs) => lexical.buildIndex(docs.map((doc) => ({
  ...doc,
  fields: [{ text: doc.title }, { text: doc.keywords ?? '' }, { text: doc.text }]
})));

let cached = null;

const index = async () => {
  if (cached && Date.now() - cached.at < INDEX_TTL_MS) return cached.value;
  const value = buildIndex(await loadDocuments());
  cached = { value, at: Date.now() };
  return value;
};

const invalidate = () => {
  cached = null;
};

// query 是本次提問；context 是先前幾則使用者訊息，權重較低，讓「那要多久？」這類追問也能找到前文主題。
const search = async (query, { context = [], topK = DEFAULT_TOP_K, budget = DEFAULT_BUDGET } = {}) => {
  const idx = await index();
  const weights = lexical.queryWeights([
    { text: query, weight: 1 },
    ...context.filter(Boolean).map((text, i) => ({ text, weight: i === context.length - 1 ? 0.5 : 0.3 }))
  ], expandQuery);
  const ranked = lexical.rank(idx, weights);
  if (ranked.length === 0) return [];

  const floor = ranked[0].score * RELATIVE_CUTOFF;
  const picked = [];
  let used = 0;
  for (const r of ranked) {
    if (picked.length >= topK || r.score < floor) break;
    const size = r.doc.title.length + r.doc.text.length;
    if (used + size > budget && picked.length > 0) continue;
    picked.push({ ...r.doc, score: Math.round(r.score * 100) / 100 });
    used += size;
  }
  return picked;
};

const format = (docs) => (docs.length
  ? docs.map((d, i) => `[${i + 1}] ${d.title}\n${d.text}`).join('\n\n')
  : '（沒有找到相關資料）');

module.exports = { PLATFORM_TOPICS, SYNONYMS, tokenize: lexical.tokenize, expandQuery, splitLegal, buildIndex, search, format, invalidate };
