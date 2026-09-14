const express = require('express');
const prisma = require('../../lib/prisma');
const requireAdmin = require('../../middleware/requireAdmin');
const v = require('../../lib/validate');
const { badRequest, notFound } = require('../../lib/errors');
const { changeBalance } = require('../../services/wallet');
const { notify } = require('../../services/notify');
const audit = require('../../services/audit');
const { requireVerification } = require('../../services/security');

const router = express.Router();
const canManage = requireAdmin('wallets');

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

router.get('/wallets', canManage, async (req, res) => {
  const keyword = v.text(req.query.keyword, { label: '關鍵字', max: 100 });
  const { page, limit, skip } = v.pagination(req.query, { limit: 30 });

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

  res.status(200).json({
    success: true,
    pagination: v.pageMeta(total, { page, limit }),
    data: users.map(walletSummary)
  });
});

router.get('/wallets/:userId', canManage, async (req, res) => {
  const userId = v.id(req.params.userId, '會員編號');

  const user = await prisma.users.findUnique({
    where: { user_id: userId },
    select: { ...walletUserSelect, wallets: true }
  });
  if (!user) throw notFound('找不到此會員');

  const transactions = user.wallets
    ? await prisma.wallet_transactions.findMany({
        where: { wallet_id: user.wallets.wallet_id },
        orderBy: { created_at: 'desc' },
        take: 50
      })
    : [];

  res.status(200).json({ success: true, data: { ...walletSummary(user), transactions } });
});

router.post('/wallets/:userId/adjust', canManage, requireVerification('sensitive'), async (req, res) => {
  const userId = v.id(req.params.userId, '會員編號');
  const amount = Number(req.body.amount);
  const description = v.text(req.body.description, { label: '調整原因', max: 200 });

  if (!Number.isFinite(amount) || amount === 0) throw badRequest('請輸入非零的調整金額');
  if (Math.abs(amount) > MAX_ADJUST) throw badRequest('單次調整不可超過 1,000,000');
  // 餘額欄位為 DECIMAL(12,2)，超過兩位小數會被資料庫默默四捨五入。
  if (Math.abs(amount * 100 - Math.round(amount * 100)) > 1e-6) throw badRequest('金額最多可至小數點後兩位');
  if (!description) throw badRequest('請填寫調整原因，此原因將記錄於帳務紀錄');

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
    adminId: req.user.userId,
    action: '調整會員錢包',
    targetType: 'wallet',
    targetId: userId,
    summary: `${amount > 0 ? '替' : '從'} ${user.nickname} 的錢包${amount > 0 ? '加入' : '扣除'} ${Math.abs(amount)} 代幣，原因：${description}`,
    changes: [{ label: '餘額', from: `${Number(before?.balance ?? 0)} 代幣`, to: `${Number(balance)} 代幣` }],
    undo: [audit.undoWallet(userId, amount)],
    req
  });
  res.status(200).json({ success: true, message: '已調整餘額', data: { balance } });
});

module.exports = router;
