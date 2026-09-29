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
const bookChat = require('../services/ai/book-chat');
const consent = require('../services/ai/consent');
const requests = require('../services/ai/requests');
const aiLocale = require('../services/ai/locale');
const feedback = require('../services/ai/feedback');
const listingAdoption = require('../services/ai/listing-adoption');
const recommendationEvents = require('../services/recommendation-events');

const router = express.Router();

const photos = memoryImageUpload({ maxFileSize: 5 * 1024 * 1024, maxFiles: 4 });

const aiLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 20,
  key: byUser,
  message: '操作過於頻繁，請稍後再試'
});

// 推薦在背景產生，App 會在首次開啟後稍後重新讀取；限流只擋異常的連續請求。
const recommendLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 30,
  key: byUser,
  message: '操作過於頻繁，請稍後再試'
});

router.get('/status', authenticateToken, async (req, res) => {
  res.status(200).json({ success: true, data: await runner.status(req.user.userId) });
});

router.put('/consent', authenticateToken, async (req, res) => {
  const granted = req.body?.granted;
  if (typeof granted !== 'boolean') throw badRequest('設定值不正確');
  if (granted && req.body?.notice_version !== consent.NOTICE_VERSION) throw consent.noticeOutdated();
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
  const clientId = requests.parseClientId(req.body.client_id);

  const data = await support.sendMessage(req.user.userId, content, { clientId, locale: aiLocale.normalize(req.body?.locale) });
  res.status(201).json({ success: true, data });
});

const feedbackLimiter = rateLimit({ windowMs: 60 * 1000, max: 30, key: byUser, message: '操作過於頻繁，請稍後再試' });

const feedbackInput = (body) => ({ rating: body?.rating ?? null, reason: body?.reason ?? null });

router.put('/support/messages/:messageNo/feedback', authenticateToken, feedbackLimiter, async (req, res) => {
  const data = await feedback.rate(req.user.userId, 'support', req.params.messageNo, feedbackInput(req.body));
  res.status(200).json({ success: true, message: '已記錄評價', data });
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
  const mode = body.mode ? v.oneOf(String(body.mode), listingAssist.MODES, '請求內容不正確') : 'full';
  if (mode === 'full' && !rawIsbn && !title && files.length === 0) throw badRequest('請至少提供 ISBN、書名或照片其中一項');
  if (mode === 'condition' && files.length === 0 && !conditionNote) throw badRequest('請提供書籍照片或書況說明');

  const data = await listingAssist.assist({
    userId: req.user.userId,
    isbn: rawIsbn.toUpperCase(),
    title,
    conditionNote,
    files,
    mode,
    ...(mode === 'condition' && {
      book: {
        author: v.text(body.author, { label: '作者', max: 255 }),
        publisher: v.text(body.publisher, { label: '出版社', max: 255 }),
        publishDate: v.text(body.publish_date, { label: '出版日期', max: 20 }),
        categoryId: v.optionalId(body.category_id, '分類')
      },
      originalPrice: v.isBlank(body.original_price) ? null : v.int(body.original_price, { label: '定價', min: 1, max: 99999 }),
      followupToken: v.text(body.followup_token, { label: '權杖', max: 100 }) || null
    })
  });
  const token = await listingAdoption.issue(req.user.userId, data, { isbn: rawIsbn, title })
    .catch((err) => console.error('[上架輔助權杖發出失敗]:', err.message));
  res.status(200).json({ success: true, data: { ...data, suggestion_token: token ?? null } });
});

router.get('/book-chat/session', authenticateToken, async (req, res) => {
  res.status(200).json({ success: true, data: await bookChat.currentSession(req.user.userId) });
});

router.post('/book-chat/messages', authenticateToken, aiLimiter, async (req, res) => {
  const content = v.text(req.body?.content, { label: '訊息', max: 500 });
  if (!content) throw badRequest('請輸入訊息內容');
  const clientId = requests.parseClientId(req.body?.client_id);

  const data = await bookChat.sendMessage(req.user.userId, content, { clientId });
  res.status(201).json({ success: true, data });
});

router.put('/book-chat/messages/:messageNo/feedback', authenticateToken, feedbackLimiter, async (req, res) => {
  const data = await feedback.rate(req.user.userId, 'book_chat', req.params.messageNo, feedbackInput(req.body));
  res.status(200).json({ success: true, message: '已記錄評價', data });
});

router.post('/book-chat/session/close', authenticateToken, async (req, res) => {
  await bookChat.close(req.user.userId);
  res.status(200).json({ success: true, message: '已開始新的對話' });
});

router.get('/recommendations', authenticateToken, recommendLimiter, async (req, res) => {
  const { limit } = v.pagination(req.query, { limit: 10, max: 30 });
  // 最近瀏覽紀錄只存在 App 端，由查詢參數帶入，當作較弱的興趣訊號。
  const viewedIds = typeof req.query.viewed_ids === 'string'
    ? [...new Set(req.query.viewed_ids.split(',').map(v.toInt).filter((n) => Number.isSafeInteger(n) && n > 0))].slice(0, 20)
    : [];
  const { data, groups, meta } = await recommend.recommendations(req.user.userId, limit, { viewedIds });
  recommendationEvents.logServedSafely(req.user.userId, data, { ai: meta.source === 'ai', hiddenIds: viewedIds });
  res.status(200).json({ success: true, data, groups, meta });
});

router.post('/recommendations/clicks', authenticateToken, feedbackLimiter, async (req, res) => {
  const bookId = v.id(req.body?.book_id, '書籍編號');
  const recorded = await recommendationEvents.click(req.user.userId, bookId);
  res.status(200).json({ success: true, data: { recorded } });
});

router.post('/recommendations/dismissals', authenticateToken, feedbackLimiter, async (req, res) => {
  const bookId = v.id(req.body?.book_id, '書籍編號');
  await recommendationEvents.dismiss(req.user.userId, bookId);
  res.status(200).json({ success: true, message: '之後不會再推薦這本書' });
});

module.exports = router;
