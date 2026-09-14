const prisma = require('./prisma');

const RECHECK_MS = 60 * 1000;
const cache = new Map();

const hasTables = async (tables) => {
  const key = tables.join(',');
  const hit = cache.get(key);
  if (hit && (hit.ok || Date.now() - hit.at < RECHECK_MS)) return hit.ok;

  const rows = await prisma.$queryRawUnsafe(
    `SELECT COUNT(*) AS n FROM information_schema.TABLES
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN (${tables.map(() => '?').join(',')})`,
    ...tables
  );
  const ok = Number(rows[0]?.n ?? 0) === tables.length;
  cache.set(key, { ok, at: Date.now() });
  return ok;
};

const hasColumn = async (table, column) => {
  const key = `${table}.${column}`;
  const hit = cache.get(key);
  if (hit && (hit.ok || Date.now() - hit.at < RECHECK_MS)) return hit.ok;

  const rows = await prisma.$queryRaw`
    SELECT COUNT(*) AS n FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ${table} AND COLUMN_NAME = ${column}`;
  const ok = Number(rows[0]?.n ?? 0) > 0;
  cache.set(key, { ok, at: Date.now() });
  return ok;
};

const resetCache = () => cache.clear();

module.exports = { hasTables, hasColumn, resetCache };
