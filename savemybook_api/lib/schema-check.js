const prisma = require('./prisma');

const { placeholders } = require('./sql');

const RECHECK_MS = 60 * 1000;
const cache = new Map();

const hasTables = async (tables) => {
  const key = tables.join(',');
  const hit = cache.get(key);
  if (hit && (hit.ok || Date.now() - hit.at < RECHECK_MS)) return hit.ok;

  const rows = await prisma.$queryRawUnsafe(
    `SELECT COUNT(*) AS n FROM information_schema.TABLES
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN (${placeholders(tables)})`,
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
  { migration: '007_consent_sessions_payment.sql', table: 'push_devices', column: 'session_sid' },
  { migration: '008_chat_mute_block.sql', table: 'chat_room_mutes' },
  { migration: '008_chat_mute_block.sql', table: 'user_blocks' },
  { migration: '008_chat_mute_block.sql', table: 'chat_messages', column: 'reply_to_id' },
  { migration: '009_chat_groups_transfers.sql', table: 'chat_rooms', column: 'room_type' },
  { migration: '009_chat_groups_transfers.sql', table: 'chat_rooms', column: 'name' },
  { migration: '009_chat_groups_transfers.sql', table: 'chat_rooms', column: 'avatar_url' },
  { migration: '009_chat_groups_transfers.sql', table: 'chat_rooms', column: 'created_by' },
  { migration: '009_chat_groups_transfers.sql', table: 'chat_messages', column: 'edited_at' },
  { migration: '009_chat_groups_transfers.sql', table: 'notifications', column: 'actor_id' },
  { migration: '009_chat_groups_transfers.sql', table: 'chat_room_members' },
  { migration: '009_chat_groups_transfers.sql', table: 'chat_room_pins' },
  { migration: '009_chat_groups_transfers.sql', table: 'chat_aliases' },
  { migration: '009_chat_groups_transfers.sql', table: 'chat_transfers' },
  { migration: '010_chat_mentions_albums.sql', table: 'chat_room_members', column: 'history_from_id' },
  { migration: '010_chat_mentions_albums.sql', table: 'chat_messages', column: 'mentions' },
  { migration: '010_chat_mentions_albums.sql', table: 'chat_mentions' },
  { migration: '011_ai.sql', table: 'ai_settings' },
  { migration: '011_ai.sql', table: 'ai_usage_logs' },
  { migration: '011_ai.sql', table: 'ai_support_sessions' },
  { migration: '011_ai.sql', table: 'ai_support_messages' },
  { migration: '011_ai.sql', table: 'ai_recommendation_cache' },
  { migration: '011_ai.sql', table: 'ai_book_reviews' },
  { migration: '011_ai.sql', table: 'ai_consents' },
  { migration: '012_ai_error_detail.sql', table: 'ai_usage_logs', column: 'error_detail' },
  { migration: '013_ai_book_chat.sql', table: 'ai_chat_sessions' },
  { migration: '013_ai_book_chat.sql', table: 'ai_chat_messages' },
  { migration: '014_auth_identities.sql', table: 'user_identities' },
  { migration: '014_auth_identities.sql', table: 'auth_settings' },
  { migration: '014_auth_identities.sql', table: 'oauth_states' },
  { migration: '014_auth_identities.sql', table: 'oauth_results' },
  { migration: '014_auth_identities.sql', table: 'users', column: 'password_set' },
  { migration: '014_auth_identities.sql', table: 'login_logs', column: 'login_method' }
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

let pending = { at: 0, migrations: [] };

const pendingMigrations = async ({ cachedOnly = false } = {}) => {
  if (cachedOnly || Date.now() - pending.at < RECHECK_MS) return pending.migrations;
  try {
    const missing = await missingSchema();
    pending = { at: Date.now(), migrations: [...new Set(missing.map((m) => m.migration))] };
  } catch {
    pending = { at: Date.now(), migrations: pending.migrations };
  }
  return pending.migrations;
};

module.exports = { hasTables, hasColumn, resetCache, missingSchema, pendingMigrations };
