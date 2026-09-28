const { HttpError } = require('../../lib/errors');
const ai = require('../../lib/ai');
const settingsService = require('./settings');
const usage = require('./usage');
const consent = require('./consent');
const semantic = require('./semantic');
const { EMBEDDING_FEATURES } = require('./disclosures');

const STATUS_CACHE_MS = 30 * 1000;
const BILLED_FAILURE_LIMIT = 10;

const clipMessage = (err) => ai.redact(err?.message ?? '') || null;

const errors = {
  disabled: () => new HttpError(503, 'AI 功能目前未開放', 'AI_DISABLED'),
  budget: () => new HttpError(503, 'AI 功能本月用量已達上限，請稍後再試', 'AI_BUDGET_EXCEEDED'),
  daily: () => new HttpError(429, '今日 AI 使用次數已達上限，請明日再試', 'AI_DAILY_LIMIT'),
  notConfigured: () => new HttpError(503, 'AI 服務尚未完成設定', 'AI_NOT_CONFIGURED')
};

const providerFor = (settings, feature) => settings.features[feature]?.provider ?? settings.default_provider;

const visionProvider = (provider) => {
  if (ai.PROVIDERS[provider]?.vision) return provider;
  return ai.VISION_ORDER.find((id) => ai.keyConfigured(id)) ?? provider;
};

// 回傳 null 代表可用，否則為對應的錯誤建構函式名稱。
const blocker = async (settings, feature) => {
  if (!settings.enabled || !settings.features[feature]?.enabled) return 'disabled';
  if (!ai.keyConfigured(providerFor(settings, feature))) return 'notConfigured';
  if (await usage.budgetExceeded(settings)) return 'budget';
  return null;
};

const access = async (feature, { needsVision = false } = {}) => {
  const settings = await settingsService.load();
  const problem = await blocker(settings, feature);
  if (problem) throw errors[problem]();
  const base = providerFor(settings, feature);
  const provider = needsVision ? visionProvider(base) : base;
  return { settings, provider };
};

// 每日次數只計成功的呼叫；已計費的失敗另設上限，避免反覆觸發失敗而無限制地產生費用。
const assertDailyLimit = async (settings, feature, userId) => {
  const limit = Number(settings.limits.daily_per_user[feature] ?? 0);
  if (!limit || !userId) return;
  if ((await usage.dailyCount(userId, feature)) >= limit) throw errors.daily();
  if ((await usage.billedFailureCount(userId, feature)) >= BILLED_FAILURE_LIMIT) throw errors.daily();
};

const call = async (feature, { settings, provider, userId = null, ...options }) => {
  const prices = settings.providers[provider];
  const model = prices.model;
  const search = Boolean(options.search) && ai.PROVIDERS[provider].web_search;
  const started = Date.now();
  let searchUsedThisMonth = 0;
  try {
    searchUsedThisMonth = search && prices.search_free_per_month > 0 ? await usage.monthSearchCalls(provider) : 0;
    const result = await ai.generate(provider, { ...options, search, model });
    const costUsd = ai.costOf(result.usage, prices, { searchUsedThisMonth });
    await usage.log({ feature, provider, model, userId, usage: result.usage, costUsd, latencyMs: result.latency_ms });
    return { ...result, provider, model, cost_usd: costUsd };
  } catch (err) {
    const partial = err.usage ? ai.costOf(err.usage, prices, { searchUsedThisMonth }) : 0;
    await usage.log({
      feature,
      provider,
      model,
      userId,
      usage: err.usage ?? {},
      costUsd: partial,
      latencyMs: err.latency_ms ?? Date.now() - started,
      status: 'error',
      errorCode: err instanceof ai.AiProviderError ? err.reason : 'INTERNAL',
      errorDetail: err instanceof ai.AiProviderError ? err.providerMessage || null : clipMessage(err)
    });
    if (err instanceof ai.AiProviderError) throw err;
    console.error(`[AI 呼叫失敗：${feature}]`, err);
    throw new ai.AiProviderError('SERVER', { provider });
  }
};

let statusCache = null;

const clearCache = () => {
  statusCache = null;
  settingsService.clearCache();
};

const USER_FEATURES = ['support', 'listing_assist', 'recommend', 'book_chat'];

const featureStatus = async () => {
  if (statusCache && Date.now() - statusCache.at < STATUS_CACHE_MS) return statusCache.value;
  const value = { support: false, listing_assist: false, recommend: false, book_chat: false, web_search: false };
  const used = new Set();
  const settings = await settingsService.load();
  for (const feature of USER_FEATURES) {
    value[feature] = (await blocker(settings, feature)) === null;
    if (!value[feature]) continue;
    const base = providerFor(settings, feature);
    used.add(base);
    if (feature === 'listing_assist') used.add(visionProvider(base));
  }
  value.web_search = value.listing_assist
    && settings.features.listing_assist.web_search
    && ai.PROVIDERS[providerFor(settings, 'listing_assist')].web_search;
  const embedding = EMBEDDING_FEATURES.some((f) => value[f]) ? semantic.profile() : null;
  if (embedding) used.add(embedding.provider);
  const providers = ai.PROVIDER_IDS.filter((id) => used.has(id)).map((id) => ai.PROVIDERS[id].name);
  statusCache = {
    value: { ...value, providers_in_use: providers, embedding_provider: embedding ? ai.PROVIDERS[embedding.provider].name : null },
    at: Date.now()
  };
  return statusCache.value;
};

const status = async (userId) => {
  const { granted, outdated } = await consent.stateOf(userId);
  return { ...(await featureStatus()), consented: granted, consent_outdated: outdated };
};

module.exports = {
  USER_FEATURES, BILLED_FAILURE_LIMIT, errors, providerFor, visionProvider, blocker, access, assertDailyLimit, call, status, clearCache
};
