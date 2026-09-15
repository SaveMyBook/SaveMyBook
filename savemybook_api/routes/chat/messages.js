const express = require('express');
const { rateLimit, byUser } = require('../../middleware/rateLimit');
const v = require('../../lib/validate');
const { badRequest } = require('../../lib/errors');
const codec = require('../../services/chat/codec');
const messages = require('../../services/chat/messages');
const { sendLimiter, CHAT_IMAGE_RE } = require('./limits');

const router = express.Router();

const MAX_MESSAGE_LENGTH = 2000;
const CLIENT_TYPES = ['text', 'image', 'voice'];
const VOICE_RE = /^\/uploads\/voice\/[\w.-]+$/;

const typingLimiter = rateLimit({ windowMs: 60 * 1000, max: 40, key: byUser });

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
    if (duration > codec.MAX_VOICE_SECONDS) throw badRequest(`語音最長 ${codec.MAX_VOICE_SECONDS} 秒`);
    return { messageType: 'system', content: codec.encodeVoice({ url, duration }), preview: `[語音] ${duration} 秒` };
  }

  const text = v.text(body.content, { label: '訊息', max: MAX_MESSAGE_LENGTH });
  if (!text) throw badRequest('訊息內容不可為空');
  return { messageType: 'text', content: text, preview: text.slice(0, 100) };
};

router.get('/rooms/:roomId/messages', async (req, res) => {
  const roomId = v.id(req.params.roomId, '聊天室編號');
  const { limit } = v.pagination(req.query, { limit: 50, max: 200 });
  const beforeId = v.optionalId(req.query.before_id, 'before_id');
  const afterId = req.query.after_id === undefined ? null : v.int(req.query.after_id, { label: 'after_id', min: 0 });
  const before = req.query.before ? v.date(req.query.before, 'before') : null;

  const result = await messages.list(roomId, req.user.userId, {
    limit, beforeId, afterId, before, markRead: req.query.mark_read !== 'false'
  });
  res.status(200).json({ success: true, ...result });
});

router.post('/rooms/:roomId/messages', sendLimiter, async (req, res) => {
  const roomId = v.id(req.params.roomId, '聊天室編號');
  const outgoing = buildContent(req.body);
  const replyToId = v.optionalId(req.body.reply_to_id, '回覆的訊息編號');

  const data = await messages.send(roomId, req.user.userId, { ...outgoing, replyToId });
  res.status(201).json({ success: true, data });
});

router.patch('/rooms/:roomId/messages/:messageId', async (req, res) => {
  const roomId = v.id(req.params.roomId, '聊天室編號');
  const messageId = v.id(req.params.messageId, '訊息編號');
  const content = v.text(req.body.content, { label: '訊息', max: MAX_MESSAGE_LENGTH });
  if (!content) throw badRequest('訊息內容不可為空');

  const data = await messages.edit(roomId, messageId, req.user.userId, content);
  res.status(200).json({ success: true, message: '訊息已編輯', data });
});

router.post('/rooms/:roomId/typing', typingLimiter, async (req, res) => {
  const roomId = v.id(req.params.roomId, '聊天室編號');
  await messages.setTyping(roomId, req.user.userId, req.body.typing !== false);
  res.status(200).json({ success: true });
});

router.post('/rooms/:roomId/messages/:messageId/recall', async (req, res) => {
  const roomId = v.id(req.params.roomId, '聊天室編號');
  const messageId = v.id(req.params.messageId, '訊息編號');

  const data = await messages.recall(roomId, messageId, req.user.userId);
  res.status(200).json({ success: true, message: '訊息已收回', data });
});

module.exports = router;
