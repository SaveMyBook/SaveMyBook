const { AiProviderError, postJson, baseClassify, errorText, quotaExhausted, withUsage } = require('./http');

const BASE = 'https://generativelanguage.googleapis.com/v1beta';

const classify = (status, data) => {
  const text = errorText(data);
  if (text.includes('api key not valid') || text.includes('api_key_invalid') || text.includes('permission_denied')) return 'AUTH';
  if (status === 404 || (text.includes('model') && text.includes('not found'))) return 'MODEL_NOT_FOUND';
  if (status === 429 && quotaExhausted(text)) return 'QUOTA';
  return baseClassify(status);
};

// Gemini 2.5 之後的模型預設會思考，思考 token 計入 maxOutputTokens，額度不足時只會回傳空白內容。
const THINKING_HEADROOM = 2048;
const thinkingModel = (modelId) => /^gemini-(2\.5|[3-9])/.test(modelId);
const levelModel = (modelId) => /^gemini-[3-9]/.test(modelId);
const BLOCK_FINISH = new Set(['SAFETY', 'PROHIBITED_CONTENT', 'BLOCKLIST', 'SPII', 'IMAGE_SAFETY']);
const MEDIA_RESOLUTIONS = { low: 'MEDIA_RESOLUTION_LOW', high: 'MEDIA_RESOLUTION_HIGH' };
const DOMAIN = /^(?:[a-z0-9-]+\.)+[a-z]{2,}$/i;

// 部分模型不接受思考等級或解析度參數，服務商回報時拿掉該參數重送一次。
const generate = async (options) => {
  let flags = { thinkingLevel: true, mediaResolution: true };
  const started = Date.now();
  for (;;) {
    try {
      // 重送共用同一個時限，否則呼叫端依剩餘時間算出的逾時會被放大。
      const timeoutMs = options.timeoutMs ? Math.max(1, options.timeoutMs - (Date.now() - started)) : options.timeoutMs;
      return await generateOnce({ ...options, timeoutMs }, flags);
    } catch (err) {
      if (!(err instanceof AiProviderError) || err.reason !== 'BAD_REQUEST') throw err;
      const message = String(err.providerMessage ?? '');
      const modelId = String(options.model).replace(/^models\//, '');
      if (flags.thinkingLevel && levelModel(modelId) && /thinking/i.test(message)) flags = { ...flags, thinkingLevel: false };
      else if (flags.mediaResolution && options.imageDetail && /media.?resolution/i.test(message)) flags = { ...flags, mediaResolution: false };
      else throw err;
    }
  }
};

const generateOnce = async (
  { apiKey, model, system, history = [], prompt, images = [], imageDetail, json, search, reasoning, maxOutputTokens, timeoutMs },
  flags
) => {
  const modelId = String(model).replace(/^models\//, '');
  const thinks = thinkingModel(modelId);
  const withThinkingLevel = flags.thinkingLevel && levelModel(modelId);
  const mediaResolution = flags.mediaResolution && images.length > 0 ? MEDIA_RESOLUTIONS[imageDetail] : undefined;
  // Gemini 3 官方建議維持預設 temperature，調低容易造成重複輸出，因此不傳 temperature。
  // 部分 Gemini 版本不允許 google_search 與 JSON 回應格式並用，搜尋時改由提示詞要求 JSON 並寬鬆解析。
  const body = {
    ...(system && { systemInstruction: { parts: [{ text: system }] } }),
    contents: [
      ...history.map((m) => ({ role: m.role === 'assistant' ? 'model' : 'user', parts: [{ text: m.content }] })),
      {
        role: 'user',
        parts: [
          { text: prompt },
          ...images.map((img) => ({ inlineData: { mimeType: img.mimeType, data: img.data } }))
        ]
      }
    ],
    generationConfig: {
      ...(maxOutputTokens && { maxOutputTokens: maxOutputTokens + (thinks ? THINKING_HEADROOM : 0) }),
      ...(json && !search && { responseMimeType: 'application/json' }),
      ...(mediaResolution && { mediaResolution }),
      ...(thinks && withThinkingLevel && { thinkingConfig: { thinkingLevel: reasoning ?? (search ? 'low' : 'minimal') } })
    },
    ...(search && { tools: [{ google_search: {} }] })
  };

  const data = await postJson(`${BASE}/models/${modelId}:generateContent`, {
    headers: { 'x-goog-api-key': apiKey },
    body,
    timeoutMs,
    classify,
    provider: 'gemini'
  });

  const candidate = data?.candidates?.[0];
  const finish = candidate?.finishReason ?? '';
  const grounding = candidate?.groundingMetadata ?? {};
  const queries = Array.isArray(grounding.webSearchQueries) ? grounding.webSearchQueries.filter((q) => String(q ?? '').trim()) : [];
  const meta = data?.usageMetadata ?? {};
  const usage = {
    input_tokens: Number(meta.promptTokenCount) || 0,
    cached_tokens: Number(meta.cachedContentTokenCount) || 0,
    output_tokens: (Number(meta.candidatesTokenCount) || 0) + (Number(meta.thoughtsTokenCount) || 0),
    search_calls: search ? queries.length : 0
  };

  if (!candidate && data?.promptFeedback?.blockReason) {
    throw withUsage(new AiProviderError('BLOCKED', { provider: 'gemini', providerMessage: `blockReason ${data.promptFeedback.blockReason}` }), usage);
  }
  if (BLOCK_FINISH.has(finish)) {
    throw withUsage(new AiProviderError('BLOCKED', { provider: 'gemini', providerMessage: `finishReason ${finish}` }), usage);
  }
  const text = (candidate?.content?.parts ?? [])
    .filter((p) => typeof p?.text === 'string' && !p.thought)
    .map((p) => p.text)
    .join('');
  if (!text.trim() && finish === 'MAX_TOKENS') {
    throw withUsage(new AiProviderError('INCOMPLETE', { provider: 'gemini', providerMessage: 'finishReason MAX_TOKENS' }), usage);
  }
  // 引用網址是 Google 的轉址連結，實際網站的網域只出現在 title。
  const sources = (grounding.groundingChunks ?? [])
    .map((c) => c?.web)
    .filter((w) => w && typeof w.uri === 'string')
    .map((w) => {
      const title = String(w.title ?? '').trim();
      return { title, url: w.uri, domain: DOMAIN.test(title) ? title.toLowerCase() : '' };
    });

  return { text, sources, model: modelId, usage, finish_reason: finish, truncated: finish === 'MAX_TOKENS' };
};

module.exports = { generate, classify };
