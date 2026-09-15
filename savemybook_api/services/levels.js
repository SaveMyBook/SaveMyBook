const prisma = require('../lib/prisma');
const { notFound } = require('../lib/errors');
const audit = require('./audit');

const POINTS_PER_ORDER = 10;

const basePointsOf = (completedOrders) => completedOrders * POINTS_PER_ORDER;

const effectivePoints = (completedOrders, bonus) =>
  Math.max(0, basePointsOf(completedOrders) + (bonus ?? 0));

const levelFor = (levels, points) =>
  [...levels].reverse().find((l) => points >= l.min_points) ?? levels[0] ?? null;

const nextLevelFor = (levels, points) => levels.find((l) => l.min_points > points) ?? null;

const listLevels = () => prisma.member_levels.findMany({ orderBy: { min_points: 'asc' } });

const completedOrderCount = (userId) =>
  prisma.orders.count({ where: { buyer_id: userId, status: 'completed' } });

const summaryFor = async (userId) => {
  const [allLevels, completedOrders, me] = await Promise.all([
    listLevels(),
    completedOrderCount(userId),
    prisma.users.findUnique({ where: { user_id: userId }, select: { bonus_points: true } })
  ]);

  const points = effectivePoints(completedOrders, me?.bonus_points);
  const next = nextLevelFor(allLevels, points);

  return {
    points,
    completed_orders: completedOrders,
    current_level: levelFor(allLevels, points),
    next_level: next,
    points_to_next: next ? next.min_points - points : 0,
    levels: allLevels
  };
};

const FIELDS = {
  level_name: '名稱',
  min_points: '最低點數',
  max_points: { label: '最高點數', format: (v) => (v === null ? '無上限' : String(v)) },
  benefits: '福利說明'
};

const findOrThrow = async (levelId) => {
  const level = await prisma.member_levels.findUnique({ where: { level_id: levelId } });
  if (!level) throw notFound('找不到此等級');
  return level;
};

const create = async (data, { adminId, req }) => {
  const created = await prisma.member_levels.create({ data });
  await audit.record(null, {
    adminId,
    action: '新增會員等級',
    targetType: 'level',
    targetId: created.level_id,
    summary: `新增會員等級「${data.level_name}」（${data.min_points} 點起）`,
    undo: [audit.undoCreate('member_levels', created.level_id)],
    req
  });
  return created;
};

const update = async (levelId, data, { adminId, req }) => {
  const before = await findOrThrow(levelId);

  await prisma.member_levels.update({ where: { level_id: levelId }, data });

  const changes = audit.diff(before, data, FIELDS);
  await audit.record(null, {
    adminId,
    action: '編輯會員等級',
    targetType: 'level',
    targetId: levelId,
    summary: changes.length
      ? `修改會員等級「${before.level_name}」的${changes.map((c) => c.label).join('、')}`
      : `重新儲存會員等級「${before.level_name}」（無實際變更）`,
    changes,
    undo: changes.length ? [audit.undoUpdate('member_levels', levelId, before, data, FIELDS)] : null,
    req
  });
};

const remove = async (levelId, { adminId, req }) => {
  const before = await findOrThrow(levelId);
  await prisma.member_levels.delete({ where: { level_id: levelId } });
  await audit.record(null, {
    adminId,
    action: '刪除會員等級',
    targetType: 'level',
    targetId: levelId,
    summary: `刪除會員等級「${before.level_name}」`,
    undo: [audit.undoDelete('member_levels', before)],
    req
  });
};

module.exports = {
  create, update, remove,
  basePointsOf, effectivePoints, levelFor, listLevels, completedOrderCount, summaryFor
};
