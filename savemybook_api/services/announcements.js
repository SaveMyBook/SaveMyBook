const prisma = require('../lib/prisma');
const { notFound } = require('../lib/errors');
const { clip } = require('../lib/text');
const { userName } = require('../lib/selects');
const { ANNOUNCEMENT_TYPE_LABELS } = require('../constants/domain');
const audit = require('./audit');
const { notifyActiveUsers } = require('./notify');

const withAuthor = { users: { select: userName } };

const FIELDS = {
  title: '標題',
  content: '內容',
  type: { label: '類型', format: (t) => ANNOUNCEMENT_TYPE_LABELS[t] ?? t },
  is_published: { label: '發布', format: (p) => (p ? '已發布' : '草稿') },
  expires_at: '到期時間'
};

const visibleWhere = () => ({
  is_published: true,
  OR: [{ expires_at: null }, { expires_at: { gt: new Date() } }]
});

const broadcast = (announcement) => {
  const text = String(announcement.content ?? '').replace(/\s+/g, ' ').trim();
  return notifyActiveUsers({
    type: announcement.type === 'promotion' ? 'promotion' : 'system',
    title: `${ANNOUNCEMENT_TYPE_LABELS[announcement.type] ?? '公告'}：${announcement.title}`,
    content: clip(text, 120),
    relatedId: announcement.announcement_id,
    relatedType: 'announcement'
  });
};

const listVisible = () => prisma.system_announcements.findMany({
  where: visibleWhere(),
  orderBy: { published_at: 'desc' },
  include: withAuthor
});

const listAll = () => prisma.system_announcements.findMany({
  orderBy: { created_at: 'desc' },
  include: withAuthor
});

const findVisible = async (announcementId) => {
  const announcement = await prisma.system_announcements.findFirst({
    where: { announcement_id: announcementId, ...visibleWhere() },
    include: withAuthor
  });
  if (!announcement) throw notFound('此公告不存在或已下架');
  return announcement;
};

const create = async (data, { adminId, req }) => {
  const announcement = await prisma.system_announcements.create({
    data: {
      ...data,
      admin_id: adminId,
      published_at: data.is_published ? new Date() : null
    }
  });

  const notified = announcement.is_published ? await broadcast(announcement) : 0;

  await audit.record(null, {
    adminId,
    action: '新增系統公告',
    targetType: 'announcement',
    targetId: announcement.announcement_id,
    summary: `${announcement.is_published ? '發布' : '建立草稿'}「${data.title}」（${ANNOUNCEMENT_TYPE_LABELS[data.type]}）`
      + (notified ? `，已通知 ${notified} 位使用者（通知無法收回）` : ''),
    undo: [audit.undoCreate('system_announcements', announcement.announcement_id)],
    req
  });

  return { announcement, notified };
};

const update = async (announcementId, data, isPublished, { adminId, req }) => {
  const existing = await prisma.system_announcements.findUnique({ where: { announcement_id: announcementId } });
  if (!existing) throw notFound('找不到該公告');

  const published = isPublished ?? existing.is_published;
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
    adminId,
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

  return { announcement, notified };
};

const remove = async (announcementId, { adminId, req }) => {
  const before = await prisma.system_announcements.findUnique({ where: { announcement_id: announcementId } });
  if (!before) throw notFound('找不到該公告');

  await prisma.system_announcements.delete({ where: { announcement_id: announcementId } });
  await audit.record(null, {
    adminId,
    action: '刪除系統公告',
    targetType: 'announcement',
    targetId: announcementId,
    summary: `刪除公告「${before.title}」`,
    undo: [audit.undoDelete('system_announcements', before)],
    req
  });
};

module.exports = { listVisible, listAll, findVisible, create, update, remove };
