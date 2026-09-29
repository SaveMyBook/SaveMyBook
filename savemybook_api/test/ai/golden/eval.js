// 固定答案評測（A 層）：以題庫驅動實際的檢索程式，計算前 k 名命中率與 MRR（平均排名倒數）。
// 測試環境關閉語意向量，這裡量到的是純關鍵字檢索；模型一律以假回應代替，不產生費用。
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const DAY = 24 * 60 * 60 * 1000;
const HOUR = 60 * 60 * 1000;

const load = (name) => JSON.parse(fs.readFileSync(path.join(__dirname, `${name}.json`), 'utf8'));

// 各評測依賴的題庫檔；雜湊值記在基準中，用來分辨指標變動來自題庫還是受測程式。
const BANKS = {
  support: ['support'],
  book_chat_planned: ['book-chat', 'catalog'],
  book_chat_raw: ['book-chat', 'catalog'],
  recommend: ['recommend', 'catalog']
};
const bankHash = (name) => crypto.createHash('sha1')
  .update(BANKS[name].map((file) => JSON.stringify(load(file))).join('\n'))
  .digest('hex')
  .slice(0, 12);

const round = (value) => Math.round(value * 1000) / 1000;
const mean = (values) => (values.length ? values.reduce((sum, v) => sum + v, 0) / values.length : 0);

const firstRank = (ranked, relevant) => {
  const index = ranked.findIndex((id) => relevant.has(id));
  return index < 0 ? null : index + 1;
};

const summarize = (ranks, ks) => {
  const out = { n: ranks.length };
  for (const k of ks) out[`hit@${k}`] = round(mean(ranks.map((r) => (r != null && r <= k ? 1 : 0))));
  out.mrr = round(mean(ranks.map((r) => (r ? 1 / r : 0))));
  return out;
};

const byTag = (items, ks) => {
  const tags = [...new Set(items.flatMap((i) => i.tags ?? []))].sort();
  return Object.fromEntries(tags.map((tag) => [tag, summarize(items.filter((i) => i.tags?.includes(tag)).map((i) => i.rank), ks)]));
};

// ---------- 種子資料：客服索引實際會納入的常見問題與法律文件 ----------

const SQL_STRING = "'((?:[^']|'')*)'";
const unquote = (s) => s.replace(/''/g, "'");

const statementOf = (seed, table) => {
  const start = seed.indexOf(`INSERT IGNORE INTO ${table} `);
  if (start < 0) throw new Error(`seed.sql 找不到 ${table}`);
  const end = seed.indexOf('\nINSERT ', start + 1);
  return seed.slice(start, end < 0 ? undefined : end);
};

const seedDocuments = (apiRoot) => {
  const seed = fs.readFileSync(path.join(apiRoot, 'prisma/seed.sql'), 'utf8');
  const legalRow = new RegExp(`\\('(\\w+)',\\s*${SQL_STRING},\\s*${SQL_STRING},\\s*\\d+,\\s*\\d+\\)`, 'g');
  const faqRow = new RegExp(`\\((\\d+),\\s*'(\\w+)',\\s*${SQL_STRING},\\s*${SQL_STRING},\\s*(\\d+)\\)`, 'g');
  const legal = [...statementOf(seed, 'legal_documents').matchAll(legalRow)]
    .map((m, i) => ({ doc_id: i + 1, doc_key: m[1], title: unquote(m[2]), content: unquote(m[3]) }));
  const faqs = [...statementOf(seed, 'faqs').matchAll(faqRow)].map((m) => ({
    faq_id: Number(m[1]), category: m[2], question: unquote(m[3]), answer: unquote(m[4]), sort_order: Number(m[5]), is_visible: true
  }));
  if (legal.length === 0 || faqs.length === 0) throw new Error('seed.sql 的法律文件或常見問題解析失敗');
  return { legal, faqs };
};

// ---------- 客服 ----------

const SUPPORT_KS = [1, 3, 6];
const docId = (id) => (id.includes(':') ? id : `platform:${id}`);

const evaluateSupport = async (h) => {
  const knowledge = h.api('services/ai/knowledge');
  const { questions } = load('support');
  const { legal, faqs } = seedDocuments(h.API_ROOT);
  h.prisma.store.faqs = faqs;
  h.prisma.store.legal_documents = legal;
  knowledge.invalidate();

  const items = [];
  for (const q of questions) {
    const docs = await knowledge.search(q.q, { context: q.context ?? [] });
    const ids = docs.map((d) => d.id);
    items.push({
      id: q.id, label: q.q, tags: q.tags, max_rank: q.max_rank ?? null, rank: firstRank(ids, new Set(q.expect.map(docId))), top: ids[0] ?? null
    });
  }
  return { items, metrics: summarize(items.map((i) => i.rank), SUPPORT_KS), by_tag: byTag(items, SUPPORT_KS) };
};

// ---------- 測試書目 ----------

const seedCatalog = (prisma, now = Date.now()) => {
  const catalog = load('catalog');
  const categoryName = new Map(catalog.categories.map((c) => [c.category_id, c.category_name]));
  const cabinetOf = new Map(catalog.cabinets.map((c) => [c.cabinet_id, c]));
  const books = catalog.books.map((b) => {
    const cabinet = cabinetOf.get(b.cabinet) ?? null;
    const createdAt = new Date(now - b.days * DAY);
    return {
      book_id: b.id,
      seller_id: b.seller,
      isbn: b.isbn ?? null,
      title: b.title,
      author: b.author ?? null,
      publisher: b.publisher ?? null,
      category_id: b.category,
      condition_level: b.condition,
      price: b.price,
      description: b.description ?? null,
      cabinet_id: b.cabinet ?? null,
      status: b.status ?? 'on_sale',
      view_count: b.views ?? 0,
      is_approved: b.approved ?? true,
      created_at: createdAt,
      updated_at: createdAt,
      book_categories: { category_name: categoryName.get(b.category) ?? null },
      smart_cabinets: cabinet && { cabinet_id: cabinet.cabinet_id, cabinet_name: cabinet.cabinet_name },
      book_images: [{ image_url: `https://example.test/${b.id}.jpg` }],
      users: { user_id: b.seller, nickname: `賣家${b.seller}`, avatar_url: null },
      _count: { favorites: 0, shopping_cart: 0, chat_rooms: 0, book_images: 1 }
    };
  });
  prisma.store.books = books;
  prisma.store.book_categories = catalog.categories.map((c, i) => ({ ...c, parent_id: null, sort_order: i }));
  prisma.store.smart_cabinets = catalog.cabinets.map((c) => ({ ...c, is_active: true }));
  prisma.store.book_deposits = [];
  prisma.store.reservations = catalog.reservations.map((r) => ({
    reservation_id: r.reservation_id,
    book_id: r.book_id,
    buyer_id: r.buyer_id,
    status: r.status,
    pickup_deadline: r.hours == null ? null : new Date(now + r.hours * HOUR)
  }));

  // 不可推薦的書以題庫資料獨立判斷，不沿用受測的程式，才能抓到程式本身的遺漏。
  const maintenance = new Set(catalog.cabinets.filter((c) => c.is_maintenance).map((c) => c.cabinet_id));
  const blocked = (viewer) => {
    const out = new Map();
    for (const b of catalog.books) {
      if ((b.status ?? 'on_sale') !== 'on_sale' || b.approved === false) out.set(b.id, '非在售或未核准');
      else if (maintenance.has(b.cabinet)) out.set(b.id, '書櫃維修中');
      else if (b.seller === viewer) out.set(b.id, '本人上架');
    }
    for (const r of catalog.reservations) {
      if (r.status === 'confirmed' && r.hours > 0 && r.buyer_id !== viewer && !out.has(r.book_id)) out.set(r.book_id, '他人預約保留中');
    }
    return out;
  };
  return { catalog, books, byId: new Map(books.map((b) => [b.book_id, b])), blocked };
};

// must_show 為依規則可購買、必須出現的書（例如已過期或待回覆的預約、本人的保留），用來抓過度排除。
const missingOf = (id, mustShow, shown) => (mustShow ?? [])
  .filter((bookId) => !shown.includes(bookId))
  .map((bookId) => `${id} 書 ${bookId}：可購買卻被排除`);

// ---------- 書籍顧問 ----------

const BOOK_CHAT_KS = [1, 3, 6];
const DEFAULT_VIEWER = 120;

// planned：第一段模型給出搜尋條件；raw：模型沒有給條件，只能以使用者原話檢索。
const evaluateBookChat = async (h, mode) => {
  const bookChat = h.api('services/ai/book-chat');
  const { catalog, blocked } = seedCatalog(h.prisma);
  const categoryIds = new Set(catalog.categories.map((c) => c.category_id));
  const { queries } = load('book-chat');

  const items = [];
  const violations = [];
  for (const q of queries) {
    const viewer = q.viewer ?? DEFAULT_VIEWER;
    const search = bookChat.sanitizeSearch(mode === 'planned' ? q.search : {}, categoryIds);
    const { rows, matched, extraIds } = await bookChat.candidates(viewer, search, q.content);
    const shown = rows.map((b) => b.book_id);
    // 未命中檢索時候選書只是熱門書，補位的其他在售書也不是檢索結果，兩者都不算排名與涵蓋率。
    const retrieved = matched ? shown.filter((id) => !extraIds.has(id)) : [];
    violations.push(...missingOf(q.id, q.must_show, shown));

    const unavailable = blocked(viewer);
    for (const b of rows) {
      const reasons = [];
      if (unavailable.has(b.book_id)) reasons.push(unavailable.get(b.book_id));
      if (search.max_price != null && b.price > search.max_price) reasons.push('超出預算上限');
      if (search.min_price != null && b.price < search.min_price) reasons.push('低於預算下限');
      if (search.condition_levels.length > 0 && !search.condition_levels.includes(b.condition_level)) reasons.push('書況不符');
      if (reasons.length) violations.push(`${q.id} 書 ${b.book_id}：${reasons.join('、')}`);
    }

    if (q.expect.length === 0) continue;
    const relevant = new Set(q.expect);
    items.push({
      id: q.id,
      label: q.content,
      tags: q.tags,
      rank: firstRank(retrieved, relevant),
      recall: round(q.expect.filter((id) => retrieved.includes(id)).length / q.expect.length),
      top: retrieved[0] ?? null
    });
  }
  return {
    items,
    violations,
    metrics: { ...summarize(items.map((i) => i.rank), BOOK_CHAT_KS), 'recall@retrieved': round(mean(items.map((i) => i.recall))) },
    by_tag: byTag(items, BOOK_CHAT_KS)
  };
};

// ---------- 個人化推薦 ----------

const RECOMMEND_KS = [1, 3, 10];
const RECOMMEND_LIMIT = 10;

const candidateKeys = (prompt) => {
  const section = String(prompt).split('【候選書籍】')[1] ?? '';
  return [...section.matchAll(/^(b\d+)｜/gm)].map((m) => m[1]);
};

// 模型依候選順序原樣回傳，量到的是檢索與過濾本身的排序，而不是模型的判斷。
const echoModel = async (provider, options) => {
  const json = { items: candidateKeys(options.prompt).map((id) => ({ id, basis: '', reason: '符合您的閱讀紀錄' })) };
  return { text: JSON.stringify(json), json, usage: {}, latency_ms: 1, sources: [] };
};

const evaluateRecommend = async (h) => {
  const recommend = h.api('services/ai/recommend');
  const now = Date.now();
  const { byId, blocked } = seedCatalog(h.prisma, now);
  const { personas } = load('recommend');

  const rowsOf = (key) => personas.flatMap((p) => (p[key] ?? []).map((bookId, i) => ({
    user_id: p.user, book_id: bookId, created_at: new Date(now - (i + 1) * HOUR), books: byId.get(bookId)
  })));
  h.prisma.store.favorites = rowsOf('favorites');
  h.prisma.store.shopping_cart = rowsOf('cart');
  const orderItems = personas.flatMap((p) => (p.purchases ?? []).map(([bookId, status], i) => ({
    item_id: p.user * 100 + i, book_id: bookId, buyer_id: p.user, status, books: byId.get(bookId)
  })));
  // 假 Prisma 不支援以關聯欄位（orders.buyer_id）過濾，這裡依推薦與排行實際使用的條件篩選。
  const statusOk = (status, filter = {}) => !(filter.notIn ?? []).includes(status) && (!filter.in || filter.in.includes(status));
  h.onModel('order_items.findMany', ({ where, take }) => orderItems
    .filter((r) => r.buyer_id === where.orders.buyer_id && statusOk(r.status, where.orders.status))
    .sort((a, b) => b.item_id - a.item_id)
    .slice(0, take ?? undefined)
    .map((r) => ({ book_id: r.book_id, books: r.books })));

  h.setSettings({ enabled: true });
  for (const p of personas) {
    h.setConsent(p.user, p.consent !== false);
    if (p.cache) {
      const strong = [...(p.favorites ?? []), ...(p.cart ?? []), ...(p.purchases ?? []).map(([id]) => id)];
      h.prisma.rows('ai_recommendation_cache').push({
        user_id: p.user,
        payload: JSON.stringify({ items: p.cache.map((id) => ({ book_id: id, reason: '先前的推薦' })), fingerprint: recommend.fingerprintOf(strong) }),
        created_at: new Date(now - HOUR)
      });
    }
  }

  const items = [];
  const violations = [];
  const original = h.ai.generate;
  h.ai.generate = echoModel;
  try {
    for (const p of personas) {
      // 推薦在背景產生：第一次請求觸發產生，等背景工作結束後再量測產生後的結果。
      const options = { viewedIds: p.viewed ?? [] };
      await recommend.recommendations(p.user, RECOMMEND_LIMIT, options);
      await recommend.idle(p.user);
      const { data, meta } = await recommend.recommendations(p.user, RECOMMEND_LIMIT, options);
      const ids = data.map((d) => d.book.book_id);
      if (meta.source !== p.source) violations.push(`${p.id} 預期走 ${p.source}，實際為 ${meta.source}`);
      const unavailable = blocked(p.user);
      for (const id of ids) if (unavailable.has(id)) violations.push(`${p.id} 書 ${id}：${unavailable.get(id)}`);
      violations.push(...missingOf(p.id, p.must_show, ids));
      if (ids.length === 0) violations.push(`${p.id} 沒有任何推薦`);

      if (p.expect.length === 0) continue;
      const relevant = new Set(p.expect);
      items.push({
        id: p.id,
        label: p.label,
        tags: p.tags,
        rank: firstRank(ids, relevant),
        recall: round(p.expect.filter((id) => ids.includes(id)).length / p.expect.length),
        top: ids[0] ?? null
      });
    }
  } finally {
    h.ai.generate = original;
  }
  return {
    items,
    violations,
    metrics: { ...summarize(items.map((i) => i.rank), RECOMMEND_KS), [`recall@${RECOMMEND_LIMIT}`]: round(mean(items.map((i) => i.recall))) },
    by_tag: byTag(items, RECOMMEND_KS)
  };
};

module.exports = {
  load, bankHash, round, firstRank, summarize, seedDocuments, seedCatalog, candidateKeys,
  evaluateSupport, evaluateBookChat, evaluateRecommend
};
