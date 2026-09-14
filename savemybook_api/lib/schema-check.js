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

const REQUIRED = [
  { migration: '004_account_privacy_and_ops.sql', table: 'users', column: 'deletion_requested_at' },
  { migration: '004_account_privacy_and_ops.sql', table: 'users', column: 'anonymized_at' },
  { migration: '004_account_privacy_and_ops.sql', table: 'users', column: 'share_token' },
  { migration: '004_account_privacy_and_ops.sql', table: 'db_backups' },
  { migration: '005_book_share_and_admin_ops.sql', table: 'books', column: 'share_token' },
  { migration: '005_book_share_and_admin_ops.sql', table: 'admin_permissions', column: 'can_manage_system' },
  { migration: '006_push_notifications.sql', table: 'push_devices' },
  { migration: '006_push_notifications.sql', table: 'notifications', column: 'pushed_at' },
  { migration: '007_consent_sessions_payment.sql', table: 'legal_documents', column: 'version' },
  { migration: '007_consent_sessions_payment.sql', table: 'legal_documents', column: 'requires_consent' },
  { migration: '007_consent_sessions_payment.sql', table: 'user_legal_consents' },
  { migration: '007_consent_sessions_payment.sql', table: 'user_sessions' },
  { migration: '007_consent_sessions_payment.sql', table: 'user_security' },
  { migration: '007_consent_sessions_payment.sql', table: 'push_devices', column: 'session_sid' }
];

const missingSchema = async () => {
  const [tables, columns] = await Promise.all([
    prisma.$queryRaw`SELECT TABLE_NAME AS t FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE()`,
    prisma.$queryRaw`SELECT TABLE_NAME AS t, COLUMN_NAME AS c FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE()`
  ]);
  const tableSet = new Set(tables.map((r) => String(r.t)));
  const columnSet = new Set(columns.map((r) => `${r.t}.${r.c}`));
  return REQUIRED.filter((r) => (r.column ? !columnSet.has(`${r.table}.${r.column}`) : !tableSet.has(r.table)));
};

module.exports.REQUIRED = REQUIRED;
module.exports.missingSchema = missingSchema;
