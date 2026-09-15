const express = require('express');
const prisma = require('../lib/prisma');
const authenticateToken = require('../middleware/auth');
const v = require('../lib/validate');
const { badRequest, notFound } = require('../lib/errors');

const router = express.Router();

router.use(authenticateToken);

const bookInclude = {
  users: { select: { user_id: true, nickname: true, avatar_url: true } },
  book_images: { select: { image_id: true, image_url: true, image_type: true } },
  book_categories: { select: { category_name: true } }
};

router.get('/', async (req, res) => {
  const favorites = await prisma.favorites.findMany({
    where: { user_id: req.user.userId, books: { is_approved: true } },
    orderBy: { created_at: 'desc' },
    include: { books: { include: bookInclude } }
  });
  res.status(200).json({ success: true, data: favorites.map((f) => f.books) });
});

router.get('/ids', async (req, res) => {
  const favorites = await prisma.favorites.findMany({
    where: { user_id: req.user.userId },
    select: { book_id: true }
  });
  res.status(200).json({ success: true, data: favorites.map((f) => f.book_id) });
});

router.post('/', async (req, res) => {
  if (req.body.book_id === undefined) throw badRequest('請提供 book_id');
  const bookId = v.id(req.body.book_id, '書籍編號');

  const book = await prisma.books.findUnique({ where: { book_id: bookId }, select: { book_id: true } });
  if (!book) throw notFound('找不到該書籍');

  const favorite = await prisma.favorites.upsert({
    where: { user_id_book_id: { user_id: req.user.userId, book_id: bookId } },
    update: {},
    create: { user_id: req.user.userId, book_id: bookId }
  });

  res.status(201).json({ success: true, message: '已加入收藏', data: favorite });
});

router.delete('/:bookId', async (req, res) => {
  const bookId = v.id(req.params.bookId, '書籍編號');
  await prisma.favorites.deleteMany({ where: { user_id: req.user.userId, book_id: bookId } });
  res.status(200).json({ success: true, message: '已取消收藏' });
});

module.exports = router;
