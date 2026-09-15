const express = require('express');
const requireAdmin = require('../../middleware/requireAdmin');
const v = require('../../lib/validate');
const { actorOf } = require('../../lib/request-context');
const { ORDER_STATUSES } = require('../../constants/domain');
const orders = require('../../services/orders');

const router = express.Router();
const canManage = requireAdmin('orders');

router.get('/orders', canManage, async (req, res) => {
  const keyword = v.text(req.query.keyword, { label: '關鍵字', max: 100 });
  const status = req.query.status;
  const { page, limit, skip } = v.pagination(req.query);

  if (status && status !== 'all') v.oneOf(status, ORDER_STATUSES, '不支援的訂單狀態');

  const { orders: data, total } = await orders.adminList({ keyword, status, skip, limit });
  res.status(200).json({ success: true, pagination: v.pageMeta(total, { page, limit }), data });
});

router.get('/orders/:id', canManage, async (req, res) => {
  res.status(200).json({ success: true, data: await orders.adminDetail(v.id(req.params.id, '訂單編號')) });
});

router.patch('/orders/:id', canManage, async (req, res) => {
  const orderId = v.id(req.params.id, '訂單編號');
  const status = v.oneOf(req.body.status, ORDER_STATUSES, '不支援的訂單狀態');
  const note = v.optionalText(req.body.note, { label: '說明', max: 500 }) ?? null;

  const { money, effect } = await orders.adminChangeStatus(orderId, status, note, actorOf(req));
  res.status(200).json({
    success: true,
    message: effect ? `訂單狀態已更新，${effect}` : '訂單狀態已更新',
    data: { paid_out: money.paidOut, clawed_back: money.clawedBack, refunded: money.refunded }
  });
});

module.exports = router;
