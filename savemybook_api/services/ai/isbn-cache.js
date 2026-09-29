const crypto = require('crypto');
const prisma = require('../../lib/prisma');
const isbnCodes = require('../../lib/isbn');
const { titleMatches } = require('../../lib/book-match');
const { mergeSources } = require('./sources');

const DAY_MS = 24 * 60 * 60 * 1000;
const COMPLETE_TTL_DAYS = 180;
const PARTIAL_TTL_DAYS = 30;
const NONE_TTL_DAYS = 30;
const MISSING_TTL_DAYS = 30;
const MISSING_KEYS = ['description', 'author', 'publisher', 'publish_date', 'original_price'];
const MAX_SOURCES = 8;
const FIELD_KEYS = ['title', 'subtitle', 'author', 'publisher', 'publish_date', 'page_count', 'language'];
const DESCRIPTION_SOURCES = ['sources', 'mixed', 'ai'];

const prompts = new Map();

// 上架輔助與書目補齊各自登錄產生簡介與定價的提示詞；任一份改動後，舊的快取一律視為未命中。
const register = (name, text) => {
  prompts.set(name, String(text));
};

const version = () => crypto.createHash('sha1')
  .update([...prompts.entries()].sort(([a], [b]) => a.localeCompare(b)).map(([k, v]) => `${k}\n${v}`).join('\n\n'))
  .digest('hex')
  .slice(0, 16);

const keyOf = (isbn) => isbnCodes.isbn13(isbn) || null;

const parse = (value, fallback) => {
  try {
    const parsed = JSON.parse(value ?? '');
    return parsed ?? fallback;
  } catch {
    return fallback;
  }
};

const cleanFields = (fields) => {
  const out = {};
  for (const key of FIELD_KEYS) {
    const value = fields?.[key];
    if (value != null && String(value).trim()) out[key] = key === 'page_count' ? Number(value) || null : String(value).trim();
  }
  return Object.keys(out).length > 0 ? out : null;
};

// 網路搜尋過仍查不到的欄位：整個 ISBN 查無結果時另記為 none，這裡記的是有書目但缺簡介、定價或出版日期的情況。
const missingMarks = (value, now = new Date()) => {
  const parsed = parse(value, {});
  const since = now.getTime() - MISSING_TTL_DAYS * DAY_MS;
  return Object.fromEntries(Object.entries(parsed && typeof parsed === 'object' ? parsed : {})
    .filter(([key, at]) => MISSING_KEYS.includes(key) && new Date(at).getTime() > since));
};

const toEntry = (row, now = new Date()) => ({
  isbn: row.isbn,
  status: row.status,
  fields: cleanFields(parse(row.fields, null)),
  description: row.description || '',
  description_source: DESCRIPTION_SOURCES.includes(row.description_source) ? row.description_source : '',
  original_price: row.original_price == null ? null : Number(row.original_price),
  sources: mergeSources([parse(row.sources, [])], { max: MAX_SOURCES, trustDomain: true }),
  missing: Object.keys(missingMarks(row.missing, now)),
  hits: Number(row.hits ?? 0),
  created_at: row.created_at,
  expires_at: row.expires_at
});

const fresh = (row, now = new Date()) => row && row.prompt_version === version() && new Date(row.expires_at) > now;

const get = async (isbn, { now = new Date() } = {}) => {
  const key = keyOf(isbn);
  if (!key) return null;
  const row = await prisma.ai_isbn_cache.findUnique({ where: { isbn: key } });
  return fresh(row, now) ? toEntry(row, now) : null;
};

// 快取的書名與這次的書名不符時不能沿用：同一個 ISBN 被登錄在別本書上時，快取會把別本書的資料帶給其他賣家。
const fits = (entry, title) => {
  const cached = entry?.fields?.title;
  return !title || !cached || titleMatches(title, cached, { subtitle: entry.fields.subtitle ?? '' });
};

const hit = (isbn) => prisma.ai_isbn_cache.updateMany({ where: { isbn: keyOf(isbn) ?? '' }, data: { hits: { increment: 1 } } })
  .catch(() => null);

const ttlDays = (entry) => {
  if (entry.status === 'none') return NONE_TTL_DAYS;
  return entry.description && entry.original_price != null ? COMPLETE_TTL_DAYS : PARTIAL_TTL_DAYS;
};

const toRow = (entry, now, existing) => ({
  status: entry.status,
  fields: entry.fields ? JSON.stringify(entry.fields) : null,
  description: entry.description || null,
  description_source: entry.description ? entry.description_source : '',
  original_price: entry.original_price,
  sources: entry.sources.length > 0 ? JSON.stringify(entry.sources) : null,
  missing: Object.keys(entry.marks ?? {}).length > 0 ? JSON.stringify(entry.marks) : null,
  prompt_version: version(),
  updated_at: now,
  expires_at: new Date(Math.max(
    now.getTime() + ttlDays(entry) * DAY_MS,
    existing && entry.status === existing.status ? new Date(existing.expires_at).getTime() : 0
  ))
});

const contentOf = (entry) => JSON.stringify([
  entry.fields, entry.description, entry.description_source, entry.original_price, entry.sources, Object.keys(entry.marks ?? {}).sort()
]);

const hasValue = (entry, key) => {
  if (key === 'description') return Boolean(entry.description);
  if (key === 'original_price') return entry.original_price != null;
  return Boolean(entry.fields?.[key]);
};

const validPrice = (value) => {
  const n = Math.round(Number(value));
  return Number.isFinite(n) && n >= 1 && n <= 99999 ? n : null;
};

// 只補上快取還沒有的內容，已存的資料不被後來的結果覆寫；要更正錯誤的快取由管理員清除後重新產生。
// missing：這次網路搜尋仍查不到的欄位，30 天內同一欄位不再搜尋；之後查到時自動移除。
const put = async (isbn, {
  fields = null, description = '', descriptionSource = '', originalPrice = null, sources = [], missing = []
}, { now = new Date() } = {}) => {
  const key = keyOf(isbn);
  if (!key) return null;
  const row = await prisma.ai_isbn_cache.findUnique({ where: { isbn: key } });
  const base = fresh(row, now) && row.status === 'found' ? { ...toEntry(row, now), marks: missingMarks(row.missing, now) } : null;
  const text = String(description ?? '').trim();
  const patch = {
    fields: cleanFields(fields),
    description: text && DESCRIPTION_SOURCES.includes(descriptionSource) ? text : '',
    original_price: validPrice(originalPrice)
  };
  const entry = {
    status: 'found',
    fields: cleanFields({ ...patch.fields, ...base?.fields }),
    description: base?.description || patch.description,
    description_source: base?.description ? base.description_source : patch.description ? descriptionSource : '',
    original_price: base?.original_price ?? patch.original_price,
    sources: mergeSources([base?.sources ?? [], sources], { max: MAX_SOURCES, trustDomain: true })
  };
  const stamp = now.toISOString();
  const marks = { ...Object.fromEntries(missing.filter((key) => MISSING_KEYS.includes(key)).map((key) => [key, stamp])), ...base?.marks };
  entry.marks = Object.fromEntries(Object.entries(marks).filter(([key]) => !hasValue(entry, key)));
  if (!entry.fields && !entry.description && entry.original_price == null) return null;
  // 沒有新內容時不寫入，否則常被沿用的快取每次都會延長期限而永遠不會重新查證。
  if (base && contentOf(entry) === contentOf(base)) return base;
  const data = toRow(entry, now, base && row);
  await prisma.ai_isbn_cache.upsert({
    where: { isbn: key },
    create: { isbn: key, ...data, hits: 0, created_at: now },
    update: { ...data, ...(!base && { hits: 0, created_at: now }) }
  });
  return entry;
};

// 查詢與網路搜尋都沒有結果：30 天內不再重新搜尋。已有資料的快取不會被蓋掉。
const markNone = async (isbn, { now = new Date() } = {}) => {
  const key = keyOf(isbn);
  if (!key) return;
  const row = await prisma.ai_isbn_cache.findUnique({ where: { isbn: key } });
  if (fresh(row, now) && row.status === 'found') return;
  const data = toRow({ status: 'none', fields: null, description: '', original_price: null, sources: [] }, now, null);
  await prisma.ai_isbn_cache.upsert({
    where: { isbn: key },
    create: { isbn: key, ...data, hits: 0, created_at: now },
    update: { ...data, hits: 0, created_at: now }
  });
};

const safely = (task) => Promise.resolve().then(task).catch((err) => {
  console.error('[ISBN 快取寫入失敗]:', err.message);
  return null;
});

const find = async (isbn) => {
  const key = keyOf(isbn);
  if (!key) return null;
  const row = await prisma.ai_isbn_cache.findUnique({ where: { isbn: key } });
  if (!row) return null;
  return { ...toEntry(row), current: fresh(row) };
};

const clear = async (isbn) => {
  const key = keyOf(isbn);
  if (!key) return 0;
  const { count } = await prisma.ai_isbn_cache.deleteMany({ where: { isbn: key } });
  return count;
};

const purgeExpired = async (now = new Date()) => {
  const { count } = await prisma.ai_isbn_cache.deleteMany({ where: { expires_at: { lt: now } } });
  return count;
};

module.exports = {
  COMPLETE_TTL_DAYS, PARTIAL_TTL_DAYS, NONE_TTL_DAYS, MISSING_TTL_DAYS, register, version, keyOf, get, fits, hit, put, markNone, safely, find, clear, purgeExpired
};
