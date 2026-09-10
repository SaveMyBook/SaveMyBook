const express = require('express');
const prisma = require('../lib/prisma');
const authenticateToken = require('../middleware/auth');

const router = express.Router();

router.get('/', authenticateToken, async (req, res) => {
  const page = parseInt(req.query.page) || 1;
  const limit = parseInt(req.query.limit) || 20;
  const type = req.query.type;

  try {
    const where = {
      user_id: req.user.userId,
      ...(type && { type })
    };

    const [notifications, totalCount, unreadCount] = await Promise.all([
      prisma.notifications.findMany({
        where,
        skip: (page - 1) * limit,
        take: limit,
        orderBy: { created_at: 'desc' }
      }),
      prisma.notifications.count({ where }),
      prisma.notifications.count({ where: { user_id: req.user.userId, is_read: false } })
    ]);

    res.status(200).json({
      success: true,
      unread_count: unreadCount,
      pagination: { total: totalCount, page, limit, total_pages: Math.ceil(totalCount / limit) },
      data: notifications
    });
  } catch (err) {
    console.error('[取得通知失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.get('/unread-count', authenticateToken, async (req, res) => {
  try {
    const count = await prisma.notifications.count({
      where: { user_id: req.user.userId, is_read: false }
    });
    res.status(200).json({ success: true, data: { unread_count: count } });
  } catch (err) {
    console.error('[取得未讀數失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.patch('/read-all', authenticateToken, async (req, res) => {
  try {
    await prisma.notifications.updateMany({
      where: { user_id: req.user.userId, is_read: false },
      data: { is_read: true }
    });
    res.status(200).json({ success: true, message: '已全部標為已讀' });
  } catch (err) {
    console.error('[標記全部已讀失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.patch('/:id/read', authenticateToken, async (req, res) => {
  const notificationId = parseInt(req.params.id);
  try {
    const result = await prisma.notifications.updateMany({
      where: { notification_id: notificationId, user_id: req.user.userId },
      data: { is_read: true }
    });
    if (result.count === 0) return res.status(404).json({ success: false, message: '找不到該通知' });
    res.status(200).json({ success: true, message: '已標為已讀' });
  } catch (err) {
    console.error('[標記已讀失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.delete('/:id', authenticateToken, async (req, res) => {
  const notificationId = parseInt(req.params.id);
  try {
    const result = await prisma.notifications.deleteMany({
      where: { notification_id: notificationId, user_id: req.user.userId }
    });
    if (result.count === 0) return res.status(404).json({ success: false, message: '找不到該通知' });
    res.status(200).json({ success: true, message: '通知已刪除' });
  } catch (err) {
    console.error('[刪除通知失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

module.exports = router;
