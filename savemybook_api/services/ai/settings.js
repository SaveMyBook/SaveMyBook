const prisma = require('../../lib/prisma');
const { hasTables } = require('../../lib/schema-check');
const { badRequest, HttpError } = require('../../lib/errors');
const { PROVIDERS, PROVIDER_IDS, keyConfigured } = require('../../lib/ai');
const audit = require('../audit');

const AI_TABLES = ['ai_settings', 'ai_usage_logs', 'ai_support_sessions', 'ai_support_messages', 'ai_recommendation_cache', 'ai_book_reviews', 'ai_consents'];
const FEATURES = ['support', 'listing_assist', 'recommend', 'moderation'];
const LIMITED_FEATURES = ['support', 'listing_assist', 'recommend'];
const MODERATION_ACTIONS = ['review', 'block'];
const MODEL_RE = /^[A-Za-z0-9._:\-/]{1,80}$/;
const CACHE_MS = 30 * 1000;

const DEFAULTS = Object.freeze({
  enabled: false,
  default_provider: 'deepseek',
  providers: {
    deepseek: { model: 'deepseek-flash', input_per_m: 0.14, cached_input_per_m: 0.0028, output_per_m: 0.28, search_price_per_k: 0, search_free_per_month: 0 },
    gemini: { model: 'gemini-3.1-flash-lite', input_per_m: 0.25, cached_input_per_m: 0.025, output_per_m: 1.5, search_price_per_k: 14, search_free_per_month: 5000 },
    openai: { model: 'gpt-5-nano', input_per_m: 0.05, cached_input_per_m: 0.005, output_per_m: 0.4, search_price_per_k: 10, search_free_per_month: 0 }
  },
  features: {
    support: { enabled: true, provider: null },
    listing_assist: { enabled: true, provider: 'gemini', web_search: true },
    recommend: { enabled: true, provider: null },
    moderation: { enabled: true, provider: null, action: 'review' }
  },
  limits: {
    monthly_budget_usd: 10,
    daily_per_user: { support: 30, listing_assist: 15, recommend: 5 }
  }
});

const FEATURE_LABELS = { support: 'AI 客服', listing_assist: '上架輔助', recommend: '個人推薦', moderation: '上架審核' };
const PRICE_LABELS = {
  model: '模型',
  input_per_m: '輸入單價',
  cached_input_per_m: '快取輸入單價',
  output_per_m: '輸出單價',
  search_price_per_k: '搜尋單價',
  search_free_per_month: '每月免費搜尋次數'
};

const unavailable = () => new HttpError(503, 'AI 功能目前無法使用，伺服器尚未完成資料庫更新', 'AI_UNAVAILABLE');

const clone = (value) => JSON.parse(JSON.stringify(value));

const isObject = (value) => value !== null && typeof value === 'object' && !Array.isArray(value);

// strict 為 true 時（管理員送出）不合法的值直接回 400；讀取資料庫時則靜默改回預設值。
const normalize = (raw, { strict = false } = {}) => {
  const src = isObject(raw) ? raw : {};
  const fail = (message) => {
    if (strict) throw badRequest(message);
  };

  const bool = (value, fallback, label) => {
    if (value === undefined) return fallback;
    if (typeof value === 'boolean') return value;
    fail(`${label}必須是 true 或 false`);
    return fallback;
  };
  const numberIn = (value, fallback, { min, max, integer = false, label }) => {
    if (value === undefined) return fallback;
    const n = typeof value === 'number' ? value : NaN;
    if (Number.isFinite(n) && n >= min && n <= max && (!integer || Number.isInteger(n))) return n;
    fail(`${label}必須是 ${min} ~ ${max} 之間的${integer ? '整數' : '數值'}`);
    return fallback;
  };
  const providerRef = (value, fallback, label, { nullable }) => {
    if (value === undefined) return fallback;
    if (value === null && nullable) return null;
    if (PROVIDER_IDS.includes(value)) return value;
    fail(`${label}僅接受：${PROVIDER_IDS.join(', ')}${nullable ? ' 或 null' : ''}`);
    return fallback;
  };

  const out = clone(DEFAULTS);
  out.enabled = bool(src.enabled, out.enabled, 'enabled ');
  out.default_provider = providerRef(src.default_provider, out.default_provider, '預設服務商', { nullable: false });

  const providers = isObject(src.providers) ? src.providers : {};
  for (const id of PROVIDER_IDS) {
    const p = isObject(providers[id]) ? providers[id] : {};
    const target = out.providers[id];
    const name = PROVIDERS[id].name;
    if (p.model !== undefined) {
      if (typeof p.model === 'string' && MODEL_RE.test(p.model.trim())) target.model = p.model.trim();
      else fail(`${name} 模型名稱格式不正確`);
    }
    for (const field of ['input_per_m', 'cached_input_per_m', 'output_per_m', 'search_price_per_k']) {
      target[field] = numberIn(p[field], target[field], { min: 0, max: 1000, label: `${name} ${PRICE_LABELS[field]}` });
    }
    target.search_free_per_month = numberIn(p.search_free_per_month, target.search_free_per_month, {
      min: 0, max: 1000000, integer: true, label: `${name} ${PRICE_LABELS.search_free_per_month}`
    });
  }

  const features = isObject(src.features) ? src.features : {};
  for (const feature of FEATURES) {
    const f = isObject(features[feature]) ? features[feature] : {};
    const target = out.features[feature];
    const label = FEATURE_LABELS[feature];
    target.enabled = bool(f.enabled, target.enabled, `${label}的 enabled `);
    target.provider = providerRef(f.provider, target.provider, `${label}的服務商`, { nullable: true });
    if (feature === 'listing_assist') target.web_search = bool(f.web_search, target.web_search, `${label}的 web_search `);
    if (feature === 'moderation' && f.action !== undefined) {
      if (MODERATION_ACTIONS.includes(f.action)) target.action = f.action;
      else fail(`${label}的處理方式僅接受：${MODERATION_ACTIONS.join(', ')}`);
    }
  }

  const limits = isObject(src.limits) ? src.limits : {};
  out.limits.monthly_budget_usd = numberIn(limits.monthly_budget_usd, out.limits.monthly_budget_usd, {
    min: 0, max: 100000, label: '每月預算'
  });
  const daily = isObject(limits.daily_per_user) ? limits.daily_per_user : {};
  for (const feature of LIMITED_FEATURES) {
    out.limits.daily_per_user[feature] = numberIn(daily[feature], out.limits.daily_per_user[feature], {
      min: 0, max: 10000, integer: true, label: `${FEATURE_LABELS[feature]}每人每日次數`
    });
  }
  return out;
};

let cache = null;

const clearCache = () => {
  cache = null;
};

const migrationReady = () => hasTables(AI_TABLES);

const load = async () => {
  if (cache && Date.now() - cache.at < CACHE_MS) return cache.value;
  let value = normalize(null);
  if (await migrationReady()) {
    const rows = await prisma.$queryRaw`SELECT config FROM ai_settings WHERE id = 1`;
    if (rows[0]?.config) {
      try {
        value = normalize(JSON.parse(String(rows[0].config)));
      } catch {
        value = normalize(null);
      }
    }
  }
  cache = { value, at: Date.now() };
  return value;
};

const flatten = (obj, prefix = '') => Object.entries(obj).flatMap(([key, value]) => (isObject(value)
  ? flatten(value, `${prefix}${key}.`)
  : [[`${prefix}${key}`, value]]));

const labelOf = (path) => {
  const parts = path.split('.');
  if (parts[0] === 'enabled') return 'AI 功能總開關';
  if (parts[0] === 'default_provider') return '預設服務商';
  if (parts[0] === 'providers') return `${PROVIDERS[parts[1]]?.name ?? parts[1]} ${PRICE_LABELS[parts[2]] ?? parts[2]}`;
  if (parts[0] === 'features') {
    const field = { enabled: '開關', provider: '服務商', web_search: '網路搜尋', action: '處理方式' }[parts[2]] ?? parts[2];
    return `${FEATURE_LABELS[parts[1]] ?? parts[1]}${field}`;
  }
  if (parts[1] === 'monthly_budget_usd') return '每月預算（美元）';
  return `${FEATURE_LABELS[parts[2]] ?? parts[2]}每人每日次數`;
};

const diffSettings = (before, after) => {
  const old = new Map(flatten(before));
  return flatten(after)
    .filter(([path, value]) => old.get(path) !== value)
    .map(([path, value]) => ({ field: path, label: labelOf(path), from: audit.display(old.get(path)), to: audit.display(value) }));
};

const save = async (input, { adminId, req }) => {
  if (!(await migrationReady())) throw unavailable();
  const next = normalize(input, { strict: true });
  clearCache();
  const before = await load();

  await prisma.$executeRaw`
    INSERT INTO ai_settings (id, config, updated_by, updated_at)
    VALUES (1, ${JSON.stringify(next)}, ${adminId}, ${new Date()})
    ON DUPLICATE KEY UPDATE config = VALUES(config), updated_by = VALUES(updated_by), updated_at = VALUES(updated_at)`;
  clearCache();

  const changes = diffSettings(before, next);
  await audit.record(null, {
    adminId,
    action: '修改 AI 設定',
    summary: changes.length
      ? `修改 AI 設定：${changes.map((c) => c.label).join('、')}`
      : '重新儲存 AI 設定（無實際變更）',
    changes,
    req
  });
  return next;
};

const providerList = () => PROVIDER_IDS.map((id) => ({
  id,
  name: PROVIDERS[id].name,
  key_configured: keyConfigured(id),
  vision: PROVIDERS[id].vision,
  web_search: PROVIDERS[id].web_search,
  default_model: PROVIDERS[id].default_model,
  docs_url: PROVIDERS[id].docs_url
}));

module.exports = {
  AI_TABLES, FEATURES, LIMITED_FEATURES, MODERATION_ACTIONS, DEFAULTS, FEATURE_LABELS,
  normalize, load, save, clearCache, migrationReady, providerList, diffSettings, unavailable
};
