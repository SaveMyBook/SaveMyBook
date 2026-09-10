const express = require('express');
const prisma = require('../lib/prisma');
const authenticateToken = require('../middleware/auth');

const router = express.Router();

const PENDING_INCOME_STATUS = ['pending_payment', 'pending_deposit', 'deposited', 'pending_pickup'];

const ensureWallet = async (userId) => {
  return prisma.wallets.upsert({
    where: { user_id: userId },
    update: {},
    create: { user_id: userId }
  });
};

router.get('/', authenticateToken, async (req, res) => {
  try {
    const wallet = await ensureWallet(req.user.userId);

    const pending = await prisma.orders.aggregate({
      where: { seller_id: req.user.userId, status: { in: PENDING_INCOME_STATUS } },
      _sum: { total_amount: true }
    });

    res.status(200).json({
      success: true,
      data: {
        ...wallet,
        pending_income: pending._sum.total_amount ?? 0
      }
    });
  } catch (err) {
    console.error('[取得錢包失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.get('/transactions', authenticateToken, async (req, res) => {
  const page = parseInt(req.query.page) || 1;
  const limit = parseInt(req.query.limit) || 20;

  try {
    const where = { wallets: { user_id: req.user.userId } };

    const [transactions, totalCount] = await Promise.all([
      prisma.wallet_transactions.findMany({
        where,
        skip: (page - 1) * limit,
        take: limit,
        orderBy: { created_at: 'desc' },
        include: {
          orders: {
            select: {
              order_id: true,
              order_no: true,
              order_items: {
                take: 1,
                include: { books: { select: { title: true, book_images: { select: { image_url: true }, take: 1 } } } }
              }
            }
          }
        }
      }),
      prisma.wallet_transactions.count({ where })
    ]);

    res.status(200).json({
      success: true,
      pagination: { total: totalCount, page, limit, total_pages: Math.ceil(totalCount / limit) },
      data: transactions
    });
  } catch (err) {
    console.error('[取得交易紀錄失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.get('/pending', authenticateToken, async (req, res) => {
  try {
    const orders = await prisma.orders.findMany({
      where: { seller_id: req.user.userId, status: { in: PENDING_INCOME_STATUS } },
      orderBy: { created_at: 'desc' },
      include: {
        order_items: {
          include: { books: { include: { book_images: { select: { image_url: true, image_type: true } } } } }
        },
        smart_cabinets: { select: { cabinet_id: true, cabinet_name: true, address: true } },
        cabinet_slots: { select: { slot_number: true } }
      }
    });

    const total = orders.reduce((sum, o) => sum + Number(o.total_amount), 0);

    res.status(200).json({ success: true, total_amount: total, data: orders });
  } catch (err) {
    console.error('[取得待定收益失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

module.exports = router;
