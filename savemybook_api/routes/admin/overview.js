const express = require('express');
const prisma = require('../../lib/prisma');
const requireAdmin = require('../../middleware/requireAdmin');
const v = require('../../lib/validate');

const router = express.Router();

router.get('/overview', async (req, res) => {
  const startOfToday = new Date();
  startOfToday.setHours(0, 0, 0, 0);

  const [members, pendingReports, pendingDisputes, cabinets, todayOrders, openTickets] = await Promise.all([
    prisma.users.count(),
    prisma.reports.count({ where: { status: 'pending' } }),
    prisma.transaction_disputes.count({ where: { status: { in: ['pending', 'processing'] } } }),
    prisma.smart_cabinets.count({ where: { is_active: true } }),
    prisma.orders.count({ where: { created_at: { gte: startOfToday } } }),
    prisma.support_tickets.count({ where: { status: 'open' } })
  ]);

  res.status(200).json({
    success: true,
    data: {
      member_count: members,
      pending_report_count: pendingReports,
      pending_dispute_count: pendingDisputes,
      active_cabinet_count: cabinets,
      today_order_count: todayOrders,
      open_ticket_count: openTickets
    }
  });
});

router.get('/stats', requireAdmin('stats'), async (req, res) => {
  const days = Math.min(Math.max(v.toInt(req.query.days) || 7, 1), 90);

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

  // 先分桶再組序列，避免每一天都把整段資料掃一遍。
  const key = (d) => new Date(d).toISOString().slice(0, 10);
  const bucket = new Map();
  const at = (k) => {
    if (!bucket.has(k)) bucket.set(k, { orders: 0, revenue: 0, new_users: 0, new_books: 0 });
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
    series.push({ date: k, ...(bucket.get(k) ?? { orders: 0, revenue: 0, new_users: 0, new_books: 0 }) });
  }

  const categoryIds = topCategories.map((t) => t.category_id).filter(Boolean);
  const categories = categoryIds.length
    ? await prisma.book_categories.findMany({
        where: { category_id: { in: categoryIds } },
        select: { category_id: true, category_name: true }
      })
    : [];

  res.status(200).json({
    success: true,
    data: {
      days,
      series,
      completed_order_count: completed._count,
      completed_revenue: Number(completed._sum.total_amount ?? 0),
      top_categories: topCategories.map((t) => ({
        category_name: categories.find((c) => c.category_id === t.category_id)?.category_name ?? '未分類',
        book_count: t._count.category_id
      }))
    }
  });
});

router.get('/operation-logs', async (req, res) => {
  const { page, limit, skip } = v.pagination(req.query, { limit: 50 });

  const [logs, total] = await Promise.all([
    prisma.admin_operation_logs.findMany({
      include: { users: { select: { user_id: true, nickname: true, avatar_url: true } } },
      orderBy: { created_at: 'desc' },
      skip,
      take: limit
    }),
    prisma.admin_operation_logs.count()
  ]);

  res.status(200).json({
    success: true,
    pagination: v.pageMeta(total, { page, limit }),
    data: logs.map((l) => ({
      log_id: l.log_id,
      action: l.action,
      target_type: l.target_type,
      target_id: l.target_id,
      detail: l.detail,
      created_at: l.created_at,
      admin: l.users
    }))
  });
});

router.get('/maintenance-logs', async (req, res) => {
  const { page, limit, skip } = v.pagination(req.query, { limit: 30 });
  const where = { target_type: { in: ['cabinet', 'cabinet_slot'] } };

  const [logs, total] = await Promise.all([
    prisma.admin_operation_logs.findMany({
      where,
      skip,
      take: limit,
      orderBy: { created_at: 'desc' },
      include: { users: { select: { user_id: true, nickname: true } } }
    }),
    prisma.admin_operation_logs.count({ where })
  ]);

  res.status(200).json({ success: true, pagination: v.pageMeta(total, { page, limit }), data: logs });
});

module.exports = router;
