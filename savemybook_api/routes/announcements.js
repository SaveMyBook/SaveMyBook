const express = require('express');
const authenticateToken = require('../middleware/auth');
const requireAdmin = require('../middleware/requireAdmin');
const v = require('../lib/validate');
const { actorOf } = require('../lib/request-context');
const { badRequest } = require('../lib/errors');
const { ANNOUNCEMENT_TYPES } = require('../constants/domain');
const announcements = require('../services/announcements');

const router = express.Router();

const canManage = [authenticateToken, requireAdmin('announcements')];

const title = (value) => v.text(value, { label: '標題', max: 255 });
const content = (value) => v.text(value, { label: '內容', max: 20000 });
const type = (value) => v.oneOf(value, ANNOUNCEMENT_TYPES, `type 僅接受：${ANNOUNCEMENT_TYPES.join(', ')}`);

router.get('/', async (req, res) => {
  res.status(200).json({ success: true, data: await announcements.listVisible() });
});

router.get('/all', ...canManage, async (req, res) => {
  res.status(200).json({ success: true, data: await announcements.listAll() });
});

// 必須排在 /all 之後，否則 all 會被當成公告編號。
router.get('/:id', async (req, res) => {
  const announcement = await announcements.findVisible(v.id(req.params.id, '公告編號'));
  res.status(200).json({ success: true, data: announcement });
});

router.post('/', ...canManage, async (req, res) => {
  const body = req.body;
  const data = {
    title: title(body.title),
    content: content(body.content),
    type: body.type ? type(body.type) : 'general',
    is_published: v.bool(body.is_published),
    expires_at: v.date(body.expires_at, '到期時間')
  };
  if (!data.title || !data.content) throw badRequest('請填寫標題與內容');

  const { announcement, notified } = await announcements.create(data, actorOf(req));
  res.status(201).json({
    success: true,
    message: notified ? `公告已發布，已通知 ${notified} 位使用者` : '公告已建立',
    data: announcement
  });
});

router.put('/:id', ...canManage, async (req, res) => {
  const announcementId = v.id(req.params.id, '公告編號');
  const body = req.body;

  const data = {
    title: body.title === undefined ? undefined : title(body.title),
    content: body.content === undefined ? undefined : content(body.content),
    type: body.type === undefined ? undefined : type(body.type),
    expires_at: body.expires_at === undefined ? undefined : v.date(body.expires_at, '到期時間')
  };
  if (data.title === '' || data.content === '') throw badRequest('請填寫標題與內容');

  const isPublished = body.is_published === undefined ? undefined : v.bool(body.is_published);
  const { announcement, notified } = await announcements.update(announcementId, data, isPublished, actorOf(req));
  res.status(200).json({
    success: true,
    message: notified ? `公告已發布，已通知 ${notified} 位使用者` : '公告已更新',
    data: announcement
  });
});

router.delete('/:id', ...canManage, async (req, res) => {
  await announcements.remove(v.id(req.params.id, '公告編號'), actorOf(req));
  res.status(200).json({ success: true, message: '公告已刪除' });
});

module.exports = router;
