const express = require('express');
const prisma = require('../../lib/prisma');
const requireAdmin = require('../../middleware/requireAdmin');
const v = require('../../lib/validate');
const { forbidden, notFound, conflict } = require('../../lib/errors');
const audit = require('../../services/audit');
const undo = require('../../services/undo');
const publicId = require('../../lib/public-id');
const { requireVerification } = require('../../services/security');

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

const TARGET_TYPES = [
  'user', 'book', 'category', 'level', 'faq', 'legal', 'announcement', 'cabinet', 'cabinet_slot',
  'wallet', 'ticket', 'report', 'dispute', 'order', 'backup'
];

const keywordFilters = (keyword) => {
  const filters = [{ action: { contains: keyword } }, { detail: { contains: keyword } }];
  const code = publicId.decodeAny(keyword);
  if (code?.prefix === publicId.prefixOf('log')) {
    filters.push({ log_id: code.id });
  } else if (code) {
    const types = TARGET_TYPES.filter((t) => publicId.prefixOf(t) === code.prefix);
    if (types.length > 0) filters.push({ target_id: code.id, target_type: { in: types } });
  }
  return filters;
};

const shapeLog = (l) => {
  const detail = audit.parseDetail(l.detail);
  return {
    log_id: l.log_id,
    log_no: publicId.encode('log', l.log_id),
    action: l.action,
    target_type: l.target_type,
    target_id: l.target_id,
    target_no: l.target_id == null ? null : publicId.encode(l.target_type, l.target_id),
    summary: detail.summary,
    changes: detail.changes ?? [],
    can_undo: Boolean(detail.undo) && !detail.reverted,
    reverted: detail.reverted ?? null,
    // 舊版 App 讀的是 detail。
    detail: detail.summary,
    ip_address: l.ip_address,
    created_at: l.created_at,
    admin: l.users
  };
};

router.get('/operation-logs', async (req, res) => {
  const { page, limit, skip } = v.pagination(req.query, { limit: 50 });
  const targetType = req.query.target_type ? v.oneOf(req.query.target_type, TARGET_TYPES, '不支援的對象類型') : null;
  const adminId = v.optionalId(req.query.admin_id, '管理員編號');
  const keyword = v.text(req.query.keyword, { label: '關鍵字', max: 100 });

  const where = {
    ...(targetType && { target_type: targetType }),
    ...(adminId && { admin_id: adminId }),
    ...(keyword && { OR: keywordFilters(keyword) })
  };

  const [logs, total] = await Promise.all([
    prisma.admin_operation_logs.findMany({
      where,
      include: { users: { select: { user_id: true, nickname: true, avatar_url: true } } },
      orderBy: { created_at: 'desc' },
      skip,
      take: limit
    }),
    prisma.admin_operation_logs.count({ where })
  ]);

  res.status(200).json({ success: true, pagination: v.pageMeta(total, { page, limit }), data: logs.map(shapeLog) });
});

router.post('/operation-logs/:id/undo', requireVerification('sensitive'), async (req, res) => {
  const logId = v.id(req.params.id, '紀錄編號');
  const log = await prisma.admin_operation_logs.findUnique({ where: { log_id: logId } });
  if (!log) throw notFound('找不到此操作紀錄');

  const detail = audit.parseDetail(log.detail);
  if (!detail.undo) throw conflict('此操作無法自動還原（例如涉及金流、密碼或已刪除的檔案），請至對應頁面手動處理');
  if (detail.reverted) throw conflict('此操作已還原');

  const permission = undo.PERMISSION_BY_TARGET[log.target_type];
  if (!permission || !(await requireAdmin.hasPermission(req.user, permission))) {
    throw forbidden('您沒有此功能的權限，無法還原此操作');
  }

  const result = await prisma.$transaction(async (tx) => {
    // 以原紀錄內容為條件更新，避免兩人同時還原。
    const reverted = { at: new Date().toISOString(), by: req.user.userId };
    const claimed = await tx.admin_operation_logs.updateMany({
      where: { log_id: logId, detail: log.detail },
      data: { detail: JSON.stringify({ ...detail, reverted }) }
    });
    if (claimed.count === 0) throw conflict('此操作已被其他人還原');

    await undo.run(tx, detail.undo, { adminId: req.user.userId, label: detail.summary });

    const entry = await audit.record(tx, {
      adminId: req.user.userId,
      action: `還原：${log.action}`,
      targetType: log.target_type,
      targetId: log.target_id,
      summary: `還原 #${logId}「${detail.summary}」`,
      changes: (detail.changes ?? []).map((c) => ({ ...c, from: c.to, to: c.from })),
      req
    });

    await tx.admin_operation_logs.update({
      where: { log_id: logId },
      data: { detail: JSON.stringify({ ...detail, reverted: { ...reverted, log_id: entry.log_id } }) }
    });
    return entry;
  });

  res.status(200).json({ success: true, message: '已還原', data: { log_id: result.log_id } });
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

  res.status(200).json({ success: true, pagination: v.pageMeta(total, { page, limit }), data: logs.map(shapeLog) });
});

module.exports = router;
