const express = require('express');
const authenticateToken = require('../middleware/auth');
const v = require('../lib/validate');
const { badRequest } = require('../lib/errors');
const favorites = require('../services/favorites');

const router = express.Router();

router.use(authenticateToken);

router.get('/', async (req, res) => {
  res.status(200).json({ success: true, data: await favorites.list(req.user.userId) });
});

router.get('/ids', async (req, res) => {
  res.status(200).json({ success: true, data: await favorites.bookIds(req.user.userId) });
});

router.post('/', async (req, res) => {
  if (req.body.book_id === undefined) throw badRequest('請指定書籍');
  const bookId = v.id(req.body.book_id, '書籍編號');

  const favorite = await favorites.add(req.user.userId, bookId);
  res.status(201).json({ success: true, message: '已加入收藏', data: favorite });
});

router.delete('/:bookId', async (req, res) => {
  await favorites.remove(req.user.userId, v.id(req.params.bookId, '書籍編號'));
  res.status(200).json({ success: true, message: '已取消收藏' });
});

module.exports = router;
