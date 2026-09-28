const prisma = require('../../lib/prisma');
const { clip } = require('../../lib/text');
const cabinets = require('../cabinets');
const reservations = require('../reservations');
const lexical = require('./lexical');
const semantic = require('./semantic');

// 站上在售書籍的混合檢索：書籍顧問依需求找書、個人化推薦找相似書時共用。
// 關鍵字（BM25）擅長書名、作者、ISBN 這類必須字面相符的查詢；語意向量擅長換句話說與主題相近的查詢，
// 兩份排名以 RRF 合併。語意檢索無法使用時（未設定金鑰）只用關鍵字。

const INDEX_TTL_MS = 2 * 60 * 1000;
const CATALOG_LIMIT = 3000;
const DESCRIPTION_CHARS = 600;

// 欄位權重：書名最能代表一本書，其次是作者與分類。
const FIELD_WEIGHTS = { title: 3, author: 2, category: 1.5, publisher: 1, description: 1, isbn: 3 };

// ISBN 常寫成 978-986-…，分詞會拆成好幾段數字而比對不到；索引與查詢都先去掉連字號與空白再整段比對。
// \d 只認半形數字，全形數字與各式破折號要先轉成半形，否則整段 ISBN 比對不到。
const ISBN_RUN = /(?<![\dX])(?:\d(?:[-\s]?\d){12}|\d(?:[-\s]?\d){8}[-\s]?[\dX])(?![\dX])/gi;
const DASHES = /[\u2010-\u2015\u2212\uFE58\uFE63\uFF0D]/g;
const halfWidth = (text) => String(text ?? '').normalize('NFKC').replace(DASHES, '-');
const compactIsbn = (value) => halfWidth(value).replace(/[-\s]/g, '').toUpperCase();
const withCompactIsbn = (text) => halfWidth(text).replace(ISBN_RUN, compactIsbn);
// 關鍵字可能帶有「ISBN」「isbn:」等前綴，取第一段符合 ISBN 格式的數字。
const isbnOf = (text) => {
  const [run] = halfWidth(text).match(ISBN_RUN) ?? [];
  return run ? compactIsbn(run) : null;
};

const check13 = (digits) => String((10 - ([...digits].reduce((sum, d, i) => sum + Number(d) * (i % 2 ? 3 : 1), 0) % 10)) % 10);
const check10 = (digits) => {
  const r = (11 - ([...digits].reduce((sum, d, i) => sum + Number(d) * (10 - i), 0) % 11)) % 11;
  return r === 10 ? 'X' : String(r);
};

// 舊書常只印 10 碼、上架時卻填 13 碼（或反之），兩種寫法都要比對。
const isbnForms = (code) => {
  if (code.length === 10) return [code, `978${code.slice(0, 9)}${check13(`978${code.slice(0, 9)}`)}`];
  if (code.length === 13 && code.startsWith('978')) return [code, `${code.slice(3, 12)}${check10(code.slice(3, 12))}`];
  return [code];
};

const isbnCodes = (texts) => new Set(texts.flatMap((text) => [...halfWidth(text).matchAll(ISBN_RUN)])
  .flatMap((m) => isbnForms(compactIsbn(m[0]))));

let cached = null;

const loadCatalog = async () => {
  const [rows, underMaintenance] = await Promise.all([
    prisma.books.findMany({
      where: { status: 'on_sale', is_approved: true },
      orderBy: { created_at: 'desc' },
      take: CATALOG_LIMIT,
      select: {
        book_id: true, seller_id: true, title: true, author: true, publisher: true, description: true, isbn: true,
        category_id: true, price: true, condition_level: true, view_count: true, cabinet_id: true,
        book_categories: { select: { category_name: true } }
      }
    }),
    cabinets.maintenanceIds()
  ]);
  // 書櫃維修中的書暫時無法結帳，不推薦給使用者。
  return rows.filter((b) => !b.cabinet_id || !underMaintenance.has(Number(b.cabinet_id)));
};

// 結帳時會被擋下的書（書櫃維修中、其他買家預約保留中）不推薦；索引快取期間狀態可能改變，組書卡前要再過濾一次。
const availability = async (viewerId = null) => {
  const [underMaintenance, held] = await Promise.all([cabinets.maintenanceIds(), reservations.heldByOthers(viewerId)]);
  return (book) => !(book.cabinet_id && underMaintenance.has(Number(book.cabinet_id))) && !held.has(Number(book.book_id));
};

const available = async (rows, viewerId = null) => (rows.length === 0 ? rows : rows.filter(await availability(viewerId)));

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
  isbn: compactIsbn(b.isbn) || null,
  fields: [
    { text: b.title, weight: FIELD_WEIGHTS.title },
    { text: b.author ?? '', weight: FIELD_WEIGHTS.author },
    { text: b.book_categories?.category_name ?? '', weight: FIELD_WEIGHTS.category },
    { text: b.publisher ?? '', weight: FIELD_WEIGHTS.publisher },
    { text: clip(String(b.description ?? ''), DESCRIPTION_CHARS), weight: FIELD_WEIGHTS.description },
    { text: compactIsbn(b.isbn), weight: FIELD_WEIGHTS.isbn }
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
// 查詢含 ISBN 時，ISBN 完全相符的書排在最前面。
// 回傳的 similarity 為語意相似度（沒有語意結果時為 null），lexical 表示是否有關鍵字命中。
const search = async (parts, { filter = null, boost = null, limit = 30, strong = true, query = null, userId = null } = {}) => {
  const idx = await index();
  const weights = lexical.queryWeights(parts.map((p) => ({ ...p, text: withCompactIsbn(p.text) })));
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

  const codes = isbnCodes([...parts.map((p) => p.text), query]);
  const exact = codes.size === 0 ? [] : docs.filter((d) => d.isbn && codes.has(d.isbn) && (!filter || filter(d)));
  const exactIds = new Set(exact.map((d) => d.book_id));
  for (const d of exact) lexicalHit.add(d.book_id);

  const ranked = [...fused.entries()]
    .filter(([bookId]) => !exactIds.has(bookId))
    .map(([bookId, score]) => ({ doc: docById.get(bookId), score: score * (boost ? boost(docById.get(bookId)) : 1) }))
    .sort((a, b) => b.score - a.score || b.doc.view_count - a.doc.view_count || b.doc.book_id - a.doc.book_id);

  return [...exact.map((doc) => ({ doc, score: fused.get(doc.book_id) ?? 0 })), ...ranked]
    .slice(0, limit)
    .map((r) => ({
      book_id: r.doc.book_id,
      seller_id: r.doc.seller_id,
      score: Math.round(r.score * 1e4) / 1e4,
      similarity: similarity.has(r.doc.book_id) ? Math.round(similarity.get(r.doc.book_id) * 1000) / 1000 : null,
      lexical: lexicalHit.has(r.doc.book_id)
    }));
};

// 相似的書：優先用這本書已存的向量找鄰近書籍（不花費嵌入費用）；書不在販售索引或尚未建立向量時，
// 改以書名、作者、分類與簡介當查詢。關鍵字排名同時參與，語意檢索無法使用時仍有結果。
const similar = async (book, { filter = null, limit = 10, userId = null } = {}) => {
  const idx = await index();
  const docs = idx.entries.map((e) => e.doc);
  const byRef = new Map(docs.map((d) => [d.embed.ref, d]));
  const keep = (d) => d && d.book_id !== book.book_id && (!filter || filter(d));

  const parts = [
    { text: book.title, weight: 1 },
    { text: book.author ?? '', weight: 0.8 },
    { text: book.book_categories?.category_name ?? '', weight: 0.5 },
    { text: clip(String(book.description ?? ''), 200), weight: 0.3 }
  ];
  const lexicalRanked = lexical.rank(idx, lexical.queryWeights(parts), { filter: keep, strong: true });

  let semanticRanked = await semantic.neighbors('book', docs.map((d) => d.embed), String(book.book_id));
  if (!semanticRanked) semanticRanked = await semantic.rank('book', docs.map((d) => d.embed), embedText(book), { userId });
  const semanticKept = semantic.relevant((semanticRanked ?? []).filter((r) => keep(byRef.get(r.ref))), { limit: limit * 2 });

  const fused = semantic.fuse([
    { ids: lexicalRanked.map((r) => r.doc.book_id) },
    { ids: semanticKept.map((r) => byRef.get(r.ref).book_id) }
  ]);
  const docById = new Map(docs.map((d) => [d.book_id, d]));
  return [...fused.entries()]
    .sort((a, b) => b[1] - a[1] || docById.get(b[0]).view_count - docById.get(a[0]).view_count)
    .slice(0, limit)
    .map(([bookId]) => bookId);
};

// 排程與啟動時預先建立向量，避免第一位使用者等待整批索引。
const warm = async () => {
  const idx = await index();
  return semantic.sync('book', idx.entries.map((e) => e.doc.embed));
};

module.exports = { CATALOG_LIMIT, FIELD_WEIGHTS, search, similar, warm, clear, availability, available, isbnOf, isbnForms };
