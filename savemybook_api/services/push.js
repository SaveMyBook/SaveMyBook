const prisma = require('../lib/prisma');
const { env } = require('../config/env');
const { FcmClient } = require('../lib/fcm');
const maintenance = require('../lib/maintenance');
const { hasColumn } = require('../lib/schema-check');
const chatControls = require('./chat-controls');

const PLATFORMS = ['ios', 'android'];
const MAX_DEVICES_PER_USER = 10;

const QUEUE_WINDOW_MINUTES = 15;
const BATCH_SIZE = 200;
const CONCURRENCY = 20;
const POLL_MS = 3000;

const PREFERENCE_COLUMN = {
  order: 'notification_order',
  reservation: 'notification_order',
  message: 'notification_message',
  promotion: 'notification_promo'
};

// Prisma 的 tagged template 不會展開陣列，IN 清單改用 $queryRawUnsafe 搭配 ? 佔位符。
const placeholders = (values) => values.map(() => '?').join(',');

let client = null;
let ready = false;

const isReady = () => ready;

const init = async () => {
  if (!env.pushEnabled) {
    console.log('🔕 推播已由 PUSH_ENABLED=false 停用');
    return false;
  }
  if (!env.fcmServiceAccountFile) {
    console.warn('⚠️  未設定 FCM_SERVICE_ACCOUNT_FILE，手機推播停用');
    return false;
  }

  try {
    client = FcmClient.fromFile(env.fcmServiceAccountFile);
  } catch (err) {
    console.error(`⚠️  無法讀取 Firebase 服務帳戶金鑰（${env.fcmServiceAccountFile}）：${err.message}`);
    return false;
  }

  const [tableRows, columnRows] = await Promise.all([
    prisma.$queryRaw`SELECT COUNT(*) AS n FROM information_schema.TABLES
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'push_devices'`,
    prisma.$queryRaw`SELECT COUNT(*) AS n FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'notifications' AND COLUMN_NAME = 'pushed_at'`
  ]);
  if (Number(tableRows[0].n) === 0 || Number(columnRows[0].n) === 0) {
    console.warn('⚠️  資料庫缺少推播用的資料表，請先執行 migrations/006_push_notifications.sql；手機推播停用');
    return false;
  }

  ready = true;
  console.log(`🔔 手機推播已啟用（Firebase 專案：${client.projectId}）`);
  return true;
};

const registerDevice = async (userId, { token, platform, appVersion, sessionSid = null }) => {
  // 同一個 token 換帳號登入時須轉給新帳號，否則前帳號的通知會推到這支手機。
  if (await hasColumn('push_devices', 'session_sid')) {
    await prisma.$executeRaw`
      INSERT INTO push_devices (user_id, token, platform, app_version, session_sid, created_at, last_seen_at)
      VALUES (${userId}, ${token}, ${platform}, ${appVersion}, ${sessionSid}, NOW(), NOW())
      ON DUPLICATE KEY UPDATE
        user_id = VALUES(user_id), platform = VALUES(platform), app_version = VALUES(app_version),
        session_sid = VALUES(session_sid), last_seen_at = NOW()`;
  } else {
    await prisma.$executeRaw`
      INSERT INTO push_devices (user_id, token, platform, app_version, created_at, last_seen_at)
      VALUES (${userId}, ${token}, ${platform}, ${appVersion}, NOW(), NOW())
      ON DUPLICATE KEY UPDATE
        user_id = VALUES(user_id), platform = VALUES(platform),
        app_version = VALUES(app_version), last_seen_at = NOW()`;
  }

  await prisma.$executeRaw`
    DELETE FROM push_devices
    WHERE user_id = ${userId} AND device_id NOT IN (
      SELECT device_id FROM (
        SELECT device_id FROM push_devices WHERE user_id = ${userId}
        ORDER BY last_seen_at DESC LIMIT ${MAX_DEVICES_PER_USER}
      ) AS keep
    )`;
};

const unregisterDevice = (userId, token) =>
  prisma.$executeRaw`DELETE FROM push_devices WHERE user_id = ${userId} AND token = ${token}`;

const removeUserDevices = async (userId) => {
  try {
    await prisma.$executeRaw`DELETE FROM push_devices WHERE user_id = ${userId}`;
  } catch (err) {
    if (ready) console.error('[清除推播裝置失敗]:', err.message);
  }
};

const listDevices = (userId) => prisma.$queryRaw`
  SELECT device_id, platform, app_version, created_at, last_seen_at, RIGHT(token, 6) AS token_tail
  FROM push_devices WHERE user_id = ${userId} ORDER BY last_seen_at DESC`;

const deviceCount = async (userId) => {
  const rows = await prisma.$queryRaw`SELECT COUNT(*) AS n FROM push_devices WHERE user_id = ${userId}`;
  return Number(rows[0]?.n ?? 0);
};

const removeStaleDevices = () =>
  prisma.$executeRaw`DELETE FROM push_devices WHERE last_seen_at < NOW() - INTERVAL 90 DAY`;

// 先標成已推再送，避免重啟後重複推播；暫時性失敗改由 retryQueue 補送。
// 回溯視窗以資料表內最新的 created_at 為基準：created_at 由 Prisma 寫入，與 Node／資料庫時區設定無關，避免時區不一致時整批被判定過期。
const claimBatch = async () => {
  const now = new Date();
  const rows = await prisma.$queryRaw`
    SELECT n.notification_id, n.user_id, n.type, n.title, n.content, n.related_id, n.related_type
    FROM notifications n
    JOIN (SELECT MAX(created_at) AS latest FROM notifications) m
    WHERE n.pushed_at IS NULL
      AND n.created_at >= m.latest - INTERVAL ${QUEUE_WINDOW_MINUTES} MINUTE
      AND n.created_at <= ${now}
    ORDER BY n.notification_id
    LIMIT ${BATCH_SIZE}`;
  if (rows.length === 0) return [];

  const ids = rows.map((r) => Number(r.notification_id));
  await prisma.$executeRawUnsafe(
    `UPDATE notifications SET pushed_at = ? WHERE pushed_at IS NULL AND notification_id IN (${placeholders(ids)})`,
    now,
    ...ids
  );
  return rows;
};

const recipientsFor = async (userIds) => {
  const [devices, users, settings, unread] = await Promise.all([
    prisma.$queryRawUnsafe(
      `SELECT user_id, token, platform FROM push_devices WHERE user_id IN (${placeholders(userIds)})`,
      ...userIds
    ),
    prisma.users.findMany({
      where: { user_id: { in: userIds } },
      select: { user_id: true, is_active: true, is_blacklisted: true }
    }),
    prisma.user_settings.findMany({
      where: { user_id: { in: userIds } },
      select: { user_id: true, notification_order: true, notification_message: true, notification_promo: true }
    }),
    prisma.notifications.groupBy({
      by: ['user_id'],
      where: { user_id: { in: userIds }, is_read: false },
      _count: { user_id: true }
    })
  ]);

  const active = new Set(users.filter((u) => u.is_active && !u.is_blacklisted).map((u) => u.user_id));
  const byUser = new Map();
  for (const d of devices) {
    if (!active.has(Number(d.user_id))) continue;
    const list = byUser.get(Number(d.user_id)) ?? [];
    list.push(d);
    byUser.set(Number(d.user_id), list);
  }

  return {
    devicesOf: (userId) => byUser.get(userId) ?? [],
    settingsOf: new Map(settings.map((s) => [s.user_id, s])),
    unreadOf: new Map(unread.map((u) => [u.user_id, u._count.user_id]))
  };
};

const clip = (text, max) => (text.length > max ? `${text.slice(0, max - 1)}…` : text);

const threadOf = (notification) =>
  notification.related_type && notification.related_id != null
    ? `${notification.related_type}-${notification.related_id}`
    : String(notification.type ?? 'system');

const buildMessage = (notification, device, badge) => ({
  token: device.token,
  notification: {
    title: clip(String(notification.title), 100),
    body: clip(String(notification.content), 240)
  },
  // FCM data 的值必須全是字串。
  data: {
    notification_id: String(notification.notification_id),
    type: String(notification.type),
    related_type: String(notification.related_type ?? ''),
    related_id: String(notification.related_id ?? '')
  },
  android: {
    priority: 'HIGH',
    notification: { channel_id: 'savemybook_default', sound: 'default' }
  },
  apns: {
    headers: { 'apns-priority': '10', 'apns-push-type': 'alert' },
    payload: { aps: { sound: 'default', badge, 'thread-id': threadOf(notification) } }
  }
});

const runLimited = async (tasks, limit) => {
  let index = 0;
  const workers = Array.from({ length: Math.min(limit, tasks.length) }, async () => {
    while (index < tasks.length) {
      const task = tasks[index];
      index += 1;
      await task();
    }
  });
  await Promise.all(workers);
};

const RETRY_DELAYS_MS = [5000, 20000, 60000, 180000];
const RETRY_MAX_AGE_MS = QUEUE_WINDOW_MINUTES * 60 * 1000;
const retryQueue = [];

const scheduleRetry = (entry) => {
  const attempt = entry.attempt + 1;
  if (attempt > RETRY_DELAYS_MS.length || Date.now() - entry.firstAt > RETRY_MAX_AGE_MS) {
    console.error(`[推播放棄] notification=${entry.notification.notification_id} platform=${entry.device.platform}: ${entry.error}`);
    return;
  }
  retryQueue.push({ ...entry, attempt, dueAt: Date.now() + RETRY_DELAYS_MS[attempt - 1] });
};

const sendOne = async ({ notification, device, badge, invalid, attempt = 0, firstAt = Date.now() }) => {
  const result = await client.send(buildMessage(notification, device, badge));
  if (result.ok) return;
  if (result.invalidToken) {
    invalid.add(device.token);
    console.warn(`[推播 token 失效，已移除] user=${notification.user_id} platform=${device.platform}: ${result.error}`);
    return;
  }
  if (result.retryable) {
    scheduleRetry({ notification, device, badge, attempt, firstAt, error: result.error });
    return;
  }
  console.error(`[推播失敗] notification=${notification.notification_id} platform=${device.platform}: ${result.error}`);
};

const removeInvalid = async (invalid) => {
  if (invalid.size === 0) return;
  const tokens = [...invalid];
  await prisma.$executeRawUnsafe(`DELETE FROM push_devices WHERE token IN (${placeholders(tokens)})`, ...tokens);
};

const dispatchOnce = async () => {
  const rows = await claimBatch();
  if (rows.length === 0) return 0;

  const userIds = [...new Set(rows.map((r) => Number(r.user_id)))];
  const chatRoomIds = [...new Set(rows
    .filter((r) => r.type === 'message' && r.related_type === 'chat_room' && r.related_id != null)
    .map((r) => Number(r.related_id)))];
  const [{ devicesOf, settingsOf, unreadOf }, muted] = await Promise.all([
    recipientsFor(userIds),
    chatControls.mutedPairs(chatRoomIds)
  ]);
  const invalid = new Set();
  const tasks = [];

  for (const n of rows) {
    const userId = Number(n.user_id);
    const pref = PREFERENCE_COLUMN[n.type];
    if (pref && settingsOf.get(userId)?.[pref] === false) continue;
    if (n.type === 'message' && n.related_type === 'chat_room' && muted.has(`${userId}:${Number(n.related_id)}`)) continue;

    for (const device of devicesOf(userId)) {
      tasks.push(() => sendOne({ notification: n, device, badge: unreadOf.get(userId) ?? 0, invalid }));
    }
  }

  await runLimited(tasks, CONCURRENCY);
  await removeInvalid(invalid);
  return rows.length;
};

const dispatchRetries = async () => {
  const now = Date.now();
  const due = [];
  for (let i = retryQueue.length - 1; i >= 0; i -= 1) {
    if (retryQueue[i].dueAt <= now) due.push(...retryQueue.splice(i, 1));
  }
  if (due.length === 0) return 0;

  const tokens = [...new Set(due.map((e) => e.device.token))];
  const rows = await prisma.$queryRawUnsafe(
    `SELECT token FROM push_devices WHERE token IN (${placeholders(tokens)})`,
    ...tokens
  );
  const stillRegistered = new Set(rows.map((r) => r.token));
  const invalid = new Set();
  await runLimited(
    due.filter((e) => stillRegistered.has(e.device.token)).map((e) => () => sendOne({ ...e, invalid })),
    CONCURRENCY
  );
  await removeInvalid(invalid);
  return due.length;
};

const startDispatcher = () => {
  if (!ready) return () => {};

  let running = false;
  const tick = async () => {
    if (running || maintenance.current().active) return;
    running = true;
    try {
      while ((await dispatchOnce()) === BATCH_SIZE);
      await dispatchRetries();
    } catch (err) {
      console.error('[推播派送失敗]:', err.message);
    } finally {
      running = false;
    }
  };

  const timer = setInterval(tick, POLL_MS);
  return () => clearInterval(timer);
};

module.exports = {
  PLATFORMS, isReady, init, registerDevice, unregisterDevice, removeUserDevices, removeStaleDevices, deviceCount, listDevices,
  dispatchOnce, dispatchRetries, startDispatcher, buildMessage, retryQueue
};
