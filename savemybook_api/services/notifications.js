const prisma = require('../lib/prisma');
const { notFound } = require('../lib/errors');

const unreadCount = (userId) => prisma.notifications.count({ where: { user_id: userId, is_read: false } });

const list = async (userId, { skip, limit, type }) => {
  const where = { user_id: userId, ...(type && { type }) };
  const [notifications, total, unread] = await Promise.all([
    prisma.notifications.findMany({ where, skip, take: limit, orderBy: { created_at: 'desc' } }),
    prisma.notifications.count({ where }),
    unreadCount(userId)
  ]);
  return { notifications, total, unread };
};

const markAllRead = (userId) => prisma.notifications.updateMany({
  where: { user_id: userId, is_read: false },
  data: { is_read: true }
});

const markRead = async (userId, notificationId) => {
  const result = await prisma.notifications.updateMany({
    where: { notification_id: notificationId, user_id: userId },
    data: { is_read: true }
  });
  if (result.count === 0) throw notFound('找不到該通知');
};

const removeAll = async (userId) => {
  const result = await prisma.notifications.deleteMany({ where: { user_id: userId } });
  return result.count;
};

const remove = async (userId, notificationId) => {
  const result = await prisma.notifications.deleteMany({
    where: { notification_id: notificationId, user_id: userId }
  });
  if (result.count === 0) throw notFound('找不到該通知');
};

module.exports = { unreadCount, list, markAllRead, markRead, removeAll, remove };
