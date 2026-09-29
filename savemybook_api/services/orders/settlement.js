const { badRequest, conflict } = require('../../lib/errors');
const { ORDER_STATUS_LABELS } = require('../../constants/domain');
const { changeBalance, ensureWallet } = require('../wallet');

// 以讀取時的狀態與取書時間為更新條件：避免並行請求重複結算，也避免買家取書（只寫入取書時間）後訂單仍被取消退款。
const guardedUpdate = async (tx, order, data) => {
  const result = await tx.orders.updateMany({
    where: { order_id: order.order_id, status: order.status, picked_up_at: order.picked_up_at ?? null },
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

const IN_CABINET = ['deposited', 'pending_pickup'];

// 爭議處理中的訂單看不出原本進度，改依存書時間判斷書是否已放進訂單書櫃（與爭議裁決推回狀態的規則一致）。
const wasInCabinet = (order) => order.cabinet_id != null
  && (IN_CABINET.includes(order.status) || (order.status === 'refunding' && order.deposited_at != null));

const keptInCabinet = (order, item) => !order.picked_up_at && (wasInCabinet(order) || Boolean(item.pre_deposited));

const redeposit = async (tx, order, now) => {
  const result = { count: 0, forSale: 0 };
  // 款項已退回或已完成的訂單再調整狀態時不可重建存書登記，書可能早已取回或售出。
  if (phaseOf(order.status) !== 'held') return result;
  const whole = wasInCabinet(order);
  const ids = order.order_items.filter((i) => keptInCabinet(order, i)).map((i) => i.book_id);
  if (ids.length === 0) return result;
  // 爭議處理中的訂單無法確認書是否仍在櫃中，恢復登記但改為下架，避免下一位買家直接前往書櫃卻取不到書。
  const delist = order.status === 'refunding';
  const books = await tx.books.findMany({
    where: { book_id: { in: ids }, status: { in: ['on_sale', 'removed'] } },
    select: { book_id: true, cabinet_id: true, status: true, is_approved: true }
  });
  const restored = [];
  const forSale = new Set();
  for (const book of books) {
    const cabinetId = whole ? order.cabinet_id : book.cabinet_id;
    if (!cabinetId) continue;
    const row = await tx.book_deposits.upsert({
      where: { book_id: book.book_id },
      create: { book_id: book.book_id, cabinet_id: cabinetId, deposited_at: now },
      update: {}
    });
    const data = {};
    // 書籍的書櫃須與實際存放處一致：刊登的取書地點、下次結帳是否已在訂單書櫃、取回時的提示都以它判斷。
    if (row.cabinet_id !== book.cabinet_id) data.cabinet_id = row.cabinet_id;
    if (delist && book.status === 'on_sale') data.status = 'removed';
    if (Object.keys(data).length > 0) {
      await tx.books.update({ where: { book_id: book.book_id }, data: { ...data, updated_at: now } });
    }
    restored.push(Number(book.book_id));
    if ((data.status ?? book.status) === 'on_sale' && book.is_approved) forSale.add(Number(book.book_id));
  }
  const paused = await require('../cabinet-release').splitSharedDoors(tx, order, restored, now);
  result.count = restored.length;
  result.forSale = [...forSale].filter((id) => !paused.has(id)).length;
  return result;
};

// 必須在 guardedUpdate 之後、同一個交易內呼叫，靠其列鎖避免重複結算。
const settle = async (tx, order, target, { restoreBookTo = 'on_sale' } = {}) => {
  const phase = phaseOf(target);
  const result = { phase, paidOut: 0, clawedBack: 0, refunded: 0, redeposited: 0, redepositedForSale: 0 };
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
    // 加上狀態條件：書若已被管理員強制下架或刪除，完成訂單不應把它改回上架中的售出狀態。
    await tx.books.updateMany({ where: { book_id: { in: bookIds }, status: 'reserved' }, data: { status: 'sold', updated_at: now } });
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
    data: { status: restoreBookTo, updated_at: now }
  });
  const stored = await redeposit(tx, order, now);
  result.redeposited = stored.count;
  result.redepositedForSale = stored.forSale;
  return result;
};

const transition = async (tx, order, target, { cancelReason = null, restoreBookTo } = {}) => {
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
  return settle(tx, order, target, { restoreBookTo });
};

const assertAdminTransition = (from, to) => {
  if (from === to) throw badRequest('訂單已是此狀態');
  if (phaseOf(from) === 'returned' && phaseOf(to) !== 'returned') {
    throw badRequest('此訂單款項已退回買家，無法改回進行中或已完成');
  }
  if (from === 'completed' && !['refunding', 'refunded'].includes(to)) {
    throw badRequest('已完成的訂單僅能改為「審核中」或「已退款」');
  }
};

const describeSettlement = (money) => {
  const parts = [];
  if (money.paidOut) parts.push(`撥款給賣家 ${money.paidOut} 代幣`);
  if (money.clawedBack) parts.push(`向賣家收回 ${money.clawedBack} 代幣`);
  if (money.refunded) parts.push(`退還買家 ${money.refunded} 代幣`);
  return parts.join('，');
};

const storedNotice = ({ redeposited = 0, redepositedForSale = 0 }) => {
  if (redeposited === 0) return '';
  if (redepositedForSale === redeposited) return '書櫃中的書籍將繼續販售。';
  const retrieve = '請至書櫃以 App 掃描 QR Code 取回。';
  return redepositedForSale > 0
    ? `書櫃中公開販售的書籍將繼續販售；其餘書籍${retrieve}`
    : `書櫃中的書籍目前未公開販售，${retrieve}`;
};

const statusLabel = (status) => ORDER_STATUS_LABELS[status] ?? status;

module.exports = {
  phaseOf, guardedUpdate, keptInCabinet, transition, assertAdminTransition, describeSettlement, storedNotice, statusLabel
};
