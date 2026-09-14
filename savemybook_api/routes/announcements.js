const express = require('express');
const prisma = require('../lib/prisma');
const authenticateToken = require('../middleware/auth');
const requireAdmin = require('../middleware/requireAdmin');
const v = require('../lib/validate');
const { badRequest, notFound, orNotFound } = require('../lib/errors');
const { ANNOUNCEMENT_TYPES } = require('../constants/domain');
const { logAction } = require('../services/audit');

const router = express.Router();

const canManage = [authenticateToken, requireAdmin('announcements')];
const withAuthor = { users: { select: { user_id: true, nickname: true } } };

const title = (value) => v.text(value, { label: '標題', max: 255 });
const content = (value) => v.text(value, { label: '內容', max: 20000 });
const type = (value) => v.oneOf(value, ANNOUNCEMENT_TYPES, `type 僅接受：${ANNOUNCEMENT_TYPES.join(', ')}`);

router.get('/', async (req, res) => {
  const announcements = await prisma.system_announcements.findMany({
    where: {
      is_published: true,
      OR: [{ expires_at: null }, { expires_at: { gt: new Date() } }]
    },
    orderBy: { published_at: 'desc' },
    include: withAuthor
  });
  res.status(200).json({ success: true, data: announcements });
});

router.get('/all', ...canManage, async (req, res) => {
  const announcements = await prisma.system_announcements.findMany({
    orderBy: { created_at: 'desc' },
    include: withAuthor
  });
  res.status(200).json({ success: true, data: announcements });
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

  const announcement = await prisma.system_announcements.create({
    data: {
      ...data,
      admin_id: req.user.userId,
      published_at: data.is_published ? new Date() : null
    }
  });

  await logAction(req.user.userId, '新增系統公告', 'announcement', announcement.announcement_id, data.title);
  res.status(201).json({ success: true, message: '公告已建立', data: announcement });
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

  const existing = await prisma.system_announcements.findUnique({ where: { announcement_id: announcementId } });
  if (!existing) throw notFound('找不到該公告');

  const published = body.is_published === undefined ? existing.is_published : v.bool(body.is_published);

  const announcement = await prisma.system_announcements.update({
    where: { announcement_id: announcementId },
    data: {
      ...data,
      is_published: published,
      published_at: published && !existing.published_at ? new Date() : existing.published_at,
      updated_at: new Date()
    }
  });

  await logAction(req.user.userId, '編輯系統公告', 'announcement', announcementId, data.title ?? existing.title);
  res.status(200).json({ success: true, message: '公告已更新', data: announcement });
});

router.delete('/:id', ...canManage, async (req, res) => {
  const announcementId = v.id(req.params.id, '公告編號');
  await orNotFound(
    prisma.system_announcements.delete({ where: { announcement_id: announcementId } }),
    '找不到該公告'
  );
  await logAction(req.user.userId, '刪除系統公告', 'announcement', announcementId);
  res.status(200).json({ success: true, message: '公告已刪除' });
});

module.exports = router;
