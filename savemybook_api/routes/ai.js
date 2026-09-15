const express = require('express');
const authenticateToken = require('../middleware/auth');
const { rateLimit, byUser } = require('../middleware/rateLimit');
const v = require('../lib/validate');
const { memoryImageUpload } = require('../lib/upload');
const { badRequest } = require('../lib/errors');
const runner = require('../services/ai/runner');
const support = require('../services/ai/support');
const listingAssist = require('../services/ai/listing-assist');
const recommend = require('../services/ai/recommend');
const consent = require('../services/ai/consent');

const router = express.Router();

const photos = memoryImageUpload({ maxFileSize: 5 * 1024 * 1024, maxFiles: 4 });

const aiLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 20,
  key: byUser,
  message: '操作過於頻繁，請稍後再試'
});

router.get('/status', authenticateToken, async (req, res) => {
  res.status(200).json({ success: true, data: await runner.status(req.user.userId) });
});

router.put('/consent', authenticateToken, async (req, res) => {
  const granted = req.body?.granted;
  if (typeof granted !== 'boolean') throw badRequest('granted 必須是 true 或 false');
  await consent.setGranted(req.user.userId, granted);
  res.status(200).json({
    success: true,
    message: granted ? '已同意 AI 資料處理' : '已停止 AI 資料處理',
    data: await runner.status(req.user.userId)
  });
});

router.get('/support/session', authenticateToken, async (req, res) => {
  res.status(200).json({ success: true, data: await support.currentSession(req.user.userId) });
});

router.post('/support/messages', authenticateToken, aiLimiter, async (req, res) => {
  const content = v.text(req.body.content, { label: '訊息', max: 1000 });
  if (!content) throw badRequest('請輸入訊息內容');

  const data = await support.sendMessage(req.user.userId, content);
  res.status(201).json({ success: true, data });
});

router.post('/support/session/escalate', authenticateToken, aiLimiter, async (req, res) => {
  const subject = v.text(req.body?.subject, { label: '主旨', max: 100 });
  const data = await support.escalate(req.user.userId, subject || null);
  res.status(201).json({ success: true, message: '已轉由客服人員處理', data });
});

router.post('/support/session/close', authenticateToken, async (req, res) => {
  await support.close(req.user.userId);
  res.status(200).json({ success: true, message: '已結束對話' });
});

router.post('/listing-assist', authenticateToken, aiLimiter, ...photos.array('images', 4), async (req, res) => {
  const body = req.body ?? {};
  const rawIsbn = v.text(body.isbn, { label: 'ISBN', max: 20 }).replace(/[-\s]/g, '');
  if (rawIsbn && !/^(\d{9}[\dXx]|\d{13})$/.test(rawIsbn)) throw badRequest('ISBN 必須是 10 或 13 碼');
  const title = v.text(body.title, { label: '書名', max: 255 });
  const conditionNote = v.text(body.condition_note, { label: '書況說明', max: 500 });
  const files = req.files ?? [];
  if (!rawIsbn && !title && files.length === 0) throw badRequest('請至少提供 ISBN、書名或照片其中一項');

  const data = await listingAssist.assist({
    userId: req.user.userId,
    isbn: rawIsbn.toUpperCase(),
    title,
    conditionNote,
    files
  });
  res.status(200).json({ success: true, data });
});

router.get('/recommendations', authenticateToken, async (req, res) => {
  const { limit } = v.pagination(req.query, { limit: 10, max: 30 });
  const { data, meta } = await recommend.recommendations(req.user.userId, limit);
  res.status(200).json({ success: true, data, meta });
});

module.exports = router;
