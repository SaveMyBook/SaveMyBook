const express = require('express');
const authenticateToken = require('../middleware/auth');
const v = require('../lib/validate');
const { badRequest } = require('../lib/errors');
const cart = require('../services/cart');

const router = express.Router();

router.use(authenticateToken);

router.get('/', async (req, res) => {
  const { items, total } = await cart.list(req.user.userId);
  res.status(200).json({ success: true, data: items, total_amount: total });
});

router.post('/', async (req, res) => {
  if (req.body.book_id === undefined) throw badRequest('請提供 book_id');
  const bookId = v.id(req.body.book_id, '書籍編號');
  const quantity = req.body.quantity === undefined ? 1 : v.int(req.body.quantity, { label: '數量', min: 1, max: 99 });

  const { alreadyInCart, created, item } = await cart.add(req.user.userId, bookId, quantity);
  if (alreadyInCart) {
    return res.status(200).json({
      success: true,
      message: '此書籍已在購物車中',
      data: item,
      already_in_cart: true
    });
  }
  res.status(created ? 201 : 200).json({ success: true, message: '已加入購物車', data: item, already_in_cart: false });
});

router.get('/book-ids', async (req, res) => {
  res.status(200).json({ success: true, data: await cart.bookIds(req.user.userId) });
});

router.patch('/:cartId', async (req, res) => {
  const cartId = v.id(req.params.cartId, '購物車項目編號');
  const quantity = v.toInt(req.body.quantity);
  if (!Number.isSafeInteger(quantity) || quantity < 1) throw badRequest('quantity 必須大於 0');

  const updated = await cart.setQuantity(req.user.userId, cartId, quantity);
  res.status(200).json({ success: true, message: '已更新數量', data: updated });
});

router.delete('/:cartId', async (req, res) => {
  await cart.remove(req.user.userId, v.id(req.params.cartId, '購物車項目編號'));
  res.status(200).json({ success: true, message: '已從購物車移除' });
});

module.exports = router;
