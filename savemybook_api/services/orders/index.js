const prisma = require('../../lib/prisma');
const { badRequest, forbidden, notFound, conflict } = require('../../lib/errors');
const { ORDER_FINAL_STATUSES } = require('../../constants/domain');
const { notify } = require('../notify');
const { withTxnNo } = require('../wallet');
const audit = require('../audit');
const settlement = require('./settlement');
const { checkout } = require('./checkout');
const { orderInclude, adminOrderInclude } = require('./selects');

const { transition, describeSettlement, statusLabel } = settlement;

const IN_CABINET = ['deposited', 'pending_pickup'];
const PRE_DEPOSIT = ['pending_payment', 'pending_deposit'];

// 買家取書後訂單仍是「已存書」（picked_up_at 有值），等買家完成訂單或 24 小時後才撥款；
// 買家端把這類訂單放在「已完成」分頁，賣家端留在「已存書」分頁並標示待買家確認。
const AWAITING_CONFIRM = { status: { in: IN_CABINET }, picked_up_at: { not: null } };

const BUYER_TABS = {
  pending_pickup: { status: { in: [...PRE_DEPOSIT, ...IN_CABINET] }, picked_up_at: null },
  completed: { OR: [{ status: 'completed' }, AWAITING_CONFIRM] },
  cancelled: { status: { in: ['cancelled', 'refunded'] } },
  disputing: { status: 'refunding' }
};

const SELLER_TABS = {
  pending_deposit: { status: { in: PRE_DEPOSIT } },
  deposited: { status: { in: IN_CABINET } },
  // 舊版 App 的「販售中」分頁會帶 on_sale，維持回傳已存書的訂單。
  on_sale: { status: { in: IN_CABINET } },
  cancelled: { status: { in: ['cancelled', 'refunded'] } },
  completed: { status: 'completed' }
};

const tabFilter = (role, tab) => (role === 'seller' ? SELLER_TABS : BUYER_TABS)[tab];

const listForUser = async (userId, { role, filter, skip, limit }) => {
  const where = {
    ...(role === 'seller' ? { seller_id: userId } : { buyer_id: userId }),
    ...(filter ?? {})
  };

  const [list, total] = await Promise.all([
    prisma.orders.findMany({
      where,
      skip,
      take: limit,
      orderBy: { created_at: 'desc' },
      include: orderInclude,
      // 舊訂單的資料列仍保留取書碼欄位，但取書已改為掃描機台 QR Code，不得再回傳。
      omit: { pickup_code: true }
    }),
    prisma.orders.count({ where })
  ]);
  return { list, total };
};

const isParty = (order, user) =>
  order.buyer_id === user.userId || order.seller_id === user.userId || user.role === 'admin';

const findForParty = async (orderId, user, include) => {
  const order = await prisma.orders.findUnique({ where: { order_id: orderId }, include });
  if (!order) throw notFound('找不到該訂單');
  if (!isParty(order, user)) throw forbidden('存取被拒');
  return order;
};

const detailForParty = (orderId, user) => findForParty(orderId, user, orderInclude);

const cancel = async (orderId, user, reason) => {
  const order = await findForParty(orderId, user, { order_items: true });
  const isAdmin = user.role === 'admin';

  if (ORDER_FINAL_STATUSES.includes(order.status)) throw badRequest('此訂單狀態無法取消');
  // 爭議中的訂單由仲裁決定退款，當事人不能自行取消。
  if (order.status === 'refunding' && !isAdmin) {
    throw badRequest('此訂單爭議處理中，無法自行取消，請等候客服裁決');
  }
  // 書已放進書櫃後雙方都不能自行取消，有問題須提出申訴，避免書在買家手上卻被退款。
  if (!isAdmin && !PRE_DEPOSIT.includes(order.status)) {
    throw badRequest('賣家已存書，無法取消訂單；如有問題請提出申訴', 'ORDER_NOT_CANCELLABLE');
  }

  return prisma.$transaction(async (tx) => {
    const money = await transition(tx, order, 'cancelled', { cancelReason: reason });

    if (money.refunded > 0) {
      await notify(tx, {
        userId: order.buyer_id,
        type: 'order',
        title: '訂單已退款',
        content: `訂單 ${order.order_no} 已取消，${money.refunded} 代幣已退回您的帳戶。`,
        relatedId: orderId,
        relatedType: 'order'
      });
    }

    await notify(tx, {
      userId: user.userId === order.buyer_id ? order.seller_id : order.buyer_id,
      type: 'order',
      title: '訂單已取消',
      content: `訂單 ${order.order_no} 已取消。${reason ? `原因：${reason}` : ''}`,
      relatedId: orderId,
      relatedType: 'order'
    });

    return tx.orders.findUnique({ where: { order_id: orderId }, include: orderInclude });
  });
};

// 過去任一方都能重複設成 completed，每次都會再入帳一次。
// picked_up 只記錄取書時間，不撥款；completed 由買家完成訂單（或排程於取書 24 小時後）才撥款給賣家。
const TRANSITIONS = {
  deposited: {
    from: ['pending_payment', 'pending_deposit'],
    by: 'seller',
    wrongState: '此訂單目前非待存書狀態'
  },
  pending_pickup: {
    from: ['deposited'],
    by: 'seller',
    wrongState: '賣家尚未存書，無法改為待取書'
  },
  picked_up: {
    from: IN_CABINET,
    by: 'buyer',
    wrongState: '賣家尚未存書，無法確認取書'
  },
  completed: {
    from: IN_CABINET,
    by: 'buyer',
    wrongState: '賣家尚未存書，無法完成訂單'
  }
};

const CONFIRM_WINDOW_HOURS = 24;

const notifyPickedUp = (tx, order) => notify(tx, {
  userId: order.seller_id,
  type: 'order',
  title: '買家已取書',
  content: `訂單 ${order.order_no} 的書籍已由買家取走，買家完成訂單或取書滿 ${CONFIRM_WINDOW_HOURS} 小時後，款項將撥入您的錢包。`,
  relatedId: order.order_id,
  relatedType: 'order'
});

const notifyCompleted = (tx, order, money, { auto = false } = {}) => Promise.all([
  notify(tx, {
    userId: order.seller_id,
    type: 'order',
    title: '訂單已完成',
    content: money.paidOut > 0
      ? `訂單 ${order.order_no} 已完成，${money.paidOut} 代幣已撥入您的錢包。`
      : `訂單 ${order.order_no} 已完成。`,
    relatedId: order.order_id,
    relatedType: 'order'
  }),
  auto && notify(tx, {
    userId: order.buyer_id,
    type: 'order',
    title: '訂單已自動完成',
    content: `訂單 ${order.order_no} 取書已滿 ${CONFIRM_WINDOW_HOURS} 小時且未提出申訴，已自動完成。`,
    relatedId: order.order_id,
    relatedType: 'order'
  })
]);

const markPickedUp = async (tx, order) => {
  const result = await tx.orders.updateMany({
    where: { order_id: order.order_id, status: order.status, picked_up_at: null },
    data: { picked_up_at: new Date(), updated_at: new Date() }
  });
  if (result.count === 0) throw conflict('訂單狀態已變更，請重新整理後再試');
  await notifyPickedUp(tx, order);
};

const advance = async (orderId, status, user) => {
  const rule = TRANSITIONS[status];
  const order = await findForParty(orderId, user, { order_items: true });

  const isAdmin = user.role === 'admin';
  const actorId = rule.by === 'seller' ? order.seller_id : order.buyer_id;
  if (!isAdmin && user.userId !== actorId) {
    throw forbidden(rule.by === 'seller' ? '僅賣家可執行此操作' : '僅買家可確認取書或完成訂單');
  }
  if (order.status === status) throw conflict('訂單已是此狀態');
  if (!rule.from.includes(order.status)) throw badRequest(rule.wrongState);
  if (status === 'picked_up' && order.picked_up_at) throw conflict('已確認取書');

  // 舊版 App 在買家取書時直接送 completed；尚未確認取書時一律視為取書，不撥款。
  const pickupOnly = status === 'picked_up' || (status === 'completed' && !order.picked_up_at);

  return prisma.$transaction(async (tx) => {
    if (pickupOnly) {
      await markPickedUp(tx, order);
      return tx.orders.findUnique({ where: { order_id: orderId }, include: orderInclude });
    }

    const money = await transition(tx, order, status);
    const updated = await tx.orders.findUnique({ where: { order_id: orderId }, include: orderInclude });

    if (status === 'deposited' || status === 'pending_pickup') {
      const cabinet = updated.smart_cabinets?.cabinet_name;
      await notify(tx, {
        userId: order.buyer_id,
        type: 'order',
        title: '書籍已存入書櫃',
        content: `訂單 ${order.order_no} 的書籍已存入${cabinet ? `「${cabinet}」` : ''}書櫃，請前往書櫃掃描機台上的 QR Code 取書。`,
        relatedId: orderId,
        relatedType: 'order'
      });
    }
    if (status === 'completed') await notifyCompleted(tx, order, money);

    return updated;
  });
};

// ---------- 排程：自動完成與逾期取消 ----------

const DEPOSIT_DAYS = 7;
const PICKUP_DAYS = 7;
const BATCH = 100;

const hoursAgo = (h, now) => new Date(now.getTime() - h * 60 * 60 * 1000);

// 每筆訂單各自一個交易：單筆失敗（例如狀態剛被使用者變更）不影響其他訂單。
const eachOrder = async (where, handler) => {
  const due = await prisma.orders.findMany({ where, include: { order_items: true }, take: BATCH, orderBy: { order_id: 'asc' } });
  let done = 0;
  for (const order of due) {
    try {
      await prisma.$transaction((tx) => handler(tx, order));
      done += 1;
    } catch (err) {
      if (err.status !== 409) console.error(`[訂單 ${order.order_no} 自動處理失敗]:`, err.message);
    }
  }
  return done;
};

const completeDue = (now = new Date()) => eachOrder(
  { status: { in: IN_CABINET }, picked_up_at: { not: null, lte: hoursAgo(CONFIRM_WINDOW_HOURS, now) } },
  async (tx, order) => {
    const money = await transition(tx, order, 'completed');
    await notifyCompleted(tx, order, money, { auto: true });
  }
);

const cancelOverdue = async (tx, order, { reason, buyerContent, sellerContent }) => {
  const money = await transition(tx, order, 'cancelled', { cancelReason: reason, restoreBookTo: 'removed' });
  await notify(tx, {
    userId: order.buyer_id,
    type: 'order',
    title: '訂單已取消',
    content: `${buyerContent}${money.refunded > 0 ? `${money.refunded} 代幣已退回您的錢包。` : ''}`,
    relatedId: order.order_id,
    relatedType: 'order'
  });
  await notify(tx, {
    userId: order.seller_id,
    type: 'order',
    title: '訂單已取消',
    content: sellerContent,
    relatedId: order.order_id,
    relatedType: 'order'
  });
};

const cancelUndeposited = (now = new Date()) => eachOrder(
  { status: { in: PRE_DEPOSIT }, created_at: { lte: hoursAgo(DEPOSIT_DAYS * 24, now) } },
  (tx, order) => cancelOverdue(tx, order, {
    reason: `賣家逾 ${DEPOSIT_DAYS} 天未存書`,
    buyerContent: `訂單 ${order.order_no} 的賣家逾 ${DEPOSIT_DAYS} 天未存書，訂單已自動取消，`,
    sellerContent: `訂單 ${order.order_no} 逾 ${DEPOSIT_DAYS} 天未存書，已自動取消，書籍已改為下架，如需販售請重新上架。`
  })
);

const cancelUncollected = (now = new Date()) => eachOrder(
  { status: { in: IN_CABINET }, picked_up_at: null, deposited_at: { lte: hoursAgo(PICKUP_DAYS * 24, now) } },
  (tx, order) => cancelOverdue(tx, order, {
    reason: `買家逾 ${PICKUP_DAYS} 天未取書`,
    buyerContent: `訂單 ${order.order_no} 存書後逾 ${PICKUP_DAYS} 天未取書，訂單已自動取消，`,
    sellerContent: `訂單 ${order.order_no} 的買家逾 ${PICKUP_DAYS} 天未取書，訂單已自動取消，請至書櫃取回書籍；書籍已改為下架，如需販售請重新上架。`
  })
);

const runAutomation = async (now = new Date()) => ({
  completed: await completeDue(now),
  undeposited: await cancelUndeposited(now),
  uncollected: await cancelUncollected(now)
});

const shapeAdminOrder = (o) => ({
  order_id: o.order_id,
  order_no: o.order_no,
  status: o.status,
  total_amount: o.total_amount,
  created_at: o.created_at,
  completed_at: o.completed_at,
  cancelled_at: o.cancelled_at,
  cancel_reason: o.cancel_reason,
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

const adminList = async ({ keyword, status, skip, limit }) => {
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
    prisma.orders.findMany({ where, include: adminOrderInclude, orderBy: { created_at: 'desc' }, skip, take: limit }),
    prisma.orders.count({ where })
  ]);
  return { orders: orders.map(shapeAdminOrder), total };
};

const adminDetail = async (orderId) => {
  const order = await prisma.orders.findUnique({
    where: { order_id: orderId },
    include: {
      ...adminOrderInclude,
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

  if (!order) throw notFound('找不到此訂單');

  return {
    ...shapeAdminOrder(order),
    payment_method: order.payment_method,
    note: order.note,
    slot: order.cabinet_slots,
    updated_at: order.updated_at,
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
    wallet_transactions: order.wallet_transactions.map(withTxnNo)
  };
};

const adminChangeStatus = async (orderId, status, note, { adminId, req }) => {
  const order = await prisma.orders.findUnique({ where: { order_id: orderId }, include: { order_items: true } });
  if (!order) throw notFound('找不到此訂單');
  settlement.assertAdminTransition(order.status, status);

  let money;
  try {
    money = await prisma.$transaction(async (tx) => {
      const result = await transition(tx, order, status, { cancelReason: note || '管理員手動取消' });
      const effect = describeSettlement(result);
      const content = `訂單 ${order.order_no} 已由客服調整為「${statusLabel(status)}」。`
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
    if (err.status === 409) throw conflict('訂單狀態已被其他人變更，請重新整理後再試');
    throw err;
  }

  const effect = describeSettlement(money);
  // 涉及金流的變更不提供一鍵還原，否則等於重新扣款或撥款。
  await audit.record(null, {
    adminId,
    action: '調整訂單狀態',
    targetType: 'order',
    targetId: orderId,
    summary: `將訂單 ${order.order_no} 從「${statusLabel(order.status)}」改為「${statusLabel(status)}」`
      + `${effect ? `，${effect}` : ''}${note ? `。說明：${note}` : ''}`,
    changes: [{ label: '訂單狀態', from: statusLabel(order.status), to: statusLabel(status) }],
    req
  });
  return { money, effect };
};

module.exports = {
  TRANSITIONS, CONFIRM_WINDOW_HOURS, DEPOSIT_DAYS, PICKUP_DAYS, tabFilter, listForUser, detailForParty, checkout, cancel, advance,
  completeDue, cancelUndeposited, cancelUncollected, runAutomation, adminList, adminDetail, adminChangeStatus
};
