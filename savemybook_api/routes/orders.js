const express = require('express');
const authenticateToken = require('../middleware/auth');
const { requireVerification } = require('../middleware/verification');
const v = require('../lib/validate');
const { badRequest } = require('../lib/errors');
const orders = require('../services/orders');
const cabinetAccess = require('../services/cabinet-access');
const cabinetManual = require('../services/cabinet-manual');

const router = express.Router();

router.use(authenticateToken);

router.get('/', async (req, res) => {
  const role = req.query.role === 'seller' ? 'seller' : 'buyer';
  const tab = req.query.tab;
  const { page, limit, skip } = v.pagination(req.query);

  const filter = tab ? orders.tabFilter(role, tab) : null;
  if (tab && !filter) throw badRequest('請求內容不正確');

  const { list, total } = await orders.listForUser(req.user.userId, { role, filter, skip, limit });
  const data = await cabinetManual.decorateOrders(await cabinetAccess.decorateOrders(list));
  res.status(200).json({ success: true, pagination: v.pageMeta(total, { page, limit }), data });
});

router.get('/by-no/:orderNo', async (req, res) => {
  const orderNo = String(req.params.orderNo ?? '').trim().toUpperCase();
  if (!orders.ORDER_NO_PATTERN.test(orderNo)) throw badRequest('訂單編號格式不正確');
  const order = await orders.detailForPartyByNo(orderNo, req.user);
  res.status(200).json({ success: true, data: await cabinetManual.decorateOrders(await cabinetAccess.decorateOrders(order)) });
});

router.get('/:id', async (req, res) => {
  const order = await orders.detailForParty(v.id(req.params.id, '訂單編號'), req.user);
  res.status(200).json({ success: true, data: await cabinetManual.decorateOrders(await cabinetAccess.decorateOrders(order)) });
});

router.post('/checkout', requireVerification('payment'), async (req, res) => {
  let cartIds = null;
  if (req.body.cart_ids !== undefined && req.body.cart_ids !== null) {
    if (!Array.isArray(req.body.cart_ids) || req.body.cart_ids.length > 200) {
      throw badRequest('購物車項目格式不正確');
    }
    cartIds = req.body.cart_ids.map((cid) => v.id(cid, '購物車項目編號'));
  }
  const created = await orders.checkout(req.user.userId, { cartIds, paymentMethod: 'wallet' });
  res.status(201).json({ success: true, message: '結帳成功', data: created });
});

router.post('/buy-now', requireVerification('payment'), async (req, res) => {
  const bookId = v.id(req.body.book_id, '書籍編號');
  const order = await orders.buyNow(req.user.userId, { bookId, paymentMethod: 'wallet' });
  res.status(201).json({ success: true, message: '購買成功', data: order });
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
  const status = v.oneOf(req.body.status, allowed, '訂單狀態不正確');

  const updated = await orders.advance(orderId, status, req.user);
  if (cabinetManual.isPending(updated)) {
    const data = await cabinetAccess.decorateOrders(updated);
    return res.status(202).json({ success: true, message: '已送出手動回報，待客服確認後生效', data });
  }
  res.status(200).json({ success: true, message: '訂單狀態已更新', data: updated });
});

module.exports = router;
