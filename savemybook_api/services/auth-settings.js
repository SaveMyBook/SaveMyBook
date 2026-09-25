const prisma = require('../lib/prisma');
const { badRequest, forbidden } = require('../lib/errors');
const { env } = require('../config/env');
const firebase = require('../lib/firebase-token');
const audit = require('./audit');

const PROVIDER_IDS = ['google', 'apple', 'phone', 'line', 'discord'];
const FIREBASE_PROVIDERS = ['google', 'apple', 'phone'];
const OAUTH_PROVIDERS = ['line', 'discord'];
const PROVIDER_LABELS = Object.freeze({
  google: 'Google', apple: 'Apple', phone: '手機號碼', line: 'LINE', discord: 'Discord'
});
const CACHE_MS = 30 * 1000;

const DEFAULTS = Object.freeze({
  social_enabled: true,
  providers: {
    google: { enabled: true, signup: true },
    apple: { enabled: true, signup: true },
    phone: { enabled: true, signup: true },
    line: { enabled: false, signup: false },
    discord: { enabled: false, signup: false }
  }
});

const disabled = (provider) =>
  forbidden(`目前未開放以 ${PROVIDER_LABELS[provider] ?? provider} 登入`, 'SIGN_IN_METHOD_DISABLED');

const clone = (value) => JSON.parse(JSON.stringify(value));

const isObject = (value) => value !== null && typeof value === 'object' && !Array.isArray(value);

// strict 為 true 時（管理員送出）不合法的值直接回 400；讀取資料庫時則靜默改回預設值。
const normalize = (raw, { strict = false } = {}) => {
  const src = isObject(raw) ? raw : {};
  const bool = (value, fallback, label) => {
    if (value === undefined) return fallback;
    if (typeof value === 'boolean') return value;
    if (strict) throw badRequest(`${label}必須是 true 或 false`);
    return fallback;
  };

  const out = clone(DEFAULTS);
  out.social_enabled = bool(src.social_enabled, out.social_enabled, '社群登入總開關');

  const providers = isObject(src.providers) ? src.providers : {};
  for (const id of PROVIDER_IDS) {
    const p = isObject(providers[id]) ? providers[id] : {};
    const target = out.providers[id];
    target.enabled = bool(p.enabled, target.enabled, `${PROVIDER_LABELS[id]}的啟用設定`);
    target.signup = bool(p.signup, target.signup, `${PROVIDER_LABELS[id]}的註冊設定`);
  }
  return out;
};

// 憑證缺少時一律視為不可用，不論管理員把開關設成什麼。
const isConfigured = (provider) => {
  if (FIREBASE_PROVIDERS.includes(provider)) return firebase.isConfigured();
  if (provider === 'line') return Boolean(env.lineChannelId && env.lineChannelSecret);
  if (provider === 'discord') return Boolean(env.discordClientId && env.discordClientSecret);
  return false;
};

let cache = null;

const clearCache = () => {
  cache = null;
};

const load = async () => {
  if (cache && Date.now() - cache.at < CACHE_MS) return cache.value;
  let value = normalize(null);
  const rows = await prisma.$queryRaw`SELECT config FROM auth_settings WHERE id = 1`;
  if (rows[0]?.config) {
    try {
      value = normalize(JSON.parse(String(rows[0].config)));
    } catch {
      value = normalize(null);
    }
  }
  cache = { value, at: Date.now() };
  return value;
};

const channelOf = async (provider) => {
  const settings = await load();
  const channel = settings.providers[provider];
  return {
    enabled: Boolean(settings.social_enabled && channel?.enabled && isConfigured(provider)),
    signup: Boolean(channel?.signup)
  };
};

// 登入、綁定都先過這一關；signup 另由呼叫端在確定要建立帳號時檢查。
const assertEnabled = async (provider) => {
  const channel = await channelOf(provider);
  if (!channel.enabled) throw disabled(provider);
  return channel;
};

const publicPayload = async () => {
  const settings = await load();
  return {
    social_enabled: settings.social_enabled,
    providers: PROVIDER_IDS.map((id) => ({
      id,
      enabled: Boolean(settings.social_enabled && settings.providers[id].enabled && isConfigured(id)),
      signup: Boolean(settings.providers[id].signup),
      configured: isConfigured(id)
    }))
  };
};

const providerList = () => PROVIDER_IDS.map((id) => ({
  id,
  name: PROVIDER_LABELS[id],
  configured: isConfigured(id)
}));

const changesOf = (before, after) => {
  const rows = [];
  if (before.social_enabled !== after.social_enabled) {
    rows.push({
      field: 'social_enabled',
      label: '社群登入總開關',
      from: audit.display(before.social_enabled),
      to: audit.display(after.social_enabled)
    });
  }
  for (const id of PROVIDER_IDS) {
    for (const [key, label] of [['enabled', '開關'], ['signup', '允許直接註冊']]) {
      if (before.providers[id][key] === after.providers[id][key]) continue;
      rows.push({
        field: `providers.${id}.${key}`,
        label: `${PROVIDER_LABELS[id]}${label}`,
        from: audit.display(before.providers[id][key]),
        to: audit.display(after.providers[id][key])
      });
    }
  }
  return rows;
};

const save = async (input, { adminId, req }) => {
  const next = normalize(input, { strict: true });
  clearCache();
  const before = await load();

  await prisma.$executeRaw`
    INSERT INTO auth_settings (id, config, updated_by, updated_at)
    VALUES (1, ${JSON.stringify(next)}, ${adminId}, ${new Date()})
    ON DUPLICATE KEY UPDATE config = VALUES(config), updated_by = VALUES(updated_by), updated_at = VALUES(updated_at)`;
  clearCache();

  const changes = changesOf(before, next);
  await audit.record(null, {
    adminId,
    action: '修改登入方式設定',
    summary: changes.length
      ? `修改登入方式設定：${changes.map((c) => c.label).join('、')}`
      : '重新儲存登入方式設定（無實際變更）',
    changes,
    req
  });
  return next;
};

module.exports = {
  PROVIDER_IDS, FIREBASE_PROVIDERS, OAUTH_PROVIDERS, PROVIDER_LABELS, DEFAULTS,
  normalize, load, save, clearCache, isConfigured, channelOf, assertEnabled,
  publicPayload, providerList, disabled
};
