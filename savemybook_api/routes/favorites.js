const express = require('express');
const prisma = require('../lib/prisma');
const authenticateToken = require('../middleware/auth');

const router = express.Router();

const bookInclude = {
  users: { select: { user_id: true, nickname: true, avatar_url: true } },
  book_images: { select: { image_url: true, image_type: true } },
  book_categories: { select: { category_name: true } }
};

router.get('/', authenticateToken, async (req, res) => {
  try {
    const favorites = await prisma.favorites.findMany({
      where: { user_id: req.user.userId },
      orderBy: { created_at: 'desc' },
      include: { books: { include: bookInclude } }
    });

    res.status(200).json({ success: true, data: favorites.map(f => f.books) });
  } catch (err) {
    console.error('[取得收藏清單失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.get('/ids', authenticateToken, async (req, res) => {
  try {
    const favorites = await prisma.favorites.findMany({
      where: { user_id: req.user.userId },
      select: { book_id: true }
    });
    res.status(200).json({ success: true, data: favorites.map(f => f.book_id) });
  } catch (err) {
    console.error('[取得收藏 ID 失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.post('/', authenticateToken, async (req, res) => {
  const bookId = parseInt(req.body.book_id);
  if (!bookId) return res.status(400).json({ success: false, message: '請提供 book_id' });

  try {
    const book = await prisma.books.findUnique({ where: { book_id: bookId } });
    if (!book) return res.status(404).json({ success: false, message: '找不到該書籍' });

    const favorite = await prisma.favorites.upsert({
      where: { user_id_book_id: { user_id: req.user.userId, book_id: bookId } },
      update: {},
      create: { user_id: req.user.userId, book_id: bookId }
    });

    res.status(201).json({ success: true, message: '已加入收藏', data: favorite });
  } catch (err) {
    console.error('[加入收藏失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.delete('/:bookId', authenticateToken, async (req, res) => {
  const bookId = parseInt(req.params.bookId);
  try {
    await prisma.favorites.deleteMany({
      where: { user_id: req.user.userId, book_id: bookId }
    });
    res.status(200).json({ success: true, message: '已取消收藏' });
  } catch (err) {
    console.error('[取消收藏失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

module.exports = router;
