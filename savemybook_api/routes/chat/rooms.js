const express = require('express');
const v = require('../../lib/validate');
const { badRequest } = require('../../lib/errors');
const rooms = require('../../services/chat/rooms');
const groups = require('../../services/chat/groups');

const router = express.Router();

router.get('/rooms', async (req, res) => {
  res.status(200).json({ success: true, data: await rooms.list(req.user.userId) });
});

router.get('/unread-count', async (req, res) => {
  const count = await rooms.unreadCount(req.user.userId);
  res.status(200).json({ success: true, data: { unread_count: count } });
});

router.patch('/read-all', async (req, res) => {
  await rooms.markAllRead(req.user.userId);
  res.status(200).json({ success: true, message: '已全部標為已讀' });
});

router.delete('/rooms/:id', async (req, res) => {
  const result = await groups.removeRoom(v.id(req.params.id, '聊天室編號'), req.user.userId);
  res.status(200).json({ success: true, message: result === 'left' ? '已退出群組' : '已刪除聊天室' });
});

router.get('/rooms/:roomId', async (req, res) => {
  const roomId = v.id(req.params.roomId, '聊天室編號');
  res.status(200).json({ success: true, data: await rooms.detail(roomId, req.user.userId) });
});

router.post('/rooms', async (req, res) => {
  if (req.body.user_id === undefined) throw badRequest('請提供 user_id');
  const partnerId = v.id(req.body.user_id, '使用者編號');
  const bookId = v.optionalId(req.body.book_id, '書籍編號');

  const roomId = await rooms.open(req.user.userId, partnerId, bookId);
  res.status(200).json({ success: true, data: { room_id: roomId } });
});

router.put('/rooms/:roomId/mute', async (req, res) => {
  const roomId = v.id(req.params.roomId, '聊天室編號');
  if (typeof req.body.muted !== 'boolean') throw badRequest('muted 必須為布林值');
  await rooms.setMuted(roomId, req.user.userId, req.body.muted);
  res.status(200).json({
    success: true,
    message: req.body.muted ? '已將此聊天室設為靜音' : '已取消靜音',
    data: { room_id: roomId, muted: req.body.muted }
  });
});

router.put('/rooms/:roomId/pin', async (req, res) => {
  const roomId = v.id(req.params.roomId, '聊天室編號');
  if (typeof req.body.pinned !== 'boolean') throw badRequest('pinned 必須為布林值');
  const data = await rooms.setPinned(roomId, req.user.userId, req.body.pinned);
  res.status(200).json({ success: true, message: data.pinned ? '已釘選聊天室' : '已取消釘選', data });
});

module.exports = router;
