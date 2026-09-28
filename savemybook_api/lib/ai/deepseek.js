const { AiProviderError, postJson, baseClassify, errorText, quotaExhausted, withUsage } = require('./http');

const BASE = 'https://api.deepseek.com';

const classify = (status, data) => {
  const text = errorText(data);
  if (status === 402 || text.includes('insufficient balance') || quotaExhausted(text)) return 'QUOTA';
  if (text.includes('model not exist') || text.includes('model_not_found')) return 'MODEL_NOT_FOUND';
  if (text.includes('authentication') || text.includes('api key')) return status >= 500 ? 'SERVER' : 'AUTH';
  return baseClassify(status);
};

// DeepSeek 的 json_object 格式要求提示詞出現 "json" 字樣，否則回傳 400。
const generate = async ({ apiKey, model, system, history = [], prompt, json, maxOutputTokens, timeoutMs, temperature }) => {
  const body = {
    model,
    messages: [
      ...(system ? [{ role: 'system', content: system }] : []),
      ...history.map((m) => ({ role: m.role === 'assistant' ? 'assistant' : 'user', content: m.content })),
      { role: 'user', content: json && !/json/i.test(`${system ?? ''}${prompt}`) ? `${prompt}\n\n請只輸出一個 JSON 物件。` : prompt }
    ],
    ...(json && { response_format: { type: 'json_object' } }),
    ...(maxOutputTokens && { max_tokens: maxOutputTokens }),
    ...(temperature !== undefined && { temperature }),
    stream: false
  };

  const data = await postJson(`${BASE}/chat/completions`, {
    headers: { authorization: `Bearer ${apiKey}` },
    body,
    timeoutMs,
    classify,
    provider: 'deepseek'
  });
  const meta = data?.usage ?? {};
  const usage = {
    input_tokens: Number(meta.prompt_tokens) || 0,
    cached_tokens: Number(meta.prompt_cache_hit_tokens) || 0,
    output_tokens: Number(meta.completion_tokens) || 0,
    search_calls: 0
  };
  const choice = data?.choices?.[0];
  const finish = String(choice?.finish_reason ?? '');
  const text = typeof choice?.message?.content === 'string' ? choice.message.content : '';
  if (finish === 'content_filter') {
    throw withUsage(new AiProviderError('BLOCKED', { provider: 'deepseek', providerMessage: 'finish_reason content_filter' }), usage);
  }
  if (finish === 'length' && !text.trim()) {
    throw withUsage(new AiProviderError('INCOMPLETE', { provider: 'deepseek', providerMessage: 'finish_reason length' }), usage);
  }
  return { text, sources: [], model, usage, finish_reason: finish, truncated: finish === 'length' };
};

module.exports = { generate, classify };
