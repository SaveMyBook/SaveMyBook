const { badRequest, conflict } = require('../../lib/errors');
const { ORDER_STATUS_LABELS } = require('../../constants/domain');
const { changeBalance, ensureWallet } = require('../wallet');

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

module.exports = { phaseOf, transition, assertAdminTransition, describeSettlement, statusLabel };
