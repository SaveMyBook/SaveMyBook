const prisma = require('../../lib/prisma');
const { AiProviderError } = require('../../lib/ai');
const traces = require('./trace');
const usage = require('./usage');

// 決策紀錄：每次功能處理一筆，只存代號、計數與布林值，不存使用者原文、完整提示詞或照片。
const RETENTION_DAYS = 90;
const DAY_MS = 24 * 60 * 60 * 1000;
const REPORT_FEATURES = ['support', 'book_chat', 'recommend', 'listing_assist'];
// 追蹤欄位上線前的嵌入用量沒有 origin，不能歸給任何一個來源。
const UNKNOWN_ORIGIN = 'unknown';

// 代號只能是全小寫或全大寫的底線命名（picked、INVALID_OUTPUT），上限與 path 欄位同為 30 字。
// 單一全小寫或全大寫英文字仍會通過，呼叫端不得把書名、關鍵字或模型輸出放進 stats。
const CODE_FORMAT = /^(?:[a-z][a-z0-9]*(?:_[a-z0-9]+)*|[A-Z][A-Z0-9]*(?:_[A-Z0-9]+)*)$/;
const CODE_MAX = 30;
const isCode = (value) => typeof value === 'string' && value.length <= CODE_MAX && CODE_FORMAT.test(value) && !/\d{6}/.test(value);
// 計數與耗時都遠小於百萬；超過的數值多半是電話或 ISBN。
const NUMBER_MAX = 1e6;
const MAX_DEPTH = 3;
const MAX_ITEMS = 40;

// 呼叫端不小心放進自由文字（書名、電話、ISBN、模型輸出）時直接丟掉，而不是截斷後保存。
const codesOnly = (value, depth = 0) => {
  if (value === null || typeof value === 'boolean') return value;
  if (typeof value === 'number') return Number.isFinite(value) && Math.abs(value) < NUMBER_MAX ? Math.round(value * 1000) / 1000 : undefined;
  if (typeof value === 'string') return isCode(value) ? value : undefined;
  if (depth >= MAX_DEPTH || typeof value !== 'object') return undefined;
  if (Array.isArray(value)) return value.slice(0, MAX_ITEMS).map((v) => codesOnly(v, depth + 1)).filter((v) => v !== undefined);
  const out = {};
  for (const [key, v] of Object.entries(value).slice(0, MAX_ITEMS)) {
    const kept = isCode(key) ? codesOnly(v, depth + 1) : undefined;
    if (kept !== undefined) out[key] = kept;
  }
  return out;
};

// stats 慣例：flags 為布林旗標（報表計次數）、counts 為數量（報表取平均），其餘欄位只供除錯。
const record = async ({ trace = null, feature = trace?.feature, userId = trace?.userId ?? null, outcome, path = null, stats = {} }) => {
  try {
    const timings = trace ? { ...trace.timings, total: trace.elapsed() } : undefined;
    const payload = codesOnly({ ...stats, ...(timings && { ms: timings }) }) ?? {};
    await prisma.$executeRaw`
      INSERT INTO ai_decision_logs (request_id, feature, user_id, outcome, path, stats, created_at)
      VALUES (${trace?.id ?? traces.newRequestId()}, ${feature}, ${userId}, ${traces.OUTCOMES.includes(outcome) ? outcome : 'failed'},
        ${isCode(path) ? path : null}, ${JSON.stringify(payload)}, ${new Date()})`;
  } catch (err) {
    console.error('[AI 決策紀錄寫入失敗]:', err.message);
  }
};

// 次數上限等檢查失敗不是 AI 的處理結果，不記錄。
const recordFailure = async (err, { trace, stats = {} }) => {
  if (!(err instanceof AiProviderError)) return;
  await record({ trace, outcome: err.outcome ?? traces.outcomeOfError(err), stats: { ...stats, error: err.reason ?? 'INTERNAL' } });
};

const cutoffOf = (now) => new Date(now.getTime() - RETENTION_DAYS * DAY_MS);

// 對話可能持續超過保存期限；舊訊息的 meta 與決策紀錄同樣滿 90 天刪除，訊息本身依對話的保存規則處理。
const purgeExpired = async (now = new Date()) => {
  const cutoff = cutoffOf(now);
  const logs = await prisma.$executeRaw`DELETE FROM ai_decision_logs WHERE created_at < ${cutoff}`;
  const support = await prisma.$executeRaw`
    UPDATE ai_support_messages SET meta = NULL WHERE created_at < ${cutoff} AND meta IS NOT NULL`;
  const bookChat = await prisma.$executeRaw`
    UPDATE ai_chat_messages SET meta = NULL WHERE created_at < ${cutoff} AND meta IS NOT NULL`;
  return { logs: Number(logs), meta: Number(support) + Number(bookChat) };
};

const deleteUser = (db, userId) => db.$executeRaw`DELETE FROM ai_decision_logs WHERE user_id = ${userId}`;

const parseJson = (value) => {
  try {
    const parsed = JSON.parse(String(value ?? ''));
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : null;
  } catch {
    return null;
  }
};

const exportUser = async (userId) => {
  const rows = await prisma.$queryRaw`
    SELECT feature, outcome, path, stats, created_at FROM ai_decision_logs WHERE user_id = ${userId} ORDER BY created_at ASC`;
  return rows.map((r) => ({ feature: r.feature, outcome: r.outcome, path: r.path ?? null, stats: parseJson(r.stats) ?? {}, created_at: r.created_at }));
};

const num = (value) => Number(value ?? 0) || 0;
const round = (value, digits = 3) => Math.round(value * 10 ** digits) / 10 ** digits;

const tally = (rows, featureOf) => {
  const byFeature = new Map(REPORT_FEATURES.map((f) => [f, []]));
  for (const row of rows) {
    const feature = featureOf(row);
    if (!byFeature.has(feature)) byFeature.set(feature, []);
    byFeature.get(feature).push(row);
  }
  return [...byFeature].map(([feature, list]) => {
    const outcomes = Object.fromEntries(traces.OUTCOMES.map((o) => [o, 0]));
    const paths = {};
    const flags = {};
    const sums = {};
    for (const row of list) {
      outcomes[row.outcome] = (outcomes[row.outcome] ?? 0) + 1;
      if (row.path) paths[row.path] = (paths[row.path] ?? 0) + 1;
      const stats = parseJson(row.stats) ?? {};
      for (const [key, on] of Object.entries(stats.flags ?? {})) {
        flags[key] = (flags[key] ?? 0) + (on === true ? 1 : 0);
      }
      for (const [key, value] of Object.entries(stats.counts ?? {})) {
        if (typeof value !== 'number') continue;
        const entry = sums[key] ?? { total: 0, n: 0 };
        entry.total += value;
        entry.n += 1;
        sums[key] = entry;
      }
    }
    const averages = Object.fromEntries(Object.entries(sums).map(([key, { total, n }]) => [key, round(total / n, 2)]));
    return { feature, total: list.length, outcomes, paths, flags, averages };
  });
};

// 輸出格式錯誤的比例依功能與服務商分開統計；修復重試成功的那次另計為 repaired。
// 分母不含沒有送出的呼叫；validate 判定的非格式問題（處理結果 empty，例如回覆清理後為空）不算格式錯誤。
const FORMAT_EXCLUDED = ['embedding', 'test'];

// 只提供彙總數字，不提供任何一筆對話或使用者的明細。
const report = async (period, { now = new Date() } = {}) => {
  const { from, to } = usage.periodRange(period, now);
  const [rows, versions, embeddings, formats] = await Promise.all([
    prisma.$queryRaw`
      SELECT feature, outcome, path, stats FROM ai_decision_logs WHERE created_at >= ${from} AND created_at <= ${to}`,
    prisma.$queryRaw`
      SELECT feature, prompt_version, COUNT(*) AS requests, COALESCE(SUM(status = 'error'), 0) AS errors,
        COALESCE(SUM(outcome = 'degraded'), 0) AS degraded, COALESCE(SUM(outcome = 'repaired'), 0) AS repaired,
        MIN(created_at) AS first_at, MAX(created_at) AS last_at
      FROM ai_usage_logs WHERE prompt_version IS NOT NULL AND created_at >= ${from} AND created_at <= ${to}
      GROUP BY feature, prompt_version`,
    prisma.$queryRaw`
      SELECT origin, COUNT(*) AS requests, COALESCE(SUM(cost_usd), 0) AS cost_usd
      FROM ai_usage_logs WHERE feature = 'embedding' AND created_at >= ${from} AND created_at <= ${to}
      GROUP BY origin`,
    prisma.$queryRaw`
      SELECT feature, provider, COUNT(*) AS requests,
        COALESCE(SUM(error_code = 'INVALID_OUTPUT' AND (outcome IS NULL OR outcome <> 'empty')), 0) AS invalid_output,
        COALESCE(SUM(error_code = 'INCOMPLETE'), 0) AS incomplete, COALESCE(SUM(outcome = 'repaired'), 0) AS repaired,
        COALESCE(SUM(format_dropped > 0), 0) AS dropped, COALESCE(SUM(format_defaulted > 0), 0) AS defaulted
      FROM ai_usage_logs
      WHERE feature NOT IN (${FORMAT_EXCLUDED[0]}, ${FORMAT_EXCLUDED[1]}) AND (outcome IS NULL OR outcome <> ${traces.NOT_SENT})
        AND created_at >= ${from} AND created_at <= ${to}
      GROUP BY feature, provider`
  ]);
  return {
    period,
    from,
    to,
    features: tally(rows, (r) => r.feature),
    prompt_versions: versions
      .map((r) => ({
        feature: r.feature,
        prompt_version: r.prompt_version,
        requests: num(r.requests),
        errors: num(r.errors),
        degraded: num(r.degraded),
        repaired: num(r.repaired),
        first_at: r.first_at,
        last_at: r.last_at
      }))
      .sort((a, b) => a.feature.localeCompare(b.feature) || new Date(b.last_at) - new Date(a.last_at)),
    embedding_by_origin: embeddings
      .map((r) => ({ origin: r.origin ?? UNKNOWN_ORIGIN, requests: num(r.requests), cost_usd: round(num(r.cost_usd), 6) }))
      .sort((a, b) => b.cost_usd - a.cost_usd || b.requests - a.requests),
    format_errors: formats
      .map((r) => ({
        feature: r.feature,
        provider: r.provider,
        requests: num(r.requests),
        invalid_output: num(r.invalid_output),
        incomplete: num(r.incomplete),
        repaired: num(r.repaired),
        dropped: num(r.dropped),
        defaulted: num(r.defaulted)
      }))
      .sort((a, b) => a.feature.localeCompare(b.feature) || a.provider.localeCompare(b.provider))
  };
};

module.exports = { RETENTION_DAYS, REPORT_FEATURES, UNKNOWN_ORIGIN, isCode, codesOnly, record, recordFailure, purgeExpired, deleteUser, exportUser, report };
