const { badRequest } = require('./errors');

// 主鍵是 UNSIGNED INT，但 Prisma Int 是 32 位元有號整數，超過會變成 500。
const INT_MAX = 2147483647;

const toInt = (value) => {
  if (typeof value === 'number') return Number.isInteger(value) ? value : NaN;
  if (typeof value !== 'string' || !/^\s*-?\d+\s*$/.test(value)) return NaN;
  return Number(value);
};

const isBlank = (value) => value === undefined || value === null || value === '' || value === 'null';

const id = (value, label = '編號') => {
  const n = toInt(value);
  if (!Number.isSafeInteger(n) || n < 1 || n > INT_MAX) throw badRequest(`${label}不正確`);
  return n;
};

const optionalId = (value, label) => (isBlank(value) ? null : id(value, label));

const int = (value, { label = '數值', min = -INT_MAX, max = INT_MAX } = {}) => {
  const n = toInt(value);
  if (!Number.isSafeInteger(n) || n < min || n > max) {
    throw badRequest(`${label}必須是 ${min} ~ ${max} 之間的整數`);
  }
  return n;
};

const number = (value, { label = '數值', min = -Infinity, max = Infinity } = {}) => {
  const n = typeof value === 'string' && value.trim() !== '' ? Number(value) : value;
  if (typeof n !== 'number' || !Number.isFinite(n) || n < min || n > max) {
    throw badRequest(`${label}格式不正確`);
  }
  return n;
};

const text = (value, { label = '內容', max } = {}) => {
  const s = typeof value === 'string' ? value.trim() : typeof value === 'number' ? String(value) : '';
  if (max && s.length > max) throw badRequest(`${label}不可超過 ${max} 個字`);
  return s;
};

const optionalText = (value, opts) => {
  if (value === undefined) return undefined;
  const s = text(value, opts);
  return s === '' ? null : s;
};

const oneOf = (value, allowed, message) => {
  if (!allowed.includes(value)) throw badRequest(message ?? `僅接受：${allowed.join(', ')}`);
  return value;
};

const bool = (value) => value === true || value === 'true' || value === 1 || value === '1';

const date = (value, label = '日期') => {
  if (isBlank(value)) return null;
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) throw badRequest(`${label}格式不正確`);
  return d;
};

const pagination = (query, { limit: defaultLimit = 20, max = 100 } = {}) => {
  const page = Math.max(1, Math.min(toInt(query.page) || 1, 100000));
  const rawLimit = toInt(query.limit);
  const limit = Math.max(1, Math.min(Number.isInteger(rawLimit) && rawLimit > 0 ? rawLimit : defaultLimit, max));
  return { page, limit, skip: (page - 1) * limit };
};

const pageMeta = (total, { page, limit }) => ({
  total, page, limit, total_pages: Math.ceil(total / limit)
});

const evidenceUrls = (value, { max = 10 } = {}) => {
  if (isBlank(value)) return null;
  const list = Array.isArray(value) ? value : String(value).split(',');
  const urls = list.map((u) => (typeof u === 'string' ? u.trim() : '')).filter(Boolean);
  if (urls.length > max) throw badRequest(`佐證資料最多 ${max} 筆`);
  for (const u of urls) {
    if (u.length > 500 || !/^(\/uploads\/[\w./-]+|https?:\/\/\S+)$/.test(u) || u.includes('..')) {
      throw badRequest('佐證連結格式不正確');
    }
  }
  return urls.length ? urls.join(',') : null;
};

module.exports = {
  INT_MAX, toInt, isBlank, id, optionalId, int, number, text, optionalText, oneOf, bool, date,
  pagination, pageMeta, evidenceUrls
};
