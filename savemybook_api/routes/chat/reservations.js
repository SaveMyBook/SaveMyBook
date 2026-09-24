const express = require('express');
const v = require('../../lib/validate');
const rooms = require('../../services/chat/rooms');
const reservations = require('../../services/reservations');
const { sendLimiter } = require('./limits');

const router = express.Router();

const RESPONSE_MESSAGES = { accept: '已接受預約', decline: '已婉拒預約', cancel: '已取消預約' };

router.post('/rooms/:roomId/reservations', sendLimiter, async (req, res) => {
  const roomId = v.id(req.params.roomId, '聊天室編號');
  const room = await rooms.findMessageable(roomId, req.user.userId);
  const bookId = v.id(req.body.book_id, '書籍編號');
  const hours = v.int(req.body.hours, { label: '保留時數', min: 1, max: 72 });
  const message = v.optionalText(req.body.message, { label: '備註', max: 200 }) ?? null;

  const data = await reservations.request({ room, buyerId: req.user.userId, bookId, hours, message });
  res.status(201).json({ success: true, message: '已送出預約，等待賣家回覆', data });
});

router.get('/reservations/mine', async (req, res) => {
  res.status(200).json({ success: true, data: await reservations.mine(req.user.userId) });
});

router.patch('/reservations/:id', async (req, res) => {
  const reservationId = v.id(req.params.id, '預約編號');
  const action = v.oneOf(req.body.action, ['accept', 'decline', 'cancel'], '操作類型不正確');
  const data = await reservations.respond(reservationId, req.user.userId, action);
  res.status(200).json({ success: true, message: RESPONSE_MESSAGES[action], data });
});

module.exports = router;
