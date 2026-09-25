const prisma = require('../lib/prisma');
const { clip } = require('../lib/text');

// title 為 VARCHAR(255)，超長時 MySQL 嚴格模式會讓整個交易失敗。
const toRow = ({ userId, type = 'system', title, content, relatedId = null, relatedType = null, createdAt }) => ({
  user_id: userId,
  type,
  title: clip(String(title), 255),
  content: String(content),
  related_id: relatedId,
  related_type: relatedType,
  ...(createdAt && { created_at: createdAt })
});

// actor_id 須與通知在同一交易內補寫，推播派送才不會先讀到缺少 actor_id 的列。
const notify = async (db, { actorId = null, ...payload }) => {
  const client = db ?? prisma;
  const created = await client.notifications.create({ data: toRow(payload) });
  if (actorId && created?.notification_id) {
    await client.$executeRaw`UPDATE notifications SET actor_id = ${actorId} WHERE notification_id = ${created.notification_id}`;
  }
  return created;
};

const insertWithActor = (client, rows, actorId, createdAt) => client.$executeRawUnsafe(
  `INSERT INTO notifications (user_id, type, title, content, related_id, related_type, actor_id, is_read, created_at)
   VALUES ${rows.map(() => '(?, ?, ?, ?, ?, ?, ?, 0, ?)').join(', ')}`,
  ...rows.flatMap((r) => [r.user_id, r.type, r.title, r.content, r.related_id, r.related_type, actorId, createdAt])
);

const notifyMany = async (db, userIds, { actorId = null, ...payload }, batchSize = 500) => {
  const client = db ?? prisma;
  const withActor = Boolean(actorId);
  const createdAt = payload.createdAt ?? new Date();
  for (let i = 0; i < userIds.length; i += batchSize) {
    const rows = userIds.slice(i, i + batchSize).map((userId) => toRow({ ...payload, userId }));
    if (withActor) await insertWithActor(client, rows, actorId, createdAt);
    else await client.notifications.createMany({ data: rows });
  }
  return userIds.length;
};

const notifyActiveUsers = async (payload) => {
  const users = await prisma.users.findMany({
    where: { is_active: true, is_blacklisted: false, anonymized_at: null },
    select: { user_id: true }
  });
  return notifyMany(prisma, users.map((u) => u.user_id), payload);
};

module.exports = { notify, notifyMany, notifyActiveUsers };
