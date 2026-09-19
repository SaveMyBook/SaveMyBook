const prisma = require('../../lib/prisma');
const { clip } = require('../../lib/text');
const cabinets = require('../cabinets');
const lexical = require('./lexical');

// 站上在售書籍的關鍵字索引：書籍顧問依需求找書、個人化推薦找相似書時共用。
// 以 BM25 依相關程度排序，取代「任一關鍵字出現即算、再按瀏覽數排序」的做法，
// 並能比對部分相同的詞（例如「機器學習入門」與「機器學習導論」）。

const INDEX_TTL_MS = 2 * 60 * 1000;
const CATALOG_LIMIT = 3000;
const DESCRIPTION_CHARS = 600;

// 欄位權重：書名最能代表一本書，其次是作者與分類。
const FIELD_WEIGHTS = { title: 3, author: 2, category: 1.5, publisher: 1, description: 1 };

let cached = null;

const loadCatalog = async () => {
  const [rows, underMaintenance] = await Promise.all([
    prisma.books.findMany({
      where: { status: 'on_sale', is_approved: true },
      orderBy: { created_at: 'desc' },
      take: CATALOG_LIMIT,
      select: {
        book_id: true, seller_id: true, title: true, author: true, publisher: true, description: true,
        category_id: true, price: true, condition_level: true, view_count: true, cabinet_id: true,
        book_categories: { select: { category_name: true } }
      }
    }),
    cabinets.maintenanceIds()
  ]);
  // 書櫃維修中的書暫時無法結帳，不推薦給使用者。
  return rows.filter((b) => !b.cabinet_id || !underMaintenance.has(Number(b.cabinet_id)));
};

const toDoc = (b) => ({
  id: b.book_id,
  book_id: b.book_id,
  seller_id: b.seller_id,
  category_id: b.category_id ?? null,
  price: Number(b.price),
  condition_level: b.condition_level,
  view_count: Number(b.view_count ?? 0),
  fields: [
    { text: b.title, weight: FIELD_WEIGHTS.title },
    { text: b.author ?? '', weight: FIELD_WEIGHTS.author },
    { text: b.book_categories?.category_name ?? '', weight: FIELD_WEIGHTS.category },
    { text: b.publisher ?? '', weight: FIELD_WEIGHTS.publisher },
    { text: clip(String(b.description ?? ''), DESCRIPTION_CHARS), weight: FIELD_WEIGHTS.description }
  ]
});

const index = async () => {
  if (cached && Date.now() - cached.at < INDEX_TTL_MS) return cached.value;
  const value = lexical.buildIndex((await loadCatalog()).map(toDoc));
  cached = { value, at: Date.now() };
  return value;
};

const clear = () => {
  cached = null;
};

// parts：[{ text, weight }]；filter 過濾不符條件的書；boost 回傳加權倍數（例如符合分類時提高）。
// strong 為 true 時至少要有一個完整詞命中，避免只因零星單字相同就被當成相關。
const search = async (parts, { filter = null, boost = null, limit = 30, strong = true } = {}) => {
  const idx = await index();
  const weights = lexical.queryWeights(parts);
  return lexical.rank(idx, weights, { filter, strong })
    .map((r) => ({ doc: r.doc, score: r.score * (boost ? boost(r.doc) : 1) }))
    .sort((a, b) => b.score - a.score || b.doc.view_count - a.doc.view_count || b.doc.book_id - a.doc.book_id)
    .slice(0, limit)
    .map((r) => ({ book_id: r.doc.book_id, score: Math.round(r.score * 100) / 100 }));
};

module.exports = { CATALOG_LIMIT, FIELD_WEIGHTS, search, clear };
