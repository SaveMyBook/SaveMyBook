const prisma = require('../../lib/prisma');
const { HttpError, badRequest, forbidden, notFound } = require('../../lib/errors');
const { hasTables } = require('../../lib/schema-check');
const { placeholders } = require('../../lib/sql');

const isAvailable = () => hasTables(['chat_room_mutes', 'user_blocks']);

const requireAvailable = async () => {
  if (!(await isAvailable())) {
    throw new HttpError(503, '此功能暫時無法使用，請稍後再試', 'CHAT_CONTROLS_UNAVAILABLE');
  }
};

// 被對方封鎖時與對方帳號停用回傳相同訊息與代碼，避免使用者得知自己被封鎖。
const recipientUnavailable = () => badRequest('對方帳號目前無法接收訊息', 'RECIPIENT_UNAVAILABLE');

const setMuted = async (userId, roomId, muted) => {
  await requireAvailable();
  if (muted) {
    await prisma.$executeRaw`
      INSERT IGNORE INTO chat_room_mutes (user_id, room_id, created_at) VALUES (${userId}, ${roomId}, ${new Date()})`;
  } else {
    await prisma.$executeRaw`DELETE FROM chat_room_mutes WHERE user_id = ${userId} AND room_id = ${roomId}`;
  }
};

const mutedRoomIds = async (userId) => {
  if (!(await isAvailable())) return new Set();
  const rows = await prisma.$queryRaw`SELECT room_id FROM chat_room_mutes WHERE user_id = ${userId}`;
  return new Set(rows.map((r) => Number(r.room_id)));
};

const blockedUserIds = async (userId) => {
  if (!(await isAvailable())) return new Set();
  const rows = await prisma.$queryRaw`SELECT blocked_id FROM user_blocks WHERE blocker_id = ${userId}`;
  return new Set(rows.map((r) => Number(r.blocked_id)));
};

const relation = async (myId, partnerId) => {
  if (!(await isAvailable())) return { blocked: false, blockedBy: false };
  const rows = await prisma.$queryRaw`
    SELECT blocker_id FROM user_blocks
    WHERE (blocker_id = ${myId} AND blocked_id = ${partnerId})
       OR (blocker_id = ${partnerId} AND blocked_id = ${myId})`;
  return {
    blocked: rows.some((r) => Number(r.blocker_id) === myId),
    blockedBy: rows.some((r) => Number(r.blocker_id) === partnerId)
  };
};

const assertCanMessage = async (myId, partnerId) => {
  const { blocked, blockedBy } = await relation(myId, partnerId);
  if (blocked) throw forbidden('您已封鎖此使用者，解除封鎖後才能傳送訊息', 'CHAT_BLOCKED');
  if (blockedBy) throw recipientUnavailable();
};

const block = async (myId, targetId) => {
  await requireAvailable();
  if (targetId === myId) throw badRequest('無法封鎖自己');
  const target = await prisma.users.findUnique({ where: { user_id: targetId }, select: { user_id: true } });
  if (!target) throw notFound('找不到該使用者');
  await prisma.$executeRaw`
    INSERT IGNORE INTO user_blocks (blocker_id, blocked_id, created_at) VALUES (${myId}, ${targetId}, ${new Date()})`;
};

const unblock = async (myId, targetId) => {
  await requireAvailable();
  await prisma.$executeRaw`DELETE FROM user_blocks WHERE blocker_id = ${myId} AND blocked_id = ${targetId}`;
};

const listBlocks = async (myId) => {
  await requireAvailable();
  const rows = await prisma.$queryRaw`
    SELECT b.blocked_id AS user_id, u.nickname, u.avatar_url, b.created_at AS blocked_at
    FROM user_blocks b JOIN users u ON u.user_id = b.blocked_id
    WHERE b.blocker_id = ${myId}
    ORDER BY b.created_at DESC`;
  return rows.map((r) => ({
    user_id: Number(r.user_id),
    nickname: r.nickname,
    avatar_url: r.avatar_url,
    blocked_at: r.blocked_at
  }));
};

const mutedPairs = async (roomIds) => {
  if (roomIds.length === 0 || !(await isAvailable())) return new Set();
  const rows = await prisma.$queryRawUnsafe(
    `SELECT user_id, room_id FROM chat_room_mutes WHERE room_id IN (${placeholders(roomIds)})`,
    ...roomIds
  );
  return new Set(rows.map((r) => `${Number(r.user_id)}:${Number(r.room_id)}`));
};

module.exports = {
  setMuted, mutedRoomIds, blockedUserIds, relation, assertCanMessage, recipientUnavailable,
  block, unblock, listBlocks, mutedPairs
};
