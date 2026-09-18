const express = require('express');
const authenticateToken = require('../middleware/auth');
const { rateLimit, byUser } = require('../middleware/rateLimit');
const v = require('../lib/validate');
const { badRequest, notFound } = require('../lib/errors');
const { TICKET_CATEGORIES } = require('../constants/domain');
const support = require('../services/support');
const faqs = require('../services/faqs');
const legal = require('../services/legal');
const attachments = require('../services/support-attachments');
const { uploadHeaders } = require('../middleware/security');

const router = express.Router();

const ticketLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 20,
  key: byUser,
  message: '送出過於頻繁，請稍後再試'
});

router.get('/faqs', async (req, res) => {
  res.status(200).json({ success: true, data: await faqs.listVisible() });
});

router.get('/legal', async (req, res) => {
  res.status(200).json({ success: true, data: await legal.listSummaries() });
});

router.get('/legal/:key', async (req, res) => {
  const key = String(req.params.key || '');
  if (!legal.KEY_RE.test(key)) throw notFound('找不到此文件');
  res.status(200).json({ success: true, data: await legal.findByKey(key) });
});

router.get('/tickets', authenticateToken, async (req, res) => {
  res.status(200).json({ success: true, data: await support.listMine(req.user.userId) });
});

router.get('/tickets/:id', authenticateToken, async (req, res) => {
  const data = await support.detail(v.id(req.params.id, '工單編號'), req.user);
  res.status(200).json({ success: true, data });
});

router.post('/tickets', authenticateToken, ticketLimiter, async (req, res) => {
  const subject = v.text(req.body.subject);
  const content = v.text(req.body.content, { label: '問題描述', max: 5000 });
  const category = TICKET_CATEGORIES.includes(req.body.category) ? req.body.category : 'other';

  if (!subject) throw badRequest('請填寫問題主旨');
  if (subject.length > 100) throw badRequest('主旨不可超過 100 字');
  if (!content) throw badRequest('請描述您遇到的問題');
  const attachmentUrls = attachments.parseUrls(req.body.attachments);

  const ticket = await support.open(req.user.userId, { subject, category, content, attachmentUrls });
  res.status(201).json({ success: true, data: { ticket_id: ticket.ticket_id } });
});

router.post('/tickets/:id/messages', authenticateToken, ticketLimiter, async (req, res) => {
  const ticketId = v.id(req.params.id, '工單編號');
  const content = v.text(req.body.content, { label: '內容', max: 5000 });
  const attachmentUrls = attachments.parseUrls(req.body.attachments);
  if (!content && attachmentUrls.length === 0) throw badRequest('請輸入內容');

  await support.reply(ticketId, req.user, content, attachmentUrls);
  res.status(201).json({ success: true, message: '已送出' });
});

// 附件不走 /uploads 靜態目錄：網址由工單內容回應簽發，只有能讀取該工單的人拿得到。
router.get('/attachments/:file', (req, res) => {
  const file = String(req.params.file || '');
  if (!attachments.verifyLink(file, req.query.exp, req.query.sig)) throw notFound('找不到此圖片');

  const { path: filePath, mime } = attachments.fileInfo(file);
  const maxAge = Math.max(0, Number(req.query.exp) - Math.floor(Date.now() / 1000));
  uploadHeaders(res);
  res.setHeader('Cache-Control', `private, max-age=${maxAge}`);
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.type(mime);
  res.sendFile(filePath, { dotfiles: 'deny' }, (err) => {
    if (err && !res.headersSent) res.status(404).json({ success: false, message: '找不到此圖片' });
  });
});

router.patch('/tickets/:id/close', authenticateToken, async (req, res) => {
  await support.close(v.id(req.params.id, '工單編號'), req.user);
  res.status(200).json({ success: true, message: '問題已結案' });
});

module.exports = router;
