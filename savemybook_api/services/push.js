const prisma = require('../lib/prisma');
const { env } = require('../config/env');
const { FcmClient } = require('../lib/fcm');
const maintenance = require('../lib/maintenance');
const { hasColumn } = require('../lib/schema-check');

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

// 先標成已推再送，避免重啟後重複推播。
// 時間由 Node 計算而非 DB NOW()：created_at 由 Prisma 以 UTC 寫入，資料庫時區可能不同。
const claimBatch = async () => {
  const now = new Date();
  const since = new Date(now.getTime() - QUEUE_WINDOW_MINUTES * 60 * 1000);
  const rows = await prisma.$queryRaw`
    SELECT notification_id, user_id, type, title, content, related_id, related_type
    FROM notifications
    WHERE pushed_at IS NULL AND created_at >= ${since} AND created_at <= ${now}
    ORDER BY notification_id
    LIMIT ${BATCH_SIZE}`;
  if (rows.length === 0) return [];

  const ids = rows.map((r) => Number(r.notification_id));
  await prisma.$executeRawUnsafe(
    `UPDATE notifications SET pushed_at = ? WHERE notification_id IN (${placeholders(ids)})`,
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
    headers: { 'apns-priority': '10' },
    payload: { aps: { sound: 'default', badge } }
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

const dispatchOnce = async () => {
  const rows = await claimBatch();
  if (rows.length === 0) return 0;

  const userIds = [...new Set(rows.map((r) => Number(r.user_id)))];
  const { devicesOf, settingsOf, unreadOf } = await recipientsFor(userIds);
  const invalid = new Set();
  const tasks = [];

  for (const n of rows) {
    const userId = Number(n.user_id);
    const pref = PREFERENCE_COLUMN[n.type];
    if (pref && settingsOf.get(userId)?.[pref] === false) continue;

    for (const device of devicesOf(userId)) {
      tasks.push(async () => {
        let result = await client.send(buildMessage(n, device, unreadOf.get(userId) ?? 0));
        if (!result.ok && result.retryable) {
          await new Promise((r) => setTimeout(r, 1000));
          result = await client.send(buildMessage(n, device, unreadOf.get(userId) ?? 0));
        }
        if (result.ok) return;
        if (result.invalidToken) {
          invalid.add(device.token);
          console.warn(`[推播 token 失效，已移除] user=${userId} platform=${device.platform}: ${result.error}`);
        }
        else console.error(`[推播失敗] notification=${n.notification_id} platform=${device.platform}: ${result.error}`);
      });
    }
  }

  await runLimited(tasks, CONCURRENCY);

  if (invalid.size > 0) {
    const tokens = [...invalid];
    await prisma.$executeRawUnsafe(`DELETE FROM push_devices WHERE token IN (${placeholders(tokens)})`, ...tokens);
  }
  return rows.length;
};

const startDispatcher = () => {
  if (!ready) return () => {};

  let running = false;
  const tick = async () => {
    if (running || maintenance.current().active) return;
    running = true;
    try {
      while ((await dispatchOnce()) === BATCH_SIZE);
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
  dispatchOnce, startDispatcher, buildMessage
};
