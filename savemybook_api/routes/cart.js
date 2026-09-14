const express = require('express');
const prisma = require('../lib/prisma');
const authenticateToken = require('../middleware/auth');
const v = require('../lib/validate');
const { badRequest, forbidden, notFound } = require('../lib/errors');
const reservations = require('../services/reservations');

const router = express.Router();

router.use(authenticateToken);

const cartInclude = {
  books: {
    include: {
      users: { select: { user_id: true, nickname: true, avatar_url: true } },
      book_images: { select: { image_id: true, image_url: true, image_type: true } },
      book_categories: { select: { category_name: true } },
      smart_cabinets: { select: { cabinet_id: true, cabinet_name: true, address: true } }
    }
  }
};

const MAX_CART_ITEMS = 100;

router.get('/', async (req, res) => {
  const items = await prisma.shopping_cart.findMany({
    where: { user_id: req.user.userId },
    orderBy: { added_at: 'desc' },
    include: cartInclude
  });

  const now = new Date();
  const holds = items.length > 0
    ? await prisma.reservations.findMany({
        where: { book_id: { in: items.map((i) => i.book_id) }, status: 'confirmed', pickup_deadline: { gt: now } },
        select: { book_id: true, buyer_id: true, pickup_deadline: true }
      })
    : [];
  const holdOf = new Map(holds.map((h) => [h.book_id, h]));
  const data = items.map((i) => {
    const hold = holdOf.get(i.book_id);
    return hold
      ? { ...i, books: { ...i.books, reservation: { reserved_until: hold.pickup_deadline, reserved_for_me: hold.buyer_id === req.user.userId } } }
      : i;
  });

  const total = items.reduce((sum, i) => sum + Number(i.books.price) * i.quantity, 0);
  res.status(200).json({ success: true, data, total_amount: total });
});

router.post('/', async (req, res) => {
  if (req.body.book_id === undefined) throw badRequest('請提供 book_id');
  const bookId = v.id(req.body.book_id, '書籍編號');
  const quantity = req.body.quantity === undefined ? 1 : v.int(req.body.quantity, { label: '數量', min: 1, max: 99 });

  const book = await prisma.books.findUnique({
    where: { book_id: bookId },
    select: { book_id: true, title: true, seller_id: true, status: true, quantity: true }
  });
  if (!book) throw notFound('找不到該書籍');
  if (book.seller_id === req.user.userId) throw badRequest('無法將自己上架的書籍加入購物車');
  if (book.status !== 'on_sale') throw badRequest('此書籍目前無法購買');
  await reservations.assertNotHeldByOthers(null, [book], req.user.userId);

  const existing = await prisma.shopping_cart.findUnique({
    where: { user_id_book_id: { user_id: req.user.userId, book_id: bookId } },
    select: { quantity: true }
  });
  if (!existing && (await prisma.shopping_cart.count({ where: { user_id: req.user.userId } })) >= MAX_CART_ITEMS) {
    throw badRequest(`購物車最多可放入 ${MAX_CART_ITEMS} 項商品`);
  }

  const max = Math.max(book.quantity, 1);
  if (existing && existing.quantity >= max) {
    return res.status(200).json({
      success: true,
      message: '此書籍已在購物車中',
      data: { ...existing, book_id: bookId },
      already_in_cart: true
    });
  }

  // 重複加入不可累加數量，否則結帳會對同一本書重複收費。
  const capped = Math.min((existing?.quantity ?? 0) + quantity, max);

  const item = await prisma.shopping_cart.upsert({
    where: { user_id_book_id: { user_id: req.user.userId, book_id: bookId } },
    update: { quantity: capped },
    create: { user_id: req.user.userId, book_id: bookId, quantity: capped }
  });

  res.status(existing ? 200 : 201).json({ success: true, message: '已加入購物車', data: item, already_in_cart: false });
});

router.get('/book-ids', async (req, res) => {
  const items = await prisma.shopping_cart.findMany({ where: { user_id: req.user.userId }, select: { book_id: true } });
  res.status(200).json({ success: true, data: items.map((i) => i.book_id) });
});

router.patch('/:cartId', async (req, res) => {
  const cartId = v.id(req.params.cartId, '購物車項目編號');
  const quantity = v.toInt(req.body.quantity);
  if (!Number.isSafeInteger(quantity) || quantity < 1) throw badRequest('quantity 必須大於 0');

  const item = await prisma.shopping_cart.findUnique({
    where: { cart_id: cartId },
    include: { books: { select: { quantity: true } } }
  });
  if (!item) throw notFound('找不到該購物車項目');
  if (item.user_id !== req.user.userId) throw forbidden('存取被拒');

  const max = Math.max(item.books.quantity, 1);
  if (quantity > max) throw badRequest(`此書籍數量僅 ${max} 本`);

  const updated = await prisma.shopping_cart.update({ where: { cart_id: cartId }, data: { quantity } });
  res.status(200).json({ success: true, message: '已更新數量', data: updated });
});

router.delete('/:cartId', async (req, res) => {
  const cartId = v.id(req.params.cartId, '購物車項目編號');
  const result = await prisma.shopping_cart.deleteMany({ where: { cart_id: cartId, user_id: req.user.userId } });
  if (result.count === 0) throw notFound('找不到該購物車項目');
  res.status(200).json({ success: true, message: '已從購物車移除' });
});

module.exports = router;
