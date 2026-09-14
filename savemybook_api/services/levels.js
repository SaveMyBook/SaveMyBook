const prisma = require('../lib/prisma');

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

module.exports = {
  POINTS_PER_ORDER, basePointsOf, effectivePoints, levelFor, nextLevelFor, listLevels, completedOrderCount
};
