const prisma = require('../../lib/prisma');

const shape = (row) => ({
  user_id: Number(row.user_id),
  nickname: row.nickname,
  avatar_url: row.avatar_url ?? null,
  role: row.role,
  joined_at: row.joined_at,
  last_read_message_id: Number(row.last_read_message_id ?? 0)
});

const active = async (roomId, db = prisma) => {
  const rows = await db.$queryRaw`
    SELECT m.user_id, m.role, m.joined_at, m.last_read_message_id, u.nickname, u.avatar_url
    FROM chat_room_members m JOIN users u ON u.user_id = m.user_id
    WHERE m.room_id = ${roomId} AND m.left_at IS NULL
    ORDER BY m.joined_at, m.user_id`;
  return rows.map(shape);
};

const isActive = async (roomId, userId) => {
  const rows = await prisma.$queryRaw`
    SELECT user_id FROM chat_room_members WHERE room_id = ${roomId} AND user_id = ${userId} AND left_at IS NULL`;
  return rows.length > 0;
};

const join = (tx, roomId, entries, { joinedAt, lastReadId }) => tx.$executeRawUnsafe(
  `INSERT INTO chat_room_members (room_id, user_id, role, joined_at, left_at, last_read_message_id)
   VALUES ${entries.map(() => '(?, ?, ?, ?, NULL, ?)').join(', ')}
   ON DUPLICATE KEY UPDATE role = VALUES(role), joined_at = VALUES(joined_at), left_at = NULL,
     last_read_message_id = VALUES(last_read_message_id)`,
  ...entries.flatMap((e) => [roomId, e.userId, e.role, joinedAt, lastReadId])
);

const addDirect = (db, roomId, userIds, joinedAt) => db.$executeRawUnsafe(
  `INSERT IGNORE INTO chat_room_members (room_id, user_id, role, joined_at, last_read_message_id)
   VALUES ${userIds.map(() => "(?, ?, 'member', ?, 0)").join(', ')}`,
  ...userIds.flatMap((userId) => [roomId, userId, joinedAt])
);

const leave = (tx, roomId, userId, now) => tx.$executeRaw`
  UPDATE chat_room_members SET left_at = ${now}, role = 'member'
  WHERE room_id = ${roomId} AND user_id = ${userId} AND left_at IS NULL`;

const promote = (tx, roomId, userId) => tx.$executeRaw`
  UPDATE chat_room_members SET role = 'owner' WHERE room_id = ${roomId} AND user_id = ${userId} AND left_at IS NULL`;

const markRead = (db, roomId, userId, messageId) => db.$executeRaw`
  UPDATE chat_room_members SET last_read_message_id = GREATEST(last_read_message_id, ${messageId})
  WHERE room_id = ${roomId} AND user_id = ${userId}`;

const unpin = (db, roomId, userId) => db.$executeRaw`
  DELETE FROM chat_room_pins WHERE user_id = ${userId} AND room_id = ${roomId}`;

module.exports = { active, isActive, join, addDirect, leave, promote, markRead, unpin };
