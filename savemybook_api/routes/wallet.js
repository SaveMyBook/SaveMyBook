const express = require('express');
const prisma = require('../lib/prisma');
const authenticateToken = require('../middleware/auth');
const v = require('../lib/validate');
const { ORDER_OPEN_STATUSES } = require('../constants/domain');
const { ensureWallet } = require('../services/wallet');

const router = express.Router();

router.use(authenticateToken);

router.get('/', async (req, res) => {
  const [wallet, pending] = await Promise.all([
    ensureWallet(prisma, req.user.userId),
    prisma.orders.aggregate({
      where: { seller_id: req.user.userId, status: { in: ORDER_OPEN_STATUSES } },
      _sum: { total_amount: true }
    })
  ]);

  res.status(200).json({
    success: true,
    data: { ...wallet, pending_income: pending._sum.total_amount ?? 0 }
  });
});

router.get('/transactions', async (req, res) => {
  const { page, limit, skip } = v.pagination(req.query);
  const where = { wallets: { user_id: req.user.userId } };

  const [transactions, total] = await Promise.all([
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

  res.status(200).json({ success: true, pagination: v.pageMeta(total, { page, limit }), data: transactions });
});

router.get('/pending', async (req, res) => {
  const orders = await prisma.orders.findMany({
    where: { seller_id: req.user.userId, status: { in: ORDER_OPEN_STATUSES } },
    orderBy: { created_at: 'desc' },
    include: {
      order_items: {
        include: {
          books: {
            include: { book_images: { select: { image_url: true, image_type: true } } }
          }
        }
      },
      smart_cabinets: { select: { cabinet_id: true, cabinet_name: true, address: true } },
      cabinet_slots: { select: { slot_number: true } }
    }
  });

  const total = orders.reduce((sum, o) => sum + Number(o.total_amount), 0);
  res.status(200).json({ success: true, total_amount: total, data: orders });
});

module.exports = router;
