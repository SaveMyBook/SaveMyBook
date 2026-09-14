const express = require('express');
const prisma = require('../lib/prisma');
const authenticateToken = require('../middleware/auth');
const v = require('../lib/validate');
const { badRequest } = require('../lib/errors');
const orders = require('../services/orders');

const router = express.Router();

router.use(authenticateToken);

// 前端頁籤 -> orders.status 對照表
const BUYER_TABS = {
  pending_pickup: ['pending_payment', 'pending_deposit', 'deposited', 'pending_pickup'],
  completed: ['completed'],
  cancelled: ['cancelled', 'refunded'],
  disputing: ['refunding']
};

const SELLER_TABS = {
  pending_deposit: ['pending_payment', 'pending_deposit'],
  on_sale: ['deposited', 'pending_pickup'],
  cancelled: ['cancelled', 'refunded'],
  completed: ['completed']
};

router.get('/', async (req, res) => {
  const role = req.query.role === 'seller' ? 'seller' : 'buyer';
  const tab = req.query.tab;
  const { page, limit, skip } = v.pagination(req.query);

  const tabMap = role === 'seller' ? SELLER_TABS : BUYER_TABS;
  const statuses = tab ? tabMap[tab] : null;
  if (tab && !statuses) throw badRequest(`不支援的 tab：${String(tab).slice(0, 30)}`);

  const where = {
    ...(role === 'seller' ? { seller_id: req.user.userId } : { buyer_id: req.user.userId }),
    ...(statuses && { status: { in: statuses } })
  };

  const [list, total] = await Promise.all([
    prisma.orders.findMany({
      where,
      skip,
      take: limit,
      orderBy: { created_at: 'desc' },
      include: orders.orderInclude
    }),
    prisma.orders.count({ where })
  ]);

  res.status(200).json({ success: true, pagination: v.pageMeta(total, { page, limit }), data: list });
});

router.get('/:id', async (req, res) => {
  const order = await orders.findForParty(v.id(req.params.id, '訂單編號'), req.user, orders.orderInclude);
  res.status(200).json({ success: true, data: order });
});

router.post('/checkout', async (req, res) => {
  let cartIds = null;
  if (req.body.cart_ids !== undefined && req.body.cart_ids !== null) {
    if (!Array.isArray(req.body.cart_ids) || req.body.cart_ids.length > 200) {
      throw badRequest('cart_ids 格式不正確');
    }
    cartIds = req.body.cart_ids.map((cid) => v.id(cid, '購物車項目編號'));
  }
  const paymentMethod = req.body.payment_method === 'bank_transfer' ? 'bank_transfer' : 'wallet';

  const created = await orders.checkout(req.user.userId, { cartIds, paymentMethod });
  res.status(201).json({ success: true, message: '結帳成功', data: created });
});

router.patch('/:id/cancel', async (req, res) => {
  const orderId = v.id(req.params.id, '訂單編號');
  const reason = v.optionalText(req.body.reason, { label: '取消原因', max: 500 }) ?? null;

  const updated = await orders.cancel(orderId, req.user, reason);
  res.status(200).json({ success: true, message: '訂單已取消', data: updated });
});

router.patch('/:id/status', async (req, res) => {
  const orderId = v.id(req.params.id, '訂單編號');
  const allowed = Object.keys(orders.TRANSITIONS);
  const status = v.oneOf(req.body.status, allowed, `status 僅接受：${allowed.join(', ')}`);

  const updated = await orders.advance(orderId, status, req.user);
  res.status(200).json({ success: true, message: '訂單狀態已更新', data: updated });
});

module.exports = router;
