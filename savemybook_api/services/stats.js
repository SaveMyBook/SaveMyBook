const prisma = require('../lib/prisma');
const aiSettings = require('./ai/settings');
const chatRisk = require('./chat/risk');

const EMPTY_DAY = () => ({ orders: 0, revenue: 0, new_users: 0, new_books: 0 });

// 上架審核（規則或 AI 攔下的書）與檢舉同屬「內容審核」，未執行 011 時視為 0。
const pendingListingReviews = async () => {
  if (!(await aiSettings.migrationReady())) return 0;
  const [row] = await prisma.$queryRaw`SELECT COUNT(*) AS n FROM ai_book_reviews WHERE status = 'pending'`;
  return Number(row?.n ?? 0);
};

const overview = async () => {
  const startOfToday = new Date();
  startOfToday.setHours(0, 0, 0, 0);

  const [members, pendingReports, pendingDisputes, cabinets, todayOrders, openTickets, pendingReviews, riskAlerts] = await Promise.all([
    prisma.users.count(),
    prisma.reports.count({ where: { status: 'pending' } }),
    prisma.transaction_disputes.count({ where: { status: { in: ['pending', 'processing'] } } }),
    prisma.smart_cabinets.count({ where: { is_active: true } }),
    prisma.orders.count({ where: { created_at: { gte: startOfToday } } }),
    prisma.support_tickets.count({ where: { status: 'open' } }),
    pendingListingReviews(),
    chatRisk.openCount()
  ]);

  return {
    member_count: members,
    pending_report_count: pendingReports,
    pending_listing_review_count: pendingReviews,
    open_risk_alert_count: riskAlerts,
    pending_dispute_count: pendingDisputes,
    active_cabinet_count: cabinets,
    today_order_count: todayOrders,
    open_ticket_count: openTickets
  };
};

const trends = async (days) => {
  const since = new Date();
  since.setHours(0, 0, 0, 0);
  since.setDate(since.getDate() - (days - 1));

  const [orders, newUsers, newBooks, completed, topCategories] = await Promise.all([
    prisma.orders.findMany({
      where: { created_at: { gte: since } },
      select: { created_at: true, total_amount: true, status: true }
    }),
    prisma.users.findMany({ where: { created_at: { gte: since } }, select: { created_at: true } }),
    prisma.books.findMany({ where: { created_at: { gte: since } }, select: { created_at: true } }),
    prisma.orders.aggregate({
      where: { status: 'completed', completed_at: { gte: since } },
      _sum: { total_amount: true },
      _count: true
    }),
    prisma.books.groupBy({
      by: ['category_id'],
      _count: { category_id: true },
      orderBy: { _count: { category_id: 'desc' } },
      take: 5
    })
  ]);

  const key = (d) => new Date(d).toISOString().slice(0, 10);
  const bucket = new Map();
  const at = (k) => {
    if (!bucket.has(k)) bucket.set(k, EMPTY_DAY());
    return bucket.get(k);
  };
  for (const o of orders) {
    const b = at(key(o.created_at));
    b.orders += 1;
    b.revenue += Number(o.total_amount);
  }
  for (const u of newUsers) at(key(u.created_at)).new_users += 1;
  for (const b of newBooks) at(key(b.created_at)).new_books += 1;

  const series = [];
  for (let i = 0; i < days; i += 1) {
    const day = new Date(since);
    day.setDate(since.getDate() + i);
    const k = key(day);
    series.push({ date: k, ...(bucket.get(k) ?? EMPTY_DAY()) });
  }

  const categoryIds = topCategories.map((t) => t.category_id).filter(Boolean);
  const categories = categoryIds.length
    ? await prisma.book_categories.findMany({
        where: { category_id: { in: categoryIds } },
        select: { category_id: true, category_name: true }
      })
    : [];

  return {
    days,
    series,
    completed_order_count: completed._count,
    completed_revenue: Number(completed._sum.total_amount ?? 0),
    top_categories: topCategories.map((t) => ({
      category_name: categories.find((c) => c.category_id === t.category_id)?.category_name ?? '未分類',
      book_count: t._count.category_id
    }))
  };
};

module.exports = { overview, trends };
