const { AsyncLocalStorage } = require('async_hooks');
const prisma = require('../lib/prisma');
const { env } = require('../config/env');

const REVALIDATE_MS = 5 * 60 * 1000;
const DETACHED_DELAY_MS = 1000;
const TYPING_MIN_GAP_MS = 1000;

let io = null;
const pendingStore = new AsyncLocalStorage();

const userRoom = (userId) => `user:${userId}`;

const recipientsOf = async (roomId) => {
  const rooms = require('./chat/rooms');
  if ((await rooms.typeOf(roomId)) === 'group') {
    const members = require('./chat/members');
    return (await members.active(roomId)).map((m) => m.user_id);
  }
  const room = await prisma.chat_rooms.findUnique({ where: { room_id: roomId }, select: { user_a_id: true, user_b_id: true } });
  return room ? [room.user_a_id, room.user_b_id] : [];
};

const emitRoom = async (roomId, { exceptUserIds = [], extraUserIds = [] } = {}) => {
  if (!io) return;
  const except = new Set(exceptUserIds);
  const targets = [...new Set([...(await recipientsOf(roomId)), ...extraUserIds])].filter((id) => !except.has(id));
  if (targets.length > 0) io.to(targets.map(userRoom)).emit('chat:room', { room_id: roomId });
};

const flush = (pending) => {
  for (const [roomId, options] of pending) {
    emitRoom(roomId, { exceptUserIds: [...options.except], extraUserIds: [...options.extra] })
      .catch((err) => console.error('[即時推送失敗]:', err.message));
  }
};

// 服務層多半在交易內呼叫；請求內先記下，等回應送出（交易已提交）後才推送，避免 App 收到通知時還讀不到新資料。
const touchRoom = (roomId, { exceptUserId, extraUserIds = [] } = {}) => {
  if (!io || !roomId) return;
  const pending = pendingStore.getStore();
  if (!pending) {
    const detached = new Map([[roomId, { except: new Set(exceptUserId ? [exceptUserId] : []), extra: new Set(extraUserIds) }]]);
    setTimeout(() => flush(detached), DETACHED_DELAY_MS).unref();
    return;
  }
  const entry = pending.get(roomId) ?? { except: new Set(), extra: new Set() };
  if (exceptUserId) entry.except.add(exceptUserId);
  extraUserIds.forEach((id) => entry.extra.add(id));
  pending.set(roomId, entry);
};

const collect = (req, res, next) => {
  if (!io) return next();
  const pending = new Map();
  res.on('finish', () => {
    if (res.statusCode < 400 && pending.size > 0) flush(pending);
  });
  pendingStore.run(pending, next);
};

const typingVisible = async (roomId, userId) => {
  const rooms = require('./chat/rooms');
  if ((await rooms.typeOf(roomId)) === 'group') return null;
  const room = await prisma.chat_rooms.findUnique({ where: { room_id: roomId }, select: { user_a_id: true, user_b_id: true } });
  if (!room) return false;
  const partnerId = room.user_a_id === userId ? room.user_b_id : room.user_a_id;
  const relation = await require('./chat/controls').relation(userId, partnerId);
  return !relation.blocked && !relation.blockedBy;
};

const emitTyping = async (roomId, userId, typing) => {
  if (!io) return;
  if ((await typingVisible(roomId, userId)) === false) return;
  const targets = (await recipientsOf(roomId)).filter((id) => id !== userId);
  if (targets.length > 0) io.to(targets.map(userRoom)).emit('chat:typing', { room_id: roomId, user_id: userId, typing });
};

const onTyping = (socket) => async (payload) => {
  const roomId = Number(payload?.room_id);
  if (!Number.isSafeInteger(roomId) || roomId < 1) return;
  const typingNow = payload?.typing !== false;
  const last = socket.data.typingAt ?? 0;
  if (typingNow && Date.now() - last < TYPING_MIN_GAP_MS) return;
  socket.data.typingAt = Date.now();
  try {
    await require('./chat/messages').setTyping(roomId, socket.data.userId, typingNow);
  } catch {
    // 非成員或聊天室不存在時直接忽略，不回應錯誤。
  }
};

const revalidate = async () => {
  const { authenticate } = require('../middleware/auth');
  for (const socket of await io.fetchSockets()) {
    const { problem } = await authenticate(socket.data.token).catch(() => ({ problem: true }));
    if (problem) socket.disconnect(true);
  }
};

const attach = (httpServer) => {
  const { Server } = require('socket.io');
  const { authenticate } = require('../middleware/auth');
  const sessions = require('./sessions');

  io = new Server(httpServer, {
    path: '/socket.io',
    serveClient: false,
    cors: { origin: env.corsOrigins },
    pingInterval: 25000,
    pingTimeout: 20000
  });

  io.use(async (socket, next) => {
    const token = typeof socket.handshake.auth?.token === 'string' ? socket.handshake.auth.token : null;
    try {
      const { user, decoded, problem } = await authenticate(token);
      if (problem) {
        const err = new Error(problem[1]);
        err.data = { status: problem[0], code: problem[2] ?? null };
        return next(err);
      }
      if (decoded.sid) sessions.touch(decoded.sid, socket.handshake.address);
      socket.data.userId = user.user_id;
      socket.data.token = token;
      next();
    } catch (err) {
      next(err);
    }
  });

  io.on('connection', (socket) => {
    socket.join(userRoom(socket.data.userId));
    socket.on('typing', onTyping(socket));
  });

  const timer = setInterval(() => revalidate().catch((err) => console.error('[即時連線驗證失敗]:', err.message)), REVALIDATE_MS);
  timer.unref();

  return {
    // 不可用 io.close()：那會連同 HTTP 伺服器一起關閉，由呼叫端自行關閉 HTTP 伺服器。
    close: () => {
      clearInterval(timer);
      io.disconnectSockets(true);
      io = null;
    }
  };
};

module.exports = { attach, collect, touchRoom, emitTyping };
