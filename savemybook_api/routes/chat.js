const express = require('express');
const prisma = require('../lib/prisma');
const authenticateToken = require('../middleware/auth');

const router = express.Router();

const userSelect = { user_id: true, nickname: true, avatar_url: true };

const shapeRoom = (room, myId) => {
  const other = room.user_a_id === myId
    ? room.users_chat_rooms_user_b_idTousers
    : room.users_chat_rooms_user_a_idTousers;

  const last = room.chat_messages[0] ?? null;

  return {
    room_id: room.room_id,
    book: room.books
      ? { book_id: room.books.book_id, title: room.books.title, image_url: room.books.book_images[0]?.image_url ?? null }
      : null,
    partner: other,
    last_message: last ? { content: last.content, message_type: last.message_type, created_at: last.created_at } : null,
    unread_count: room._count?.chat_messages ?? 0,
    updated_at: room.updated_at
  };
};

router.get('/rooms', authenticateToken, async (req, res) => {
  const myId = req.user.userId;
  try {
    const rooms = await prisma.chat_rooms.findMany({
      where: { OR: [{ user_a_id: myId }, { user_b_id: myId }] },
      orderBy: { updated_at: 'desc' },
      include: {
        users_chat_rooms_user_a_idTousers: { select: userSelect },
        users_chat_rooms_user_b_idTousers: { select: userSelect },
        books: { select: { book_id: true, title: true, book_images: { select: { image_url: true }, take: 1 } } },
        chat_messages: { orderBy: { created_at: 'desc' }, take: 1 },
        _count: { select: { chat_messages: { where: { is_read: false, sender_id: { not: myId } } } } }
      }
    });

    res.status(200).json({ success: true, data: rooms.map(r => shapeRoom(r, myId)) });
  } catch (err) {
    console.error('[取得聊天室列表失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

// 建立或取得與某位使用者（可帶書籍）的聊天室
router.post('/rooms', authenticateToken, async (req, res) => {
  const myId = req.user.userId;
  const partnerId = parseInt(req.body.user_id);
  const bookId = req.body.book_id ? parseInt(req.body.book_id) : null;

  if (!partnerId) return res.status(400).json({ success: false, message: '請提供 user_id' });
  if (partnerId === myId) return res.status(400).json({ success: false, message: '無法與自己建立聊天室' });

  try {
    const [userA, userB] = myId < partnerId ? [myId, partnerId] : [partnerId, myId];

    let room = await prisma.chat_rooms.findFirst({
      where: { user_a_id: userA, user_b_id: userB, book_id: bookId }
    });

    if (!room) {
      room = await prisma.chat_rooms.create({
        data: { user_a_id: userA, user_b_id: userB, book_id: bookId }
      });
    }

    res.status(200).json({ success: true, data: { room_id: room.room_id } });
  } catch (err) {
    console.error('[建立聊天室失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.get('/rooms/:roomId/messages', authenticateToken, async (req, res) => {
  const roomId = parseInt(req.params.roomId);
  const myId = req.user.userId;
  const limit = parseInt(req.query.limit) || 50;
  const before = req.query.before ? new Date(req.query.before) : null;

  try {
    const room = await prisma.chat_rooms.findUnique({
      where: { room_id: roomId },
      include: {
        users_chat_rooms_user_a_idTousers: { select: userSelect },
        users_chat_rooms_user_b_idTousers: { select: userSelect },
        books: { select: { book_id: true, title: true, price: true, book_images: { select: { image_url: true }, take: 1 } } }
      }
    });

    if (!room) return res.status(404).json({ success: false, message: '找不到該聊天室' });
    if (room.user_a_id !== myId && room.user_b_id !== myId) {
      return res.status(403).json({ success: false, message: '存取被拒' });
    }

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

    const partner = room.user_a_id === myId
      ? room.users_chat_rooms_user_b_idTousers
      : room.users_chat_rooms_user_a_idTousers;

    res.status(200).json({
      success: true,
      partner,
      book: room.books,
      data: messages.reverse()
    });
  } catch (err) {
    console.error('[取得訊息失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.post('/rooms/:roomId/messages', authenticateToken, async (req, res) => {
  const roomId = parseInt(req.params.roomId);
  const myId = req.user.userId;
  const content = (req.body.content || '').trim();
  const messageType = ['text', 'image', 'system'].includes(req.body.message_type) ? req.body.message_type : 'text';

  if (!content) return res.status(400).json({ success: false, message: '訊息內容不可為空' });

  try {
    const room = await prisma.chat_rooms.findUnique({ where: { room_id: roomId } });
    if (!room) return res.status(404).json({ success: false, message: '找不到該聊天室' });
    if (room.user_a_id !== myId && room.user_b_id !== myId) {
      return res.status(403).json({ success: false, message: '存取被拒' });
    }

    const message = await prisma.$transaction(async (tx) => {
      const m = await tx.chat_messages.create({
        data: { room_id: roomId, sender_id: myId, content, message_type: messageType },
        include: { users: { select: userSelect } }
      });

      await tx.chat_rooms.update({ where: { room_id: roomId }, data: { updated_at: new Date() } });

      await tx.notifications.create({
        data: {
          user_id: room.user_a_id === myId ? room.user_b_id : room.user_a_id,
          type: 'message',
          title: '您有一則新訊息',
          content: messageType === 'image' ? '[圖片]' : content.slice(0, 100),
          related_id: roomId,
          related_type: 'chat_room'
        }
      });

      return m;
    });

    res.status(201).json({ success: true, data: message });
  } catch (err) {
    console.error('[送出訊息失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

module.exports = router;
