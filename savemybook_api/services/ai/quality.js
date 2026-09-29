const prisma = require('../../lib/prisma');
const usage = require('./usage');
const { FIELDS: LISTING_FIELDS } = require('./listing-adoption');

// 用量報表的品質區塊。各比例在分母為 0 時回傳 null，App 顯示為無資料，避免把「沒有樣本」看成 0%。
const ratio = (part, total) => (total > 0 ? Math.round((part / total) * 10000) / 10000 : null);

const parseList = (value) => {
  try {
    const list = JSON.parse(String(value ?? '[]'));
    return Array.isArray(list) ? list.filter((x) => typeof x === 'string') : [];
  } catch {
    return [];
  }
};

const tally = () => new Map();
const bump = (map, key, field) => {
  if (!map.has(key)) map.set(key, { decisions: 0, overturned: 0 });
  map.get(key)[field] += 1;
};
const rows = (map, keyName) => [...map].map(([key, v]) => ({ [keyName]: key, ...v, rate: ratio(v.overturned, v.decisions) }))
  .sort((a, b) => b.decisions - a.decisions);

// 只計管理員的決定（misjudged 不為 null）：賣家修改後通過、改回在售待審中的書都不代表原判定有誤。
const moderationQuality = async (range) => {
  const events = await prisma.ai_review_events.findMany({
    where: { actor: { in: ['admin', 'relist'] }, misjudged: { not: null }, created_at: range },
    select: { origin: true, categories: true, misjudged: true }
  });
  const byCategory = tally();
  const byOrigin = tally();
  for (const e of events) {
    const categories = parseList(e.categories);
    for (const category of categories.length ? categories : ['unspecified']) {
      bump(byCategory, category, 'decisions');
      if (e.misjudged) bump(byCategory, category, 'overturned');
    }
    bump(byOrigin, e.origin, 'decisions');
    if (e.misjudged) bump(byOrigin, e.origin, 'overturned');
  }
  const overturned = events.filter((e) => e.misjudged).length;
  return {
    decisions: events.length,
    overturned,
    rate: ratio(overturned, events.length),
    by_category: rows(byCategory, 'category'),
    by_origin: rows(byOrigin, 'origin')
  };
};

const ratingsOf = async (table, range) => {
  const rated = await prisma[table].findMany({
    where: { feedback: { not: null }, feedback_at: range },
    select: { feedback: true, feedback_reason: true }
  });
  const unhelpful = rated.filter((r) => r.feedback === 'unhelpful');
  const reasons = {};
  for (const r of unhelpful) reasons[r.feedback_reason ?? 'unspecified'] = (reasons[r.feedback_reason ?? 'unspecified'] ?? 0) + 1;
  return { rated: rated.length, unhelpful: unhelpful.length, negative_rate: ratio(unhelpful.length, rated.length), reasons };
};

const supportQuality = async (range) => {
  const [sessions, escalated, ratings] = await Promise.all([
    prisma.ai_support_sessions.count({ where: { created_at: range } }),
    prisma.ai_support_sessions.count({ where: { created_at: range, status: 'escalated' } }),
    ratingsOf('ai_support_messages', range)
  ]);
  return { sessions, escalated, handoff_rate: ratio(escalated, sessions), ...ratings };
};

// 未附書的回覆包含追問使用者需求的回覆。
const bookChatQuality = async (range) => {
  const [replies, withoutBooks, ratings] = await Promise.all([
    prisma.ai_chat_messages.count({ where: { role: 'assistant', created_at: range } }),
    prisma.ai_chat_messages.count({ where: { role: 'assistant', created_at: range, book_ids: null } }),
    ratingsOf('ai_chat_messages', range)
  ]);
  return { replies, without_books: withoutBooks, no_books_rate: ratio(withoutBooks, replies), ...ratings };
};

const disputeQuality = async (range) => {
  const [resolved, rated] = await Promise.all([
    prisma.ai_dispute_analyses.findMany({ where: { resolved_at: range, agreed: { not: null } }, select: { agreed: true } }),
    prisma.ai_dispute_analyses.findMany({ where: { created_at: range, helpful: { not: null } }, select: { helpful: true } })
  ]);
  const agreed = resolved.filter((r) => r.agreed).length;
  const helpful = rated.filter((r) => r.helpful).length;
  return {
    resolved: resolved.length,
    agreed,
    agreement_rate: ratio(agreed, resolved.length),
    rated: rated.length,
    helpful,
    helpful_rate: ratio(helpful, rated.length)
  };
};

const recommendationQuality = async (range) => {
  const [groups, dismissed] = await Promise.all([
    prisma.recommendation_logs.groupBy({ by: ['source', 'is_clicked'], where: { created_at: range }, _count: { _all: true } }),
    prisma.recommendation_dismissals.count({ where: { created_at: range } })
  ]);
  const bySource = Object.fromEntries(['ai', 'rules'].map((source) => {
    const of = groups.filter((g) => g.source === source);
    const impressions = of.reduce((n, g) => n + Number(g._count?._all ?? 0), 0);
    const clicks = of.filter((g) => g.is_clicked).reduce((n, g) => n + Number(g._count?._all ?? 0), 0);
    return [source, { impressions, clicks, ctr: ratio(clicks, impressions) }];
  }));
  return { ...bySource, not_interested: dismissed };
};

const listingQuality = async (range) => {
  const used = await prisma.ai_listing_suggestions.findMany({
    where: { used_at: range, adopted: { not: null } },
    select: { adopted: true }
  });
  const counts = new Map(LISTING_FIELDS.map((f) => [f, { suggested: 0, adopted: 0 }]));
  for (const row of used) {
    let adopted = {};
    try {
      adopted = JSON.parse(String(row.adopted));
    } catch {
      continue;
    }
    for (const [field, value] of Object.entries(adopted)) {
      if (!counts.has(field)) continue;
      counts.get(field).suggested += 1;
      if (Number(value) === 1) counts.get(field).adopted += 1;
    }
  }
  return {
    listings: used.length,
    fields: [...counts].filter(([, c]) => c.suggested > 0).map(([field, c]) => ({ field, ...c, rate: ratio(c.adopted, c.suggested) }))
  };
};

const report = async (period, { now = new Date() } = {}) => {
  const { from, to } = usage.periodRange(period, now);
  const range = { gte: from, lte: to };
  const [moderation, support, bookChat, disputes, recommendations, listing, faqs] = await Promise.all([
    moderationQuality(range),
    supportQuality(range),
    bookChatQuality(range),
    disputeQuality(range),
    recommendationQuality(range),
    listingQuality(range),
    prisma.faqs.count({ where: { source_ticket_id: { not: null }, created_at: range } })
  ]);
  return {
    period,
    from,
    to,
    moderation,
    support,
    book_chat: bookChat,
    dispute_assist: disputes,
    recommendations,
    listing_assist: listing,
    faqs_from_tickets: faqs
  };
};

module.exports = { report, ratio };
