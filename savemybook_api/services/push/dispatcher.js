const prisma = require('../../lib/prisma');
const { env } = require('../../config/env');
const maintenance = require('../../lib/maintenance');
const { hasColumn } = require('../../lib/schema-check');
const { placeholders } = require('../../lib/sql');
const { clip } = require('../../lib/text');
const chatControls = require('../chat/controls');
const chatSchema = require('../chat/schema');
const { isReady, fcm } = require('./setup');

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

// 先標成已推再送，避免重啟後重複推播；暫時性失敗改由 retryQueue 補送。
// 回溯視窗以資料表內最新的 created_at 為基準：created_at 由 Prisma 寫入，與 Node／資料庫時區設定無關，避免時區不一致時整批被判定過期。
const claimBatch = async () => {
  const now = new Date();
  const rows = (await hasColumn('notifications', 'actor_id'))
    ? await prisma.$queryRaw`
        SELECT n.notification_id, n.user_id, n.type, n.title, n.content, n.related_id, n.related_type, n.actor_id
        FROM notifications n
        JOIN (SELECT MAX(created_at) AS latest FROM notifications) m
        WHERE n.pushed_at IS NULL
          AND n.created_at >= m.latest - INTERVAL ${QUEUE_WINDOW_MINUTES} MINUTE
          AND n.created_at <= ${now}
        ORDER BY n.notification_id
        LIMIT ${BATCH_SIZE}`
    : await prisma.$queryRaw`
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

const threadOf = (notification) =>
  notification.related_type && notification.related_id != null
    ? `${notification.related_type}-${notification.related_id}`
    : String(notification.type ?? 'system');

const isChatMessage = (n) => n.type === 'message' && n.related_type === 'chat_room' && n.related_id != null;

const absoluteUrl = (url) => {
  if (!url) return '';
  if (/^https?:\/\//i.test(url)) return url;
  return env.publicWebUrl ? `${env.publicWebUrl}/${String(url).replace(/^\/+/, '')}` : '';
};

const chatContextFor = async (rows) => {
  const chatRows = rows.filter((r) => isChatMessage(r) && r.actor_id != null);
  const context = { actors: new Map(), rooms: new Map(), aliases: new Map() };
  if (chatRows.length === 0) return context;

  const actorIds = [...new Set(chatRows.map((r) => Number(r.actor_id)))];
  const roomIds = [...new Set(chatRows.map((r) => Number(r.related_id)))];
  const ownerIds = [...new Set(chatRows.map((r) => Number(r.user_id)))];
  const v2 = await chatSchema.isV2();
  const [actors, rooms, aliases] = await Promise.all([
    prisma.users.findMany({
      where: { user_id: { in: actorIds } },
      select: { user_id: true, nickname: true, avatar_url: true }
    }),
    v2
      ? prisma.$queryRawUnsafe(`SELECT room_id, room_type, name FROM chat_rooms WHERE room_id IN (${placeholders(roomIds)})`, ...roomIds)
      : [],
    v2
      ? prisma.$queryRawUnsafe(
          `SELECT owner_id, target_user_id, alias FROM chat_aliases
           WHERE owner_id IN (${placeholders(ownerIds)}) AND target_user_id IN (${placeholders(actorIds)})`,
          ...ownerIds,
          ...actorIds
        )
      : []
  ]);
  for (const a of actors) context.actors.set(Number(a.user_id), a);
  for (const r of rooms) context.rooms.set(Number(r.room_id), r);
  for (const a of aliases) context.aliases.set(`${Number(a.owner_id)}:${Number(a.target_user_id)}`, a.alias);
  return context;
};

const viewOf = (n, context) => {
  const view = {
    title: String(n.title),
    body: String(n.content),
    sender: { sender_id: '', sender_name: '', sender_avatar: '', room_type: '', room_title: '', thread_id: threadOf(n) }
  };
  if (!isChatMessage(n)) return view;

  const room = context.rooms.get(Number(n.related_id));
  const roomType = room?.room_type ?? 'direct';
  const group = roomType === 'group';
  view.sender.room_type = roomType;
  if (group) view.sender.room_title = room.name ?? '';

  const actor = n.actor_id == null ? null : context.actors.get(Number(n.actor_id));
  if (!actor) return view;

  const senderName = context.aliases.get(`${Number(n.user_id)}:${Number(actor.user_id)}`) || actor.nickname || '';
  const prefix = `${actor.nickname}：`;
  view.sender = {
    ...view.sender,
    sender_id: String(actor.user_id),
    sender_name: senderName,
    sender_avatar: absoluteUrl(actor.avatar_url),
    room_title: group ? room.name ?? '' : senderName
  };
  if (group) {
    view.title = room.name || view.title;
    if (view.body.startsWith(prefix)) view.body = `${senderName}：${view.body.slice(prefix.length)}`;
  } else {
    view.title = senderName || view.title;
  }
  return view;
};

// iOS 由 Notification Service Extension 補上發送者頭貼；Android 改送純 data 訊息，由 App 以 MessagingStyle 自行顯示。
const buildMessage = (notification, device, badge, view) => {
  const title = clip(view.title, 100);
  const body = clip(view.body, 240);
  const chat = notification.type === 'message';
  // FCM data 的值必須全是字串。
  const data = {
    notification_id: String(notification.notification_id),
    type: String(notification.type),
    related_type: String(notification.related_type ?? ''),
    related_id: String(notification.related_id ?? ''),
    ...view.sender
  };

  if (chat && device.platform === 'android') {
    return { token: device.token, data: { ...data, title, body }, android: { priority: 'HIGH' } };
  }

  return {
    token: device.token,
    notification: { title, body },
    data,
    android: {
      priority: 'HIGH',
      notification: { channel_id: 'savemybook_default', sound: 'default' }
    },
    apns: {
      headers: { 'apns-priority': '10', 'apns-push-type': 'alert' },
      payload: {
        aps: {
          sound: 'default',
          badge,
          'thread-id': view.sender.thread_id,
          ...(chat && { 'mutable-content': 1, category: 'CHAT_MESSAGE' })
        }
      }
    }
  };
};

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

const sendOne = async ({ notification, device, badge, view, invalid, attempt = 0, firstAt = Date.now() }) => {
  const result = await fcm().send(buildMessage(notification, device, badge, view));
  if (result.ok) return;
  if (result.invalidToken) {
    invalid.add(device.token);
    console.warn(`[推播 token 失效，已移除] user=${notification.user_id} platform=${device.platform}: ${result.error}`);
    return;
  }
  if (result.retryable) {
    scheduleRetry({ notification, device, badge, view, attempt, firstAt, error: result.error });
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
  const [{ devicesOf, settingsOf, unreadOf }, muted, context] = await Promise.all([
    recipientsFor(userIds),
    chatControls.mutedPairs(chatRoomIds),
    chatContextFor(rows)
  ]);
  const invalid = new Set();
  const tasks = [];

  for (const n of rows) {
    const userId = Number(n.user_id);
    const pref = PREFERENCE_COLUMN[n.type];
    if (pref && settingsOf.get(userId)?.[pref] === false) continue;
    if (n.type === 'message' && n.related_type === 'chat_room' && muted.has(`${userId}:${Number(n.related_id)}`)) continue;

    const view = viewOf(n, context);
    for (const device of devicesOf(userId)) {
      tasks.push(() => sendOne({ notification: n, device, badge: unreadOf.get(userId) ?? 0, view, invalid }));
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
  if (!isReady()) return () => {};

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

module.exports = { dispatchOnce, dispatchRetries, startDispatcher, retryQueue };
