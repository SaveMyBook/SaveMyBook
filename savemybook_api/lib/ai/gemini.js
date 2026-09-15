const { AiProviderError, postJson, baseClassify, errorText, quotaExhausted } = require('./http');

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

const generate = async (options) => {
  try {
    return await generateOnce(options, true);
  } catch (err) {
    const modelId = String(options.model).replace(/^models\//, '');
    if (!(err instanceof AiProviderError) || err.reason !== 'BAD_REQUEST' || !levelModel(modelId)) throw err;
    if (!/thinking/i.test(err.providerMessage)) throw err;
    return generateOnce(options, false);
  }
};

const generateOnce = async ({ apiKey, model, system, history = [], prompt, images = [], json, search, maxOutputTokens, timeoutMs }, withThinkingLevel) => {
  const modelId = String(model).replace(/^models\//, '');
  const thinks = thinkingModel(modelId);
  const levelSupported = levelModel(modelId);
  withThinkingLevel = withThinkingLevel && levelSupported;
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
      ...(thinks && withThinkingLevel && { thinkingConfig: { thinkingLevel: search ? 'low' : 'minimal' } })
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
  if (!candidate && data?.promptFeedback?.blockReason) throw new AiProviderError('BLOCKED', { provider: 'gemini' });
  if (candidate?.finishReason === 'SAFETY' || candidate?.finishReason === 'PROHIBITED_CONTENT') {
    throw new AiProviderError('BLOCKED', { provider: 'gemini' });
  }
  const text = (candidate?.content?.parts ?? [])
    .filter((p) => typeof p?.text === 'string' && !p.thought)
    .map((p) => p.text)
    .join('');
  if (!text.trim() && candidate?.finishReason === 'MAX_TOKENS') {
    throw new AiProviderError('INCOMPLETE', { provider: 'gemini', providerMessage: 'finishReason MAX_TOKENS' });
  }
  const grounding = candidate?.groundingMetadata ?? {};
  const sources = (grounding.groundingChunks ?? [])
    .map((c) => c?.web)
    .filter((w) => w && typeof w.uri === 'string')
    .map((w) => ({ title: w.title ?? '', url: w.uri }));
  const queries = Array.isArray(grounding.webSearchQueries) ? grounding.webSearchQueries.filter((q) => String(q ?? '').trim()) : [];
  const usage = data?.usageMetadata ?? {};

  return {
    text,
    sources,
    model: modelId,
    usage: {
      input_tokens: Number(usage.promptTokenCount) || 0,
      cached_tokens: Number(usage.cachedContentTokenCount) || 0,
      output_tokens: (Number(usage.candidatesTokenCount) || 0) + (Number(usage.thoughtsTokenCount) || 0),
      search_calls: search ? queries.length : 0
    }
  };
};

module.exports = { generate, classify };
