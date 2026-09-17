const prisma = require('../lib/prisma');
const { badRequest, conflict, notFound } = require('../lib/errors');
const audit = require('./audit');

const POINTS_PER_ORDER = 10;

const basePointsOf = (completedOrders) => completedOrders * POINTS_PER_ORDER;

const effectivePoints = (completedOrders, bonus) =>
  Math.max(0, basePointsOf(completedOrders) + (bonus ?? 0));

const levelFor = (levels, points) =>
  [...levels].reverse().find((l) => points >= l.min_points) ?? levels[0] ?? null;

const nextLevelFor = (levels, points) => levels.find((l) => l.min_points > points) ?? null;

// max_points 一律依下一個等級的門檻推算；資料庫中的舊值可能與實際判定不符，不直接採用。
const withRanges = (rows) => rows.map((level, i) => ({
  ...level,
  max_points: i + 1 < rows.length ? Math.max(level.min_points, rows[i + 1].min_points - 1) : null
}));

const listLevels = async () =>
  withRanges(await prisma.member_levels.findMany({ orderBy: [{ min_points: 'asc' }, { level_id: 'asc' }] }));

const pointsOfMembers = async () => {
  const [members, completed] = await Promise.all([
    prisma.users.findMany({
      where: { anonymized_at: null, role: { not: 'admin' } },
      select: { user_id: true, bonus_points: true }
    }),
    prisma.orders.groupBy({ by: ['buyer_id'], where: { status: 'completed' }, _count: { _all: true } })
  ]);
  const orders = new Map(completed.map((row) => [row.buyer_id, Number(row._count?._all ?? row._count ?? 0)]));
  return members.map((m) => effectivePoints(orders.get(m.user_id) ?? 0, m.bonus_points));
};

/** 後台用：各等級附上目前符合的會員人數。 */
const listWithMembers = async () => {
  const [levels, points] = await Promise.all([listLevels(), pointsOfMembers()]);
  const counts = new Map(levels.map((l) => [l.level_id, 0]));
  for (const p of points) {
    const level = levelFor(levels, p);
    if (level) counts.set(level.level_id, counts.get(level.level_id) + 1);
  }
  return levels.map((l) => ({ ...l, member_count: counts.get(l.level_id) }));
};

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
  min_points: '門檻點數',
  benefits: '福利說明'
};

const sameName = (a, b) => a.trim().toLowerCase() === b.trim().toLowerCase();

// 只檢查與本次儲存的等級有關的衝突，既有資料若已不一致，仍可逐一修正。
const validate = async (data, levelId = null) => {
  const all = await prisma.member_levels.findMany({ orderBy: { min_points: 'asc' } });
  const others = all.filter((l) => l.level_id !== levelId);

  if (others.some((l) => sameName(l.level_name, data.level_name))) {
    throw conflict(`已有名為「${data.level_name}」的等級`, 'LEVEL_NAME_TAKEN');
  }
  const clash = others.find((l) => l.min_points === data.min_points);
  if (clash) {
    throw conflict(`「${clash.level_name}」已使用 ${data.min_points} 點作為門檻，每個等級的門檻須不同`, 'LEVEL_THRESHOLD_TAKEN');
  }
  const lowest = Math.min(data.min_points, ...others.map((l) => l.min_points));
  if (lowest !== 0) throw badRequest('起始等級的門檻須為 0 點，所有會員才會有對應的等級', 'LEVEL_BASE_REQUIRED');
};

const findOrThrow = async (levelId) => {
  const level = await prisma.member_levels.findUnique({ where: { level_id: levelId } });
  if (!level) throw notFound('找不到此等級');
  return level;
};

const create = async (data, { adminId, req }) => {
  await validate(data);
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
  await validate(data, levelId);

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
  const levels = await listWithMembers();
  const rest = levels.filter((l) => l.level_id !== levelId);

  if (before.min_points === 0 && rest.length > 0 && !rest.some((l) => l.min_points === 0)) {
    throw conflict('起始等級無法刪除，請先將其他等級的門檻調整為 0 點', 'LEVEL_BASE_REQUIRED');
  }

  const memberCount = levels.find((l) => l.level_id === levelId)?.member_count ?? 0;
  const fallback = levelFor(withRanges(rest), before.min_points);

  await prisma.member_levels.delete({ where: { level_id: levelId } });
  await audit.record(null, {
    adminId,
    action: '刪除會員等級',
    targetType: 'level',
    targetId: levelId,
    summary: memberCount > 0 && fallback
      ? `刪除會員等級「${before.level_name}」，${memberCount} 位會員改列「${fallback.level_name}」`
      : `刪除會員等級「${before.level_name}」`,
    undo: [audit.undoDelete('member_levels', before)],
    req
  });
  return { moved_members: fallback ? memberCount : 0, moved_to: fallback?.level_name ?? null };
};

// 排序只調動名稱與福利的位置：門檻依原本由低到高的數值，依新順序重新分配。
const reorder = async (ids, { adminId, req }) => {
  const existing = await prisma.member_levels.findMany({ orderBy: { min_points: 'asc' } });
  if (ids.length !== existing.length || existing.some((l) => !ids.includes(l.level_id))) {
    throw badRequest('排序資料須包含所有等級');
  }

  const thresholds = existing.map((l) => l.min_points);
  const byId = new Map(existing.map((l) => [l.level_id, l]));
  const moves = ids
    .map((id, index) => ({ before: byId.get(id), min_points: thresholds[index] }))
    .filter((m) => m.before.min_points !== m.min_points);
  if (moves.length === 0) return;

  await prisma.$transaction(
    moves.map((m) => prisma.member_levels.update({
      where: { level_id: m.before.level_id },
      data: { min_points: m.min_points }
    }))
  );

  await audit.record(null, {
    adminId,
    action: '調整會員等級順序',
    targetType: 'level',
    summary: `調整會員等級順序為${ids.map((id) => `「${byId.get(id).level_name}」`).join('→')}`,
    changes: [{
      label: '順序',
      from: existing.map((l) => l.level_name).join('、'),
      to: ids.map((id) => byId.get(id).level_name).join('、')
    }],
    undo: moves.map((m) => audit.undoUpdate('member_levels', m.before.level_id, m.before, { min_points: m.min_points }, { min_points: '門檻點數' })),
    req
  });
};

module.exports = {
  create, update, remove, reorder, listWithMembers,
  basePointsOf, effectivePoints, levelFor, listLevels, completedOrderCount, summaryFor
};
