const express = require('express');
const prisma = require('../lib/prisma');
const authenticateToken = require('../middleware/auth');
const { rateLimit, byUser } = require('../middleware/rateLimit');
const v = require('../lib/validate');
const { badRequest, forbidden, notFound } = require('../lib/errors');
const { notify } = require('../services/notify');

const router = express.Router();

router.use(authenticateToken);

const userSelect = { user_id: true, nickname: true, avatar_url: true };
const MAX_MESSAGE_LENGTH = 2000;

const sendLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 60,
  key: byUser,
  message: '訊息傳送太頻繁，請稍後再試'
});

const partnerOf = (room, myId) => (room.user_a_id === myId
  ? room.users_chat_rooms_user_b_idTousers
  : room.users_chat_rooms_user_a_idTousers);

const shapeRoom = (room, myId) => {
  const last = room.chat_messages[0] ?? null;
  return {
    room_id: room.room_id,
    partner: partnerOf(room, myId),
    last_message: last ? { content: last.content, message_type: last.message_type, created_at: last.created_at } : null,
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

/// 詢問商品時插進對話裡的商品卡片。用 system 訊息夾帶 JSON，
/// 這樣不必為了它在 chat_messages 加欄位。
const BOOK_CARD_PREFIX = '[book]';

const buildBookCard = (book) => BOOK_CARD_PREFIX + JSON.stringify({
  book_id: book.book_id,
  title: book.title,
  price: book.price,
  image_url: book.book_images[0]?.image_url ?? null
});

router.get('/rooms', async (req, res) => {
  const myId = req.user.userId;
  const rooms = await prisma.chat_rooms.findMany({
    where: myRooms(myId),
    orderBy: { updated_at: 'desc' },
    include: {
      users_chat_rooms_user_a_idTousers: { select: userSelect },
      users_chat_rooms_user_b_idTousers: { select: userSelect },
      books: { select: { book_id: true, title: true, book_images: { select: { image_url: true }, take: 1 } } },
      chat_messages: { orderBy: { created_at: 'desc' }, take: 1 },
      _count: { select: { chat_messages: { where: { is_read: false, sender_id: { not: myId } } } } }
    }
  });

  res.status(200).json({ success: true, data: rooms.map((r) => shapeRoom(r, myId)) });
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
  if (!room) throw notFound('找不到這個聊天室');
  if (room.user_a_id !== myId && room.user_b_id !== myId) throw forbidden('你沒有權限刪除這個聊天室');

  // 訊息有 onDelete: Cascade，但這裡明確刪掉比較不依賴 DB 設定。
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
  if (!partner.is_active || partner.is_blacklisted) throw badRequest('對方帳號目前無法接收訊息');

  const book = bookId
    ? await prisma.books.findUnique({
        where: { book_id: bookId },
        select: { book_id: true, title: true, price: true, book_images: { select: { image_url: true }, take: 1 } }
      })
    : null;

  const [userA, userB] = myId < partnerId ? [myId, partnerId] : [partnerId, myId];

  // 一個人只有一間聊天室，不再依 book_id 分開。問不同的書時改成
  // 在同一段對話裡插一張商品卡片。
  let room = await prisma.chat_rooms.findFirst({
    where: { user_a_id: userA, user_b_id: userB },
    orderBy: { updated_at: 'desc' }
  });

  if (!room) {
    room = await prisma.chat_rooms.create({
      data: { user_a_id: userA, user_b_id: userB, book_id: book?.book_id ?? null }
    });
  }

  if (book) {
    const card = buildBookCard(book);

    // 同一張卡片已是最後一則訊息時不重複插入。
    const latest = await prisma.chat_messages.findFirst({
      where: { room_id: room.room_id },
      orderBy: { created_at: 'desc' },
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

router.get('/rooms/:roomId/messages', async (req, res) => {
  const roomId = v.id(req.params.roomId, '聊天室編號');
  const myId = req.user.userId;
  const { limit } = v.pagination(req.query, { limit: 50, max: 200 });
  const before = req.query.before ? v.date(req.query.before, 'before') : null;

  const room = await findMyRoom(roomId, myId, {
    users_chat_rooms_user_a_idTousers: { select: userSelect },
    users_chat_rooms_user_b_idTousers: { select: userSelect },
    books: { select: { book_id: true, title: true, price: true, book_images: { select: { image_url: true }, take: 1 } } }
  });

  const messages = await prisma.chat_messages.findMany({
    where: { room_id: roomId, ...(before && { created_at: { lt: before } }) },
    orderBy: { created_at: 'desc' },
    take: limit,
    include: { users: { select: userSelect } }
  });

  await prisma.chat_messages.updateMany({
    where: { room_id: roomId, sender_id: { not: myId }, is_read: false },
    data: { is_read: true }
  });

  res.status(200).json({
    success: true,
    partner: partnerOf(room, myId),
    book: room.books,
    data: messages.reverse()
  });
});

/// 用戶端只能送文字與圖片。system 類型會被 App 當成商品卡片解析，
/// 開放的話任何人都能在對話裡偽造一張價格不實的商品卡。
const CLIENT_MESSAGE_TYPES = ['text', 'image'];

router.post('/rooms/:roomId/messages', sendLimiter, async (req, res) => {
  const roomId = v.id(req.params.roomId, '聊天室編號');
  const myId = req.user.userId;
  const content = v.text(req.body.content, { label: '訊息', max: MAX_MESSAGE_LENGTH });
  const messageType = CLIENT_MESSAGE_TYPES.includes(req.body.message_type) ? req.body.message_type : 'text';

  if (!content) throw badRequest('訊息內容不可為空');

  const room = await findMyRoom(roomId, myId);

  const message = await prisma.$transaction(async (tx) => {
    const created = await tx.chat_messages.create({
      data: { room_id: roomId, sender_id: myId, content, message_type: messageType },
      include: { users: { select: userSelect } }
    });

    await tx.chat_rooms.update({ where: { room_id: roomId }, data: { updated_at: new Date() } });

    await notify(tx, {
      userId: room.user_a_id === myId ? room.user_b_id : room.user_a_id,
      type: 'message',
      title: '您有一則新訊息',
      content: messageType === 'image' ? '[圖片]' : content.slice(0, 100),
      relatedId: roomId,
      relatedType: 'chat_room'
    });

    return created;
  });

  res.status(201).json({ success: true, data: message });
});

module.exports = router;
