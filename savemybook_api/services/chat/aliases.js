const prisma = require('../../lib/prisma');
const { badRequest, notFound } = require('../../lib/errors');

const MAX_ALIAS_LENGTH = 30;

const mine = async (ownerId) => {
  const rows = await prisma.$queryRaw`SELECT target_user_id, alias FROM chat_aliases WHERE owner_id = ${ownerId}`;
  return new Map(rows.map((r) => [Number(r.target_user_id), r.alias]));
};

const set = async (ownerId, targetId, alias) => {
  if (targetId === ownerId) throw badRequest('無法為自己設定暱稱');
  const target = await prisma.users.findUnique({ where: { user_id: targetId }, select: { user_id: true } });
  if (!target) throw notFound('找不到該使用者');

  if (!alias) {
    await prisma.$executeRaw`DELETE FROM chat_aliases WHERE owner_id = ${ownerId} AND target_user_id = ${targetId}`;
    return null;
  }
  await prisma.$executeRaw`
    INSERT INTO chat_aliases (owner_id, target_user_id, alias, updated_at) VALUES (${ownerId}, ${targetId}, ${alias}, ${new Date()})
    ON DUPLICATE KEY UPDATE alias = VALUES(alias), updated_at = VALUES(updated_at)`;
  return alias;
};

module.exports = { MAX_ALIAS_LENGTH, mine, set };
