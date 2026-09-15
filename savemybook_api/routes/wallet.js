const express = require('express');
const authenticateToken = require('../middleware/auth');
const v = require('../lib/validate');
const wallet = require('../services/wallet');

const router = express.Router();

router.use(authenticateToken);

router.get('/', async (req, res) => {
  res.status(200).json({ success: true, data: await wallet.summary(req.user.userId) });
});

router.get('/transactions', async (req, res) => {
  const { page, limit, skip } = v.pagination(req.query);
  const { rows, total } = await wallet.transactions(req.user.userId, { skip, limit });

  res.status(200).json({
    success: true,
    pagination: v.pageMeta(total, { page, limit }),
    data: rows
  });
});

router.get('/pending', async (req, res) => {
  const { orders, total } = await wallet.pendingIncome(req.user.userId);
  res.status(200).json({ success: true, total_amount: total, data: orders });
});

module.exports = router;
