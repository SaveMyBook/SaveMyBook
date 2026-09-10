const express = require('express');
const prisma = require('../lib/prisma');
const authenticateToken = require('../middleware/auth');

const router = express.Router();

const cartInclude = {
  books: {
    include: {
      users: { select: { user_id: true, nickname: true, avatar_url: true } },
      book_images: { select: { image_url: true, image_type: true } },
      book_categories: { select: { category_name: true } },
      smart_cabinets: { select: { cabinet_id: true, cabinet_name: true, address: true } }
    }
  }
};

router.get('/', authenticateToken, async (req, res) => {
  try {
    const items = await prisma.shopping_cart.findMany({
      where: { user_id: req.user.userId },
      orderBy: { added_at: 'desc' },
      include: cartInclude
    });

    const total = items.reduce((sum, i) => sum + Number(i.books.price) * i.quantity, 0);

    res.status(200).json({ success: true, data: items, total_amount: total });
  } catch (err) {
    console.error('[取得購物車失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.post('/', authenticateToken, async (req, res) => {
  const bookId = parseInt(req.body.book_id);
  const quantity = parseInt(req.body.quantity) || 1;
  if (!bookId) return res.status(400).json({ success: false, message: '請提供 book_id' });

  try {
    const book = await prisma.books.findUnique({ where: { book_id: bookId } });
    if (!book) return res.status(404).json({ success: false, message: '找不到該書籍' });
    if (book.seller_id === req.user.userId) {
      return res.status(400).json({ success: false, message: '無法將自己上架的書籍加入購物車' });
    }
    if (book.status !== 'on_sale') {
      return res.status(400).json({ success: false, message: '此書籍目前無法購買' });
    }

    const item = await prisma.shopping_cart.upsert({
      where: { user_id_book_id: { user_id: req.user.userId, book_id: bookId } },
      update: { quantity: { increment: quantity } },
      create: { user_id: req.user.userId, book_id: bookId, quantity }
    });

    res.status(201).json({ success: true, message: '已加入購物車', data: item });
  } catch (err) {
    console.error('[加入購物車失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.patch('/:cartId', authenticateToken, async (req, res) => {
  const cartId = parseInt(req.params.cartId);
  const quantity = parseInt(req.body.quantity);
  if (!quantity || quantity < 1) {
    return res.status(400).json({ success: false, message: 'quantity 必須大於 0' });
  }

  try {
    const item = await prisma.shopping_cart.findUnique({ where: { cart_id: cartId } });
    if (!item) return res.status(404).json({ success: false, message: '找不到該購物車項目' });
    if (item.user_id !== req.user.userId) {
      return res.status(403).json({ success: false, message: '存取被拒' });
    }

    const updated = await prisma.shopping_cart.update({
      where: { cart_id: cartId },
      data: { quantity }
    });
    res.status(200).json({ success: true, message: '已更新數量', data: updated });
  } catch (err) {
    console.error('[更新購物車失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.delete('/:cartId', authenticateToken, async (req, res) => {
  const cartId = parseInt(req.params.cartId);
  try {
    const result = await prisma.shopping_cart.deleteMany({
      where: { cart_id: cartId, user_id: req.user.userId }
    });
    if (result.count === 0) {
      return res.status(404).json({ success: false, message: '找不到該購物車項目' });
    }
    res.status(200).json({ success: true, message: '已從購物車移除' });
  } catch (err) {
    console.error('[移除購物車項目失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

module.exports = router;
