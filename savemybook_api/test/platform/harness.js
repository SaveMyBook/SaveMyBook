// 平台共用功能（帳號安全、隱私、通知推播、後台）的測試設定：
// 沿用 test/lib 的假 Prisma、假 fetch 與 Express 應用，另外補上迷你 SQL 直譯器不支援的查詢。
const crypto = require('crypto');
const fs = require('fs');
const os = require('os');
const path = require('path');

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'smb-platform-'));
process.env.BACKUP_DIR = path.join(tempDir, 'backups');

const server = require('../lib/server');
const { registerModels } = require('../lib/fake-prisma');

const {
  API_ROOT, prisma, api, request, runSuite, runFolder, onReset, onFetch, jsonResponse, fetchLog
} = server;

registerModels({
  autoKeys: {
    user_sessions: 'session_id',
    push_devices: 'device_id',
    db_backups: 'backup_id',
    support_tickets: 'ticket_id',
    user_qr_codes: 'qr_id'
  },
  uniqueKeys: {
    user_security: [['user_id']],
    push_devices: [['token']],
    user_settings: [['user_id']],
    user_legal_consents: [['user_id', 'doc_key']]
  }
});

const { env } = api('config/env');
const authToken = api('lib/auth-token');
const bcrypt = api('node_modules/bcrypt');
const schemaCheck = api('lib/schema-check');
const maintenance = api('lib/maintenance');
const sessions = api('services/sessions');
const push = api('services/push');

// ---------- FCM ----------

// 推播派送需要一個可用的服務帳戶金鑰；改用臨時金鑰與攔截的 fetch，完全不連外。
const { privateKey } = crypto.generateKeyPairSync('rsa', { modulusLength: 2048 });
const serviceAccountFile = path.join(tempDir, 'fcm.json');
fs.writeFileSync(serviceAccountFile, JSON.stringify({
  project_id: 'savemybook-test',
  client_email: 'push@savemybook-test.iam.gserviceaccount.com',
  private_key: privateKey.export({ type: 'pkcs8', format: 'pem' })
}));

const pushMessages = [];
let pushResponses = [];
let tokenRequests = 0;

const queuePush = (...items) => pushResponses.push(...items);

onFetch('https://oauth2.googleapis.com/token', () => {
  tokenRequests += 1;
  return jsonResponse({ access_token: `token-${tokenRequests}`, expires_in: 3600 });
});

onFetch('https://fcm.googleapis.com/', (url, init) => {
  const { message } = JSON.parse(init.body);
  pushMessages.push(message);
  const next = pushResponses.shift();
  if (!next) return jsonResponse({ name: 'projects/savemybook-test/messages/1' });
  if (typeof next === 'function') return next(message);
  return jsonResponse(next.body ?? {}, { status: next.status ?? 200 });
});

// ---------- 迷你 SQL 直譯器不支援的查詢 ----------

// 011 之前就存在的資料表，schema 設定只列出各次 migration 新增的部分。
const BASE_TABLES = ['users', 'books', 'orders', 'notifications', 'login_logs', 'admin_permissions', 'legal_documents', 'chat_messages', 'chat_rooms'];

const num = (value) => Number(value ?? 0) || 0;
const rowsOf = (table) => prisma.rows(table);
const time = (value) => new Date(value).getTime();

// 以 LEFT JOIN 一次取回工作階段與帳號安全設定。
prisma.onSql(/LEFT JOIN user_sessions s ON s\.sid/, (sql, [sid, userId]) => {
  const session = rowsOf('user_sessions').find((s) => s.sid === sid) ?? null;
  const security = rowsOf('user_security').find((s) => Number(s.user_id) === Number(userId)) ?? null;
  return [{
    session_user: session ? session.user_id : null,
    revoked_at: session?.revoked_at ?? null,
    tokens_valid_after: security?.tokens_valid_after ?? null
  }];
});

prisma.onSql(/SELECT session_id, user_id, sid, pay_key_hash, last_seen_at FROM user_sessions/, (sql, [sid, cutoff]) =>
  rowsOf('user_sessions').filter((s) => s.sid === sid && s.revoked_at == null && time(s.last_seen_at) >= time(cutoff)));

prisma.onSql(/pay_key_hash IS NOT NULL AS biometric_pay/, (sql, [userId, cutoff]) =>
  rowsOf('user_sessions')
    .filter((s) => Number(s.user_id) === Number(userId) && s.revoked_at == null && time(s.last_seen_at) >= time(cutoff))
    .sort((a, b) => time(b.last_seen_at) - time(a.last_seen_at))
    .map((s) => ({ ...s, biometric_pay: s.pay_key_hash ? 1 : 0 })));

prisma.onSql(/RIGHT\(token, 6\) AS token_tail/, (sql, [userId]) =>
  rowsOf('push_devices')
    .filter((d) => Number(d.user_id) === Number(userId))
    .sort((a, b) => time(b.last_seen_at) - time(a.last_seen_at))
    .map((d) => ({
      device_id: d.device_id,
      platform: d.platform,
      app_version: d.app_version,
      created_at: d.created_at,
      last_seen_at: d.last_seen_at,
      token_tail: String(d.token).slice(-6)
    })));

// push_devices 的 upsert 以 NOW() 當時間戳，迷你直譯器無法解析內建函式。
prisma.onSql(/^INSERT INTO push_devices \(/, (sql, values) => {
  const columns = /\(([^)]+)\)/.exec(sql)[1].split(',').map((c) => c.trim());
  const row = Object.fromEntries(values.map((value, index) => [columns[index], value]));
  const now = new Date();
  const existing = rowsOf('push_devices').find((d) => d.token === row.token);
  if (existing) Object.assign(existing, row, { last_seen_at: now });
  else rowsOf('push_devices').push({ device_id: prisma.nextId('push_devices'), ...row, created_at: now, last_seen_at: now });
  return 1;
});

// 只保留每位使用者最近使用的 N 台裝置。
prisma.onSql(/DELETE FROM push_devices WHERE user_id = \? AND device_id NOT IN/, (sql, [userId, , limit]) => {
  const mine = rowsOf('push_devices')
    .filter((d) => Number(d.user_id) === Number(userId))
    .sort((a, b) => time(b.last_seen_at) - time(a.last_seen_at));
  const keep = new Set(mine.slice(0, num(limit)).map((d) => d.device_id));
  prisma.store.push_devices = rowsOf('push_devices')
    .filter((d) => Number(d.user_id) !== Number(userId) || keep.has(d.device_id));
  return mine.length - keep.size;
});

// 一次寫入多筆通知（含 actor_id）時是多組 VALUES，迷你直譯器只支援單筆。
prisma.onSql(/^INSERT INTO notifications \(user_id, type, title, content, related_id, related_type, actor_id, is_read, created_at\)/, (sql, values) => {
  const columns = ['user_id', 'type', 'title', 'content', 'related_id', 'related_type', 'actor_id', 'created_at'];
  for (let i = 0; i < values.length; i += columns.length) {
    const row = Object.fromEntries(columns.map((c, index) => [c, values[i + index]]));
    prisma.rows('notifications').push({ notification_id: prisma.nextId('notifications'), is_read: false, pushed_at: null, ...row });
  }
  return values.length / columns.length;
});

const notificationCategories = api('services/notification-categories');

prisma.onSql(/AS category, COUNT\(\*\) AS n\s+FROM notifications WHERE user_id = \? AND is_read = 0 GROUP BY category/, (sql, [userId]) => {
  const counts = new Map();
  for (const n of rowsOf('notifications')) {
    if (Number(n.user_id) !== Number(userId) || n.is_read) continue;
    const category = notificationCategories.categoryOf(n.type, n.related_type);
    counts.set(category, (counts.get(category) ?? 0) + 1);
  }
  return [...counts].map(([category, n]) => ({ category, n: BigInt(n) }));
});

// 推播派送批次：取回視窗內尚未推播的通知。
prisma.onSql(/FROM notifications n JOIN \(SELECT MAX\(created_at\) AS latest FROM notifications\) m/, (sql, [minutes, now]) => {
  const all = rowsOf('notifications');
  if (all.length === 0) return [];
  const latest = Math.max(...all.map((n) => time(n.created_at)));
  const from = latest - num(minutes) * 60 * 1000;
  return all
    .filter((n) => n.pushed_at == null && time(n.created_at) >= from && time(n.created_at) <= time(now))
    .sort((a, b) => Number(a.notification_id) - Number(b.notification_id))
    .slice(0, 200)
    .map((n) => ({
      notification_id: n.notification_id,
      user_id: n.user_id,
      type: n.type,
      title: n.title,
      content: n.content,
      related_id: n.related_id ?? null,
      related_type: n.related_type ?? null,
      ...(/n\.actor_id/.test(sql) && { actor_id: n.actor_id ?? null })
    }));
});

// lib/schema-check 的 missingSchema() 直接列出所有資料表與欄位。
prisma.onSql(/SELECT TABLE_NAME AS t FROM information_schema\.TABLES/, () =>
  [...BASE_TABLES, ...prisma.schema.tables].map((t) => ({ t })));

prisma.onSql(/SELECT TABLE_NAME AS t, COLUMN_NAME AS c FROM information_schema\.COLUMNS/, () =>
  prisma.schema.columns.map((entry) => ({ t: entry.split('.')[0], c: entry.split('.')[1] })));

// push.init() 以固定的資料表名稱查詢 information_schema，沒有參數可比對。
prisma.onSql(/TABLE_NAME = 'push_devices'/, () => [{ n: BigInt(1) }]);
prisma.onSql(/COLUMN_NAME = 'pushed_at'/, () => [{ n: BigInt(1) }]);

// ---------- 資料庫狀態 ----------

const FULL_SCHEMA = {
  tables: [
    'db_backups', 'push_devices', 'user_legal_consents', 'user_sessions', 'user_security',
    'chat_room_mutes', 'user_blocks', 'chat_room_members', 'chat_room_pins', 'chat_aliases',
    'chat_transfers', 'chat_mentions', 'ai_settings', 'ai_usage_logs', 'ai_support_sessions',
    'ai_support_messages', 'ai_recommendation_cache', 'ai_book_reviews', 'ai_consents',
    'ai_chat_sessions', 'ai_chat_messages', 'user_identities', 'auth_settings', 'oauth_states', 'oauth_results',
    'user_passkeys', 'webauthn_challenges', 'support_ticket_attachments', 'ai_embeddings', 'ai_book_enrichments',
    'chat_message_risks', 'chat_risk_alerts'
  ],
  columns: [
    'users.deletion_requested_at', 'users.anonymized_at', 'users.share_token', 'users.password_set',
    'login_logs.login_method', 'ai_usage_logs.error_detail', 'notifications.pushed_at', 'notifications.actor_id',
    'push_devices.session_sid', 'books.share_token', 'admin_permissions.can_manage_system',
    'legal_documents.version', 'legal_documents.requires_consent', 'chat_messages.reply_to_id',
    'chat_rooms.room_type', 'chat_rooms.name', 'chat_rooms.avatar_url', 'chat_rooms.created_by',
    'chat_messages.edited_at', 'chat_room_members.history_from_id', 'chat_messages.mentions',
    'smart_cabinets.is_maintenance'
  ]
};

const without = (schema, names) => ({
  tables: schema.tables.filter((t) => !names.includes(t)),
  columns: schema.columns.filter((c) => !names.includes(c))
});

const EMPTY_TABLES = [
  'users', 'login_logs', 'admin_permissions', 'admin_operation_logs', 'notifications', 'user_settings',
  'user_sessions', 'user_security', 'push_devices', 'user_qr_codes', 'db_backups', 'favorites',
  'shopping_cart', 'orders', 'order_items', 'books', 'wallets', 'wallet_transactions', 'reports',
  'transaction_disputes', 'support_tickets', 'user_legal_consents', 'legal_documents', 'chat_messages',
  'chat_room_mutes', 'member_levels', 'ai_consents', 'ai_support_sessions', 'ai_recommendation_cache',
  'ai_chat_sessions', 'user_identities', 'user_passkeys', 'webauthn_challenges'
];

const reset = ({ schema = FULL_SCHEMA, tables = {} } = {}) => {
  pushMessages.length = 0;
  pushResponses = [];
  maintenance.leave();
  server.reset({
    schema,
    tables: { ...Object.fromEntries(EMPTY_TABLES.map((t) => [t, []])), ...tables }
  });
};

server.setDefaultReset(() => reset());

onReset(() => {
  schemaCheck.resetCache();
});

// ---------- 使用者與工作階段 ----------

let userSeq = 0;

const addUser = ({
  role = 'buyer_seller', nickname = '測試使用者', plainPassword = 'Passw0rd123',
  isActive = true, isBlacklisted = false, email, deletionRequestedAt = null
} = {}) => {
  userSeq += 1;
  const row = {
    user_id: userSeq,
    email: email ?? `user${userSeq}@example.com`,
    password_hash: plainPassword ? bcrypt.hashSync(plainPassword, 4) : 'not-a-bcrypt-hash',
    nickname,
    avatar_url: null,
    bio: null,
    phone: null,
    birthday: null,
    gender: 'undisclosed',
    role,
    is_active: isActive,
    is_blacklisted: isBlacklisted,
    bonus_points: 0,
    deletion_requested_at: deletionRequestedAt,
    anonymized_at: null,
    share_token: null,
    password_set: 1,
    created_at: new Date(),
    updated_at: new Date()
  };
  prisma.rows('users').push(row);
  return row;
};

const addAdmin = (permissions = {}) => {
  const admin = addUser({ role: 'admin', nickname: '管理員' });
  prisma.rows('admin_permissions').push({ user_id: admin.user_id, ...permissions });
  return admin;
};

const addSession = (user, {
  sid = crypto.randomBytes(16).toString('hex'), deviceName = 'iPhone 17', platform = 'ios',
  appVersion = '1.0.0', ip = '10.0.0.1', revokedAt = null, payKeyHash = null, lastSeenAt = new Date()
} = {}) => {
  const row = {
    session_id: prisma.nextId('user_sessions'),
    user_id: user.user_id,
    sid,
    device_id: sid.slice(0, 8),
    device_name: deviceName,
    platform,
    app_version: appVersion,
    ip_address: ip,
    created_at: new Date(),
    last_seen_at: lastSeenAt,
    revoked_at: revokedAt,
    pay_key_hash: payKeyHash
  };
  prisma.rows('user_sessions').push(row);
  return row;
};

const setPin = (user, pin = '135790') => {
  prisma.store.user_security = [
    ...prisma.rows('user_security').filter((r) => Number(r.user_id) !== Number(user.user_id)),
    {
      user_id: user.user_id,
      payment_pin_hash: bcrypt.hashSync(pin, 4),
      pin_failed_count: 0,
      pin_locked_until: null,
      pin_updated_at: new Date(),
      tokens_valid_after: null
    }
  ];
};

const tokenFor = (user, sid) => authToken.signToken(user, sid);

// 驗證權杖由 services/security 簽發，測試需要時直接以同樣的內容簽一份。
const verifyTokenFor = ({ user, sid = null, scope = 'sensitive', method = 'password' }) =>
  authToken.sign(
    { typ: 'verify', uid: user.user_id, sid, scope, method, jti: crypto.randomBytes(12).toString('hex') },
    300
  );

const verified = (user, sid, extra = {}) => ({
  ...extra,
  headers: { 'x-verify-token': verifyTokenFor({ user, sid }), ...(extra.headers ?? {}) }
});

// ---------- 推播 ----------

const addDevice = (user, { token, platform = 'ios', appVersion = '1.0.0', sessionSid = null, lastSeenAt = new Date() } = {}) => {
  const row = {
    device_id: prisma.nextId('push_devices'),
    user_id: user.user_id,
    token: token ?? `fcm-token-${prisma.rows('push_devices').length + 1}-${'x'.repeat(20)}`,
    platform,
    app_version: appVersion,
    session_sid: sessionSid,
    created_at: new Date(),
    last_seen_at: lastSeenAt
  };
  prisma.rows('push_devices').push(row);
  return row;
};

const enablePush = async () => {
  env.pushEnabled = true;
  env.fcmServiceAccountFile = serviceAccountFile;
  if (!push.isReady()) await push.init();
};

module.exports = {
  API_ROOT, api, prisma, request, runSuite, runFolder, onFetch, jsonResponse, fetchLog, env,
  reset, without, FULL_SCHEMA, tempDir, schemaCheck, maintenance, sessions, push,
  addUser, addAdmin, addSession, addDevice, setPin, tokenFor, verifyTokenFor, verified,
  enablePush, queuePush, pushMessages, tokenRequests: () => tokenRequests
};
