const prisma = require('../lib/prisma');
const { badRequest } = require('../lib/errors');

const ensureWallet = (db, userId) =>
  (db ?? prisma).wallets.upsert({
    where: { user_id: userId },
    update: {},
    create: { user_id: userId, balance: 0 }
  });

// 須在交易內呼叫；由資料庫做加減並把餘額足夠放進 WHERE，避免並行覆寫或扣成負數。
const changeBalance = async (tx, userId, {
  amount, type, description, orderId = null, counters = {},
  insufficientMessage = '代幣不足，請先儲值後再結帳',
  allowNegative = false
}) => {
  const wallet = await ensureWallet(tx, userId);
  const now = new Date();

  if (amount < 0 && !allowNegative) {
    const result = await tx.wallets.updateMany({
      where: { wallet_id: wallet.wallet_id, balance: { gte: -amount } },
      data: { balance: { decrement: -amount }, ...counters, updated_at: now }
    });
    if (result.count === 0) throw badRequest(insufficientMessage, 'INSUFFICIENT_BALANCE');
  } else {
    await tx.wallets.update({
      where: { wallet_id: wallet.wallet_id },
      data: { balance: { increment: amount }, ...counters, updated_at: now }
    });
  }

  const { balance } = await tx.wallets.findUnique({
    where: { wallet_id: wallet.wallet_id },
    select: { balance: true }
  });

  await tx.wallet_transactions.create({
    data: {
      wallet_id: wallet.wallet_id,
      type,
      amount,
      balance_after: balance,
      related_order_id: orderId,
      description
    }
  });

  return balance;
};

module.exports = { ensureWallet, changeBalance };
