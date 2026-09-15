const prisma = require('../../lib/prisma');
const { badRequest } = require('../../lib/errors');
const { placeholders } = require('../../lib/sql');

const EVERYONE = 0;
const MAX_MENTIONS = 20;
const MAX_MENTION_LENGTH = 60;

const invalid = () => badRequest('提及的成員資料不正確');
const directOnly = () => badRequest('僅群組聊天室可提及成員');

const targetsOf = (mentions, otherIds) => {
  if (mentions.length === 0) return [];
  const others = new Set(otherIds);
  if (mentions.some((m) => m.user_id !== EVERYONE && !others.has(m.user_id))) throw invalid();
  if (mentions.some((m) => m.user_id === EVERYONE)) return [...others];
  return [...new Set(mentions.map((m) => m.user_id))];
};

const insertRows = (tx, { messageId, roomId, userIds }) => (userIds.length === 0
  ? null
  : tx.$executeRawUnsafe(
      `INSERT IGNORE INTO chat_mentions (message_id, room_id, user_id) VALUES ${userIds.map(() => '(?, ?, ?)').join(', ')}`,
      ...userIds.flatMap((userId) => [messageId, roomId, userId])
    ));

const save = async (tx, { messageId, roomId, mentions, userIds }) => {
  await tx.$executeRaw`UPDATE chat_messages SET mentions = ${JSON.stringify(mentions)} WHERE message_id = ${messageId}`;
  await insertRows(tx, { messageId, roomId, userIds });
};

const replaceRows = async (tx, { messageId, roomId, userIds }) => {
  await tx.$executeRaw`DELETE FROM chat_mentions WHERE message_id = ${messageId}`;
  await insertRows(tx, { messageId, roomId, userIds });
};

const clear = async (tx, messageId) => {
  await tx.$executeRaw`UPDATE chat_messages SET mentions = NULL WHERE message_id = ${messageId}`;
  await tx.$executeRaw`DELETE FROM chat_mentions WHERE message_id = ${messageId}`;
};

const forMessages = async (messages) => {
  const ids = messages.filter((m) => m.message_type === 'text').map((m) => m.message_id);
  if (ids.length === 0) return new Map();
  const rows = await prisma.$queryRawUnsafe(
    `SELECT message_id, mentions FROM chat_messages WHERE mentions IS NOT NULL AND message_id IN (${placeholders(ids)})`,
    ...ids
  );
  return new Map(rows.map((r) => [Number(r.message_id), r.mentions]));
};

module.exports = {
  EVERYONE, MAX_MENTIONS, MAX_MENTION_LENGTH, invalid, directOnly, targetsOf, save, replaceRows, clear, forMessages
};
