const { env } = require('../../config/env');
const { AiProviderError, REASON_DETAILS, redact } = require('./http');
const deepseek = require('./deepseek');
const gemini = require('./gemini');
const openai = require('./openai');

const PROVIDERS = {
  deepseek: {
    id: 'deepseek',
    name: 'DeepSeek',
    vision: false,
    web_search: false,
    image_types: [],
    strict_schema: false,
    default_model: 'deepseek-flash',
    docs_url: 'https://api-docs.deepseek.com',
    envKey: 'deepseekApiKey',
    adapter: deepseek
  },
  gemini: {
    id: 'gemini',
    name: 'Google Gemini',
    vision: true,
    web_search: true,
    image_types: ['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif'],
    strict_schema: false,
    default_model: 'gemini-3.1-flash-lite',
    docs_url: 'https://ai.google.dev/gemini-api/docs',
    envKey: 'geminiApiKey',
    adapter: gemini
  },
  openai: {
    id: 'openai',
    name: 'OpenAI',
    vision: true,
    web_search: true,
    image_types: openai.IMAGE_TYPES,
    strict_schema: true,
    default_model: 'gpt-5-nano',
    docs_url: 'https://developers.openai.com/api/docs',
    envKey: 'openaiApiKey',
    adapter: openai
  }
};

const PROVIDER_IDS = Object.keys(PROVIDERS);
const VISION_ORDER = ['gemini', 'openai'];

const DEFAULT_TIMEOUT_MS = 20000;
const SEARCH_TIMEOUT_MS = 50000;

const apiKeyOf = (provider) => (PROVIDERS[provider] ? env[PROVIDERS[provider].envKey] || '' : '');
const keyConfigured = (provider) => Boolean(apiKeyOf(provider));

const round6 = (n) => Math.round(n * 1e6) / 1e6;

// input_tokens 含快取命中的部分，快取以較低單價計算。
const tokenCost = (usage, prices) => {
  const input = Math.max(0, Number(usage.input_tokens) || 0);
  const cached = Math.min(input, Math.max(0, Number(usage.cached_tokens) || 0));
  const output = Math.max(0, Number(usage.output_tokens) || 0);
  return ((input - cached) * prices.input_per_m + cached * prices.cached_input_per_m + output * prices.output_per_m) / 1e6;
};

const billableSearchCalls = (calls, usedThisMonth, freePerMonth) => {
  const free = Math.max(0, Number(freePerMonth) || 0);
  const used = Math.max(0, Number(usedThisMonth) || 0);
  const n = Math.max(0, Number(calls) || 0);
  return Math.max(0, used + n - free) - Math.max(0, used - free);
};

const costOf = (usage, prices, { searchUsedThisMonth = 0 } = {}) => {
  const searchCost = (billableSearchCalls(usage.search_calls, searchUsedThisMonth, prices.search_free_per_month)
    * (Number(prices.search_price_per_k) || 0)) / 1000;
  return round6(tokenCost(usage, prices) + searchCost);
};

// repaired：JSON 前後夾帶其他文字，截取大括號範圍後才解析成功。只去除 BOM 或程式碼區塊標記不算修復。
const parseJson = (text) => {
  if (typeof text !== 'string') return { json: null, repaired: false };
  const cleaned = text.replace(/^\uFEFF/, '').replace(/```(?:json)?/gi, '').trim();
  try {
    return { json: JSON.parse(cleaned), repaired: false };
  } catch {
    const start = cleaned.indexOf('{');
    const end = cleaned.lastIndexOf('}');
    if (start < 0 || end <= start) return { json: null, repaired: false };
    try {
      return { json: JSON.parse(cleaned.slice(start, end + 1)), repaired: true };
    } catch {
      return { json: null, repaired: false };
    }
  }
};

const extractJson = (text) => parseJson(text).json;

// 輸出被截斷時，找出最後一個完整的清單項目並補上結尾括號；只保留完整的項目，未寫完的欄位與項目一律捨棄。
// 清單指最外層的陣列：項目內還有陣列（例如標籤）時，只在清單本身的項目結束處切，寫到一半的項目不會因內層陣列完整而被保留。
const SALVAGE_TRIES = 50;
const CLOSERS = { '{': '}', '[': ']' };
const salvageJson = (text) => {
  if (typeof text !== 'string') return null;
  const cleaned = text.replace(/^\uFEFF/, '').replace(/```(?:json)?/gi, '');
  const start = cleaned.indexOf('{');
  if (start < 0) return null;
  const s = cleaned.slice(start);
  const stack = [];
  const cuts = [];
  let inString = false;
  let escaped = false;
  const mark = (end) => {
    if (stack[stack.length - 1] === '[' && stack.indexOf('[') === stack.length - 1) {
      cuts.push({ end, closers: stack.map((c) => CLOSERS[c]).reverse().join('') });
    }
  };
  for (let i = 0; i < s.length; i += 1) {
    const ch = s[i];
    if (inString) {
      if (escaped) escaped = false;
      else if (ch === '\\') escaped = true;
      else if (ch === '"') {
        inString = false;
        mark(i + 1);
      }
      continue;
    }
    if (ch === '"') inString = true;
    else if (ch === '{' || ch === '[') stack.push(ch);
    else if (ch === '}' || ch === ']') {
      stack.pop();
      if (stack.length === 0) return null;
      mark(i + 1);
    }
  }
  for (const cut of cuts.slice(-SALVAGE_TRIES).reverse()) {
    try {
      const json = JSON.parse(`${s.slice(0, cut.end)}${cut.closers}`);
      if (json && typeof json === 'object' && !Array.isArray(json)) return json;
    } catch {
    }
  }
  return null;
};

// 依服務商能接受的圖片格式分成實際送出與略過兩組；提示詞中的張數必須以 sent 計算。
const imagesFor = (provider, images = []) => {
  const types = PROVIDERS[provider]?.vision ? PROVIDERS[provider].image_types : [];
  const sent = [];
  const skipped = [];
  for (const img of images) (types.includes(img?.mimeType) ? sent : skipped).push(img);
  return { sent, skipped };
};

const generate = async (provider, options) => {
  const spec = PROVIDERS[provider];
  if (!spec) throw new AiProviderError('BAD_REQUEST', { provider });
  const apiKey = options.apiKey ?? apiKeyOf(provider);
  if (!apiKey) throw new AiProviderError('NOT_CONFIGURED', { provider });

  const search = Boolean(options.search) && spec.web_search;
  const { sent: images } = imagesFor(provider, options.images ?? []);
  const timeoutMs = options.timeoutMs ?? (search ? SEARCH_TIMEOUT_MS : DEFAULT_TIMEOUT_MS);

  const started = Date.now();
  let result;
  try {
    result = await spec.adapter.generate({ ...options, apiKey, search, images, timeoutMs });
  } catch (err) {
    if (err && typeof err === 'object' && err.latency_ms == null) err.latency_ms = Date.now() - started;
    throw err;
  }
  const latencyMs = Date.now() - started;

  let json;
  let repaired = false;
  let salvaged = false;
  if (options.json) {
    ({ json, repaired } = parseJson(result.text));
    // salvage：呼叫端的輸出是可截短的清單（例如推薦），截斷時保留完整的項目。
    if (!json && result.truncated && options.salvage) {
      json = salvageJson(result.text);
      salvaged = Boolean(json);
    }
    if (!json || typeof json !== 'object' || Array.isArray(json)) {
      // 只記長度與結束原因：輸出可能夾帶使用者內容，錯誤細節會顯示在後台。
      const err = new AiProviderError(result.truncated ? 'INCOMPLETE' : 'INVALID_OUTPUT', {
        provider,
        providerMessage: `輸出 ${String(result.text ?? '').length} 字，結束原因 ${result.finish_reason || '未提供'}`
      });
      err.usage = result.usage;
      err.latency_ms = latencyMs;
      throw err;
    }
  }
  return {
    ...result, ...(options.json && { json }), ...((repaired || salvaged) && { repaired: true }), ...(salvaged && { salvaged: true }), latency_ms: latencyMs
  };
};

const moderate = (options) => openai.moderate({ ...options, apiKey: options.apiKey ?? apiKeyOf('openai') });

module.exports = {
  PROVIDERS, PROVIDER_IDS, VISION_ORDER, DEFAULT_TIMEOUT_MS, SEARCH_TIMEOUT_MS, REASON_DETAILS, AiProviderError,
  redact, apiKeyOf, keyConfigured, tokenCost, billableSearchCalls, costOf, extractJson, salvageJson, imagesFor, generate, moderate
};
