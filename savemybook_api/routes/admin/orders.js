const express = require('express');
const prisma = require('../../lib/prisma');
const requireAdmin = require('../../middleware/requireAdmin');
const v = require('../../lib/validate');
const { notFound, conflict } = require('../../lib/errors');
const { ORDER_STATUSES } = require('../../constants/domain');
const orderFlow = require('../../services/orders');
const { notify } = require('../../services/notify');
const { logAction } = require('../../services/audit');

const router = express.Router();
const canManage = requireAdmin('orders');

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

router.get('/orders', canManage, async (req, res) => {
  const keyword = v.text(req.query.keyword, { label: '關鍵字', max: 100 });
  const status = req.query.status;
  const { page, limit, skip } = v.pagination(req.query);

  if (status && status !== 'all') v.oneOf(status, ORDER_STATUSES, '不支援的訂單狀態');

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
    prisma.orders.findMany({ where, include: orderInclude, orderBy: { created_at: 'desc' }, skip, take: limit }),
    prisma.orders.count({ where })
  ]);

  res.status(200).json({
    success: true,
    pagination: v.pageMeta(total, { page, limit }),
    data: orders.map(shapeOrder)
  });
});

/// 單筆訂單的完整樣貌：時間軸、櫃位、金額、退款與申訴。
///
/// 列表為了輕量只帶摘要，但客服在處理一筆爭議時要看的就是這些細節——
/// 錢什麼時候扣的、書放進哪一格、有沒有退過款、對方申訴了什麼。
router.get('/orders/:id', canManage, async (req, res) => {
  const orderId = v.id(req.params.id, '訂單編號');

  const order = await prisma.orders.findUnique({
    where: { order_id: orderId },
    include: {
      ...orderInclude,
      cabinet_slots: { select: { slot_id: true, slot_number: true, status: true } },
      refund_records: {
        select: {
          refund_id: true, refund_type: true, amount: true, reason: true,
          status: true, created_at: true, processed_at: true
        },
        orderBy: { created_at: 'desc' }
      },
      transaction_disputes: {
        select: {
          dispute_id: true, reason: true, status: true, result: true,
          admin_note: true, created_at: true, resolved_at: true
        },
        orderBy: { created_at: 'desc' }
      },
      wallet_transactions: {
        select: { txn_id: true, type: true, amount: true, balance_after: true, description: true, created_at: true },
        orderBy: { created_at: 'asc' }
      }
    }
  });

  if (!order) throw notFound('找不到這筆訂單');

  res.status(200).json({
    success: true,
    data: {
      ...shapeOrder(order),
      payment_method: order.payment_method,
      note: order.note,
      slot: order.cabinet_slots,
      updated_at: order.updated_at,
      // 時間軸讓客服一眼看出卡在哪一步。null 代表還沒走到。
      timeline: {
        created_at: order.created_at,
        payment_at: order.payment_at,
        deposited_at: order.deposited_at,
        picked_up_at: order.picked_up_at,
        completed_at: order.completed_at,
        cancelled_at: order.cancelled_at
      },
      refunds: order.refund_records,
      disputes: order.transaction_disputes,
      wallet_transactions: order.wallet_transactions
    }
  });
});

/// 客服手動改狀態與使用者操作走同一套結算：改成已完成會撥款給賣家，
/// 改成已取消／已退款會退款給買家（必要時先向賣家收回貨款）。
router.patch('/orders/:id', canManage, async (req, res) => {
  const orderId = v.id(req.params.id, '訂單編號');
  const status = v.oneOf(req.body.status, ORDER_STATUSES, '不支援的訂單狀態');
  const note = v.optionalText(req.body.note, { label: '說明', max: 500 }) ?? null;

  const order = await prisma.orders.findUnique({ where: { order_id: orderId }, include: { order_items: true } });
  if (!order) throw notFound('找不到這筆訂單');
  orderFlow.assertAdminTransition(order.status, status);

  let money;
  try {
    money = await prisma.$transaction(async (tx) => {
      const result = await orderFlow.transition(tx, order, status, { cancelReason: note || '管理員手動取消' });
      const effect = orderFlow.describeSettlement(result);
      const content = `訂單 ${order.order_no} 已由客服調整為「${orderFlow.statusLabel(status)}」。`
        + `${effect ? `${effect}。` : ''}${note ? `說明：${note}` : ''}`;

      for (const userId of [order.buyer_id, order.seller_id]) {
        await notify(tx, {
          userId,
          type: 'order',
          title: '訂單狀態已更新',
          content,
          relatedId: orderId,
          relatedType: 'order'
        });
      }
      return result;
    });
  } catch (err) {
    if (err.status === 409) throw conflict('訂單狀態剛剛被其他人變更了，請重新整理後再試');
    throw err;
  }

  const effect = orderFlow.describeSettlement(money);
  await logAction(req.user.userId, '調整訂單狀態', 'order', orderId,
    `${order.status} -> ${status}${effect ? `｜${effect}` : ''}`);
  res.status(200).json({
    success: true,
    message: effect ? `訂單狀態已更新，${effect}` : '訂單狀態已更新',
    data: { paid_out: money.paidOut, clawed_back: money.clawedBack, refunded: money.refunded }
  });
});

module.exports = router;
