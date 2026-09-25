const prisma = require('../../lib/prisma');
const { placeholders } = require('../../lib/sql');

const MAX_GROUP_NICKNAME = 30;

const shape = (row) => ({
  user_id: Number(row.user_id),
  nickname: row.nickname,
  avatar_url: row.avatar_url ?? null,
  role: row.role,
  joined_at: row.joined_at,
  last_read_message_id: Number(row.last_read_message_id ?? 0),
  group_nickname: row.group_nickname || null
});

const active = async (roomId, db = prisma) => {
  const rows = await db.$queryRaw`
    SELECT m.user_id, m.role, m.joined_at, m.last_read_message_id, m.group_nickname, u.nickname, u.avatar_url
    FROM chat_room_members m JOIN users u ON u.user_id = m.user_id
    WHERE m.room_id = ${roomId} AND m.left_at IS NULL
    ORDER BY m.joined_at, m.user_id`;
  return rows.map(shape);
};

const setGroupNickname = (db, roomId, userId, nickname) => db.$executeRaw`
  UPDATE chat_room_members SET group_nickname = ${nickname} WHERE room_id = ${roomId} AND user_id = ${userId} AND left_at IS NULL`;

// 聊天室列表只需要各群組最後一則訊息發送者的群組暱稱，一次查齊，鍵為 room_id:user_id。
const groupNicknames = async (roomIds) => {
  const ids = [...new Set(roomIds.map(Number))];
  if (ids.length === 0) return new Map();
  const rows = await prisma.$queryRawUnsafe(
    `SELECT room_id, user_id, group_nickname FROM chat_room_members
     WHERE room_id IN (${placeholders(ids)}) AND left_at IS NULL AND group_nickname IS NOT NULL`,
    ...ids
  );
  return new Map(rows.map((r) => [`${Number(r.room_id)}:${Number(r.user_id)}`, r.group_nickname]));
};

const isActive = async (roomId, userId) => {
  const rows = await prisma.$queryRaw`
    SELECT user_id FROM chat_room_members WHERE room_id = ${roomId} AND user_id = ${userId} AND left_at IS NULL`;
  return rows.length > 0;
};

const join = (tx, roomId, entries, { joinedAt, lastReadId, historyFromId }) => tx.$executeRawUnsafe(
  `INSERT INTO chat_room_members (room_id, user_id, role, joined_at, left_at, last_read_message_id, history_from_id)
   VALUES ${entries.map(() => '(?, ?, ?, ?, NULL, ?, ?)').join(', ')}
   ON DUPLICATE KEY UPDATE role = VALUES(role), joined_at = VALUES(joined_at), left_at = NULL,
     last_read_message_id = VALUES(last_read_message_id), history_from_id = VALUES(history_from_id)`,
  ...entries.flatMap((e) => [roomId, e.userId, e.role, joinedAt, lastReadId, historyFromId])
);

const addDirect = (db, roomId, userIds, joinedAt) => db.$executeRawUnsafe(
  `INSERT IGNORE INTO chat_room_members (room_id, user_id, role, joined_at, last_read_message_id)
   VALUES ${userIds.map(() => "(?, ?, 'member', ?, 0)").join(', ')}`,
  ...userIds.flatMap((userId) => [roomId, userId, joinedAt])
);

const leave = (tx, roomId, userId, now) => tx.$executeRaw`
  UPDATE chat_room_members SET left_at = ${now}, role = 'member'
  WHERE room_id = ${roomId} AND user_id = ${userId} AND left_at IS NULL`;

const setRole = (tx, roomId, userId, role) => tx.$executeRaw`
  UPDATE chat_room_members SET role = ${role} WHERE room_id = ${roomId} AND user_id = ${userId} AND left_at IS NULL`;

const markRead = (db, roomId, userId, messageId) => db.$executeRaw`
  UPDATE chat_room_members SET last_read_message_id = GREATEST(last_read_message_id, ${messageId})
  WHERE room_id = ${roomId} AND user_id = ${userId}`;

const unpin = (db, roomId, userId) => db.$executeRaw`
  DELETE FROM chat_room_pins WHERE user_id = ${userId} AND room_id = ${roomId}`;

// 退出或被移出群組時一併清掉靜音：否則日後被重新邀請回同一群組，舊的靜音會無聲生效。
const clearRoomPreferences = async (db, roomId, userId) => {
  await unpin(db, roomId, userId);
  await db.$executeRaw`UPDATE chat_room_members SET group_nickname = NULL WHERE room_id = ${roomId} AND user_id = ${userId}`;
  await db.$executeRaw`DELETE FROM chat_room_mutes WHERE user_id = ${userId} AND room_id = ${roomId}`;
};

module.exports = {
  MAX_GROUP_NICKNAME, setGroupNickname, groupNicknames, active, isActive, join, addDirect, leave, setRole, markRead, unpin, clearRoomPreferences };
