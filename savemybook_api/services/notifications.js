const prisma = require('../lib/prisma');
const { notFound } = require('../lib/errors');
const categories = require('./notification-categories');

const UNREAD_BY_CATEGORY_SQL = `SELECT ${categories.caseSql()} AS category, COUNT(*) AS n
  FROM notifications WHERE user_id = ? AND is_read = 0 GROUP BY category`;

const scoped = (userId, category) => ({
  user_id: userId,
  ...(category && { AND: [categories.whereOf(category)] })
});

const unreadCount = (userId) => prisma.notifications.count({ where: { user_id: userId, is_read: false } });

const unreadByCategory = async (userId) => {
  const rows = await prisma.$queryRawUnsafe(UNREAD_BY_CATEGORY_SQL, userId);
  const byCategory = Object.fromEntries(categories.CATEGORIES.map((c) => [c, 0]));
  for (const row of rows) {
    if (row.category in byCategory) byCategory[row.category] = Number(row.n);
  }
  const total = Object.values(byCategory).reduce((sum, n) => sum + n, 0);
  return { total, byCategory };
};

const withCategory = (row) => ({ ...row, category: categories.categoryOf(row.type, row.related_type) });

const list = async (userId, { skip, limit, type, category }) => {
  const where = { ...scoped(userId, category), ...(type && { type }) };
  const [notifications, total, unread] = await Promise.all([
    prisma.notifications.findMany({ where, skip, take: limit, orderBy: { created_at: 'desc' } }),
    prisma.notifications.count({ where }),
    unreadCount(userId)
  ]);
  return { notifications: notifications.map(withCategory), total, unread };
};

const markAllRead = async (userId, { category } = {}) => {
  const result = await prisma.notifications.updateMany({
    where: { ...scoped(userId, category), is_read: false },
    data: { is_read: true }
  });
  return result.count;
};

const markRead = async (userId, notificationId) => {
  const result = await prisma.notifications.updateMany({
    where: { notification_id: notificationId, user_id: userId },
    data: { is_read: true }
  });
  if (result.count === 0) throw notFound('找不到該通知');
};

const removeAll = async (userId, { category } = {}) => {
  const result = await prisma.notifications.deleteMany({ where: scoped(userId, category) });
  return result.count;
};

const remove = async (userId, notificationId) => {
  const result = await prisma.notifications.deleteMany({
    where: { notification_id: notificationId, user_id: userId }
  });
  if (result.count === 0) throw notFound('找不到該通知');
};

module.exports = { UNREAD_BY_CATEGORY_SQL, unreadCount, unreadByCategory, list, markAllRead, markRead, removeAll, remove };
