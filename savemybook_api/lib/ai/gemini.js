const { AiProviderError, postJson, baseClassify, errorText } = require('./http');

const BASE = 'https://generativelanguage.googleapis.com/v1beta';

const classify = (status, data) => {
  const text = errorText(data);
  if (text.includes('api key not valid') || text.includes('api_key_invalid') || text.includes('permission_denied')) return 'AUTH';
  if (status === 404 || (text.includes('model') && text.includes('not found'))) return 'MODEL_NOT_FOUND';
  if (status === 429 && text.includes('quota')) return 'RATE_LIMITED';
  return baseClassify(status);
};

const generate = async ({ apiKey, model, system, history = [], prompt, images = [], json, search, maxOutputTokens, timeoutMs }) => {
  const modelId = String(model).replace(/^models\//, '');
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
      ...(maxOutputTokens && { maxOutputTokens }),
      ...(json && !search && { responseMimeType: 'application/json' })
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
