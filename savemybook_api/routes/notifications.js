const express = require('express');
const authenticateToken = require('../middleware/auth');
const v = require('../lib/validate');
const { NOTIFICATION_TYPES } = require('../constants/domain');
const notifications = require('../services/notifications');
const { CATEGORIES } = require('../services/notification-categories');

const router = express.Router();

const categoryParam = (query) => (query.category ? v.oneOf(query.category, CATEGORIES, '不支援的通知分類') : null);

router.use(authenticateToken);

router.get('/', async (req, res) => {
  const { page, limit, skip } = v.pagination(req.query);
  const type = req.query.type ? v.oneOf(req.query.type, NOTIFICATION_TYPES, '不支援的通知類型') : null;
  const category = categoryParam(req.query);

  const result = await notifications.list(req.user.userId, { skip, limit, type, category });

  res.status(200).json({
    success: true,
    unread_count: result.unread,
    pagination: v.pageMeta(result.total, { page, limit }),
    data: result.notifications
  });
});

router.get('/unread-count', async (req, res) => {
  const { total, byCategory } = await notifications.unreadByCategory(req.user.userId);
  res.status(200).json({ success: true, data: { unread_count: total, by_category: byCategory } });
});

router.patch('/read-all', async (req, res) => {
  const updated = await notifications.markAllRead(req.user.userId, { category: categoryParam(req.query) });
  res.status(200).json({ success: true, message: '已全部標為已讀', data: { updated } });
});

router.patch('/:id/read', async (req, res) => {
  await notifications.markRead(req.user.userId, v.id(req.params.id, '通知編號'));
  res.status(200).json({ success: true, message: '已標為已讀' });
});

// 必須排在 /:id 之前，否則 all 會被當成通知編號。
router.delete('/all', async (req, res) => {
  const deleted = await notifications.removeAll(req.user.userId, { category: categoryParam(req.query) });
  res.status(200).json({
    success: true,
    message: `已清除 ${deleted} 則通知`,
    data: { deleted }
  });
});

router.delete('/:id', async (req, res) => {
  await notifications.remove(req.user.userId, v.id(req.params.id, '通知編號'));
  res.status(200).json({ success: true, message: '通知已刪除' });
});

module.exports = router;
