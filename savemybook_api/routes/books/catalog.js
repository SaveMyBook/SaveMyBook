const express = require('express');
const authenticateToken = require('../../middleware/auth');
const { peekUserId } = require('../../middleware/auth');
const { rateLimit, byUser } = require('../../middleware/rateLimit');
const v = require('../../lib/validate');
const { publicBase } = require('../../lib/public-url');
const { badRequest } = require('../../lib/errors');
const { BOOK_STATUSES } = require('../../constants/domain');
const books = require('../../services/books');
const ranking = require('../../services/ranking');

const router = express.Router();

const PUBLIC_STATUSES = BOOK_STATUSES.filter((s) => s !== 'removed');

const isbnLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 30,
  key: byUser,
  message: '查詢過於頻繁，請稍後再試'
});

const positiveIds = (value) => (typeof value === 'string'
  ? value.split(',').map(v.toInt).filter((n) => Number.isSafeInteger(n) && n > 0)
  : []);

router.get('/isbn/:isbn', authenticateToken, isbnLimiter, async (req, res) => {
  const code = String(req.params.isbn || '').replace(/[-\s]/g, '');
  if (!/^(\d{9}[\dXx]|\d{13})$/.test(code)) throw badRequest('ISBN 必須是 10 或 13 碼');

  res.status(200).json({ success: true, data: await books.lookupIsbn(code) });
});

router.get('/', async (req, res) => {
  const { page, limit, skip } = v.pagination(req.query);
  const keyword = v.text(req.query.keyword, { label: '關鍵字', max: 100 });
  const status = req.query.status || 'on_sale';
  const sort = books.SORTS[req.query.sort] ? req.query.sort : 'newest';
  const sellerId = v.optionalId(req.query.seller_id, '賣家編號');
  const viewerId = peekUserId(req);
  const ownView = sellerId != null && sellerId === viewerId;

  if (status !== 'all') v.oneOf(status, ownView ? BOOK_STATUSES : PUBLIC_STATUSES, '不支援的書籍狀態');

  const { total, books: data } = await books.list({
    skip,
    limit,
    sort,
    viewerId,
    status,
    sellerId,
    ownView,
    keyword,
    categoryIds: positiveIds(req.query.category_ids).slice(0, 50)
  });

  res.status(200).json({ success: true, pagination: v.pageMeta(total, { page, limit }), data });
});

router.get('/recommended', async (req, res) => {
  const { limit } = v.pagination(req.query, { limit: 12, max: ranking.RECOMMEND_LIMIT });
  const viewedIds = [...new Set(positiveIds(req.query.viewed_ids))].slice(0, 20);

  const data = await books.recommended(peekUserId(req), viewedIds, limit);
  res.status(200).json({ success: true, data });
});

router.get('/briefs', async (req, res) => {
  const ids = [...new Set(positiveIds(req.query.ids))].slice(0, 50);
  res.status(200).json({ success: true, data: await books.briefs(ids) });
});

router.get('/share/:token', async (req, res) => {
  const data = await books.findByShareToken(String(req.params.token || '').toLowerCase(), peekUserId(req));
  res.status(200).json({ success: true, data });
});

router.get('/:id/share-link', async (req, res) => {
  const data = await books.shareLink(v.id(req.params.id, '書籍編號'), publicBase(req));
  res.status(200).json({ success: true, data });
});

router.get('/:id', async (req, res) => {
  const bookId = v.id(req.params.id, '書籍編號');
  const data = await books.detail(bookId, { viewerId: peekUserId(req), viewerKey: req.ip });
  res.status(200).json({ success: true, data });
});

module.exports = router;
