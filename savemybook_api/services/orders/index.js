const prisma = require('../../lib/prisma');
const { badRequest, forbidden, notFound, conflict } = require('../../lib/errors');
const { ORDER_FINAL_STATUSES, ORDER_NO_SOURCE } = require('../../constants/domain');
const policy = require('../../constants/policy');
const { notify } = require('../notify');
const { withTxnNo } = require('../wallet');
const audit = require('../audit');
const settlement = require('./settlement');
const { checkout, buyNow } = require('./checkout');
const { orderInclude, adminOrderInclude } = require('./selects');
const cabinetAccess = require('../cabinet-access');
const doors = require('../cabinet-doors');

const cabinetRelease = () => require('../cabinet-release');
const cabinetManual = () => require('../cabinet-manual');

const { transition, describeSettlement, storedNotice, statusLabel } = settlement;

const IN_CABINET = ['deposited', 'pending_pickup'];
const PRE_DEPOSIT = ['pending_payment', 'pending_deposit'];

// 買家取書後訂單仍是「已存書」（picked_up_at 有值），等買家完成訂單或 24 小時後才撥款。
const AWAITING_CONFIRM = { status: { in: IN_CABINET }, picked_up_at: { not: null } };

const STAGE_TABS = {
  awaiting_deposit: { status: { in: PRE_DEPOSIT } },
  awaiting_pickup: { status: { in: IN_CABINET } },
  disputing: { status: 'refunding' },
  finished: { status: 'completed' },
  cancelled: { status: { in: ['cancelled', 'refunded'] } }
};

// 其餘為購買紀錄與銷售紀錄時期的頁籤，舊版 App 仍會帶入，條件不可更動。
const BUYER_TABS = {
  ...STAGE_TABS,
  pending_pickup: { status: { in: [...PRE_DEPOSIT, ...IN_CABINET] }, picked_up_at: null },
  completed: { OR: [{ status: 'completed' }, AWAITING_CONFIRM] }
};

const SELLER_TABS = {
  ...STAGE_TABS,
  pending_deposit: { status: { in: PRE_DEPOSIT } },
  deposited: { status: { in: IN_CABINET } },
  on_sale: { status: { in: IN_CABINET } },
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

const findForParty = async (orderId, user, include, omit) => {
  const order = await prisma.orders.findUnique({ where: { order_id: orderId }, include, ...(omit && { omit }) });
  if (!order) throw notFound('找不到該訂單');
  if (!isParty(order, user)) throw forbidden();
  return order;
};

const detailForParty = (orderId, user) => findForParty(orderId, user, orderInclude, { pickup_code: true });

const ORDER_NO_PATTERN = new RegExp(`^${ORDER_NO_SOURCE}$`);

// 非當事人與不存在一律回 404，避免以編號探測他人的訂單是否存在。
const detailForPartyByNo = async (orderNo, user) => {
  const found = await prisma.orders.findUnique({
    where: { order_no: orderNo },
    select: { order_id: true, buyer_id: true, seller_id: true }
  });
  if (!found || !isParty(found, user)) throw notFound('找不到該訂單');
  return detailForParty(found.order_id, user);
};

const cancel = async (orderId, user, reason) => {
  const order = await findForParty(orderId, user, { order_items: true });
  const isAdmin = user.role === 'admin';

  if (ORDER_FINAL_STATUSES.includes(order.status)) throw badRequest('此訂單狀態無法取消');
  // 爭議中的訂單由仲裁決定退款，當事人不能自行取消。
  if (order.status === 'refunding' && !isAdmin) {
    throw badRequest('此訂單爭議處理中，無法自行取消，請等候客服裁決');
  }
  // 書已放進書櫃後雙方都不能自行取消，有問題須申請爭議，避免書在買家手上卻被退款。
  if (!isAdmin && !policy.ORDER_CANCELLABLE_STATUSES.includes(order.status)) {
    throw badRequest('賣家已存書，無法取消訂單；如有問題請申請爭議', 'ORDER_NOT_CANCELLABLE');
  }
  if (!isAdmin) await cabinetRelease().assertNotInSession(orderId);

  return prisma.$transaction(async (tx) => {
    const money = await transition(tx, order, 'cancelled', { cancelReason: reason });

    if (money.refunded > 0) {
      await notify(tx, {
        userId: order.buyer_id,
        type: 'order',
        title: '訂單已退款',
        content: `訂單 ${order.order_no} 已取消，${money.refunded} 代幣已退回您的錢包。`,
        relatedId: orderId,
        relatedType: 'order'
      });
    }

    const stored = storedNotice(money);
    let recipients = [order.buyer_id];
    if (user.userId === order.buyer_id) recipients = [order.seller_id];
    else if (user.userId !== order.seller_id && stored) recipients = [order.buyer_id, order.seller_id];
    for (const recipientId of recipients) {
      await notify(tx, {
        userId: recipientId,
        type: 'order',
        title: '訂單已取消',
        content: `訂單 ${order.order_no} 已取消。${recipientId === order.seller_id ? stored : ''}${reason ? `原因：${reason}` : ''}`,
        relatedId: orderId,
        relatedType: 'order'
      });
    }

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

const CONFIRM_WINDOW_HOURS = policy.ORDER_AUTO_COMPLETE_HOURS;

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
    content: `訂單 ${order.order_no} 取書已滿 ${CONFIRM_WINDOW_HOURS} 小時且未申請爭議，已自動完成。`,
    relatedId: order.order_id,
    relatedType: 'order'
  })
]);

const markPickedUpInTx = async (tx, order) => {
  const result = await tx.orders.updateMany({
    where: { order_id: order.order_id, status: order.status, picked_up_at: null },
    data: { picked_up_at: new Date(), updated_at: new Date() }
  });
  if (result.count === 0) throw conflict('訂單狀態已變更，請重新整理後再試');
  await notifyPickedUp(tx, order);
};

const cabinetNameOf = async (db, order) => {
  if (order.smart_cabinets?.cabinet_name) return order.smart_cabinets.cabinet_name;
  if (order.cabinet_id == null) return null;
  const cabinet = await db.smart_cabinets.findUnique({ where: { cabinet_id: order.cabinet_id }, select: { cabinet_name: true } });
  return cabinet?.cabinet_name ?? null;
};

const notifyDeposited = async (tx, order) => {
  const cabinet = await cabinetNameOf(tx, order);
  await notify(tx, {
    userId: order.buyer_id,
    type: 'order',
    title: '書籍已存入書櫃',
    content: `訂單 ${order.order_no} 的書籍已存入${cabinet ? `「${cabinet}」` : ''}書櫃，請於營業時間內至書櫃以 App 掃描 QR Code 取書。`,
    relatedId: order.order_id,
    relatedType: 'order'
  });
};

const markDepositedInTx = async (tx, order) => {
  const money = await transition(tx, order, 'deposited');
  await notifyDeposited(tx, order);
  return money;
};

const orderBookIds = (order) => (order.order_items ?? []).map((i) => Number(i.book_id));

const advance = async (orderId, status, user) => {
  const rule = TRANSITIONS[status];
  const order = await findForParty(orderId, user, { order_items: true });

  // 身為當事人的管理員只能以自己的身分操作，不得代替對方回報存書或取書。
  const isStaff = user.role === 'admin' && user.userId !== order.buyer_id && user.userId !== order.seller_id;
  const actorId = rule.by === 'seller' ? order.seller_id : order.buyer_id;
  if (!isStaff && user.userId !== actorId) {
    throw forbidden(rule.by === 'seller' ? '僅賣家可執行此操作' : '僅買家可確認取書或完成訂單');
  }
  if (order.status === status) throw conflict('訂單已是此狀態');
  if (!rule.from.includes(order.status)) throw badRequest(rule.wrongState);
  if (status === 'picked_up' && order.picked_up_at) throw conflict('已確認取書');

  // 舊版 App 在買家取書時直接送 completed；尚未確認取書時一律視為取書，不撥款。
  const pickupOnly = status === 'picked_up' || (status === 'completed' && !order.picked_up_at);

  if (status === 'deposited' || pickupOnly) {
    const manual = await cabinetAccess.assertManualAllowed(order.cabinet_id, user, {
      buyerId: order.buyer_id, sellerId: order.seller_id
    });
    if (manual.audited) {
      return cabinetManual().submit({
        kind: status === 'deposited' ? 'deposit' : 'pickup', order, user, targetStatus: status, reason: manual.reason
      });
    }
  }

  return prisma.$transaction(async (tx) => {
    if (pickupOnly) {
      await markPickedUpInTx(tx, order);
      const slotIds = await doors.removeBooks(tx, orderBookIds(order));
      if (slotIds.length) await doors.markCheck(tx, slotIds, { reason: 'MANUAL_REPORT' });
      return tx.orders.findUnique({ where: { order_id: orderId }, include: orderInclude, omit: { pickup_code: true } });
    }

    const money = status === 'deposited' ? await markDepositedInTx(tx, order) : await transition(tx, order, status);
    const updated = await tx.orders.findUnique({ where: { order_id: orderId }, include: orderInclude, omit: { pickup_code: true } });

    if (status === 'pending_pickup') await notifyDeposited(tx, updated);
    if (status === 'completed') await notifyCompleted(tx, order, money);

    return updated;
  });
};

const DEPOSIT_DAYS = policy.ORDER_DEPOSIT_DAYS;
const PICKUP_DAYS = policy.ORDER_PICKUP_DAYS;
const BATCH = 100;

const hoursAgo = (h, now) => new Date(now.getTime() - h * 60 * 60 * 1000);

// 每筆訂單各自一個交易：單筆失敗（例如狀態剛被使用者變更）不影響其他訂單。處理函式回傳 false 表示本次保留不處理。
// 保留的訂單狀態不變、每次都會再被查到，因此以游標逐批處理完全部到期訂單，否則保留超過一批後，較新的訂單永遠輪不到。
const eachOrder = async (where, handler) => {
  let done = 0;
  let after = 0;
  for (;;) {
    const due = await prisma.orders.findMany({
      where: { ...where, order_id: { gt: after } }, include: { order_items: true }, take: BATCH, orderBy: { order_id: 'asc' }
    });
    for (const order of due) {
      try {
        const handled = await prisma.$transaction((tx) => handler(tx, order));
        if (handled !== false) done += 1;
      } catch (err) {
        if (err.status !== 409) console.error(`[訂單 ${order.order_no} 自動處理失敗]:`, err.message);
      }
    }
    if (due.length < BATCH) return done;
    after = Number(due[due.length - 1].order_id);
  }
};

const completeDue = (now = new Date()) => eachOrder(
  { status: { in: IN_CABINET }, picked_up_at: { not: null, lte: hoursAgo(CONFIRM_WINDOW_HOURS, now) } },
  async (tx, order) => {
    const money = await transition(tx, order, 'completed');
    await notifyCompleted(tx, order, money, { auto: true });
  }
);

const cancelOverdue = async (tx, order, { reason, buyerContent, sellerContent }, now = new Date()) => {
  if (await cabinetRelease().overdueHold(tx, order, now)) return false;
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
    content: sellerContent(money.redeposited > 0),
    relatedId: order.order_id,
    relatedType: 'order'
  });
};

const cancelUndeposited = (now = new Date()) => eachOrder(
  { status: { in: PRE_DEPOSIT }, created_at: { lte: hoursAgo(DEPOSIT_DAYS * 24, now) } },
  (tx, order) => {
    const missed = (order.order_items ?? []).some((i) => i.pre_deposited) ? '未存齊書籍' : '未存書';
    return cancelOverdue(tx, order, {
      reason: `賣家逾 ${DEPOSIT_DAYS} 天${missed}`,
      buyerContent: `訂單 ${order.order_no} 的賣家逾 ${DEPOSIT_DAYS} 天${missed}，訂單已自動取消，`,
      sellerContent: (stored) => (stored
        ? `訂單 ${order.order_no} 逾 ${DEPOSIT_DAYS} 天${missed}，已自動取消，書籍已改為下架。已存放於書櫃的書籍請至書櫃以 App 掃描 QR Code 取回；如需販售請重新上架。`
        : `訂單 ${order.order_no} 逾 ${DEPOSIT_DAYS} 天${missed}，已自動取消，書籍已改為下架，如需販售請重新上架。`)
    }, now);
  }
);

const cancelUncollected = (now = new Date()) => eachOrder(
  { status: { in: IN_CABINET }, picked_up_at: null, deposited_at: { lte: hoursAgo(PICKUP_DAYS * 24, now) } },
  (tx, order) => cancelOverdue(tx, order, {
    reason: `買家逾 ${PICKUP_DAYS} 天未取書`,
    buyerContent: `訂單 ${order.order_no} 存書後逾 ${PICKUP_DAYS} 天未取書，訂單已自動取消，`,
    sellerContent: () => `訂單 ${order.order_no} 的買家逾 ${PICKUP_DAYS} 天未取書，訂單已自動取消，`
      + '請至書櫃以 App 掃描 QR Code 取回書籍；書籍已改為下架，如需販售請重新上架。'
  }, now)
);

const DELISTED_REASON = '書籍經審核下架';

// 交易中的書只會因檢舉、管理員或上架審核下架而成為 removed，買家尚未取書的訂單以此判斷須取消。
const delistedWhere = (bookIds) => ({
  status: { in: [...PRE_DEPOSIT, ...IN_CABINET] },
  picked_up_at: null,
  order_items: { some: { ...(bookIds && { book_id: { in: bookIds } }), books: { status: 'removed' } } }
});

// 下架的書須在取消前已是 removed：結算只把 reserved 的書改回上架，其他書籍因此照一般取消流程處理。
const cancelDelistedInTx = async (tx, order, now) => {
  const removed = await tx.order_items.findMany({
    where: { order_id: order.order_id, books: { status: 'removed' } },
    select: { books: { select: { title: true } } }
  });
  if (removed.length === 0) return false;
  if (await cabinetRelease().overdueHold(tx, order, now, { type: 'delist_review' })) return false;

  const titles = removed.map((i) => `《${i.books?.title ?? ''}》`).join('、');
  const money = await transition(tx, order, 'cancelled', { cancelReason: DELISTED_REASON });
  await notify(tx, {
    userId: order.buyer_id,
    type: 'order',
    title: '訂單已取消',
    content: `訂單 ${order.order_no} 的${titles}經審核下架，訂單已自動取消`
      + `${money.refunded > 0 ? `，${money.refunded} 代幣已全額退回您的錢包` : ''}。`,
    relatedId: order.order_id,
    relatedType: 'order'
  });
  await notify(tx, {
    userId: order.seller_id,
    type: 'order',
    title: '訂單已取消',
    content: `訂單 ${order.order_no} 的${titles}經審核下架，訂單已自動取消${money.refunded > 0 ? '，款項已全額退還買家' : ''}。`
      + storedNotice(money),
    relatedId: order.order_id,
    relatedType: 'order'
  });
  return true;
};

const cancelDelisted = async (now = new Date(), { bookIds = null } = {}) => {
  const result = { cancelled: [], held: [] };
  await eachOrder(delistedWhere(bookIds), async (tx, order) => {
    const done = await cancelDelistedInTx(tx, order, now);
    (done ? result.cancelled : result.held).push(order.order_no);
    return done;
  });
  return result;
};

const runAutomation = async (now = new Date()) => ({
  delisted: (await cancelDelisted(now)).cancelled.length,
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
  const doorMap = await doors.orderDoors([order.order_id]);

  return {
    ...shapeAdminOrder(order),
    payment_method: order.payment_method,
    note: order.note,
    slot: order.cabinet_slots,
    doors: (doorMap.get(Number(order.order_id)) ?? []).map((d) => d.label),
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
      if (status === 'completed' && !order.picked_up_at) {
        const placed = await doors.bookDoors(orderBookIds(order), { tx });
        const slotIds = [...placed.values()].filter((d) => d.cabinet_id === Number(order.cabinet_id)).map((d) => d.slot_id);
        if (slotIds.length) await doors.markCheck(tx, slotIds, { reason: 'ADMIN_COMPLETED' });
      }
      const effect = describeSettlement(result);
      const content = (extra) => `訂單 ${order.order_no} 已由客服調整為「${statusLabel(status)}」。`
        + `${effect ? `${effect}。` : ''}${extra}${note ? `說明：${note}` : ''}`;

      for (const userId of [order.buyer_id, order.seller_id]) {
        await notify(tx, {
          userId,
          type: 'order',
          title: '訂單狀態已更新',
          content: content(userId === order.seller_id ? storedNotice(result) : ''),
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
  TRANSITIONS, CONFIRM_WINDOW_HOURS, DEPOSIT_DAYS, PICKUP_DAYS, ORDER_NO_PATTERN, tabFilter, listForUser, detailForParty, detailForPartyByNo,
  checkout, buyNow, cancel, advance,
  markPickedUpInTx, markDepositedInTx, notifyDeposited,
  completeDue, cancelUndeposited, cancelUncollected, cancelDelisted, runAutomation, adminList, adminDetail, adminChangeStatus
};
