const prisma = require('../../lib/prisma');
const publicId = require('../../lib/public-id');
const { clip } = require('../../lib/text');
const { hasColumn } = require('../../lib/schema-check');

const FEATURES = ['support', 'listing_assist', 'recommend', 'moderation', 'book_chat', 'embedding', 'enrich', 'admin_assist', 'test'];
const PERIODS = ['today', '7d', '30d', 'month'];
const DAY_MS = 24 * 60 * 60 * 1000;

const num = (value) => Number(value ?? 0) || 0;
const round6 = (n) => Math.round(n * 1e6) / 1e6;
const uint = (value) => Math.max(0, Math.min(4294967295, Math.round(num(value))));

const startOfDay = (d = new Date()) => new Date(d.getFullYear(), d.getMonth(), d.getDate());
const startOfMonth = (d = new Date()) => new Date(d.getFullYear(), d.getMonth(), 1);

const localDate = (d) => {
  const pad = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
};

const log = async ({ feature, provider, model, userId = null, usage = {}, costUsd = 0, latencyMs = 0, status = 'ok', errorCode = null, errorDetail = null }) => {
  try {
    const values = [
      feature, clip(String(provider), 20), clip(String(model ?? ''), 80), userId,
      uint(usage.input_tokens), uint(usage.cached_tokens), uint(usage.output_tokens), uint(usage.search_calls),
      round6(Math.max(0, num(costUsd))), uint(latencyMs), status === 'ok' ? 'ok' : 'error',
      errorCode ? clip(String(errorCode), 60) : null
    ];
    if (await hasColumn('ai_usage_logs', 'error_detail')) {
      await prisma.$executeRawUnsafe(
        `INSERT INTO ai_usage_logs
          (feature, provider, model, user_id, input_tokens, cached_tokens, output_tokens, search_calls, cost_usd, latency_ms, status, error_code, error_detail, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        ...values, errorDetail ? clip(String(errorDetail), 400) : null, new Date()
      );
    } else {
      await prisma.$executeRawUnsafe(
        `INSERT INTO ai_usage_logs
          (feature, provider, model, user_id, input_tokens, cached_tokens, output_tokens, search_calls, cost_usd, latency_ms, status, error_code, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        ...values, new Date()
      );
    }
  } catch (err) {
    console.error('[AI 用量紀錄寫入失敗]:', err.message);
  }
};

const monthCost = async (now = new Date()) => {
  const rows = await prisma.$queryRaw`
    SELECT COALESCE(SUM(cost_usd), 0) AS cost FROM ai_usage_logs WHERE created_at >= ${startOfMonth(now)}`;
  return round6(num(rows[0]?.cost));
};

const monthSearchCalls = async (provider, now = new Date()) => {
  const rows = await prisma.$queryRaw`
    SELECT COALESCE(SUM(search_calls), 0) AS calls FROM ai_usage_logs
    WHERE provider = ${provider} AND created_at >= ${startOfMonth(now)}`;
  return num(rows[0]?.calls);
};

const budgetExceeded = async (settings) => {
  const budget = num(settings.limits.monthly_budget_usd);
  if (budget <= 0) return false;
  return (await monthCost()) >= budget;
};

const dailyCount = async (userId, feature, now = new Date()) => {
  const rows = await prisma.$queryRaw`
    SELECT COUNT(*) AS n FROM ai_usage_logs
    WHERE user_id = ${userId} AND feature = ${feature} AND status = 'ok' AND created_at >= ${startOfDay(now)}`;
  return num(rows[0]?.n);
};

const periodRange = (period, now = new Date()) => {
  const today = startOfDay(now);
  const from = {
    today,
    '7d': new Date(today.getFullYear(), today.getMonth(), today.getDate() - 6),
    '30d': new Date(today.getFullYear(), today.getMonth(), today.getDate() - 29),
    month: startOfMonth(now)
  }[period];
  return { from, to: now };
};

const daysBetween = (from, to) => {
  const days = [];
  for (let d = startOfDay(from); d <= to; d = new Date(d.getFullYear(), d.getMonth(), d.getDate() + 1)) {
    days.push(localDate(d));
  }
  return days;
};

const projectMonth = (cost, now) => {
  const monthStart = startOfMonth(now);
  const nextMonth = new Date(now.getFullYear(), now.getMonth() + 1, 1);
  const elapsed = Math.max((now - monthStart) / DAY_MS, 1 / 24);
  return round6((cost / elapsed) * ((nextMonth - monthStart) / DAY_MS));
};

const report = async (period, { monthlyBudgetUsd = 0, now = new Date() } = {}) => {
  const { from, to } = periodRange(period, now);

  const [totals, byFeature, byProvider, dailyRows, topRows, errorRows, month, pending] = await Promise.all([
    prisma.$queryRaw`
      SELECT COUNT(*) AS requests, COALESCE(SUM(status = 'error'), 0) AS errors,
        COALESCE(SUM(input_tokens), 0) AS input_tokens, COALESCE(SUM(output_tokens), 0) AS output_tokens,
        COALESCE(SUM(search_calls), 0) AS search_calls, COALESCE(SUM(cost_usd), 0) AS cost_usd
      FROM ai_usage_logs WHERE created_at >= ${from} AND created_at <= ${to}`,
    prisma.$queryRaw`
      SELECT feature, COUNT(*) AS requests, COALESCE(SUM(cost_usd), 0) AS cost_usd,
        COALESCE(SUM(input_tokens), 0) AS input_tokens, COALESCE(SUM(output_tokens), 0) AS output_tokens,
        COALESCE(SUM(status = 'error'), 0) AS errors
      FROM ai_usage_logs WHERE created_at >= ${from} AND created_at <= ${to}
      GROUP BY feature ORDER BY cost_usd DESC`,
    prisma.$queryRaw`
      SELECT provider, model, COUNT(*) AS requests, COALESCE(SUM(cost_usd), 0) AS cost_usd, COALESCE(AVG(latency_ms), 0) AS avg_latency_ms
      FROM ai_usage_logs WHERE created_at >= ${from} AND created_at <= ${to}
      GROUP BY provider, model ORDER BY cost_usd DESC`,
    // 逐筆取回再依伺服器當地日期分組：資料庫時區可能與伺服器不同，DATE() 會切錯日期。
    prisma.$queryRaw`
      SELECT feature, cost_usd, created_at FROM ai_usage_logs WHERE created_at >= ${from} AND created_at <= ${to}`,
    prisma.$queryRaw`
      SELECT l.user_id, u.nickname, COUNT(*) AS requests, COALESCE(SUM(l.cost_usd), 0) AS cost_usd
      FROM ai_usage_logs l JOIN users u ON u.user_id = l.user_id
      WHERE l.user_id IS NOT NULL AND l.created_at >= ${from} AND l.created_at <= ${to}
      GROUP BY l.user_id, u.nickname ORDER BY cost_usd DESC, requests DESC LIMIT 5`,
    hasColumn('ai_usage_logs', 'error_detail').then((withDetail) => prisma.$queryRawUnsafe(
      `SELECT created_at, feature, provider, model, error_code${withDetail ? ', error_detail' : ''} FROM ai_usage_logs
       WHERE status = 'error' AND created_at >= ? AND created_at <= ?
       ORDER BY created_at DESC LIMIT 10`,
      from, to
    )),
    monthCost(now),
    prisma.$queryRaw`SELECT COUNT(*) AS n FROM ai_book_reviews WHERE status = 'pending'`
  ]);

  const t = totals[0] ?? {};
  const budget = num(monthlyBudgetUsd);

  const days = daysBetween(from, to);
  const daily = new Map(days.map((date) => [date, { date, requests: 0, cost_usd: 0, by_feature: {} }]));
  for (const row of dailyRows) {
    const bucket = daily.get(localDate(new Date(row.created_at)));
    if (!bucket) continue;
    const cost = num(row.cost_usd);
    bucket.requests += 1;
    bucket.cost_usd += cost;
    bucket.by_feature[row.feature] = (bucket.by_feature[row.feature] ?? 0) + cost;
  }

  return {
    period,
    from,
    to,
    summary: {
      requests: num(t.requests),
      errors: num(t.errors),
      input_tokens: num(t.input_tokens),
      output_tokens: num(t.output_tokens),
      search_calls: num(t.search_calls),
      cost_usd: round6(num(t.cost_usd)),
      month_cost_usd: month,
      monthly_budget_usd: budget,
      budget_used_ratio: budget > 0 ? Math.round((month / budget) * 10000) / 10000 : 0,
      projected_month_cost_usd: projectMonth(month, now)
    },
    by_feature: byFeature.map((r) => ({
      feature: r.feature,
      requests: num(r.requests),
      cost_usd: round6(num(r.cost_usd)),
      input_tokens: num(r.input_tokens),
      output_tokens: num(r.output_tokens),
      errors: num(r.errors)
    })),
    by_provider: byProvider.map((r) => ({
      provider: r.provider,
      model: r.model,
      requests: num(r.requests),
      cost_usd: round6(num(r.cost_usd)),
      avg_latency_ms: Math.round(num(r.avg_latency_ms))
    })),
    daily: [...daily.values()].map((d) => ({
      ...d,
      cost_usd: round6(d.cost_usd),
      by_feature: Object.fromEntries(Object.entries(d.by_feature).map(([k, v]) => [k, round6(v)]))
    })),
    top_users: topRows.map((r) => ({
      user_public_id: publicId.encode('user', num(r.user_id)),
      nickname: r.nickname ?? '',
      requests: num(r.requests),
      cost_usd: round6(num(r.cost_usd))
    })),
    recent_errors: errorRows.map((r) => ({
      created_at: r.created_at,
      feature: r.feature,
      provider: r.provider,
      model: r.model ?? null,
      error_code: r.error_code,
      error_detail: r.error_detail ?? null
    })),
    pending_reviews: num(pending[0]?.n)
  };
};

module.exports = {
  FEATURES, PERIODS, startOfDay, startOfMonth, localDate, log, monthCost, monthSearchCalls, budgetExceeded, dailyCount,
  periodRange, daysBetween, projectMonth, report
};
