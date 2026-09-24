const prisma = require('../../lib/prisma');
const { clip } = require('../../lib/text');
const cabinets = require('../cabinets');
const lexical = require('./lexical');
const semantic = require('./semantic');

// 站上在售書籍的混合檢索：書籍顧問依需求找書、個人化推薦找相似書時共用。
// 關鍵字（BM25）擅長書名、作者、ISBN 這類必須字面相符的查詢；語意向量擅長換句話說與主題相近的查詢，
// 兩份排名以 RRF 合併。語意檢索無法使用時（未設定金鑰、尚未執行 020）只用關鍵字，行為與過去相同。

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

const embedText = (b) => [
  `書名：${b.title}`,
  b.author ? `作者：${b.author}` : '',
  b.book_categories?.category_name ? `分類：${b.book_categories.category_name}` : '',
  b.publisher ? `出版社：${b.publisher}` : '',
  b.description ? `簡介：${clip(String(b.description).replace(/\s+/g, ' '), DESCRIPTION_CHARS)}` : ''
].filter(Boolean).join('\n');

const lexicalDoc = (b) => ({
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

const toDoc = (b) => {
  const text = embedText(b);
  return {
    ...lexicalDoc(b),
    embed: { ref: String(b.book_id), text, hash: semantic.hashOf(text) }
  };
};

const index = async () => {
  if (cached && Date.now() - cached.at < INDEX_TTL_MS) return cached.value;
  const value = lexical.buildIndex((await loadCatalog()).map(toDoc));
  cached = { value, at: Date.now() };
  return value;
};

const clear = () => {
  cached = null;
};

const SEMANTIC_WEIGHT = 1;
const LEXICAL_WEIGHT = 1;

// parts：[{ text, weight }] 為關鍵字查詢；query 為語意查詢的完整句子（例如使用者原話加上關鍵字）。
// filter 過濾不符條件的書；boost 回傳加權倍數（例如符合分類時提高）。
// strong 為 true 時關鍵字至少要有一個完整詞命中，避免只因零星單字相同就被當成相關。
// 回傳的 similarity 為語意相似度（沒有語意結果時為 null），lexical 表示是否有關鍵字命中。
const search = async (parts, { filter = null, boost = null, limit = 30, strong = true, query = null, userId = null } = {}) => {
  const idx = await index();
  const weights = lexical.queryWeights(parts);
  const lexicalRanked = lexical.rank(idx, weights, { filter, strong });

  const docs = idx.entries.map((e) => e.doc);
  const byRef = new Map(docs.map((d) => [d.embed.ref, d]));
  const semanticRanked = semantic.relevant(
    ((await semantic.rank('book', docs.map((d) => d.embed), query, { userId })) ?? [])
      .filter((r) => !filter || filter(byRef.get(r.ref))),
    { limit: Math.max(limit, 30) }
  );

  const similarity = new Map(semanticRanked.map((r) => [byRef.get(r.ref).book_id, r.similarity]));
  const lexicalIds = lexicalRanked.map((r) => r.doc.book_id);
  const lexicalHit = new Set(lexicalIds);
  const fused = semantic.fuse([
    { ids: lexicalIds, weight: LEXICAL_WEIGHT },
    { ids: semanticRanked.map((r) => byRef.get(r.ref).book_id), weight: SEMANTIC_WEIGHT }
  ]);
  const docById = new Map(docs.map((d) => [d.book_id, d]));

  return [...fused.entries()]
    .map(([bookId, score]) => ({ doc: docById.get(bookId), score: score * (boost ? boost(docById.get(bookId)) : 1) }))
    .sort((a, b) => b.score - a.score || b.doc.view_count - a.doc.view_count || b.doc.book_id - a.doc.book_id)
    .slice(0, limit)
    .map((r) => ({
      book_id: r.doc.book_id,
      seller_id: r.doc.seller_id,
      score: Math.round(r.score * 1e4) / 1e4,
      similarity: similarity.has(r.doc.book_id) ? Math.round(similarity.get(r.doc.book_id) * 1000) / 1000 : null,
      lexical: lexicalHit.has(r.doc.book_id)
    }));
};

// 排程與啟動時預先建立向量，避免第一位使用者等待整批索引。
const warm = async () => {
  const idx = await index();
  return semantic.sync('book', idx.entries.map((e) => e.doc.embed));
};

module.exports = { CATALOG_LIMIT, FIELD_WEIGHTS, search, warm, clear };
