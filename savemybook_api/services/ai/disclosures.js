// 以 ai_usage_logs.feature 為鍵。privacy 為隱私權政策第 4 點 AI 服務提供者下的條目名稱，data 為該條目須提到的資料類別。
// 改變送出的資料時，隱私權政策（須於後台發布新版）、docs/ai.yaml 與 App 同意畫面要一併更新。
const DISCLOSURES = {
  support: {
    privacy: 'AI 客服',
    consent: true,
    embedding: true,
    data: ['訊息', '訂單', '預約', '上架書籍', '審核原因', '電子錢包餘額', '客服工單']
  },
  book_chat: { privacy: 'AI 書籍顧問', consent: true, embedding: true, data: ['需求描述', '對話', '在售書籍'] },
  book_chat_pick: { privacy: 'AI 書籍顧問', consent: true, embedding: false, data: ['需求描述', '對話', '在售書籍'] },
  listing_assist: { privacy: '上架輔助', consent: true, embedding: false, data: ['ISBN', '書名', '書況說明', '照片'] },
  recommend: { privacy: '書籍推薦', consent: true, embedding: true, data: ['收藏', '購買紀錄', '購物車', '最近瀏覽'] },
  moderation: { privacy: '上架審核', consent: false, embedding: false, data: ['書籍內容', '照片'] },
  admin_assist: {
    privacy: '交易爭議分析',
    consent: false,
    embedding: false,
    data: ['申訴內容', '提出者', '提出時間', '佐證照片', '訂單的狀態', '取書時間', '上架資料']
  },
  embedding: { privacy: '語意檢索', consent: false, embedding: false, data: ['一般書籍搜尋', 'AI 客服', 'AI 書籍顧問', '書籍推薦'] },
  enrich: { privacy: null, consent: false, embedding: false, data: [], exempt: '僅送出公開書籍的 ISBN 與書名，不含個人資料' },
  test: { privacy: null, consent: false, embedding: false, data: [], exempt: '管理員連線測試使用固定文字，不含個人資料' }
};

const EMBEDDING_FEATURES = Object.keys(DISCLOSURES).filter((f) => DISCLOSURES[f].embedding);

module.exports = { DISCLOSURES, EMBEDDING_FEATURES };
