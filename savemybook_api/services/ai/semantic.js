const crypto = require('crypto');
const prisma = require('../../lib/prisma');
const ai = require('../../lib/ai');
const embeddings = require('../../lib/ai/embeddings');
const settingsService = require('./settings');
const usage = require('./usage');

const STORE_TTL_MS = 30 * 60 * 1000;
const SYNC_LIMIT = 1000;
const INLINE_SYNC_MAX = 30;
const QUERY_CACHE_SIZE = 500;
const QUERY_TTL_MS = 60 * 60 * 1000;
const FAILURE_COOLDOWN_MS = 5 * 60 * 1000;
// 查詢向量只是加分項，等不到就只用關鍵字檢索，不拖慢互動功能的整體時限。
const QUERY_TIMEOUT_MS = 2500;
const FAILURE_STREAK = 3;
const FAILED_DOC_MS = 30 * 60 * 1000;

const hashOf = (text) => crypto.createHash('sha256').update(String(text)).digest('hex');

const profile = () => {
  const id = embeddings.ORDER.find((p) => ai.keyConfigured(p));
  return id ? embeddings.PROFILES[id] : null;
};

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

// 同步與查詢分開冷卻。系統性錯誤立即冷卻，其他錯誤（金鑰過期的 400 也屬此類）連續 FAILURE_STREAK 次才冷卻；
// 同步失敗的那批文件另外暫停重送，否則每次查詢觸發同步都會重送同一批、重複計費。
const COOLDOWN_REASONS = new Set(['AUTH', 'QUOTA', 'SERVER', 'TIMEOUT', 'NETWORK', 'RATE_LIMITED', 'MODEL_NOT_FOUND']);
const PURPOSES = ['sync', 'query'];

const health = { until: { sync: 0, query: 0 }, streak: { sync: 0, query: 0 }, lastSyncAt: null, lastError: null, coverage: new Map() };
const failedDocs = new Map();

const coolingDown = (purpose) => Date.now() < health.until[purpose];

const skipFailed = (docs) => {
  const now = Date.now();
  return docs.filter((d) => {
    const until = failedDocs.get(d.hash);
    if (until === undefined) return true;
    if (until > now) return false;
    failedDocs.delete(d.hash);
    return true;
  });
};

const systemic = (err) => err instanceof ai.AiProviderError
  && (COOLDOWN_REASONS.has(err.reason) || (err.reason === 'INVALID_OUTPUT' && err.systemic === true));

// 文件向量不論在背景或在請求中當場補算，都是維護索引的費用，記為 index，不歸給觸發的功能。
const INDEX_ORIGIN = 'index';

const logCall = (p, { result, userId = null, error = null, trace = null, origin = null }) => usage.log({
  feature: 'embedding',
  provider: p.provider,
  model: p.model,
  userId,
  requestId: trace?.id ?? null,
  origin,
  usage: { input_tokens: result?.tokens ?? error?.usage?.input_tokens ?? 0 },
  costUsd: result?.cost_usd ?? error?.cost_usd ?? 0,
  latencyMs: result?.latency_ms ?? error?.latency_ms ?? 0,
  ...(error && { status: 'error', errorCode: error.reason ?? 'INTERNAL', errorDetail: error.fullDetail ?? error.detail ?? null })
});

// 查詢的逾時很短，偶發逾時只代表這次來不及，不計入冷卻。
const countsTowardCooldown = (purpose, err) => !(purpose === 'query' && err?.reason === 'TIMEOUT');

const embedTexts = async (p, texts, { purpose, trace = null, ...options }) => {
  if (coolingDown(purpose)) throw new ai.AiProviderError('SERVER', { provider: p.provider });
  const origin = purpose === 'sync' ? INDEX_ORIGIN : trace?.feature ?? null;
  try {
    const result = await embeddings.embed(p, ai.apiKeyOf(p.provider), texts, options);
    health.streak[purpose] = 0;
    await logCall(p, { result, userId: options.userId, trace, origin });
    return result.vectors;
  } catch (err) {
    if (countsTowardCooldown(purpose, err)) {
      health.streak[purpose] += 1;
      if (systemic(err) || health.streak[purpose] >= FAILURE_STREAK) {
        health.until[purpose] = Date.now() + FAILURE_COOLDOWN_MS;
        health.streak[purpose] = 0;
      }
    }
    health.lastError = {
      at: new Date(),
      purpose,
      code: err?.reason ?? 'INTERNAL',
      detail: err?.fullDetail ?? err?.detail ?? (ai.redact(err?.message ?? '') || null)
    };
    await logCall(p, { error: err, userId: options.userId, trace, origin });
    throw err;
  }
};

const recordCoverage = (kind, entries, docs) => {
  const indexed = docs.filter((d) => entries.get(d.ref)?.hash === d.hash).length;
  health.coverage.set(kind, { indexed, total: docs.length });
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

const sync = (kind, docs, { limit = SYNC_LIMIT } = {}) => {
  const p = profile();
  if (!p) return Promise.resolve(0);
  const key = storeKey(kind, p);
  if (pending.has(key)) return pending.get(key);
  const job = (async () => {
    const ctx = await context();
    if (!ctx || (await usage.budgetExceeded(ctx.settings))) return 0;
    const entries = await loadStore(kind, p);
    const todo = skipFailed(staleDocs(entries, docs)).slice(0, limit);
    let done = 0;
    try {
      for (let i = 0; i < todo.length; i += p.batch) {
        const batch = todo.slice(i, i + p.batch);
        let vectors;
        try {
          vectors = await embedTexts(p, batch.map((d) => d.text), { purpose: 'sync' });
        } catch (err) {
          if (!(err instanceof ai.AiProviderError) || coolingDown('sync')) throw err;
          for (const d of batch) failedDocs.set(d.hash, Date.now() + FAILED_DOC_MS);
          continue;
        }
        const rows = batch.map((d, j) => ({ ...d, vector: vectors[j] }));
        await upsert(kind, p, rows);
        for (const r of rows) entries.set(r.ref, { hash: r.hash, vector: r.vector });
        done += rows.length;
      }
    } finally {
      recordCoverage(kind, entries, docs);
    }
    health.lastSyncAt = new Date();
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

const queryVector = async (p, text, userId, trace) => {
  const key = `${p.id}|${text}`;
  const hit = queryCache.get(key);
  if (hit && Date.now() - hit.at < QUERY_TTL_MS) return hit.vector;
  const [vector] = await embedTexts(p, [text], { purpose: 'query', task: 'query', userId, trace, timeoutMs: QUERY_TIMEOUT_MS });
  queryCache.set(key, { vector, at: Date.now() });
  while (queryCache.size > QUERY_CACHE_SIZE) queryCache.delete(queryCache.keys().next().value);
  return vector;
};

// 少量新文件（例如剛上架的書）當場補算，大量缺漏則在背景補齊，這次先用已有的向量。
// inlineSync 為 false 時一律在背景補算：有整體時限的互動功能不等待同步。
const rank = async (kind, docs, query, { userId = null, inlineSync = true, trace = null } = {}) => {
  const text = String(query ?? '').trim();
  if (!text || docs.length === 0) return null;
  try {
    const ctx = await context();
    if (!ctx) return null;
    const p = ctx.profile;
    const entries = await loadStore(kind, p);
    const stale = staleDocs(entries, docs);
    health.coverage.set(kind, { indexed: docs.length - stale.length, total: docs.length });
    const todo = coolingDown('sync') ? [] : skipFailed(stale);
    if (todo.length > 0) {
      const job = sync(kind, docs);
      if (inlineSync && todo.length <= INLINE_SYNC_MAX) await job;
    }
    const q = await queryVector(p, text.slice(0, 2000), userId, trace);
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

const relevant = (ranked, { minSimilarity, relative = 0.7, limit = 30 } = {}) => {
  if (!ranked || ranked.length === 0) return [];
  const p = profile();
  const min = minSimilarity ?? p?.min_similarity ?? 0;
  const floor = Math.max(min, ranked[0].similarity * relative);
  return ranked.filter((r) => r.similarity >= floor).slice(0, limit);
};

const RRF_K = 60;
const fuse = (lists) => {
  const scores = new Map();
  for (const { ids, weight = 1 } of lists) {
    ids.forEach((id, i) => scores.set(id, (scores.get(id) ?? 0) + weight / (RRF_K + i + 1)));
  }
  return scores;
};

const healthStatus = () => {
  const now = Date.now();
  return {
    cooldown_until: Object.fromEntries(PURPOSES.map((k) => [k, health.until[k] > now ? new Date(health.until[k]) : null])),
    last_sync_at: health.lastSyncAt,
    last_error: health.lastError,
    coverage: Object.fromEntries(health.coverage)
  };
};

const status = async () => {
  const p = profile();
  if (!p) return { ready: false, provider: null, model: null, counts: {}, ...healthStatus() };
  const rows = await prisma.$queryRaw`
    SELECT kind, COUNT(*) AS n FROM ai_embeddings WHERE model = ${p.id} GROUP BY kind`;
  return {
    ready: true,
    provider: p.provider,
    model: p.model,
    counts: Object.fromEntries(rows.map((r) => [r.kind, Number(r.n)])),
    ...healthStatus()
  };
};

const reset = () => {
  stores.clear();
  pending.clear();
  queryCache.clear();
  health.until = { sync: 0, query: 0 };
  health.streak = { sync: 0, query: 0 };
  failedDocs.clear();
  health.lastSyncAt = null;
  health.lastError = null;
  health.coverage.clear();
};

module.exports = { QUERY_TIMEOUT_MS, hashOf, profile, context, sync, rank, neighbors, relevant, fuse, status, reset };
