const prisma = require('../lib/prisma');
const publicId = require('../lib/public-id');
const { badRequest, notFound } = require('../lib/errors');
const { ORDER_OPEN_STATUSES } = require('../constants/domain');
const { orderItemsWithCover, cabinetBrief } = require('../lib/selects');
const { notify } = require('./notify');
const audit = require('./audit');

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

const withTxnNo = (t) => ({ ...t, txn_no: publicId.encode('transaction', t.txn_id) });

const pendingWhere = (userId) => ({ seller_id: userId, status: { in: ORDER_OPEN_STATUSES } });

const summary = async (userId) => {
  const [wallet, pending] = await Promise.all([
    ensureWallet(prisma, userId),
    prisma.orders.aggregate({
      where: pendingWhere(userId),
      _sum: { total_amount: true }
    })
  ]);
  return { ...wallet, pending_income: pending._sum.total_amount ?? 0 };
};

const transactions = async (userId, { skip, limit }) => {
  const where = { wallets: { user_id: userId } };

  const [rows, total] = await Promise.all([
    prisma.wallet_transactions.findMany({
      where,
      skip,
      take: limit,
      orderBy: { created_at: 'desc' },
      include: {
        orders: {
          select: {
            order_id: true,
            order_no: true,
            order_items: { take: 1, ...orderItemsWithCover }
          }
        }
      }
    }),
    prisma.wallet_transactions.count({ where })
  ]);
  return { rows: rows.map(withTxnNo), total };
};

const pendingIncome = async (userId) => {
  const orders = await prisma.orders.findMany({
    where: pendingWhere(userId),
    orderBy: { created_at: 'desc' },
    include: {
      order_items: {
        include: {
          books: {
            include: { book_images: { select: { image_url: true, image_type: true } } }
          }
        }
      },
      smart_cabinets: { select: cabinetBrief },
      cabinet_slots: { select: { slot_number: true } }
    }
  });

  const total = orders.reduce((sum, o) => sum + Number(o.total_amount), 0);
  return { orders, total };
};

const MAX_ADJUST = 1000000;
const walletUserSelect = { user_id: true, nickname: true, avatar_url: true, email: true };

const walletSummary = (u) => ({
  user_id: u.user_id,
  nickname: u.nickname,
  email: u.email,
  avatar_url: u.avatar_url,
  balance: u.wallets?.balance ?? 0,
  frozen_amount: u.wallets?.frozen_amount ?? 0,
  total_income: u.wallets?.total_income ?? 0,
  total_expense: u.wallets?.total_expense ?? 0
});

const adminList = async ({ keyword, skip, limit }) => {
  const where = keyword
    ? { OR: [{ nickname: { contains: keyword } }, { email: { contains: keyword } }] }
    : {};

  const [users, total] = await Promise.all([
    prisma.users.findMany({
      where,
      select: { ...walletUserSelect, wallets: true },
      orderBy: { user_id: 'asc' },
      skip,
      take: limit
    }),
    prisma.users.count({ where })
  ]);
  return { rows: users.map(walletSummary), total };
};

const adminDetail = async (userId) => {
  const user = await prisma.users.findUnique({
    where: { user_id: userId },
    select: { ...walletUserSelect, wallets: true }
  });
  if (!user) throw notFound('找不到此會員');

  const rows = user.wallets
    ? await prisma.wallet_transactions.findMany({
        where: { wallet_id: user.wallets.wallet_id },
        orderBy: { created_at: 'desc' },
        take: 50
      })
    : [];

  return { ...walletSummary(user), transactions: rows.map(withTxnNo) };
};

const adjust = async (userId, { amount, description }, { adminId, req }) => {
  const user = await prisma.users.findUnique({ where: { user_id: userId }, select: { user_id: true, nickname: true } });
  if (!user) throw notFound('找不到此會員');

  const before = await prisma.wallets.findUnique({ where: { user_id: userId }, select: { balance: true } });

  const balance = await prisma.$transaction(async (tx) => {
    const next = await changeBalance(tx, userId, {
      amount,
      type: 'admin_adjust',
      description: `管理員調整：${description}`,
      counters: amount > 0
        ? { total_income: { increment: amount } }
        : { total_expense: { increment: Math.abs(amount) } },
      insufficientMessage: '調整後餘額將為負數，請確認金額'
    });

    await notify(tx, {
      userId,
      title: amount > 0 ? '代幣已入帳' : '代幣已扣除',
      content: `客服已調整您的代幣 ${amount > 0 ? '+' : ''}${amount}，餘額 ${next}。原因：${description}`,
      relatedType: 'wallet'
    });

    return next;
  });

  await audit.record(null, {
    adminId,
    action: '調整會員錢包',
    targetType: 'wallet',
    targetId: userId,
    summary: `${amount > 0 ? '替' : '從'} ${user.nickname} 的錢包${amount > 0 ? '加入' : '扣除'} ${Math.abs(amount)} 代幣，原因：${description}`,
    changes: [{ label: '餘額', from: `${Number(before?.balance ?? 0)} 代幣`, to: `${Number(balance)} 代幣` }],
    undo: [audit.undoWallet(userId, amount)],
    req
  });
  return balance;
};

module.exports = {
  MAX_ADJUST, ensureWallet, changeBalance, withTxnNo, summary, transactions, pendingIncome, adminList, adminDetail, adjust
};
