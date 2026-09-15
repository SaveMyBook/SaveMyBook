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

const extractJson = (text) => {
  if (typeof text !== 'string') return null;
  const cleaned = text.replace(/^\uFEFF/, '').replace(/```(?:json)?/gi, '').trim();
  try {
    return JSON.parse(cleaned);
  } catch {
    const start = cleaned.indexOf('{');
    const end = cleaned.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      return JSON.parse(cleaned.slice(start, end + 1));
    } catch {
      return null;
    }
  }
};

const generate = async (provider, options) => {
  const spec = PROVIDERS[provider];
  if (!spec) throw new AiProviderError('BAD_REQUEST', { provider });
  const apiKey = options.apiKey ?? apiKeyOf(provider);
  if (!apiKey) throw new AiProviderError('NOT_CONFIGURED', { provider });

  const search = Boolean(options.search) && spec.web_search;
  const images = spec.vision ? options.images ?? [] : [];
  const timeoutMs = options.timeoutMs ?? (search ? SEARCH_TIMEOUT_MS : DEFAULT_TIMEOUT_MS);

  const started = Date.now();
  const result = await spec.adapter.generate({ ...options, apiKey, search, images, timeoutMs });
  const latencyMs = Date.now() - started;

  let json;
  if (options.json) {
    json = extractJson(result.text);
    if (!json || typeof json !== 'object' || Array.isArray(json)) {
      const err = new AiProviderError('INVALID_OUTPUT', { provider });
      err.usage = result.usage;
      err.latency_ms = latencyMs;
      throw err;
    }
  }
  return { ...result, ...(options.json && { json }), latency_ms: latencyMs };
};

const moderate = (options) => openai.moderate({ ...options, apiKey: options.apiKey ?? apiKeyOf('openai') });

module.exports = {
  PROVIDERS, PROVIDER_IDS, VISION_ORDER, DEFAULT_TIMEOUT_MS, SEARCH_TIMEOUT_MS, REASON_DETAILS, AiProviderError,
  redact, apiKeyOf, keyConfigured, tokenCost, billableSearchCalls, costOf, extractJson, generate, moderate
};
