const { AiProviderError, postJson } = require('./http');
const openai = require('./openai');
const gemini = require('./gemini');

// 向量只能和同一個模型、同一維度產生的向量比較；換模型時整批重建，因此 id 同時帶模型與維度。
const PROFILES = {
  openai: { provider: 'openai', model: 'text-embedding-3-small', dimensions: 512, price_per_m: 0.02, batch: 100, min_similarity: 0.2 },
  gemini: { provider: 'gemini', model: 'gemini-embedding-001', dimensions: 768, price_per_m: 0.15, batch: 100, min_similarity: 0.45 }
};
PROFILES.openai.id = `openai:${PROFILES.openai.model}@${PROFILES.openai.dimensions}`;
PROFILES.gemini.id = `gemini:${PROFILES.gemini.model}@${PROFILES.gemini.dimensions}`;

const ORDER = ['openai', 'gemini'];
const TIMEOUT_MS = 20000;

const normalize = (values) => {
  const v = Float32Array.from(values, Number);
  let sum = 0;
  for (let i = 0; i < v.length; i += 1) sum += v[i] * v[i];
  const norm = Math.sqrt(sum);
  if (!norm || !Number.isFinite(norm)) return null;
  for (let i = 0; i < v.length; i += 1) v[i] /= norm;
  return v;
};

const embedOpenai = async (profile, apiKey, texts) => {
  const data = await postJson('https://api.openai.com/v1/embeddings', {
    headers: { authorization: `Bearer ${apiKey}` },
    body: { model: profile.model, input: texts, dimensions: profile.dimensions },
    timeoutMs: TIMEOUT_MS,
    classify: openai.classify,
    provider: 'openai'
  });
  const rows = Array.isArray(data?.data) ? [...data.data].sort((a, b) => a.index - b.index) : [];
  return { raw: rows.map((r) => r?.embedding), tokens: Number(data?.usage?.total_tokens) || 0 };
};

// Gemini 的批次嵌入不回傳 token 數，以字數估算（中文約一字一 token）。
const embedGemini = async (profile, apiKey, texts, task) => {
  const data = await postJson(`https://generativelanguage.googleapis.com/v1beta/models/${profile.model}:batchEmbedContents`, {
    headers: { 'x-goog-api-key': apiKey },
    body: {
      requests: texts.map((text) => ({
        model: `models/${profile.model}`,
        content: { parts: [{ text }] },
        taskType: task === 'query' ? 'RETRIEVAL_QUERY' : 'RETRIEVAL_DOCUMENT',
        outputDimensionality: profile.dimensions
      }))
    },
    timeoutMs: TIMEOUT_MS,
    classify: gemini.classify,
    provider: 'gemini'
  });
  const rows = Array.isArray(data?.embeddings) ? data.embeddings : [];
  return { raw: rows.map((r) => r?.values), tokens: texts.reduce((sum, t) => sum + t.length, 0) };
};

const embed = async (profile, apiKey, texts, { task = 'document' } = {}) => {
  if (!apiKey) throw new AiProviderError('NOT_CONFIGURED', { provider: profile.provider });
  const run = profile.provider === 'openai' ? embedOpenai : embedGemini;
  const started = Date.now();
  const { raw, tokens } = await run(profile, apiKey, texts, task);
  const vectors = raw.map((values) => (Array.isArray(values) && values.length === profile.dimensions ? normalize(values) : null));
  if (vectors.length !== texts.length || vectors.some((v) => !v)) {
    throw new AiProviderError('INVALID_OUTPUT', { provider: profile.provider });
  }
  return {
    vectors,
    tokens,
    cost_usd: Math.round((tokens * profile.price_per_m) / 1e6 * 1e6) / 1e6,
    latency_ms: Date.now() - started
  };
};

const dot = (a, b) => {
  let sum = 0;
  for (let i = 0; i < a.length; i += 1) sum += a[i] * b[i];
  return sum;
};

const encode = (vector) => Buffer.from(vector.buffer, vector.byteOffset, vector.byteLength).toString('base64');

const decode = (text, dimensions) => {
  const buf = Buffer.from(String(text ?? ''), 'base64');
  if (buf.length !== dimensions * 4) return null;
  const copy = new Uint8Array(buf.length);
  copy.set(buf);
  return new Float32Array(copy.buffer);
};

module.exports = { PROFILES, ORDER, embed, normalize, dot, encode, decode };
