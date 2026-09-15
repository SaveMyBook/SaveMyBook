const { AiProviderError, postJson, baseClassify, errorText } = require('./http');

const BASE = 'https://api.openai.com/v1';
const IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];
const MODERATION_MODEL = 'omni-moderation-latest';

const classify = (status, data) => {
  const text = errorText(data);
  if (text.includes('insufficient_quota') || text.includes('billing')) return 'QUOTA';
  if (text.includes('model_not_found') || (status === 404 && text.includes('model'))) return 'MODEL_NOT_FOUND';
  if (status === 400 && text.includes('model') && text.includes('does not exist')) return 'MODEL_NOT_FOUND';
  if (text.includes('invalid_api_key') || text.includes('incorrect api key')) return 'AUTH';
  return baseClassify(status);
};

const headers = (apiKey) => ({ authorization: `Bearer ${apiKey}` });

const userContent = (prompt, images) => [
  { type: 'input_text', text: prompt },
  ...images
    .filter((img) => IMAGE_TYPES.includes(img.mimeType))
    .map((img) => ({ type: 'input_image', image_url: `data:${img.mimeType};base64,${img.data}` }))
];

const textFormat = ({ json, schema }) => {
  if (!json) return undefined;
  if (schema) return { format: { type: 'json_schema', name: schema.name, schema: schema.schema, strict: true } };
  return { format: { type: 'json_object' } };
};

const parseOutput = (data) => {
  const parts = [];
  const sources = [];
  let searchCalls = 0;
  for (const item of Array.isArray(data?.output) ? data.output : []) {
    if (item?.type === 'web_search_call') searchCalls += 1;
    if (item?.type !== 'message' || !Array.isArray(item.content)) continue;
    for (const c of item.content) {
      if (c?.type === 'refusal') throw new AiProviderError('BLOCKED', { provider: 'openai' });
      if (c?.type !== 'output_text' || typeof c.text !== 'string') continue;
      parts.push(c.text);
      for (const a of Array.isArray(c.annotations) ? c.annotations : []) {
        if (a?.type === 'url_citation' && typeof a.url === 'string') sources.push({ title: a.title ?? '', url: a.url });
      }
    }
  }
  return { text: parts.join(''), sources, searchCalls };
};

const generate = async ({ apiKey, model, system, history = [], prompt, images = [], json, schema, search, maxOutputTokens, timeoutMs }) => {
  // gpt-5 系列在 reasoning effort 為 minimal 時不支援 web_search 工具。
  const body = {
    model,
    ...(system && { instructions: system }),
    input: [
      ...history.map((m) => ({ role: m.role === 'assistant' ? 'assistant' : 'user', content: m.content })),
      { role: 'user', content: userContent(prompt, images) }
    ],
    reasoning: { effort: search ? 'low' : 'minimal' },
    ...(textFormat({ json, schema }) && { text: textFormat({ json, schema }) }),
    ...(search && { tools: [{ type: 'web_search' }] }),
    ...(maxOutputTokens && { max_output_tokens: maxOutputTokens }),
    store: false
  };

  const data = await postJson(`${BASE}/responses`, { headers: headers(apiKey), body, timeoutMs, classify, provider: 'openai' });
  const { text, sources, searchCalls } = parseOutput(data);
  const usage = data?.usage ?? {};
  return {
    text,
    sources,
    model,
    usage: {
      input_tokens: Number(usage.input_tokens) || 0,
      cached_tokens: Number(usage.input_tokens_details?.cached_tokens) || 0,
      output_tokens: Number(usage.output_tokens) || 0,
      search_calls: searchCalls
    }
  };
};

const moderate = async ({ apiKey, text, image, timeoutMs = 10000 }) => {
  const input = [
    { type: 'text', text },
    ...(image && IMAGE_TYPES.includes(image.mimeType)
      ? [{ type: 'image_url', image_url: { url: `data:${image.mimeType};base64,${image.data}` } }]
      : [])
  ];
  const data = await postJson(`${BASE}/moderations`, {
    headers: headers(apiKey),
    body: { model: MODERATION_MODEL, input },
    timeoutMs,
    classify,
    provider: 'openai'
  });
  const result = data?.results?.[0];
  if (!result) throw new AiProviderError('INVALID_OUTPUT', { provider: 'openai' });
  const scores = result.category_scores ?? {};
  const flagged = Object.entries(result.categories ?? {})
    .filter(([, on]) => on === true)
    .map(([name]) => ({ name, score: Number(scores[name]) || 0 }));
  return { flagged: result.flagged === true, categories: flagged, model: data?.model ?? MODERATION_MODEL };
};

module.exports = { generate, moderate, classify, MODERATION_MODEL, IMAGE_TYPES };
