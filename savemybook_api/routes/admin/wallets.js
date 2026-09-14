const express = require('express');
const prisma = require('../../lib/prisma');
const requireAdmin = require('../../middleware/requireAdmin');
const v = require('../../lib/validate');
const { badRequest, notFound } = require('../../lib/errors');
const { changeBalance } = require('../../services/wallet');
const { notify } = require('../../services/notify');
const { logAction } = require('../../services/audit');

const router = express.Router();
const canManage = requireAdmin('wallets');

const MAX_ADJUST = 1000000;
const walletUserSelect = { user_id: true, nickname: true, avatar_url: true, email: true };

/// 無錢包紀錄者一律回 0，用戶端不必處理 null。
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
  if (!user) throw notFound('找不到這位會員');

  const transactions = user.wallets
    ? await prisma.wallet_transactions.findMany({
        where: { wallet_id: user.wallets.wallet_id },
        orderBy: { created_at: 'desc' },
        take: 50
      })
    : [];

  res.status(200).json({ success: true, data: { ...walletSummary(user), transactions } });
});

router.post('/wallets/:userId/adjust', canManage, async (req, res) => {
  const userId = v.id(req.params.userId, '會員編號');
  const amount = Number(req.body.amount);
  const description = v.text(req.body.description, { label: '調整原因', max: 200 });

  if (!Number.isFinite(amount) || amount === 0) throw badRequest('請輸入非零的調整金額');
  if (Math.abs(amount) > MAX_ADJUST) throw badRequest('單次調整不可超過 1,000,000');
  // 餘額欄位是 DECIMAL(12,2)，超過兩位小數會被資料庫默默四捨五入，帳就對不起來。
  if (Math.abs(amount * 100 - Math.round(amount * 100)) > 1e-6) throw badRequest('金額最多只能到小數點後兩位');
  if (!description) throw badRequest('請填寫調整原因，這會寫進帳務紀錄');

  const user = await prisma.users.findUnique({ where: { user_id: userId }, select: { user_id: true } });
  if (!user) throw notFound('找不到這位會員');

  const balance = await prisma.$transaction(async (tx) => {
    const next = await changeBalance(tx, userId, {
      amount,
      type: 'admin_adjust',
      description: `管理員調整：${description}`,
      counters: amount > 0
        ? { total_income: { increment: amount } }
        : { total_expense: { increment: Math.abs(amount) } },
      insufficientMessage: '調整後餘額會變成負數，請確認金額'
    });

    await notify(tx, {
      userId,
      title: amount > 0 ? '代幣已入帳' : '代幣已扣除',
      content: `客服調整了您的代幣 ${amount > 0 ? '+' : ''}${amount}，餘額 ${next}。原因：${description}`,
      relatedType: 'wallet'
    });

    return next;
  });

  await logAction(req.user.userId, '調整會員錢包', 'wallet', userId, `${amount > 0 ? '+' : ''}${amount}｜${description}`);
  res.status(200).json({ success: true, message: '已調整餘額', data: { balance } });
});

module.exports = router;
