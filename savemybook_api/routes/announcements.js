const express = require('express');
const prisma = require('../lib/prisma');
const authenticateToken = require('../middleware/auth');
const requireAdmin = require('../middleware/requireAdmin');
const v = require('../lib/validate');
const { badRequest, notFound } = require('../lib/errors');
const { ANNOUNCEMENT_TYPES } = require('../constants/domain');
const audit = require('../services/audit');
const { notifyMany } = require('../services/notify');

const router = express.Router();

const canManage = [authenticateToken, requireAdmin('announcements')];
const withAuthor = { users: { select: { user_id: true, nickname: true } } };

const TYPE_LABELS = { general: '一般公告', maintenance: '系統維護', promotion: '優惠活動', policy: '政策更新' };

const FIELDS = {
  title: '標題',
  content: '內容',
  type: { label: '類型', format: (t) => TYPE_LABELS[t] ?? t },
  is_published: { label: '發布', format: (p) => (p ? '已發布' : '草稿') },
  expires_at: '到期時間'
};

const title = (value) => v.text(value, { label: '標題', max: 255 });
const content = (value) => v.text(value, { label: '內容', max: 20000 });
const type = (value) => v.oneOf(value, ANNOUNCEMENT_TYPES, `type 僅接受：${ANNOUNCEMENT_TYPES.join(', ')}`);

const visibleWhere = () => ({
  is_published: true,
  OR: [{ expires_at: null }, { expires_at: { gt: new Date() } }]
});

const broadcast = async (announcement) => {
  const users = await prisma.users.findMany({
    where: { is_active: true, is_blacklisted: false, anonymized_at: null },
    select: { user_id: true }
  });
  const text = String(announcement.content ?? '').replace(/\s+/g, ' ').trim();
  return notifyMany(prisma, users.map((u) => u.user_id), {
    type: announcement.type === 'promotion' ? 'promotion' : 'system',
    title: `${TYPE_LABELS[announcement.type] ?? '公告'}：${announcement.title}`,
    content: text.length > 120 ? `${text.slice(0, 119)}…` : text,
    relatedId: announcement.announcement_id,
    relatedType: 'announcement'
  });
};

router.get('/', async (req, res) => {
  const announcements = await prisma.system_announcements.findMany({
    where: visibleWhere(),
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

// 必須排在 /all 之後，否則 all 會被當成公告編號。
router.get('/:id', async (req, res) => {
  const announcement = await prisma.system_announcements.findFirst({
    where: { announcement_id: v.id(req.params.id, '公告編號'), ...visibleWhere() },
    include: withAuthor
  });
  if (!announcement) throw notFound('此公告不存在或已下架');
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

  const announcement = await prisma.system_announcements.create({
    data: {
      ...data,
      admin_id: req.user.userId,
      published_at: data.is_published ? new Date() : null
    }
  });

  const notified = announcement.is_published ? await broadcast(announcement) : 0;

  await audit.record(null, {
    adminId: req.user.userId,
    action: '新增系統公告',
    targetType: 'announcement',
    targetId: announcement.announcement_id,
    summary: `${announcement.is_published ? '發布' : '建立草稿'}「${data.title}」（${TYPE_LABELS[data.type]}）`
      + (notified ? `，已通知 ${notified} 位使用者（通知無法收回）` : ''),
    undo: [audit.undoCreate('system_announcements', announcement.announcement_id)],
    req
  });

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

  const existing = await prisma.system_announcements.findUnique({ where: { announcement_id: announcementId } });
  if (!existing) throw notFound('找不到該公告');

  const published = body.is_published === undefined ? existing.is_published : v.bool(body.is_published);
  const firstPublish = published && !existing.published_at;
  const next = {
    ...data,
    is_published: published,
    published_at: firstPublish ? new Date() : existing.published_at
  };

  const announcement = await prisma.system_announcements.update({
    where: { announcement_id: announcementId },
    data: { ...next, updated_at: new Date() }
  });

  const notified = firstPublish ? await broadcast(announcement) : 0;

  const changes = audit.diff(existing, next, FIELDS);
  await audit.record(null, {
    adminId: req.user.userId,
    action: '編輯系統公告',
    targetType: 'announcement',
    targetId: announcementId,
    summary: (changes.length
      ? `修改公告「${existing.title}」的${changes.map((c) => c.label).join('、')}`
      : `重新儲存公告「${existing.title}」（無實際變更）`)
      + (notified ? `，首次發布並通知 ${notified} 位使用者（通知無法收回）` : ''),
    changes,
    undo: changes.length
      ? [audit.undoUpdate('system_announcements', announcementId, existing, next,
          ['title', 'content', 'type', 'is_published', 'published_at', 'expires_at'])]
      : null,
    req
  });

  res.status(200).json({
    success: true,
    message: notified ? `公告已發布，已通知 ${notified} 位使用者` : '公告已更新',
    data: announcement
  });
});

router.delete('/:id', ...canManage, async (req, res) => {
  const announcementId = v.id(req.params.id, '公告編號');
  const before = await prisma.system_announcements.findUnique({ where: { announcement_id: announcementId } });
  if (!before) throw notFound('找不到該公告');

  await prisma.system_announcements.delete({ where: { announcement_id: announcementId } });
  await audit.record(null, {
    adminId: req.user.userId,
    action: '刪除系統公告',
    targetType: 'announcement',
    targetId: announcementId,
    summary: `刪除公告「${before.title}」`,
    undo: [audit.undoDelete('system_announcements', before)],
    req
  });
  res.status(200).json({ success: true, message: '公告已刪除' });
});

module.exports = router;
