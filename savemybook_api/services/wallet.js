const prisma = require('../lib/prisma');
const { badRequest } = require('../lib/errors');

const ensureWallet = (db, userId) =>
  (db ?? prisma).wallets.upsert({
    where: { user_id: userId },
    update: {},
    create: { user_id: userId, balance: 0 }
  });

/// 餘額異動一律走這裡，並且必須在交易內呼叫。
///
/// 先讀餘額、在程式裡加減、再寫回的做法在兩個請求同時進來時會互相覆蓋
/// （兩邊都讀到 100，各扣 60 後都寫回 40）。這裡讓資料庫自己做加減，
/// 扣款時把「餘額足夠」放進 WHERE，由列鎖保證不會扣成負數。
///
/// counters 是 total_income / total_expense 的增減，例如 { total_expense: { increment: 50 } }。
/// allowNegative 只用在退款時向賣家收回貨款：賣家可能已經把錢花掉，
/// 不能因此讓買家拿不到退款，餘額變負數後由之後的收入抵扣。
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
