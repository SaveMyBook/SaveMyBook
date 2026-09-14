const prisma = require('../lib/prisma');

// title 為 VARCHAR(255)，超長時 MySQL 嚴格模式會讓整個交易失敗。
const clip = (value, max) => (value.length > max ? `${value.slice(0, max - 1)}…` : value);

const toRow = ({ userId, type = 'system', title, content, relatedId = null, relatedType = null, createdAt }) => ({
  user_id: userId,
  type,
  title: clip(String(title), 255),
  content: String(content),
  related_id: relatedId,
  related_type: relatedType,
  ...(createdAt && { created_at: createdAt })
});

const notify = (db, payload) => (db ?? prisma).notifications.create({ data: toRow(payload) });

const notifyMany = async (db, userIds, payload, batchSize = 500) => {
  const client = db ?? prisma;
  for (let i = 0; i < userIds.length; i += batchSize) {
    await client.notifications.createMany({
      data: userIds.slice(i, i + batchSize).map((userId) => toRow({ ...payload, userId }))
    });
  }
  return userIds.length;
};

module.exports = { notify, notifyMany };
