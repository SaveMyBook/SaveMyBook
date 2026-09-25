const crypto = require('crypto');
const prisma = require('../../lib/prisma');
const ai = require('../../lib/ai');
const embeddings = require('../../lib/ai/embeddings');
const settingsService = require('./settings');
const usage = require('./usage');

// 語意檢索：書籍與客服知識先轉成向量存進 ai_embeddings，查詢時以餘弦相似度找意思相近的內容，
// 補足關鍵字比對找不到換句話說、上下位概念（例如「AI 書」對上書名只寫 Gemini 的書）的問題。
// 目前資料量（數千筆）直接在記憶體比對即可，不需要向量資料庫。

const STORE_TTL_MS = 30 * 60 * 1000;
const SYNC_LIMIT = 1000;
const INLINE_SYNC_MAX = 30;
const QUERY_CACHE_SIZE = 500;
const QUERY_TTL_MS = 60 * 60 * 1000;
const FAILURE_COOLDOWN_MS = 5 * 60 * 1000;

const hashOf = (text) => crypto.createHash('sha256').update(String(text)).digest('hex');

const profile = () => {
  const id = embeddings.ORDER.find((p) => ai.keyConfigured(p));
  return id ? embeddings.PROFILES[id] : null;
};

// AI 總開關關閉或未設定 OpenAI／Gemini 金鑰時回傳 null，呼叫端改用純關鍵字檢索。
const context = async () => {
  const p = profile();
  if (!p) return null;
  const settings = await settingsService.load();
  if (!settings.enabled) return null;
  return { profile: p, settings };
};

const stores = new Map();

const storeKey = (kind, p) => `${kind}|${p.id}`;

const loadStore = async (kind, p) => {
  const key = storeKey(kind, p);
  const hit = stores.get(key);
  if (hit && Date.now() - hit.at < STORE_TTL_MS) return hit.entries;
  const rows = await prisma.$queryRaw`
    SELECT ref_id, content_hash, vector FROM ai_embeddings WHERE kind = ${kind} AND model = ${p.id}`;
  const entries = new Map();
  for (const r of rows) {
    const vector = embeddings.decode(r.vector, p.dimensions);
    if (vector) entries.set(String(r.ref_id), { hash: r.content_hash, vector });
  }
  stores.set(key, { entries, at: Date.now() });
  return entries;
};

let failedUntil = 0;

const logCall = (p, { result, userId = null, error = null }) => usage.log({
  feature: 'embedding',
  provider: p.provider,
  model: p.model,
  userId,
  usage: { input_tokens: result?.tokens ?? 0 },
  costUsd: result?.cost_usd ?? 0,
  latencyMs: result?.latency_ms ?? error?.latency_ms ?? 0,
  ...(error && { status: 'error', errorCode: error.reason ?? 'INTERNAL', errorDetail: error.fullDetail ?? error.detail ?? null })
});

const embedTexts = async (p, texts, options = {}) => {
  if (Date.now() < failedUntil) throw new ai.AiProviderError('SERVER', { provider: p.provider });
  try {
    const result = await embeddings.embed(p, ai.apiKeyOf(p.provider), texts, options);
    await logCall(p, { result, userId: options.userId });
    return result.vectors;
  } catch (err) {
    // 金鑰錯誤或服務中斷時暫停一段時間，避免每次搜尋都重試而拖慢回應。
    failedUntil = Date.now() + FAILURE_COOLDOWN_MS;
    await logCall(p, { error: err, userId: options.userId });
    throw err;
  }
};

const upsert = (kind, p, rows) => prisma.$executeRawUnsafe(
  `INSERT INTO ai_embeddings (kind, ref_id, model, content_hash, vector, updated_at)
   VALUES ${rows.map(() => '(?, ?, ?, ?, ?, ?)').join(', ')}
   ON DUPLICATE KEY UPDATE model = VALUES(model), content_hash = VALUES(content_hash), vector = VALUES(vector),
     updated_at = VALUES(updated_at)`,
  ...rows.flatMap((r) => [kind, r.ref, p.id, r.hash, embeddings.encode(r.vector), new Date()])
);

const pending = new Map();

const staleDocs = (entries, docs) => docs.filter((d) => entries.get(d.ref)?.hash !== d.hash);

// docs 為 [{ ref, text, hash }]；只重算新增或內容變更的項目，同一種類同時只跑一次。
const sync = (kind, docs, { limit = SYNC_LIMIT } = {}) => {
  const p = profile();
  if (!p) return Promise.resolve(0);
  const key = storeKey(kind, p);
  if (pending.has(key)) return pending.get(key);
  const job = (async () => {
    const ctx = await context();
    if (!ctx || (await usage.budgetExceeded(ctx.settings))) return 0;
    const entries = await loadStore(kind, p);
    const todo = staleDocs(entries, docs).slice(0, limit);
    let done = 0;
    for (let i = 0; i < todo.length; i += p.batch) {
      const batch = todo.slice(i, i + p.batch);
      const vectors = await embedTexts(p, batch.map((d) => d.text));
      const rows = batch.map((d, j) => ({ ...d, vector: vectors[j] }));
      await upsert(kind, p, rows);
      for (const r of rows) entries.set(r.ref, { hash: r.hash, vector: r.vector });
      done += rows.length;
    }
    return done;
  })()
    .catch((err) => {
      if (!(err instanceof ai.AiProviderError)) console.error(`[語意索引更新失敗：${kind}]:`, err.message);
      return 0;
    })
    .finally(() => pending.delete(key));
  pending.set(key, job);
  return job;
};

const queryCache = new Map();

const queryVector = async (p, text, userId) => {
  const key = `${p.id}|${text}`;
  const hit = queryCache.get(key);
  if (hit && Date.now() - hit.at < QUERY_TTL_MS) return hit.vector;
  const [vector] = await embedTexts(p, [text], { task: 'query', userId });
  queryCache.set(key, { vector, at: Date.now() });
  while (queryCache.size > QUERY_CACHE_SIZE) queryCache.delete(queryCache.keys().next().value);
  return vector;
};

// 回傳 [{ ref, similarity }]（由高到低）；語意檢索無法使用時回傳 null。
// 少量新文件（例如剛上架的書）當場補算，大量缺漏則在背景補齊，這次先用已有的向量。
const rank = async (kind, docs, query, { userId = null } = {}) => {
  const text = String(query ?? '').trim();
  if (!text || docs.length === 0) return null;
  try {
    const ctx = await context();
    if (!ctx) return null;
    const p = ctx.profile;
    const entries = await loadStore(kind, p);
    const stale = staleDocs(entries, docs);
    if (stale.length > 0) {
      const job = sync(kind, docs);
      if (stale.length <= INLINE_SYNC_MAX) await job;
    }
    const q = await queryVector(p, text.slice(0, 2000), userId);
    const out = [];
    for (const d of docs) {
      const entry = entries.get(d.ref);
      if (entry) out.push({ ref: d.ref, similarity: embeddings.dot(q, entry.vector) });
    }
    return out.sort((a, b) => b.similarity - a.similarity);
  } catch (err) {
    if (!(err instanceof ai.AiProviderError)) console.error(`[語意檢索失敗：${kind}]:`, err.message);
    return null;
  }
};

// 以已存的向量找相近文件（例如相似的書），不需要另外呼叫嵌入 API；該文件尚未建立向量時回傳 null。
const neighbors = async (kind, docs, ref) => {
  try {
    const ctx = await context();
    if (!ctx) return null;
    const entries = await loadStore(kind, ctx.profile);
    const target = entries.get(String(ref));
    if (!target) return null;
    const out = [];
    for (const d of docs) {
      if (d.ref === String(ref)) continue;
      const entry = entries.get(d.ref);
      if (entry) out.push({ ref: d.ref, similarity: embeddings.dot(target.vector, entry.vector) });
    }
    return out.sort((a, b) => b.similarity - a.similarity);
  } catch (err) {
    console.error(`[相似文件查詢失敗：${kind}]:`, err.message);
    return null;
  }
};

// 過濾明顯無關的結果：同時要求高於服務商的最低相似度，且不能離最高分太遠。
const relevant = (ranked, { minSimilarity, relative = 0.7, limit = 30 } = {}) => {
  if (!ranked || ranked.length === 0) return [];
  const p = profile();
  const min = minSimilarity ?? p?.min_similarity ?? 0;
  const floor = Math.max(min, ranked[0].similarity * relative);
  return ranked.filter((r) => r.similarity >= floor).slice(0, limit);
};

// Reciprocal Rank Fusion：只看名次合併關鍵字與語意兩份排名，不必校正兩種分數的尺度。
const RRF_K = 60;
const fuse = (lists) => {
  const scores = new Map();
  for (const { ids, weight = 1 } of lists) {
    ids.forEach((id, i) => scores.set(id, (scores.get(id) ?? 0) + weight / (RRF_K + i + 1)));
  }
  return scores;
};

const status = async () => {
  const p = profile();
  if (!p) return { ready: false, provider: null, model: null, counts: {} };
  const rows = await prisma.$queryRaw`
    SELECT kind, COUNT(*) AS n FROM ai_embeddings WHERE model = ${p.id} GROUP BY kind`;
  return {
    ready: true,
    provider: p.provider,
    model: p.model,
    counts: Object.fromEntries(rows.map((r) => [r.kind, Number(r.n)]))
  };
};

const reset = () => {
  stores.clear();
  pending.clear();
  queryCache.clear();
  failedUntil = 0;
};

module.exports = { hashOf, profile, context, sync, rank, neighbors, relevant, fuse, status, reset };
