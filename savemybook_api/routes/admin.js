const express = require('express');
const prisma = require('../lib/prisma');
const authenticateToken = require('../middleware/auth');
const requireAdmin = require('../middleware/requireAdmin');

const router = express.Router();

router.use(authenticateToken, requireAdmin);

const logAction = (adminId, action, targetType, targetId, detail) =>
  prisma.admin_operation_logs.create({
    data: { admin_id: adminId, action, target_type: targetType, target_id: targetId, detail }
  });

/* ---------------------------------- 會員管控 --------------------------------- */

router.get('/members', async (req, res) => {
  const keyword = req.query.keyword || '';
  const status = req.query.status; // active | blacklisted | inactive
  const page = parseInt(req.query.page) || 1;
  const limit = parseInt(req.query.limit) || 20;

  try {
    const where = {
      ...(keyword && {
        OR: [
          { nickname: { contains: keyword } },
          { email: { contains: keyword } }
        ]
      }),
      ...(status === 'blacklisted' && { is_blacklisted: true }),
      ...(status === 'inactive' && { is_active: false }),
      ...(status === 'active' && { is_active: true, is_blacklisted: false })
    };

    const [members, totalCount] = await Promise.all([
      prisma.users.findMany({
        where,
        skip: (page - 1) * limit,
        take: limit,
        orderBy: { created_at: 'desc' },
        select: {
          user_id: true, email: true, nickname: true, avatar_url: true, phone: true,
          role: true, is_active: true, is_blacklisted: true, created_at: true,
          _count: {
            select: {
              books: true,
              orders_orders_buyer_idTousers: true,
              orders_orders_seller_idTousers: true
            }
          }
        }
      }),
      prisma.users.count({ where })
    ]);

    res.status(200).json({
      success: true,
      pagination: { total: totalCount, page, limit, total_pages: Math.ceil(totalCount / limit) },
      data: members
    });
  } catch (err) {
    console.error('[取得會員列表失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.patch('/members/:id', async (req, res) => {
  const userId = parseInt(req.params.id);
  const { is_active, is_blacklisted, role } = req.body;

  if (userId === req.user.userId) {
    return res.status(400).json({ success: false, message: '無法變更自己的帳號狀態' });
  }

  try {
    const updated = await prisma.users.update({
      where: { user_id: userId },
      data: {
        ...(is_active !== undefined && { is_active: !!is_active }),
        ...(is_blacklisted !== undefined && { is_blacklisted: !!is_blacklisted }),
        ...(role && ['buyer_seller', 'admin'].includes(role) && { role }),
        updated_at: new Date()
      },
      select: { user_id: true, nickname: true, role: true, is_active: true, is_blacklisted: true }
    });

    await logAction(req.user.userId, '變更會員狀態', 'user', userId, JSON.stringify({ is_active, is_blacklisted, role }));

    res.status(200).json({ success: true, message: '會員狀態已更新', data: updated });
  } catch (err) {
    if (err.code === 'P2025') return res.status(404).json({ success: false, message: '找不到該會員' });
    console.error('[更新會員狀態失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

/* -------------------------------- 商品檢舉處理 -------------------------------- */

router.get('/reports', async (req, res) => {
  const status = req.query.status; // pending | reviewing | resolved | dismissed
  try {
    const reports = await prisma.reports.findMany({
      where: { ...(status && { status }) },
      orderBy: { created_at: 'desc' },
      include: {
        users_reports_reporter_idTousers: { select: { user_id: true, nickname: true, avatar_url: true } },
        users_reports_admin_idTousers: { select: { user_id: true, nickname: true } }
      }
    });

    // 補上被檢舉對象的摘要資訊
    const bookIds = reports.filter(r => r.target_type === 'book').map(r => r.target_id);
    const userIds = reports.filter(r => r.target_type === 'user').map(r => r.target_id);

    const [books, users] = await Promise.all([
      bookIds.length
        ? prisma.books.findMany({
            where: { book_id: { in: bookIds } },
            select: { book_id: true, title: true, price: true, status: true, book_images: { select: { image_url: true }, take: 1 } }
          })
        : [],
      userIds.length
        ? prisma.users.findMany({
            where: { user_id: { in: userIds } },
            select: { user_id: true, nickname: true, avatar_url: true }
          })
        : []
    ]);

    const bookMap = new Map(books.map(b => [b.book_id, b]));
    const userMap = new Map(users.map(u => [u.user_id, u]));

    const data = reports.map(r => ({
      ...r,
      target: r.target_type === 'book' ? bookMap.get(r.target_id) ?? null
        : r.target_type === 'user' ? userMap.get(r.target_id) ?? null
        : null
    }));

    res.status(200).json({ success: true, data });
  } catch (err) {
    console.error('[取得檢舉列表失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.patch('/reports/:id', async (req, res) => {
  const reportId = parseInt(req.params.id);
  const { status, admin_note, remove_target } = req.body;
  const allowed = ['reviewing', 'resolved', 'dismissed'];

  if (!allowed.includes(status)) {
    return res.status(400).json({ success: false, message: `status 僅接受：${allowed.join(', ')}` });
  }

  try {
    const report = await prisma.reports.findUnique({ where: { report_id: reportId } });
    if (!report) return res.status(404).json({ success: false, message: '找不到該檢舉' });

    const updated = await prisma.$transaction(async (tx) => {
      const r = await tx.reports.update({
        where: { report_id: reportId },
        data: {
          status,
          admin_id: req.user.userId,
          admin_note: admin_note ?? null,
          resolved_at: status === 'resolved' || status === 'dismissed' ? new Date() : null
        }
      });

      if (remove_target && report.target_type === 'book') {
        await tx.books.update({
          where: { book_id: report.target_id },
          data: { status: 'removed', is_approved: false, updated_at: new Date() }
        });
      }

      await tx.notifications.create({
        data: {
          user_id: report.reporter_id,
          type: 'system',
          title: '您的檢舉已處理',
          content: status === 'dismissed' ? '經審核後未違反社群規範，感謝您的回報。' : '感謝您的回報，我們已完成處理。',
          related_id: reportId,
          related_type: 'report'
        }
      });

      return r;
    });

    await logAction(req.user.userId, '處理商品檢舉', 'report', reportId, status);

    res.status(200).json({ success: true, message: '檢舉已處理', data: updated });
  } catch (err) {
    console.error('[處理檢舉失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

/* --------------------------------- 仲裁交易 --------------------------------- */

router.get('/disputes', async (req, res) => {
  const status = req.query.status; // pending | processing | resolved
  try {
    const disputes = await prisma.transaction_disputes.findMany({
      where: { ...(status && { status }) },
      orderBy: { created_at: 'desc' },
      include: {
        users_transaction_disputes_applicant_idTousers: { select: { user_id: true, nickname: true, avatar_url: true } },
        orders: {
          select: {
            order_id: true, order_no: true, total_amount: true, status: true,
            users_orders_buyer_idTousers: { select: { user_id: true, nickname: true } },
            users_orders_seller_idTousers: { select: { user_id: true, nickname: true } },
            order_items: {
              include: { books: { select: { title: true, book_images: { select: { image_url: true }, take: 1 } } } }
            }
          }
        }
      }
    });
    res.status(200).json({ success: true, data: disputes });
  } catch (err) {
    console.error('[取得爭議列表失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.patch('/disputes/:id', async (req, res) => {
  const disputeId = parseInt(req.params.id);
  const { result, admin_note } = req.body;
  const allowed = ['refund_manual', 'refund_auto', 'dismissed', 'mediated'];

  if (!allowed.includes(result)) {
    return res.status(400).json({ success: false, message: `result 僅接受：${allowed.join(', ')}` });
  }

  try {
    const dispute = await prisma.transaction_disputes.findUnique({
      where: { dispute_id: disputeId },
      include: { orders: true }
    });
    if (!dispute) return res.status(404).json({ success: false, message: '找不到該爭議案件' });

    const isRefund = result === 'refund_manual' || result === 'refund_auto';

    const updated = await prisma.$transaction(async (tx) => {
      const d = await tx.transaction_disputes.update({
        where: { dispute_id: disputeId },
        data: {
          status: 'resolved',
          result,
          admin_id: req.user.userId,
          admin_note: admin_note ?? null,
          resolved_at: new Date()
        }
      });

      if (isRefund) {
        await tx.refund_records.create({
          data: {
            order_id: dispute.order_id,
            dispute_id: disputeId,
            refund_type: result === 'refund_auto' ? 'auto' : 'manual',
            amount: dispute.orders.total_amount,
            status: 'completed',
            admin_id: req.user.userId,
            reason: admin_note ?? null,
            processed_at: new Date()
          }
        });

        await tx.orders.update({
          where: { order_id: dispute.order_id },
          data: { status: 'refunded', updated_at: new Date() }
        });
      } else {
        await tx.orders.update({
          where: { order_id: dispute.order_id },
          data: { status: 'completed', completed_at: new Date(), updated_at: new Date() }
        });
      }

      await tx.notifications.create({
        data: {
          user_id: dispute.applicant_id,
          type: 'order',
          title: '爭議案件已裁決',
          content: isRefund ? '已完成退款，款項將於數個工作天內入帳。' : '經審核後維持原交易結果。',
          related_id: dispute.order_id,
          related_type: 'order'
        }
      });

      return d;
    });

    await logAction(req.user.userId, '仲裁交易爭議', 'dispute', disputeId, result);

    res.status(200).json({ success: true, message: '爭議已裁決', data: updated });
  } catch (err) {
    console.error('[仲裁爭議失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

/* ------------------------------ 硬體維護／書櫃監控 ----------------------------- */

router.get('/cabinets', async (req, res) => {
  try {
    const cabinets = await prisma.smart_cabinets.findMany({
      orderBy: { cabinet_id: 'asc' },
      include: {
        cabinet_slots: { select: { slot_id: true, slot_number: true, status: true, updated_at: true } },
        _count: { select: { orders: true } }
      }
    });

    const data = cabinets.map(c => {
      const counts = { empty: 0, occupied: 0, reserved: 0, maintenance: 0 };
      c.cabinet_slots.forEach(s => { counts[s.status] += 1; });
      return { ...c, slot_summary: counts };
    });

    res.status(200).json({ success: true, data });
  } catch (err) {
    console.error('[取得書櫃列表失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.post('/cabinets', async (req, res) => {
  const { cabinet_name, address, latitude, longitude, total_slots, open_time, close_time } = req.body;

  if (!cabinet_name || !address || latitude === undefined || longitude === undefined) {
    return res.status(400).json({ success: false, message: '請填寫書櫃名稱、地址與座標' });
  }

  try {
    const slots = parseInt(total_slots) || 20;
    const cabinet = await prisma.smart_cabinets.create({
      data: {
        cabinet_name,
        address,
        latitude: parseFloat(latitude),
        longitude: parseFloat(longitude),
        total_slots: slots,
        available_slots: slots,
        open_time: open_time ? new Date(`1970-01-01T${open_time}Z`) : null,
        close_time: close_time ? new Date(`1970-01-01T${close_time}Z`) : null,
        cabinet_slots: {
          create: Array.from({ length: slots }, (_, i) => ({
            slot_number: `A${String(i + 1).padStart(2, '0')}`
          }))
        }
      },
      include: { cabinet_slots: true }
    });

    await logAction(req.user.userId, '新增書櫃', 'cabinet', cabinet.cabinet_id, cabinet_name);

    res.status(201).json({ success: true, message: '書櫃已新增', data: cabinet });
  } catch (err) {
    console.error('[新增書櫃失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.put('/cabinets/:id', async (req, res) => {
  const cabinetId = parseInt(req.params.id);
  const { cabinet_name, address, latitude, longitude, is_active, open_time, close_time } = req.body;

  try {
    const cabinet = await prisma.smart_cabinets.update({
      where: { cabinet_id: cabinetId },
      data: {
        cabinet_name, address,
        ...(latitude !== undefined && { latitude: parseFloat(latitude) }),
        ...(longitude !== undefined && { longitude: parseFloat(longitude) }),
        ...(is_active !== undefined && { is_active: !!is_active }),
        ...(open_time !== undefined && { open_time: open_time ? new Date(`1970-01-01T${open_time}Z`) : null }),
        ...(close_time !== undefined && { close_time: close_time ? new Date(`1970-01-01T${close_time}Z`) : null }),
        updated_at: new Date()
      }
    });

    await logAction(req.user.userId, '修改書櫃', 'cabinet', cabinetId, cabinet_name ?? '');

    res.status(200).json({ success: true, message: '書櫃已更新', data: cabinet });
  } catch (err) {
    if (err.code === 'P2025') return res.status(404).json({ success: false, message: '找不到該書櫃' });
    console.error('[修改書櫃失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.patch('/cabinets/:cabinetId/slots/:slotId', async (req, res) => {
  const slotId = parseInt(req.params.slotId);
  const status = req.body.status;
  const allowed = ['empty', 'occupied', 'reserved', 'maintenance'];

  if (!allowed.includes(status)) {
    return res.status(400).json({ success: false, message: `status 僅接受：${allowed.join(', ')}` });
  }

  try {
    const slot = await prisma.cabinet_slots.update({
      where: { slot_id: slotId },
      data: { status, updated_at: new Date() }
    });

    await logAction(req.user.userId, '變更櫃位狀態', 'cabinet_slot', slotId, `${slot.slot_number} -> ${status}`);

    res.status(200).json({ success: true, message: '櫃位狀態已更新', data: slot });
  } catch (err) {
    if (err.code === 'P2025') return res.status(404).json({ success: false, message: '找不到該櫃位' });
    console.error('[更新櫃位狀態失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

// 維修紀錄：書櫃／櫃位相關的管理員操作紀錄
router.get('/maintenance-logs', async (req, res) => {
  const page = parseInt(req.query.page) || 1;
  const limit = parseInt(req.query.limit) || 30;

  try {
    const where = { target_type: { in: ['cabinet', 'cabinet_slot'] } };
    const [logs, totalCount] = await Promise.all([
      prisma.admin_operation_logs.findMany({
        where,
        skip: (page - 1) * limit,
        take: limit,
        orderBy: { created_at: 'desc' },
        include: { users: { select: { user_id: true, nickname: true } } }
      }),
      prisma.admin_operation_logs.count({ where })
    ]);

    res.status(200).json({
      success: true,
      pagination: { total: totalCount, page, limit, total_pages: Math.ceil(totalCount / limit) },
      data: logs
    });
  } catch (err) {
    console.error('[取得維修紀錄失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

/* ---------------------------------- 總覽 ---------------------------------- */

router.get('/overview', async (req, res) => {
  try {
    const [members, pendingReports, pendingDisputes, cabinets, todayOrders] = await Promise.all([
      prisma.users.count(),
      prisma.reports.count({ where: { status: 'pending' } }),
      prisma.transaction_disputes.count({ where: { status: { in: ['pending', 'processing'] } } }),
      prisma.smart_cabinets.count({ where: { is_active: true } }),
      prisma.orders.count({ where: { created_at: { gte: new Date(new Date().setHours(0, 0, 0, 0)) } } })
    ]);

    res.status(200).json({
      success: true,
      data: {
        member_count: members,
        pending_report_count: pendingReports,
        pending_dispute_count: pendingDisputes,
        active_cabinet_count: cabinets,
        today_order_count: todayOrders
      }
    });
  } catch (err) {
    console.error('[取得管理總覽失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

module.exports = router;
