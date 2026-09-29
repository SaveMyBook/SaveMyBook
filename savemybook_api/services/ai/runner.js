const { HttpError } = require('../../lib/errors');
const { clip } = require('../../lib/text');
const ai = require('../../lib/ai');
const schemas = require('../../lib/ai/schema');
const settingsService = require('./settings');
const usage = require('./usage');
const consent = require('./consent');
const semantic = require('./semantic');
const breaker = require('./breaker');
const traces = require('./trace');
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
  if (await usage.budgetExceeded(settings, feature)) return 'budget';
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
// excused：已計入其他呼叫、不應再扣次數的成功紀錄筆數（例如上架輔助以權杖折抵的第二步）。
// successes: false 只檢查已計費失敗：權杖只免除成功次數，不能用來繞過失敗上限。
const assertDailyLimit = async (settings, feature, userId, { excused = 0, successes = true } = {}) => {
  const limit = Number(settings.limits.daily_per_user[feature] ?? 0);
  if (!limit || !userId) return;
  if (successes && (await usage.dailyCount(userId, feature)) - excused >= limit) throw errors.daily();
  if ((await usage.billedFailureCount(userId, feature)) >= BILLED_FAILURE_LIMIT) throw errors.daily();
};

const SETTINGS_FEATURE = { book_chat_pick: 'book_chat' };
// 內容或輸出格式造成的失敗換服務商也不一定能解決，只有服務中斷或設定問題才改用備援。
const NO_FAILOVER = new Set(['BLOCKED', 'INVALID_OUTPUT', 'INCOMPLETE']);

// needsSearch：提示詞已依主要服務商寫明可搜尋並要求列出參考網頁，交給不能搜尋的備援會讓模型自行編造來源。
// imageTypes：提示詞的照片張數依主要服務商能接受的格式計算，備援必須能接受同樣的格式，否則張數與實際送出的不符。
const fallbackFor = (settings, feature, provider, { needsVision = false, needsSearch = false, imageTypes = [] } = {}) => {
  const id = settings.features[SETTINGS_FEATURE[feature] ?? feature]?.fallback_provider;
  if (!id || id === provider || !ai.keyConfigured(id)) return null;
  if (needsVision && !ai.PROVIDERS[id].vision) return null;
  if (imageTypes.some((type) => !ai.PROVIDERS[id].image_types.includes(type))) return null;
  return needsSearch && !ai.PROVIDERS[id].web_search ? null : id;
};

// 沒有送出請求的失敗（時間不足、斷路器暫停）也記一筆零費用的錯誤，後台才看得出降級的頻率；
// 處理結果記為 not_sent，格式錯誤比例的分母才不會算進沒有送出的呼叫。
const notSent = async (feature, { settings, provider, userId, requestId, promptVersion }, reason, detail) => {
  await usage.log({
    feature, provider, model: settings.providers[provider].model, userId, status: 'error', errorCode: reason, errorDetail: detail, requestId, promptVersion,
    outcome: traces.NOT_SENT
  });
  const err = new ai.AiProviderError(reason, { provider, providerMessage: detail });
  err.notSent = true;
  return err;
};

const problemOf = (problem) => (typeof problem === 'string' ? { detail: problem, outcome: 'failed' } : problem);

const FORMAT_DETAIL_MAX = 300;

// 規格驗證失敗時的錯誤：描述只列欄位路徑，repair 重試時原樣附在提示詞中請模型修正。
const formatError = (provider, result, problems) => {
  const err = new ai.AiProviderError('INVALID_OUTPUT', { provider, providerMessage: clip(`格式不符：${problems.join('；')}`, FORMAT_DETAIL_MAX) });
  err.usage = result.usage;
  err.latency_ms = result.latency_ms;
  err.formatProblems = problems;
  err.format = result.format;
  return err;
};

const formatOf = (stats) => ({ dropped: stats.dropped, defaulted: stats.defaulted, truncated: stats.truncated, dropped_in: { ...stats.dropped_in } });

const callOnce = async (feature, provider, { settings, userId, deadline, reserve, validate, assess, schema, options, tracked, requestId, promptVersion }) => {
  const trail = { requestId, promptVersion };
  const prices = settings.providers[provider];
  const model = prices.model;
  const search = Boolean(options.search) && ai.PROVIDERS[provider].web_search;
  // 搜尋時服務商不接受 JSON 格式參數，只能寬鬆解析後由 check() 驗證。
  const strict = schema && ai.PROVIDERS[provider].strict_schema && !search ? schema.strict : null;
  const cap = options.timeoutMs ?? (search ? ai.SEARCH_TIMEOUT_MS : ai.DEFAULT_TIMEOUT_MS);
  const timeoutMs = deadline ? deadline.budget({ reserve, cap }) : options.timeoutMs;
  if (deadline && !timeoutMs) throw await notSent(feature, { settings, provider, userId, ...trail }, 'TIMEOUT', '剩餘時間不足，未送出請求');
  const started = Date.now();
  let searchUsedThisMonth = 0;
  try {
    searchUsedThisMonth = search && prices.search_free_per_month > 0 ? await usage.monthSearchCalls(provider) : 0;
    const result = await ai.generate(provider, {
      ...options, ...(schema && { json: true }), schema: strict ?? undefined, search, model, ...(timeoutMs && { timeoutMs })
    });
    if (tracked) breaker.succeeded(provider);
    if (schema) {
      const checked = schemas.check(schema, result.json);
      result.format = formatOf(checked.stats);
      if (checked.problems.length > 0) throw formatError(provider, result, checked.problems);
      result.json = checked.value;
    }
    // 驗證在記錄用量前執行：清理後沒有可用內容的回應記為錯誤，不計入每日次數。
    const problem = validate ? validate(result) : null;
    if (problem) {
      const { detail, outcome } = problemOf(problem);
      const err = new ai.AiProviderError('INVALID_OUTPUT', { provider, providerMessage: detail });
      err.usage = result.usage;
      err.latency_ms = result.latency_ms;
      err.outcome = outcome;
      err.formatProblems = [detail];
      err.format = result.format;
      throw err;
    }
    const outcome = (assess ? assess(result) : null)?.outcome ?? (result.repaired ? 'repaired' : 'ok');
    const costUsd = ai.costOf(result.usage, prices, { searchUsedThisMonth });
    await usage.log({ feature, provider, model, userId, usage: result.usage, costUsd, latencyMs: result.latency_ms, outcome, format: result.format, ...trail });
    return { ...result, provider, model, cost_usd: costUsd, outcome };
  } catch (err) {
    if (tracked) breaker.failed(provider, err, { timeoutMs: timeoutMs ?? null });
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
      errorDetail: err instanceof ai.AiProviderError ? err.providerMessage || null : clipMessage(err),
      outcome: err.outcome ?? traces.outcomeOfError(err),
      format: err.format,
      ...trail
    });
    if (err instanceof ai.AiProviderError) throw err;
    console.error(`[AI 呼叫失敗：${feature}]`, err);
    throw new ai.AiProviderError('SERVER', { provider });
  }
};

const REPAIR_NOTE = '【格式修正】上一次的輸出不符合規定的格式';
const REPAIR_ASK = '請依規定的欄位與型別，重新輸出一個完整的 JSON 物件，不要加入其他文字。';

// 錯誤說明只來自我方的驗證描述，不回填模型輸出的內容。
const repairNote = (err) => (err.formatProblems?.length
  ? `${REPAIR_NOTE}：${clip(err.formatProblems.join('；'), FORMAT_DETAIL_MAX)}。${REPAIR_ASK}`
  : `${REPAIR_NOTE}，不是有效的 JSON 物件。${REPAIR_ASK}`);

// deadline（deadline.js）：以剩餘時間作為本次呼叫的逾時，不足時不送出請求。reserve 為呼叫後仍要保留的時間。
// schema（lib/ai/schema.js 的 define()）：支援嚴格模式的服務商由服務商保證格式，所有服務商的輸出都再經 check() 驗證，
//   json 改為規格整理後的內容；缺少必要欄位或型別不符時視為 INVALID_OUTPUT。
//   result.format 為 check() 的統計（捨棄的項目、改用預設值的欄位），會寫入用量紀錄；
//   清單項目全部被捨棄時 json 會是空陣列，與模型真的回傳空陣列無從分辨，須在 validate 以 schema.allDropped() 判斷。
// validate(result)：回傳問題描述字串時視為輸出格式錯誤；清理後沒有內容這類非格式問題回傳 { detail, outcome: 'empty' }，
//   不計入格式錯誤比例。描述只寫我方判斷，不得夾帶模型輸出。
// assess(result)：輸出可用但呼叫端會改用降級內容時回傳 { outcome: 'degraded' }，只影響用量紀錄的處理結果，仍計入每日次數。
// repair：互動功能使用。輸出格式錯誤且剩餘時間足夠時，附上錯誤說明向同一服務商重試一次，成功時處理結果記為 repaired。
const call = async (feature, {
  settings, provider, userId = null, deadline = null, reserve, validate = null, assess = null, schema = null, repair = false,
  trace = null, promptVersion = null, ...options
}) => {
  // 管理員的連線測試可指定尚未儲存的模型，不受暫停影響，結果也不能影響正式流量的斷路器。
  const tracked = feature !== 'test';
  const requestId = trace?.id ?? traces.newRequestId();
  // 提示詞的照片張數依主要服務商實際送出的照片計算；先過濾好再交給兩家，備援能接受更多格式時也只送同一組照片。
  const images = options.images ? ai.imagesFor(provider, options.images).sent : undefined;
  const sentOptions = images ? { ...options, images } : options;
  const context = { settings, userId, deadline, reserve, validate, assess, schema, options: sentOptions, tracked, requestId, promptVersion };
  const backup = fallbackFor(settings, feature, provider, {
    needsVision: (images?.length ?? 0) > 0,
    needsSearch: Boolean(options.search) && ai.PROVIDERS[provider].web_search,
    imageTypes: [...new Set((images ?? []).map((img) => img.mimeType))]
  });
  // 剩餘時間不足時由 callOnce 記錄未送出，不佔用暫停期滿後的探測名額。
  const hasTime = () => !deadline || deadline.budget({ reserve }) > 0;
  const backupAdmitted = () => Boolean(backup) && hasTime() && breaker.admit(backup);
  const attempt = async () => {
    if (tracked && hasTime() && !breaker.admit(provider)) {
      if (backupAdmitted()) return callOnce(feature, backup, context);
      throw await notSent(feature, { settings, provider, userId, requestId, promptVersion }, 'SERVER', '服務商連續失敗，暫停呼叫');
    }
    try {
      return await callOnce(feature, provider, context);
    } catch (err) {
      if (err.notSent || !(err instanceof ai.AiProviderError) || NO_FAILOVER.has(err.reason) || !backupAdmitted()) throw err;
      return callOnce(feature, backup, context);
    }
  };
  try {
    return await attempt();
  } catch (err) {
    if (!repair || err.notSent || !(err instanceof ai.AiProviderError) || err.reason !== 'INVALID_OUTPUT' || !hasTime()) throw err;
    const failed = settings.providers[err.provider] ? err.provider : provider;
    return callOnce(feature, failed, {
      ...context,
      options: { ...sentOptions, prompt: `${options.prompt ?? ''}\n\n${repairNote(err)}` },
      assess: (result) => (assess ? assess(result) : null) ?? { outcome: 'repaired' }
    });
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
    const backup = fallbackFor(settings, feature, base);
    if (backup) used.add(backup);
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
  USER_FEATURES, BILLED_FAILURE_LIMIT, REPAIR_NOTE, errors, providerFor, visionProvider, fallbackFor, blocker, access, assertDailyLimit, call, status, clearCache
};
