const crypto = require('crypto');
const prisma = require('../../lib/prisma');

// 簡介只存雜湊，比對前統一空白；ISBN 與出版日期只比數字，格式不同不算未採用。
const FIELDS = ['title', 'author', 'publisher', 'publish_date', 'isbn', 'description', 'category_id', 'condition_level', 'price'];
const TOKEN_RE = /^[0-9a-f]{32}$/;
const CLEARED = '{}';
const MAX_TOKENS = 3;
const TOKEN_TTL_MS = 24 * 60 * 60 * 1000;
const RETENTION_DAYS = 90;
const DAY_MS = 24 * 60 * 60 * 1000;

const text = (value) => String(value ?? '').replace(/\s+/g, ' ').trim();
const digits = (value) => String(value ?? '').replace(/[^0-9Xx]/g, '').toUpperCase();
const digest = (value) => crypto.createHash('sha256').update(text(value)).digest('hex').slice(0, 32);

const NORMALIZE = {
  title: text,
  author: text,
  publisher: text,
  publish_date: digits,
  isbn: digits,
  description: digest,
  category_id: (v) => (Number(v) > 0 ? String(Number(v)) : ''),
  condition_level: text,
  price: (v) => (Number(v) > 0 ? String(Math.round(Number(v))) : '')
};

// App 依賣家選擇的書況，從 price.by_condition 換成該書況的建議價，不一定是 suggested（未判斷書況時以「良好」計算）。
const PRICE_TABLE = 'price_by_condition';

const priceTableOf = (data) => {
  const table = data?.price?.by_condition;
  if (!table || typeof table !== 'object') return null;
  const entries = Object.entries(table)
    .map(([level, entry]) => [text(level), NORMALIZE.price(entry?.suggested)])
    .filter(([level, value]) => level && value !== '');
  return entries.length ? Object.fromEntries(entries) : null;
};

// 與賣家自己輸入的 ISBN、書名相同的值不是建議，列入會讓採用率接近 100%。
const suggestionOf = (data, inputs = {}) => {
  const raw = {
    ...Object.fromEntries(['title', 'author', 'publisher', 'publish_date', 'isbn', 'description'].map((f) => [f, data?.fields?.[f]])),
    category_id: data?.category?.category_id,
    condition_level: data?.condition?.level,
    price: data?.price?.suggested
  };
  const typed = Object.fromEntries(['isbn', 'title']
    .filter((f) => text(inputs[f]) !== '')
    .map((f) => [f, NORMALIZE[f](inputs[f])]));
  const fields = Object.fromEntries(FIELDS
    .filter((f) => text(raw[f]) !== '')
    .map((f) => [f, NORMALIZE[f](raw[f])])
    .filter(([f, v]) => v !== '' && v !== typed[f]));
  const table = fields.price ? priceTableOf(data) : null;
  return table ? { ...fields, [PRICE_TABLE]: table } : fields;
};

const issue = async (userId, data, inputs = {}) => {
  const fields = suggestionOf(data, inputs);
  if (Object.keys(fields).length === 0) return null;
  const token = crypto.randomBytes(16).toString('hex');
  await prisma.ai_listing_suggestions.create({
    data: { token, user_id: userId, fields: JSON.stringify(fields), created_at: new Date() }
  });
  return token;
};

const parseTokens = (value) => {
  const list = Array.isArray(value) ? value : String(value ?? '').split(',');
  return [...new Set(list.map((t) => String(t).trim().toLowerCase()).filter((t) => TOKEN_RE.test(t)))].slice(0, MAX_TOKENS);
};

const parseFields = (value) => {
  try {
    const json = JSON.parse(String(value ?? ''));
    return json && typeof json === 'object' ? json : {};
  } catch {
    return {};
  }
};

// 同一本書的第一步與第二步各有權杖時合併計算，每個欄位只算一次；結果記在最早發出的權杖上。
const record = async (userId, tokens, book, now = new Date()) => {
  const list = parseTokens(tokens);
  if (list.length === 0) return null;
  const rows = (await prisma.ai_listing_suggestions.findMany({
    where: { token: { in: list }, user_id: userId, used_at: null, created_at: { gte: new Date(now.getTime() - TOKEN_TTL_MS) } },
    orderBy: { created_at: 'asc' }
  }));
  if (rows.length === 0) return null;
  const suggested = new Map();
  const priceTables = [];
  for (const row of rows) {
    const stored = parseFields(row.fields);
    for (const [field, value] of Object.entries(stored)) {
      if (!FIELDS.includes(field)) continue;
      if (!suggested.has(field)) suggested.set(field, new Set());
      suggested.get(field).add(value);
    }
    if (stored[PRICE_TABLE] && typeof stored[PRICE_TABLE] === 'object') priceTables.push(stored[PRICE_TABLE]);
  }
  const adopted = Object.fromEntries([...suggested].map(([field, values]) => [field, values.has(NORMALIZE[field](book[field])) ? 1 : 0]));
  if (adopted.price === 0) {
    const level = text(book.condition_level);
    const price = NORMALIZE.price(book.price);
    if (price !== '' && priceTables.some((table) => table[level] === price)) adopted.price = 1;
  }
  const [first, ...rest] = rows;
  await prisma.ai_listing_suggestions.update({
    where: { token: first.token }, data: { used_at: now, adopted: JSON.stringify(adopted), fields: CLEARED }
  });
  if (rest.length) {
    await prisma.ai_listing_suggestions.updateMany({ where: { token: { in: rest.map((r) => r.token) } }, data: { used_at: now, fields: CLEARED } });
  }
  return adopted;
};

const recordSafely = (userId, tokens, book) => record(userId, tokens, book)
  .catch((err) => console.error('[上架輔助採用紀錄寫入失敗]:', err.message));

const purgeExpired = async (now = new Date()) => {
  const [unused, old] = await Promise.all([
    prisma.ai_listing_suggestions.deleteMany({ where: { used_at: null, created_at: { lt: new Date(now.getTime() - TOKEN_TTL_MS) } } }),
    prisma.ai_listing_suggestions.deleteMany({ where: { created_at: { lt: new Date(now.getTime() - RETENTION_DAYS * DAY_MS) } } })
  ]);
  return unused.count + old.count;
};

const purgeUser = (tx, userId) => tx.ai_listing_suggestions.deleteMany({ where: { user_id: userId } });

const exportUser = async (userId) => (await prisma.ai_listing_suggestions.findMany({
  where: { user_id: userId },
  orderBy: { created_at: 'asc' },
  select: { created_at: true, used_at: true, fields: true, adopted: true }
})).map((r) => {
  const suggested = parseFields(r.fields);
  return {
    created_at: r.created_at,
    used_at: r.used_at ?? null,
    suggested: Object.keys(suggested).length ? suggested : null,
    adopted: r.adopted ? parseFields(r.adopted) : null
  };
});

module.exports = { FIELDS, MAX_TOKENS, suggestionOf, issue, parseTokens, record, recordSafely, purgeExpired, purgeUser, exportUser };
