const express = require('express');
const prisma = require('../lib/prisma');
const authenticateToken = require('../middleware/auth');
const { rateLimit, byUser } = require('../middleware/rateLimit');
const v = require('../lib/validate');
const { badRequest, conflict, forbidden, notFound } = require('../lib/errors');
const { notify } = require('../services/notify');
const chat = require('../services/chat');
const reservations = require('../services/reservations');
const controls = require('../services/chat-controls');

const router = express.Router();

router.use(authenticateToken);

const userSelect = { user_id: true, nickname: true, avatar_url: true };
const MAX_MESSAGE_LENGTH = 2000;
const TYPING_TTL_MS = 6000;

const sendLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 60,
  key: byUser,
  message: '訊息傳送過於頻繁，請稍後再試'
});

const typingLimiter = rateLimit({ windowMs: 60 * 1000, max: 40, key: byUser });

const typing = new Map();

const partnerOf = (room, myId) => (room.user_a_id === myId
  ? room.users_chat_rooms_user_b_idTousers
  : room.users_chat_rooms_user_a_idTousers);

const partnerIdOf = (room, myId) => (room.user_a_id === myId ? room.user_b_id : room.user_a_id);

const shapeRoom = (room, myId, { muted, blocked }) => {
  const last = room.chat_messages[0] ?? null;
  return {
    room_id: room.room_id,
    partner: partnerOf(room, myId),
    muted: muted.has(room.room_id),
    blocked: blocked.has(partnerIdOf(room, myId)),
    last_message: last
      ? {
          content: last.content,
          message_type: last.message_type,
          kind: chat.decode(last).kind,
          preview: chat.previewOf(last),
          sender_id: last.sender_id,
          is_read: last.is_read,
          created_at: last.created_at
        }
      : null,
    unread_count: room._count?.chat_messages ?? 0,
    updated_at: room.updated_at
  };
};

const myRooms = (myId) => ({ OR: [{ user_a_id: myId }, { user_b_id: myId }] });

const findMyRoom = async (roomId, myId, include) => {
  const room = await prisma.chat_rooms.findUnique({ where: { room_id: roomId }, include });
  if (!room) throw notFound('找不到該聊天室');
  if (room.user_a_id !== myId && room.user_b_id !== myId) throw forbidden('存取被拒');
  return room;
};

router.get('/rooms', async (req, res) => {
  const myId = req.user.userId;
  const [rooms, muted, blocked] = await Promise.all([prisma.chat_rooms.findMany({
    where: myRooms(myId),
    orderBy: { updated_at: 'desc' },
    include: {
      users_chat_rooms_user_a_idTousers: { select: userSelect },
      users_chat_rooms_user_b_idTousers: { select: userSelect },
      books: { select: { book_id: true, title: true, book_images: { select: { image_url: true }, take: 1 } } },
      chat_messages: { orderBy: { message_id: 'desc' }, take: 1 },
      _count: { select: { chat_messages: { where: { is_read: false, sender_id: { not: myId } } } } }
    }
  }), controls.mutedRoomIds(myId), controls.blockedUserIds(myId)]);

  res.status(200).json({ success: true, data: rooms.map((r) => shapeRoom(r, myId, { muted, blocked })) });
});

router.get('/unread-count', async (req, res) => {
  const myId = req.user.userId;
  const count = await prisma.chat_messages.count({
    where: { is_read: false, sender_id: { not: myId }, chat_rooms: myRooms(myId) }
  });
  res.status(200).json({ success: true, data: { unread_count: count } });
});

router.patch('/read-all', async (req, res) => {
  const myId = req.user.userId;
  await prisma.chat_messages.updateMany({
    where: { is_read: false, sender_id: { not: myId }, chat_rooms: myRooms(myId) },
    data: { is_read: true }
  });
  res.status(200).json({ success: true, message: '已全部標為已讀' });
});

router.delete('/rooms/:id', async (req, res) => {
  const myId = req.user.userId;
  const roomId = v.id(req.params.id, '聊天室編號');

  const room = await prisma.chat_rooms.findUnique({
    where: { room_id: roomId },
    select: { user_a_id: true, user_b_id: true }
  });
  if (!room) throw notFound('找不到此聊天室');
  if (room.user_a_id !== myId && room.user_b_id !== myId) throw forbidden('您沒有權限刪除此聊天室');

  await prisma.$transaction([
    prisma.chat_messages.deleteMany({ where: { room_id: roomId } }),
    prisma.chat_rooms.delete({ where: { room_id: roomId } })
  ]);

  res.status(200).json({ success: true, message: '已刪除聊天室' });
});

router.post('/rooms', async (req, res) => {
  const myId = req.user.userId;
  if (req.body.user_id === undefined) throw badRequest('請提供 user_id');
  const partnerId = v.id(req.body.user_id, '使用者編號');
  const bookId = v.optionalId(req.body.book_id, '書籍編號');

  if (partnerId === myId) throw badRequest('無法與自己建立聊天室');

  const partner = await prisma.users.findUnique({
    where: { user_id: partnerId },
    select: { is_active: true, is_blacklisted: true }
  });
  if (!partner) throw notFound('找不到該使用者');
  if (!partner.is_active || partner.is_blacklisted) throw controls.recipientUnavailable();

  const { blocked, blockedBy } = await controls.relation(myId, partnerId);

  const book = bookId && !blocked && !blockedBy
    ? await prisma.books.findUnique({
        where: { book_id: bookId },
        select: { book_id: true, title: true, price: true, book_images: { select: { image_url: true }, take: 1 } }
      })
    : null;

  const [userA, userB] = myId < partnerId ? [myId, partnerId] : [partnerId, myId];

  let room = await prisma.chat_rooms.findFirst({
    where: { user_a_id: userA, user_b_id: userB },
    orderBy: { updated_at: 'desc' }
  });

  if (!room) {
    if (blockedBy) throw controls.recipientUnavailable();
    room = await prisma.chat_rooms.create({
      data: { user_a_id: userA, user_b_id: userB, book_id: book?.book_id ?? null }
    });
  }

  if (book) {
    const card = chat.encodeBook(book);
    const latest = await prisma.chat_messages.findFirst({
      where: { room_id: room.room_id },
      orderBy: { message_id: 'desc' },
      select: { message_type: true, content: true }
    });

    if (!latest || latest.message_type !== 'system' || latest.content !== card) {
      await prisma.$transaction([
        prisma.chat_messages.create({
          data: { room_id: room.room_id, sender_id: myId, content: card, message_type: 'system', is_read: true }
        }),
        prisma.chat_rooms.update({
          where: { room_id: room.room_id },
          data: { book_id: book.book_id, updated_at: new Date() }
        })
      ]);
    }
  }

  res.status(200).json({ success: true, data: { room_id: room.room_id } });
});

const typingKey = (roomId, userId) => `${roomId}:${userId}`;

const partnerTyping = (roomId, partnerId) => {
  const at = typing.get(typingKey(roomId, partnerId));
  return Boolean(at && Date.now() - at < TYPING_TTL_MS);
};

router.get('/rooms/:roomId/messages', async (req, res) => {
  const roomId = v.id(req.params.roomId, '聊天室編號');
  const myId = req.user.userId;
  const { limit } = v.pagination(req.query, { limit: 50, max: 200 });
  const beforeId = v.optionalId(req.query.before_id, 'before_id');
  const afterId = req.query.after_id === undefined ? null : v.int(req.query.after_id, { label: 'after_id', min: 0 });
  const before = req.query.before ? v.date(req.query.before, 'before') : null;

  const room = await findMyRoom(roomId, myId, {
    users_chat_rooms_user_a_idTousers: { select: userSelect },
    users_chat_rooms_user_b_idTousers: { select: userSelect },
    books: { select: { book_id: true, title: true, price: true, book_images: { select: { image_url: true }, take: 1 } } }
  });
  const partnerId = partnerIdOf(room, myId);
  const partnerAccount = partnerOf(room, myId);

  const where = { room_id: roomId };
  if (afterId != null) where.message_id = { gt: afterId };
  else if (beforeId) where.message_id = { lt: beforeId };
  else if (before) where.created_at = { lt: before };

  const messages = await prisma.chat_messages.findMany({
    where,
    orderBy: { message_id: afterId != null ? 'asc' : 'desc' },
    take: limit,
    include: { users: { select: userSelect } }
  });
  if (afterId == null) messages.reverse();

  const recentCutoff = new Date(Date.now() - 10 * 60 * 1000);
  const markRead = req.query.mark_read !== 'false';
  const [, lastRead, recalled, reservationMap, relation, muted, partnerStatus] = await Promise.all([
    markRead
      ? prisma.chat_messages.updateMany({
          where: { room_id: roomId, sender_id: { not: myId }, is_read: false },
          data: { is_read: true }
        })
      : Promise.resolve(null),
    prisma.chat_messages.findFirst({
      where: { room_id: roomId, sender_id: myId, is_read: true },
      orderBy: { message_id: 'desc' },
      select: { message_id: true }
    }),
    afterId != null
      ? prisma.chat_messages.findMany({
          where: { room_id: roomId, created_at: { gte: recentCutoff }, message_type: 'system', content: chat.PREFIX.recalled },
          select: { message_id: true }
        })
      : Promise.resolve([]),
    reservations.forUsers(myId, partnerId),
    controls.relation(myId, partnerId),
    controls.mutedRoomIds(myId),
    prisma.users.findUnique({ where: { user_id: partnerId }, select: { is_active: true, is_blacklisted: true } })
  ]);
  const partnerReachable = Boolean(partnerStatus?.is_active && !partnerStatus.is_blacklisted);

  res.status(200).json({
    success: true,
    partner: partnerAccount,
    book: room.books,
    meta: {
      read_upto: lastRead?.message_id ?? 0,
      partner_typing: !relation.blocked && !relation.blockedBy && partnerTyping(roomId, partnerId),
      muted: muted.has(roomId),
      blocked: relation.blocked,
      can_send: partnerReachable && !relation.blocked && !relation.blockedBy,
      recalled_ids: recalled.map((m) => m.message_id),
      has_more: afterId == null && messages.length === limit,
      reservations: [...reservationMap.values()]
    },
    data: messages.map((m) => chat.shapeMessage(m, { reservations: reservationMap }))
  });
});

const CLIENT_TYPES = ['text', 'image', 'voice'];
const CHAT_IMAGE_RE = /^\/uploads\/chat\/[\w.-]+$/;
const VOICE_RE = /^\/uploads\/voice\/[\w.-]+$/;

const buildContent = (body) => {
  const type = body.message_type === undefined ? 'text' : v.oneOf(body.message_type, CLIENT_TYPES, 'message_type 僅接受：text, image, voice');

  if (type === 'image') {
    const url = v.text(body.content, { label: '圖片網址', max: 500 });
    if (!CHAT_IMAGE_RE.test(url)) throw badRequest('圖片請先透過 /api/uploads/chat-image 上傳');
    return { messageType: 'image', content: url, preview: '[圖片]' };
  }

  if (type === 'voice') {
    const url = v.text(body.content, { label: '語音網址', max: 500 });
    if (!VOICE_RE.test(url)) throw badRequest('語音請先透過 /api/uploads/voice 上傳');
    const duration = Math.round(Number(body.duration));
    if (!Number.isFinite(duration) || duration < 1) throw badRequest('語音長度不正確');
    if (duration > chat.MAX_VOICE_SECONDS) throw badRequest(`語音最長 ${chat.MAX_VOICE_SECONDS} 秒`);
    return { messageType: 'system', content: chat.encodeVoice({ url, duration }), preview: `[語音] ${duration} 秒` };
  }

  const text = v.text(body.content, { label: '訊息', max: MAX_MESSAGE_LENGTH });
  if (!text) throw badRequest('訊息內容不可為空');
  return { messageType: 'text', content: text, preview: text.slice(0, 100) };
};

router.post('/rooms/:roomId/messages', sendLimiter, async (req, res) => {
  const roomId = v.id(req.params.roomId, '聊天室編號');
  const myId = req.user.userId;
  const { messageType, content, preview } = buildContent(req.body);

  const room = await findMyRoom(roomId, myId);
  const partner = await prisma.users.findUnique({
    where: { user_id: partnerIdOf(room, myId) },
    select: { is_active: true, is_blacklisted: true, nickname: true }
  });
  if (!partner || !partner.is_active || partner.is_blacklisted) throw controls.recipientUnavailable();
  await controls.assertCanMessage(myId, partnerIdOf(room, myId));

  const me = await prisma.users.findUnique({ where: { user_id: myId }, select: { nickname: true } });

  const message = await prisma.$transaction(async (tx) => {
    const created = await tx.chat_messages.create({
      data: { room_id: roomId, sender_id: myId, content, message_type: messageType },
      include: { users: { select: userSelect } }
    });

    await tx.chat_rooms.update({ where: { room_id: roomId }, data: { updated_at: new Date() } });

    await notify(tx, {
      userId: partnerIdOf(room, myId),
      type: 'message',
      title: me?.nickname ? `${me.nickname} 傳來訊息` : '您有一則新訊息',
      content: preview,
      relatedId: roomId,
      relatedType: 'chat_room'
    });

    return created;
  });

  typing.delete(typingKey(roomId, myId));
  res.status(201).json({ success: true, data: chat.shapeMessage(message) });
});

router.post('/rooms/:roomId/typing', typingLimiter, async (req, res) => {
  const roomId = v.id(req.params.roomId, '聊天室編號');
  await findMyRoom(roomId, req.user.userId);
  if (req.body.typing === false) typing.delete(typingKey(roomId, req.user.userId));
  else typing.set(typingKey(roomId, req.user.userId), Date.now());
  res.status(200).json({ success: true });
});

setInterval(() => {
  const now = Date.now();
  for (const [key, at] of typing) if (now - at > TYPING_TTL_MS) typing.delete(key);
}, 60 * 1000).unref();

router.post('/rooms/:roomId/messages/:messageId/recall', async (req, res) => {
  const roomId = v.id(req.params.roomId, '聊天室編號');
  const messageId = v.id(req.params.messageId, '訊息編號');
  const myId = req.user.userId;

  const message = await prisma.chat_messages.findUnique({ where: { message_id: messageId } });
  if (!message || message.room_id !== roomId) throw notFound('找不到此訊息');
  if (message.sender_id !== myId) throw forbidden('僅能收回自己傳送的訊息');

  const { kind } = chat.decode(message);
  if (kind === 'recalled') throw conflict('此訊息已收回');
  if (!['text', 'image', 'voice'].includes(kind)) throw badRequest('此類訊息無法收回');
  if (Date.now() - new Date(message.created_at).getTime() > chat.RECALL_WINDOW_MS) {
    throw badRequest('僅能收回 2 分鐘內傳送的訊息');
  }

  const updated = await prisma.chat_messages.update({
    where: { message_id: messageId },
    data: { content: chat.PREFIX.recalled, message_type: 'system' },
    include: { users: { select: userSelect } }
  });
  res.status(200).json({ success: true, message: '訊息已收回', data: chat.shapeMessage(updated) });
});

router.post('/rooms/:roomId/reservations', sendLimiter, async (req, res) => {
  const roomId = v.id(req.params.roomId, '聊天室編號');
  const room = await findMyRoom(roomId, req.user.userId);
  await controls.assertCanMessage(req.user.userId, partnerIdOf(room, req.user.userId));
  const bookId = v.id(req.body.book_id, '書籍編號');
  const hours = v.int(req.body.hours, { label: '保留時數', min: 1, max: 72 });
  const message = v.optionalText(req.body.message, { label: '備註', max: 200 }) ?? null;

  const data = await reservations.request({ room, buyerId: req.user.userId, bookId, hours, message });
  res.status(201).json({ success: true, message: '已送出預約，等待賣家回覆', data });
});

router.put('/rooms/:roomId/mute', async (req, res) => {
  const roomId = v.id(req.params.roomId, '聊天室編號');
  if (typeof req.body.muted !== 'boolean') throw badRequest('muted 必須為布林值');
  await findMyRoom(roomId, req.user.userId);
  await controls.setMuted(req.user.userId, roomId, req.body.muted);
  res.status(200).json({
    success: true,
    message: req.body.muted ? '已將此聊天室設為靜音' : '已取消靜音',
    data: { room_id: roomId, muted: req.body.muted }
  });
});

router.get('/blocks', async (req, res) => {
  const data = await controls.listBlocks(req.user.userId);
  res.status(200).json({ success: true, data });
});

router.put('/blocks/:userId', async (req, res) => {
  const targetId = v.id(req.params.userId, '使用者編號');
  await controls.block(req.user.userId, targetId);
  res.status(200).json({ success: true, message: '已封鎖此使用者', data: { user_id: targetId, blocked: true } });
});

router.delete('/blocks/:userId', async (req, res) => {
  const targetId = v.id(req.params.userId, '使用者編號');
  await controls.unblock(req.user.userId, targetId);
  res.status(200).json({ success: true, message: '已解除封鎖', data: { user_id: targetId, blocked: false } });
});

router.patch('/reservations/:id', async (req, res) => {
  const reservationId = v.id(req.params.id, '預約編號');
  const action = v.oneOf(req.body.action, ['accept', 'decline', 'cancel'], 'action 僅接受：accept, decline, cancel');
  const data = await reservations.respond(reservationId, req.user.userId, action);
  const messages = { accept: '已接受預約', decline: '已婉拒預約', cancel: '已取消預約' };
  res.status(200).json({ success: true, message: messages[action], data });
});

module.exports = router;
