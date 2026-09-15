const express = require('express');
const requireAdmin = require('../../middleware/requireAdmin');
const v = require('../../lib/validate');
const { actorOf } = require('../../lib/request-context');
const { badRequest } = require('../../lib/errors');
const { TICKET_STATUSES } = require('../../constants/domain');
const support = require('../../services/support');
const faqs = require('../../services/faqs');
const legal = require('../../services/legal');

const router = express.Router();
const canEditDocs = requireAdmin('announcements');
const canHandleTickets = requireAdmin('support');

router.get('/legal', canEditDocs, async (req, res) => {
  res.status(200).json({ success: true, data: await legal.listFull() });
});

router.put('/legal/:key', canEditDocs, async (req, res) => {
  const key = String(req.params.key || '');
  if (!legal.KEY_RE.test(key)) throw badRequest('文件代碼只能包含小寫英文、數字、底線與連字號');

  const title = v.text(req.body.title, { label: '標題', max: 255 });
  const content = v.text(req.body.content, { label: '內容', max: 200000 });
  // 舊版 App 送的欄位是 notify。
  const major = req.body.major === true || req.body.notify === true;

  if (!title) throw badRequest('請填寫標題');
  if (!content) throw badRequest('請填寫內容');

  const { notified, version } = await legal.save(key, { title, content, major }, actorOf(req));
  res.status(200).json({
    success: true,
    message: notified > 0 ? `已更新並通知 ${notified} 位使用者` : '已更新文件',
    data: { notified, version }
  });
});

const parseFaq = (body) => {
  const data = {
    category: v.text(body.category, { label: '分類', max: 50 }) || 'general',
    question: v.text(body.question, { label: '問題', max: 255 }),
    answer: v.text(body.answer, { label: '答案', max: 10000 }),
    sort_order: v.isBlank(body.sort_order) ? 0 : v.int(body.sort_order, { label: '排序', min: 0, max: 100000 }),
    is_visible: body.is_visible === undefined ? true : v.bool(body.is_visible)
  };
  if (!data.question || !data.answer) throw badRequest('請填寫問題與答案');
  return data;
};

router.get('/faqs', canEditDocs, async (req, res) => {
  res.status(200).json({ success: true, data: await faqs.listAll() });
});

router.post('/faqs', canEditDocs, async (req, res) => {
  const created = await faqs.create(parseFaq(req.body), actorOf(req));
  res.status(201).json({ success: true, data: { faq_id: created.faq_id } });
});

// 必須排在 /faqs/:id 之前，否則 reorder 會被當成 id。
router.put('/faqs/reorder', canEditDocs, async (req, res) => {
  const ids = v.sortOrder(req.body.order, '請提供排序後的問題順序');
  await faqs.reorder(ids, actorOf(req));
  res.status(200).json({ success: true, message: '已更新順序' });
});

router.put('/faqs/:id', canEditDocs, async (req, res) => {
  const faqId = v.id(req.params.id, '問題編號');
  await faqs.update(faqId, parseFaq(req.body), actorOf(req));
  res.status(200).json({ success: true, message: '已更新' });
});

router.delete('/faqs/:id', canEditDocs, async (req, res) => {
  await faqs.remove(v.id(req.params.id, '問題編號'), actorOf(req));
  res.status(200).json({ success: true, message: '已刪除' });
});

router.get('/tickets', canHandleTickets, async (req, res) => {
  const status = req.query.status;
  if (status && status !== 'all') v.oneOf(status, TICKET_STATUSES, '不支援的工單狀態');
  res.status(200).json({ success: true, data: await support.adminList(status) });
});

router.patch('/tickets/:id/status', canHandleTickets, async (req, res) => {
  const ticketId = v.id(req.params.id, '工單編號');
  const status = v.oneOf(req.body.status, TICKET_STATUSES, '不支援的工單狀態');

  await support.setStatus(ticketId, status, actorOf(req));
  res.status(200).json({ success: true, message: '已更新' });
});

module.exports = router;
