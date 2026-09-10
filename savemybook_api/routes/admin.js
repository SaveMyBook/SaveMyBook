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

router.get('/members', async (req, res) => {
  const keyword = req.query.keyword || '';
  const status = req.query.status;
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

router.get('/reports', async (req, res) => {
  const status = req.query.status;
  try {
    const reports = await prisma.reports.findMany({
      where: { ...(status && { status }) },
      orderBy: { created_at: 'desc' },
      include: {
        users_reports_reporter_idTousers: { select: { user_id: true, nickname: true, avatar_url: true } },
        users_reports_admin_idTousers: { select: { user_id: true, nickname: true } }
      }
    });

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
          title: '你的檢舉已處理',
          content: status === 'dismissed'
            ? '經審核後未違反社群規範，感謝你的回報。'
            : '感謝你的回報，我們已完成處理。',
          related_id: reportId,
          related_type: 'report'
        }
      });

      // 一併通知被檢舉的一方，讓對方知道審核結果
      let ownerId = null;
      if (report.target_type === 'book') {
        const book = await tx.books.findUnique({
          where: { book_id: report.target_id },
          select: { seller_id: true, title: true }
        });
        ownerId = book?.seller_id ?? null;
      } else if (report.target_type === 'user') {
        ownerId = report.target_id;
      }

      if (ownerId && ownerId !== report.reporter_id) {
        const resolved = status === 'resolved';
        await tx.notifications.create({
          data: {
            user_id: ownerId,
            type: 'system',
            title: resolved ? '檢舉審核結果：違規成立' : '檢舉審核結果：未違規',
            content: resolved
              ? (remove_target && report.target_type === 'book'
                  ? '經審核違規成立，該商品已被下架。如有疑問請聯絡客服。'
                  : '經審核違規成立，請留意社群規範，重複違規將影響帳號權益。')
              : '經審核後未違反社群規範，你的商品／帳號不受影響。',
            related_id: report.target_id,
            related_type: report.target_type
          }
        });
      }

      return r;
    });

    await logAction(req.user.userId, '處理商品檢舉', 'report', reportId, status);

    res.status(200).json({ success: true, message: '檢舉已處理', data: updated });
  } catch (err) {
    console.error('[處理檢舉失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.get('/disputes', async (req, res) => {
  const status = req.query.status;
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


// ---------- 訂單管理 ----------

const orderInclude = {
  users_orders_buyer_idTousers: { select: { user_id: true, nickname: true, avatar_url: true } },
  users_orders_seller_idTousers: { select: { user_id: true, nickname: true, avatar_url: true } },
  smart_cabinets: { select: { cabinet_id: true, cabinet_name: true, address: true } },
  order_items: {
    include: {
      books: {
        select: {
          book_id: true,
          title: true,
          book_images: { select: { image_url: true }, take: 1 }
        }
      }
    }
  }
};

const shapeOrder = (o) => ({
  order_id: o.order_id,
  order_no: o.order_no,
  status: o.status,
  total_amount: o.total_amount,
  created_at: o.created_at,
  completed_at: o.completed_at,
  cancelled_at: o.cancelled_at,
  cancel_reason: o.cancel_reason,
  pickup_code: o.pickup_code,
  buyer: o.users_orders_buyer_idTousers,
  seller: o.users_orders_seller_idTousers,
  cabinet: o.smart_cabinets,
  items: o.order_items.map((i) => ({
    book_id: i.books?.book_id ?? null,
    title: i.books?.title ?? '',
    unit_price: i.unit_price,
    subtotal: i.subtotal,
    quantity: i.quantity,
    image_url: i.books?.book_images[0]?.image_url ?? null
  }))
});

router.get('/orders', async (req, res) => {
  const keyword = (req.query.keyword || '').trim();
  const status = req.query.status;
  const page = parseInt(req.query.page) || 1;
  const limit = parseInt(req.query.limit) || 20;

  try {
    const where = {
      ...(status && status !== 'all' && { status }),
      ...(keyword && {
        OR: [
          { order_no: { contains: keyword } },
          { users_orders_buyer_idTousers: { nickname: { contains: keyword } } },
          { users_orders_seller_idTousers: { nickname: { contains: keyword } } }
        ]
      })
    };

    const [orders, total] = await Promise.all([
      prisma.orders.findMany({
        where,
        include: orderInclude,
        orderBy: { created_at: 'desc' },
        skip: (page - 1) * limit,
        take: limit
      }),
      prisma.orders.count({ where })
    ]);

    res.status(200).json({
      success: true,
      pagination: { total, page, limit, total_pages: Math.ceil(total / limit) },
      data: orders.map(shapeOrder)
    });
  } catch (err) {
    console.error('[取得訂單列表失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

const ORDER_STATUSES = [
  'pending_payment', 'pending_deposit', 'deposited', 'pending_pickup',
  'completed', 'cancelled', 'refunding', 'refunded'
];

router.patch('/orders/:id', async (req, res) => {
  const orderId = parseInt(req.params.id);
  const { status, note } = req.body;

  if (!ORDER_STATUSES.includes(status)) {
    return res.status(400).json({ success: false, message: '不支援的訂單狀態' });
  }

  try {
    const order = await prisma.orders.findUnique({ where: { order_id: orderId } });
    if (!order) return res.status(404).json({ success: false, message: '找不到這筆訂單' });

    const data = { status, updated_at: new Date() };
    if (status === 'completed') data.completed_at = new Date();
    if (status === 'cancelled') {
      data.cancelled_at = new Date();
      data.cancel_reason = note || '管理員手動取消';
    }

    await prisma.$transaction([
      prisma.orders.update({ where: { order_id: orderId }, data }),
      prisma.notifications.create({
        data: {
          user_id: order.buyer_id,
          type: 'order',
          title: '訂單狀態已更新',
          content: `訂單 ${order.order_no} 已由客服調整為「${status}」。${note ? `說明：${note}` : ''}`,
          related_id: orderId,
          related_type: 'order'
        }
      })
    ]);

    await logAction(req.user.userId, '調整訂單狀態', 'order', orderId, `${order.status} -> ${status}`);
    res.status(200).json({ success: true, message: '訂單狀態已更新' });
  } catch (err) {
    console.error('[調整訂單失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

// ---------- 書籍管理 ----------

router.get('/books', async (req, res) => {
  const keyword = (req.query.keyword || '').trim();
  const status = req.query.status;
  const page = parseInt(req.query.page) || 1;
  const limit = parseInt(req.query.limit) || 20;

  try {
    const where = {
      ...(status && status !== 'all' && { status }),
      ...(keyword && {
        OR: [
          { title: { contains: keyword } },
          { isbn: { contains: keyword } },
          { users: { nickname: { contains: keyword } } }
        ]
      })
    };

    const [books, total] = await Promise.all([
      prisma.books.findMany({
        where,
        include: {
          users: { select: { user_id: true, nickname: true, avatar_url: true } },
          book_categories: { select: { category_id: true, category_name: true } },
          book_images: { select: { image_url: true }, take: 1 }
        },
        orderBy: { created_at: 'desc' },
        skip: (page - 1) * limit,
        take: limit
      }),
      prisma.books.count({ where })
    ]);

    // reports 是 target_type + target_id 的多型設計，沒有指向 books 的關聯，
    // 所以待處理檢舉數要自己撈。
    const reportRows = books.length
      ? await prisma.reports.groupBy({
          by: ['target_id'],
          where: {
            target_type: 'book',
            status: 'pending',
            target_id: { in: books.map((b) => b.book_id) }
          },
          _count: { target_id: true }
        })
      : [];
    const reportCounts = Object.fromEntries(
      reportRows.map((r) => [r.target_id, r._count.target_id])
    );

    res.status(200).json({
      success: true,
      pagination: { total, page, limit, total_pages: Math.ceil(total / limit) },
      data: books.map((b) => ({
        book_id: b.book_id,
        pending_report_count: reportCounts[b.book_id] ?? 0,
        title: b.title,
        isbn: b.isbn,
        price: b.price,
        status: b.status,
        condition_level: b.condition_level,
        view_count: b.view_count,
        created_at: b.created_at,
        seller: b.users,
        category_name: b.book_categories?.category_name ?? '',
        image_url: b.book_images[0]?.image_url ?? null
      }))
    });
  } catch (err) {
    console.error('[取得書籍列表失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.patch('/books/:id', async (req, res) => {
  const bookId = parseInt(req.params.id);
  const { status, reason } = req.body;

  if (!['on_sale', 'removed'].includes(status)) {
    return res.status(400).json({ success: false, message: '只能設定為上架或下架' });
  }

  try {
    const book = await prisma.books.findUnique({ where: { book_id: bookId } });
    if (!book) return res.status(404).json({ success: false, message: '找不到這本書' });

    await prisma.$transaction([
      prisma.books.update({
        where: { book_id: bookId },
        data: { status, updated_at: new Date() }
      }),
      prisma.notifications.create({
        data: {
          user_id: book.seller_id,
          type: 'system',
          title: status === 'removed' ? '您的書籍已被下架' : '您的書籍已恢復上架',
          content: status === 'removed'
            ? `《${book.title}》已由管理員下架。${reason ? `原因：${reason}` : ''}`
            : `《${book.title}》已由管理員恢復上架。`,
          related_id: bookId,
          related_type: 'book'
        }
      })
    ]);

    await logAction(
      req.user.userId,
      status === 'removed' ? '強制下架書籍' : '恢復書籍上架',
      'book',
      bookId,
      reason || null
    );
    res.status(200).json({ success: true, message: status === 'removed' ? '已下架' : '已恢復上架' });
  } catch (err) {
    console.error('[調整書籍狀態失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

// ---------- 分類管理 ----------

router.get('/categories', async (req, res) => {
  try {
    const categories = await prisma.book_categories.findMany({
      orderBy: [{ sort_order: 'asc' }, { category_id: 'asc' }],
      include: { _count: { select: { books: true } } }
    });

    res.status(200).json({
      success: true,
      data: categories.map((c) => ({
        category_id: c.category_id,
        category_name: c.category_name,
        sort_order: c.sort_order,
        book_count: c._count.books
      }))
    });
  } catch (err) {
    console.error('[取得分類失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.post('/categories', async (req, res) => {
  const name = (req.body.category_name || '').trim();
  const sortOrder = parseInt(req.body.sort_order) || 0;

  if (!name) return res.status(400).json({ success: false, message: '請輸入分類名稱' });
  if (name.length > 50) return res.status(400).json({ success: false, message: '分類名稱不可超過 50 字' });

  try {
    const created = await prisma.book_categories.create({
      data: { category_name: name, sort_order: sortOrder }
    });
    await logAction(req.user.userId, '新增分類', 'category', created.category_id, name);
    res.status(201).json({ success: true, data: { category_id: created.category_id } });
  } catch (err) {
    console.error('[新增分類失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.put('/categories/:id', async (req, res) => {
  const categoryId = parseInt(req.params.id);
  const name = (req.body.category_name || '').trim();
  const sortOrder = parseInt(req.body.sort_order) || 0;

  if (!name) return res.status(400).json({ success: false, message: '請輸入分類名稱' });

  try {
    await prisma.book_categories.update({
      where: { category_id: categoryId },
      data: { category_name: name, sort_order: sortOrder }
    });
    await logAction(req.user.userId, '編輯分類', 'category', categoryId, name);
    res.status(200).json({ success: true, message: '已更新分類' });
  } catch (err) {
    console.error('[編輯分類失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.delete('/categories/:id', async (req, res) => {
  const categoryId = parseInt(req.params.id);

  try {
    // 還有書掛在底下就不能刪，否則那些書會變成沒有分類。
    const inUse = await prisma.books.count({ where: { category_id: categoryId } });
    if (inUse > 0) {
      return res.status(400).json({
        success: false,
        message: `還有 ${inUse} 本書屬於這個分類，請先調整後再刪除`
      });
    }

    await prisma.book_categories.delete({ where: { category_id: categoryId } });
    await logAction(req.user.userId, '刪除分類', 'category', categoryId, null);
    res.status(200).json({ success: true, message: '已刪除分類' });
  } catch (err) {
    console.error('[刪除分類失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

// ---------- 會員等級管理 ----------

router.get('/levels', async (req, res) => {
  try {
    const levels = await prisma.member_levels.findMany({ orderBy: { min_points: 'asc' } });
    res.status(200).json({ success: true, data: levels });
  } catch (err) {
    console.error('[取得會員等級失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

const parseLevelBody = (body) => ({
  level_name: (body.level_name || '').trim(),
  min_points: parseInt(body.min_points) || 0,
  max_points: body.max_points === null || body.max_points === '' || body.max_points === undefined
    ? null
    : parseInt(body.max_points),
  benefits: (body.benefits || '').trim() || null
});

router.post('/levels', async (req, res) => {
  const data = parseLevelBody(req.body);
  if (!data.level_name) return res.status(400).json({ success: false, message: '請輸入等級名稱' });

  try {
    const created = await prisma.member_levels.create({ data });
    await logAction(req.user.userId, '新增會員等級', 'level', created.level_id, data.level_name);
    res.status(201).json({ success: true, data: { level_id: created.level_id } });
  } catch (err) {
    console.error('[新增會員等級失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.put('/levels/:id', async (req, res) => {
  const levelId = parseInt(req.params.id);
  const data = parseLevelBody(req.body);
  if (!data.level_name) return res.status(400).json({ success: false, message: '請輸入等級名稱' });

  try {
    await prisma.member_levels.update({ where: { level_id: levelId }, data });
    await logAction(req.user.userId, '編輯會員等級', 'level', levelId, data.level_name);
    res.status(200).json({ success: true, message: '已更新等級' });
  } catch (err) {
    console.error('[編輯會員等級失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.delete('/levels/:id', async (req, res) => {
  const levelId = parseInt(req.params.id);
  try {
    await prisma.member_levels.delete({ where: { level_id: levelId } });
    await logAction(req.user.userId, '刪除會員等級', 'level', levelId, null);
    res.status(200).json({ success: true, message: '已刪除等級' });
  } catch (err) {
    console.error('[刪除會員等級失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

// ---------- 營運報表 ----------

router.get('/stats', async (req, res) => {
  const days = Math.min(Math.max(parseInt(req.query.days) || 7, 1), 90);

  try {
    const since = new Date();
    since.setHours(0, 0, 0, 0);
    since.setDate(since.getDate() - (days - 1));

    const [orders, newUsers, newBooks, completed, topCategories] = await Promise.all([
      prisma.orders.findMany({
        where: { created_at: { gte: since } },
        select: { created_at: true, total_amount: true, status: true }
      }),
      prisma.users.findMany({
        where: { created_at: { gte: since } },
        select: { created_at: true }
      }),
      prisma.books.findMany({
        where: { created_at: { gte: since } },
        select: { created_at: true }
      }),
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
    const series = [];
    for (let i = 0; i < days; i += 1) {
      const day = new Date(since);
      day.setDate(since.getDate() + i);
      const k = key(day);
      series.push({
        date: k,
        orders: orders.filter((o) => key(o.created_at) === k).length,
        revenue: orders
          .filter((o) => key(o.created_at) === k)
          .reduce((sum, o) => sum + Number(o.total_amount), 0),
        new_users: newUsers.filter((u) => key(u.created_at) === k).length,
        new_books: newBooks.filter((b) => key(b.created_at) === k).length
      });
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
          category_name:
            categories.find((c) => c.category_id === t.category_id)?.category_name ?? '未分類',
          book_count: t._count.category_id
        }))
      }
    });
  } catch (err) {
    console.error('[取得營運報表失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

// ---------- 操作紀錄 ----------

router.get('/operation-logs', async (req, res) => {
  const page = parseInt(req.query.page) || 1;
  const limit = parseInt(req.query.limit) || 50;

  try {
    const [logs, total] = await Promise.all([
      prisma.admin_operation_logs.findMany({
        include: { users: { select: { user_id: true, nickname: true, avatar_url: true } } },
        orderBy: { created_at: 'desc' },
        skip: (page - 1) * limit,
        take: limit
      }),
      prisma.admin_operation_logs.count()
    ]);

    res.status(200).json({
      success: true,
      pagination: { total, page, limit, total_pages: Math.ceil(total / limit) },
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
  } catch (err) {
    console.error('[取得操作紀錄失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});


// ---------- 錢包管理 ----------

const walletUserSelect = { user_id: true, nickname: true, avatar_url: true, email: true };

router.get('/wallets', async (req, res) => {
  const keyword = (req.query.keyword || '').trim();
  const page = parseInt(req.query.page) || 1;
  const limit = parseInt(req.query.limit) || 30;

  try {
    const where = keyword
      ? {
          OR: [
            { nickname: { contains: keyword } },
            { email: { contains: keyword } }
          ]
        }
      : {};

    const [users, total] = await Promise.all([
      prisma.users.findMany({
        where,
        select: { ...walletUserSelect, wallets: true },
        orderBy: { user_id: 'asc' },
        skip: (page - 1) * limit,
        take: limit
      }),
      prisma.users.count({ where })
    ]);

    res.status(200).json({
      success: true,
      pagination: { total, page, limit, total_pages: Math.ceil(total / limit) },
      data: users.map((u) => ({
        user_id: u.user_id,
        nickname: u.nickname,
        email: u.email,
        avatar_url: u.avatar_url,
        // 沒有錢包的人視為 0，前端不用另外處理 null。
        balance: u.wallets?.balance ?? 0,
        frozen_amount: u.wallets?.frozen_amount ?? 0,
        total_income: u.wallets?.total_income ?? 0,
        total_expense: u.wallets?.total_expense ?? 0
      }))
    });
  } catch (err) {
    console.error('[取得錢包列表失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.get('/wallets/:userId', async (req, res) => {
  const userId = parseInt(req.params.userId);

  try {
    const user = await prisma.users.findUnique({
      where: { user_id: userId },
      select: { ...walletUserSelect, wallets: true }
    });
    if (!user) return res.status(404).json({ success: false, message: '找不到這位會員' });

    const transactions = user.wallets
      ? await prisma.wallet_transactions.findMany({
          where: { wallet_id: user.wallets.wallet_id },
          orderBy: { created_at: 'desc' },
          take: 50
        })
      : [];

    res.status(200).json({
      success: true,
      data: {
        user_id: user.user_id,
        nickname: user.nickname,
        email: user.email,
        avatar_url: user.avatar_url,
        balance: user.wallets?.balance ?? 0,
        frozen_amount: user.wallets?.frozen_amount ?? 0,
        total_income: user.wallets?.total_income ?? 0,
        total_expense: user.wallets?.total_expense ?? 0,
        transactions
      }
    });
  } catch (err) {
    console.error('[取得錢包明細失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.post('/wallets/:userId/adjust', async (req, res) => {
  const userId = parseInt(req.params.userId);
  const amount = parseFloat(req.body.amount);
  const description = (req.body.description || '').trim();

  if (!Number.isFinite(amount) || amount === 0) {
    return res.status(400).json({ success: false, message: '請輸入非零的調整金額' });
  }
  if (Math.abs(amount) > 1000000) {
    return res.status(400).json({ success: false, message: '單次調整不可超過 1,000,000' });
  }
  if (!description) {
    return res.status(400).json({ success: false, message: '請填寫調整原因，這會寫進帳務紀錄' });
  }

  try {
    const user = await prisma.users.findUnique({
      where: { user_id: userId },
      select: { user_id: true, nickname: true, wallets: true }
    });
    if (!user) return res.status(404).json({ success: false, message: '找不到這位會員' });

    const result = await prisma.$transaction(async (tx) => {
      // 沒有錢包的會員先幫他開一個，否則無法調整。
      const wallet = user.wallets ??
        (await tx.wallets.create({ data: { user_id: userId, balance: 0 } }));

      const current = Number(wallet.balance);
      const next = current + amount;
      if (next < 0) throw new Error('INSUFFICIENT');

      const updated = await tx.wallets.update({
        where: { wallet_id: wallet.wallet_id },
        data: {
          balance: next,
          total_income: amount > 0
            ? { increment: amount }
            : undefined,
          total_expense: amount < 0
            ? { increment: Math.abs(amount) }
            : undefined,
          updated_at: new Date()
        }
      });

      await tx.wallet_transactions.create({
        data: {
          wallet_id: wallet.wallet_id,
          type: 'admin_adjust',
          amount,
          balance_after: next,
          description: `管理員調整：${description}`
        }
      });

      await tx.notifications.create({
        data: {
          user_id: userId,
          type: 'system',
          title: amount > 0 ? '代幣已入帳' : '代幣已扣除',
          content: `客服調整了您的代幣 ${amount > 0 ? '+' : ''}${amount}，餘額 ${next}。原因：${description}`,
          related_type: 'wallet'
        }
      });

      return updated;
    });

    await logAction(
      req.user.userId,
      '調整會員錢包',
      'wallet',
      userId,
      `${amount > 0 ? '+' : ''}${amount}｜${description}`
    );

    res.status(200).json({
      success: true,
      message: '已調整餘額',
      data: { balance: result.balance }
    });
  } catch (err) {
    if (err instanceof Error && err.message === 'INSUFFICIENT') {
      return res.status(400).json({ success: false, message: '調整後餘額會變成負數，請確認金額' });
    }
    console.error('[調整錢包失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

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
