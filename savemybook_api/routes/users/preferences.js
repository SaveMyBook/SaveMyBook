const express = require('express');
const authenticateToken = require('../../middleware/auth');
const { text, int } = require('../../lib/validate');
const { badRequest } = require('../../lib/errors');
const users = require('../../services/users');
const legal = require('../../services/legal');

const router = express.Router();

router.get('/me/notification-settings', authenticateToken, async (req, res) => {
  res.status(200).json({ success: true, data: await users.notificationSettings(req.user.userId) });
});

router.put('/me/notification-settings', authenticateToken, async (req, res) => {
  const data = {};
  for (const [key, column] of Object.entries(users.NOTIFICATION_SETTINGS)) {
    if (req.body[key] !== undefined) {
      if (typeof req.body[key] !== 'boolean') throw badRequest(`${key} 必須是 true 或 false`);
      data[column] = req.body[key];
    }
  }
  if (Object.keys(data).length === 0) throw badRequest('沒有要更新的設定');

  const settings = await users.updateNotificationSettings(req.user.userId, data);
  res.status(200).json({ success: true, message: '已更新通知設定', data: settings });
});

router.get('/me/legal-consents/pending', authenticateToken, async (req, res) => {
  res.status(200).json({ success: true, data: await legal.pendingDocs(req.user.userId) });
});

router.post('/me/legal-consents', authenticateToken, async (req, res) => {
  const docKey = text(req.body.doc_key, { label: '文件代碼', max: 50 });
  const version = int(req.body.version, { label: '版本', min: 1, max: 1000000 });

  await legal.acceptVersion(req.user.userId, docKey, version);
  res.status(200).json({ success: true, message: '已同意' });
});

module.exports = router;
