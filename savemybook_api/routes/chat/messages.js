const express = require('express');
const { rateLimit, byUser } = require('../../middleware/rateLimit');
const v = require('../../lib/validate');
const { badRequest } = require('../../lib/errors');
const codec = require('../../services/chat/codec');
const messages = require('../../services/chat/messages');
const mentionStore = require('../../services/chat/mentions');
const { sendLimiter, CHAT_IMAGE_RE } = require('./limits');

const router = express.Router();

const MAX_MESSAGE_LENGTH = 2000;
const CLIENT_TYPES = ['text', 'image', 'voice', 'album'];
const VOICE_RE = /^\/uploads\/voice\/[\w.-]+$/;
const INT_MAX = 2147483647;

const typingLimiter = rateLimit({ windowMs: 60 * 1000, max: 40, key: byUser });

const hasMentions = (value) => value !== undefined && value !== null && !(Array.isArray(value) && value.length === 0);

// v.text 會去除前後空白，App 以送出的原始字串計算位置，須扣除被去除的前導空白。
const mentionsOf = (value, rawContent, content) => {
  if (!hasMentions(value)) return [];
  if (!Array.isArray(value) || value.length > mentionStore.MAX_MENTIONS) throw mentionStore.invalid();
  const offset = typeof rawContent === 'string' ? rawContent.length - rawContent.trimStart().length : 0;

  const list = value.map((m) => {
    if (!m || typeof m !== 'object' || ![m.user_id, m.start, m.length].every(Number.isInteger)) throw mentionStore.invalid();
    const start = m.start - offset;
    const valid = m.user_id >= 0 && m.user_id <= INT_MAX
      && start >= 0 && m.length >= 1 && m.length <= mentionStore.MAX_MENTION_LENGTH
      && start + m.length <= content.length && content[start] === '@';
    if (!valid) throw mentionStore.invalid();
    return { user_id: m.user_id, start, length: m.length };
  }).sort((a, b) => a.start - b.start);

  for (let i = 1; i < list.length; i += 1) {
    if (list[i].start < list[i - 1].start + list[i - 1].length) throw mentionStore.invalid();
  }
  return list;
};

const albumOf = (value) => {
  const count = Array.isArray(value) ? value.length : 0;
  if (count < codec.MIN_ALBUM_IMAGES || count > codec.MAX_ALBUM_IMAGES) {
    throw badRequest(`相簿須包含 ${codec.MIN_ALBUM_IMAGES} 至 ${codec.MAX_ALBUM_IMAGES} 張圖片`);
  }
  return value.map((item) => {
    const url = v.text(item, { label: '圖片網址', max: 500 });
    if (!CHAT_IMAGE_RE.test(url)) throw badRequest('圖片請先透過 /api/uploads/chat-image 上傳');
    return url;
  });
};

const buildContent = (body) => {
  const type = body.message_type === undefined
    ? 'text'
    : v.oneOf(body.message_type, CLIENT_TYPES, '不支援此訊息類型');
  if (type !== 'text' && hasMentions(body.mentions)) throw badRequest('僅文字訊息可提及成員');

  if (type === 'album') {
    const urls = albumOf(body.content);
    return { messageType: 'system', content: codec.encodeAlbum(urls), preview: codec.albumPreview(urls.length) };
  }

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
  return { messageType: 'text', content: text, preview: text.slice(0, 100), mentions: mentionsOf(body.mentions, body.content, text) };
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
  const mentions = mentionsOf(req.body.mentions, req.body.content, content);

  const data = await messages.edit(roomId, messageId, req.user.userId, { content, mentions });
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
