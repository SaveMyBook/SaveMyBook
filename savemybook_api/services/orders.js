const crypto = require('crypto');
const prisma = require('../lib/prisma');
const { badRequest, forbidden, notFound, conflict } = require('../lib/errors');
const { ORDER_FINAL_STATUSES, ORDER_STATUS_LABELS } = require('../constants/domain');
const { changeBalance, ensureWallet } = require('./wallet');
const { notify } = require('./notify');
const reservations = require('./reservations');

const orderInclude = {
  order_items: {
    include: {
      books: {
        include: {
          book_images: { select: { image_id: true, image_url: true, image_type: true } },
          book_categories: { select: { category_name: true } }
        }
      }
    }
  },
  smart_cabinets: {
    select: { cabinet_id: true, cabinet_name: true, address: true, open_time: true, close_time: true }
  },
  cabinet_slots: { select: { slot_id: true, slot_number: true } },
  users_orders_buyer_idTousers: { select: { user_id: true, nickname: true, avatar_url: true } },
  users_orders_seller_idTousers: { select: { user_id: true, nickname: true, avatar_url: true } },
  transaction_disputes: { select: { dispute_id: true, status: true, result: true } }
};

const pad = (n) => String(n).padStart(2, '0');

const buildOrderNo = () => {
  const d = new Date();
  const stamp = `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`;
  // 一次結帳同一秒會產生多個編號，亂數段需夠長以免撞唯一索引。
  return `SMB${stamp}${crypto.randomInt(100000, 1000000)}`;
};

const buildPickupCode = () => String(crypto.randomInt(100000, 1000000));

const isParty = (order, user) =>
  order.buyer_id === user.userId || order.seller_id === user.userId || user.role === 'admin';

const findForParty = async (orderId, user, include) => {
  const order = await prisma.orders.findUnique({ where: { order_id: orderId }, include });
  if (!order) throw notFound('找不到該訂單');
  if (!isParty(order, user)) throw forbidden('存取被拒');
  return order;
};

// 以讀取時的狀態為更新條件，避免並行請求重複退款或重複撥款。
const guardedUpdate = async (tx, order, data) => {
  const result = await tx.orders.updateMany({
    where: { order_id: order.order_id, status: order.status },
    data: { ...data, updated_at: new Date() }
  });
  if (result.count === 0) throw conflict('訂單狀態已變更，請重新整理後再試');
};

const phaseOf = (status) => {
  if (status === 'completed') return 'paid_out';
  if (status === 'cancelled' || status === 'refunded') return 'returned';
  return 'held';
};

// 依帳本實際金流結算而非依狀態轉換推算，重複結算才不會多撥或多退。
const ledgerOf = async (tx, order) => {
  const [buyerWallet, sellerWallet] = await Promise.all([
    ensureWallet(tx, order.buyer_id),
    ensureWallet(tx, order.seller_id)
  ]);
  const sum = async (walletId, types) => {
    const { _sum } = await tx.wallet_transactions.aggregate({
      where: { wallet_id: walletId, related_order_id: order.order_id, type: { in: types } },
      _sum: { amount: true }
    });
    return Number(_sum.amount ?? 0);
  };
  const [buyerNet, sellerNet] = await Promise.all([
    sum(buyerWallet.wallet_id, ['purchase', 'refund']),
    sum(sellerWallet.wallet_id, ['sale_income', 'refund'])
  ]);
  return { buyerPaid: Math.max(0, -buyerNet), sellerReceived: Math.max(0, sellerNet) };
};

const round2 = (n) => Math.round(n * 100) / 100;

// 必須在 guardedUpdate 之後、同一個交易內呼叫，靠其列鎖避免重複結算。
const settle = async (tx, order, target) => {
  const phase = phaseOf(target);
  const result = { phase, paidOut: 0, clawedBack: 0, refunded: 0 };
  if (phase === 'held') return result;

  const amount = Number(order.total_amount);
  const { buyerPaid, sellerReceived } = await ledgerOf(tx, order);
  const bookIds = order.order_items.map((i) => i.book_id);
  const now = new Date();

  if (phase === 'paid_out') {
    const due = round2(amount - sellerReceived);
    if (due > 0) {
      await changeBalance(tx, order.seller_id, {
        amount: due,
        type: 'sale_income',
        orderId: order.order_id,
        description: '賣出',
        counters: { total_income: { increment: due } }
      });
      result.paidOut = due;
    }
    await tx.books.updateMany({ where: { book_id: { in: bookIds } }, data: { status: 'sold', updated_at: now } });
    return result;
  }

  if (sellerReceived > 0) {
    await changeBalance(tx, order.seller_id, {
      amount: -sellerReceived,
      type: 'refund',
      orderId: order.order_id,
      description: `訂單 ${order.order_no} 退款，收回貨款`,
      counters: { total_income: { decrement: sellerReceived } },
      allowNegative: true
    });
    result.clawedBack = sellerReceived;
  }

  if (buyerPaid > 0) {
    await changeBalance(tx, order.buyer_id, {
      amount: buyerPaid,
      type: 'refund',
      orderId: order.order_id,
      description: `訂單 ${order.order_no} ${target === 'cancelled' ? '取消' : ''}退款`,
      counters: { total_expense: { decrement: buyerPaid } }
    });
    result.refunded = buyerPaid;
  }

  await tx.books.updateMany({
    where: { book_id: { in: bookIds }, status: 'reserved' },
    data: { status: 'on_sale', updated_at: now }
  });
  return result;
};

const transition = async (tx, order, target, { cancelReason = null } = {}) => {
  const now = new Date();
  const data = { status: target };
  if (target === 'deposited') data.deposited_at = now;
  if (target === 'completed') {
    data.picked_up_at = order.picked_up_at ?? now;
    data.completed_at = now;
  }
  if (target === 'cancelled') {
    data.cancelled_at = now;
    data.cancel_reason = cancelReason;
  }

  await guardedUpdate(tx, order, data);
  return settle(tx, order, target);
};

const assertAdminTransition = (from, to) => {
  if (from === to) throw badRequest('訂單已是此狀態');
  if (phaseOf(from) === 'returned' && phaseOf(to) !== 'returned') {
    throw badRequest('此訂單款項已退回買家，無法改回進行中或已完成');
  }
  if (from === 'completed' && !['refunding', 'refunded'].includes(to)) {
    throw badRequest('已完成的訂單只能改為「退款處理中」或「已退款」');
  }
};

const describeSettlement = (money) => {
  const parts = [];
  if (money.paidOut) parts.push(`撥款給賣家 ${money.paidOut} 代幣`);
  if (money.clawedBack) parts.push(`向賣家收回 ${money.clawedBack} 代幣`);
  if (money.refunded) parts.push(`退還買家 ${money.refunded} 代幣`);
  return parts.join('，');
};

const statusLabel = (status) => ORDER_STATUS_LABELS[status] ?? status;

const itemQuantity = (item) => Math.max(1, Math.min(item.quantity, item.books.quantity || 1));

const checkout = async (buyerId, { cartIds, paymentMethod }) => {
  const cartItems = await prisma.shopping_cart.findMany({
    where: {
      user_id: buyerId,
      ...(cartIds && cartIds.length > 0 && { cart_id: { in: cartIds } })
    },
    include: { books: true }
  });

  if (cartItems.length === 0) throw badRequest('購物車沒有可結帳的項目');

  const unavailable = cartItems.find((i) => i.books.status !== 'on_sale');
  if (unavailable) throw badRequest(`《${unavailable.books.title}》已無法購買，請先移除`);

  await reservations.assertNotHeldByOthers(null, cartItems.map((i) => i.books), buyerId);

  const ownBook = cartItems.find((i) => i.books.seller_id === buyerId);
  if (ownBook) throw badRequest(`《${ownBook.books.title}》為您上架的書籍，無法購買`);

  // 既有資料可能有售價 0 的書，結帳時須再擋一次。
  const invalidPrice = cartItems.find((i) => !(Number(i.books.price) > 0));
  if (invalidPrice) {
    throw badRequest(`《${invalidPrice.books.title}》的售價異常，請聯絡賣家或先移除`);
  }

  const bySeller = new Map();
  for (const item of cartItems) {
    const sellerId = item.books.seller_id;
    if (!bySeller.has(sellerId)) bySeller.set(sellerId, []);
    bySeller.get(sellerId).push(item);
  }

  const lineTotal = (i) => Number(i.books.price) * itemQuantity(i);
  const grandTotal = cartItems.reduce((sum, i) => sum + lineTotal(i), 0);

  const buyerWallet = await prisma.wallets.findUnique({ where: { user_id: buyerId } });
  const currentBalance = Number(buyerWallet?.balance ?? 0);
  if (currentBalance < grandTotal) {
    throw badRequest(
      `代幣不足，此訂單需 ${grandTotal} 代幣，目前餘額 ${currentBalance}`,
      'INSUFFICIENT_BALANCE'
    );
  }

  return prisma.$transaction(async (tx) => {
    const results = [];

    for (const [sellerId, items] of bySeller) {
      const bookIds = items.map((i) => i.book_id);

      // 先把書鎖成保留中，兩個買家同時結帳時只有一人的 count 對得上。
      const reserved = await tx.books.updateMany({
        where: { book_id: { in: bookIds }, status: 'on_sale' },
        data: { status: 'reserved', updated_at: new Date() }
      });
      if (reserved.count !== bookIds.length) {
        throw conflict('購物車中有書籍已被其他買家購買，請重新整理後再結帳');
      }

      const totalAmount = items.reduce((sum, i) => sum + lineTotal(i), 0);

      const order = await tx.orders.create({
        data: {
          order_no: buildOrderNo(),
          buyer_id: buyerId,
          seller_id: sellerId,
          total_amount: totalAmount,
          cabinet_id: items[0].books.cabinet_id ?? null,
          pickup_code: buildPickupCode(),
          status: 'pending_deposit',
          payment_method: paymentMethod,
          payment_at: new Date(),
          order_items: {
            create: items.map((i) => ({
              book_id: i.book_id,
              quantity: itemQuantity(i),
              unit_price: i.books.price,
              subtotal: lineTotal(i)
            }))
          }
        },
        include: orderInclude
      });

      await changeBalance(tx, buyerId, {
        amount: -totalAmount,
        type: 'purchase',
        orderId: order.order_id,
        description: `購買訂單 ${order.order_no}`,
        counters: { total_expense: { increment: totalAmount } }
      });

      await notify(tx, {
        userId: sellerId,
        type: 'order',
        title: '您的書已售出',
        content: `訂單 ${order.order_no} 已成立，請於七天內至書櫃存書。`,
        relatedId: order.order_id,
        relatedType: 'order'
      });

      results.push(order);
    }

    await tx.shopping_cart.deleteMany({ where: { cart_id: { in: cartItems.map((i) => i.cart_id) } } });
    return results;
  });
};

const cancel = async (orderId, user, reason) => {
  const order = await findForParty(orderId, user, { order_items: true });
  const isAdmin = user.role === 'admin';

  if (ORDER_FINAL_STATUSES.includes(order.status)) throw badRequest('此訂單狀態無法取消');
  // 爭議中的訂單由仲裁決定退款，當事人不能自行取消。
  if (order.status === 'refunding' && !isAdmin) {
    throw badRequest('此訂單爭議處理中，無法自行取消，請等候客服裁決');
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
  completed: {
    from: ['deposited', 'pending_pickup'],
    by: 'buyer',
    wrongState: '賣家尚未存書，無法完成取書'
  }
};

const advance = async (orderId, status, user) => {
  const rule = TRANSITIONS[status];
  const order = await findForParty(orderId, user, { order_items: true });

  const isAdmin = user.role === 'admin';
  const actorId = rule.by === 'seller' ? order.seller_id : order.buyer_id;
  if (!isAdmin && user.userId !== actorId) {
    throw forbidden(rule.by === 'seller' ? '僅賣家可執行此操作' : '僅買家可確認取書');
  }
  if (order.status === status) throw conflict('訂單已是此狀態');
  if (!rule.from.includes(order.status)) throw badRequest(rule.wrongState);

  return prisma.$transaction(async (tx) => {
    const money = await transition(tx, order, status);
    const updated = await tx.orders.findUnique({ where: { order_id: orderId }, include: orderInclude });

    if (status === 'deposited' || status === 'pending_pickup') {
      const cabinet = updated.smart_cabinets?.cabinet_name;
      await notify(tx, {
        userId: order.buyer_id,
        type: 'order',
        title: '書籍已存入書櫃',
        content: `訂單 ${order.order_no} 的書籍已存入${cabinet ? `「${cabinet}」` : ''}書櫃，請前往取書。`
          + `${order.pickup_code ? `取書碼：${order.pickup_code}` : ''}`,
        relatedId: orderId,
        relatedType: 'order'
      });
    }
    if (status === 'completed') {
      await notify(tx, {
        userId: order.seller_id,
        type: 'order',
        title: '買家已取書',
        content: money.paidOut > 0
          ? `訂單 ${order.order_no} 已完成，${money.paidOut} 代幣已撥入您的錢包。`
          : `訂單 ${order.order_no} 已完成。`,
        relatedId: orderId,
        relatedType: 'order'
      });
    }

    return updated;
  });
};

module.exports = {
  orderInclude, TRANSITIONS, findForParty, guardedUpdate, checkout, cancel, advance,
  phaseOf, transition, assertAdminTransition, describeSettlement, statusLabel
};
