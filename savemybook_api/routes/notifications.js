const express = require('express');
const prisma = require('../lib/prisma');
const authenticateToken = require('../middleware/auth');
const v = require('../lib/validate');
const { notFound } = require('../lib/errors');
const { NOTIFICATION_TYPES } = require('../constants/domain');

const router = express.Router();

router.use(authenticateToken);

router.get('/', async (req, res) => {
  const { page, limit, skip } = v.pagination(req.query);
  const type = req.query.type ? v.oneOf(req.query.type, NOTIFICATION_TYPES, '不支援的通知類型') : null;

  const where = { user_id: req.user.userId, ...(type && { type }) };

  const [notifications, total, unreadCount] = await Promise.all([
    prisma.notifications.findMany({ where, skip, take: limit, orderBy: { created_at: 'desc' } }),
    prisma.notifications.count({ where }),
    prisma.notifications.count({ where: { user_id: req.user.userId, is_read: false } })
  ]);

  res.status(200).json({
    success: true,
    unread_count: unreadCount,
    pagination: v.pageMeta(total, { page, limit }),
    data: notifications
  });
});

router.get('/unread-count', async (req, res) => {
  const count = await prisma.notifications.count({ where: { user_id: req.user.userId, is_read: false } });
  res.status(200).json({ success: true, data: { unread_count: count } });
});

router.patch('/read-all', async (req, res) => {
  await prisma.notifications.updateMany({
    where: { user_id: req.user.userId, is_read: false },
    data: { is_read: true }
  });
  res.status(200).json({ success: true, message: '已全部標為已讀' });
});

router.patch('/:id/read', async (req, res) => {
  const result = await prisma.notifications.updateMany({
    where: { notification_id: v.id(req.params.id, '通知編號'), user_id: req.user.userId },
    data: { is_read: true }
  });
  if (result.count === 0) throw notFound('找不到該通知');
  res.status(200).json({ success: true, message: '已標為已讀' });
});

// 必須排在 /:id 之前，否則 all 會被當成通知編號。
router.delete('/all', async (req, res) => {
  const result = await prisma.notifications.deleteMany({ where: { user_id: req.user.userId } });
  res.status(200).json({
    success: true,
    message: `已清除 ${result.count} 則通知`,
    data: { deleted: result.count }
  });
});

router.delete('/:id', async (req, res) => {
  const result = await prisma.notifications.deleteMany({
    where: { notification_id: v.id(req.params.id, '通知編號'), user_id: req.user.userId }
  });
  if (result.count === 0) throw notFound('找不到該通知');
  res.status(200).json({ success: true, message: '通知已刪除' });
});

module.exports = router;
