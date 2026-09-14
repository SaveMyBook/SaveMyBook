const express = require('express');
const prisma = require('../../lib/prisma');
const requireAdmin = require('../../middleware/requireAdmin');
const v = require('../../lib/validate');
const { badRequest, orNotFound } = require('../../lib/errors');
const { TICKET_STATUSES } = require('../../constants/domain');
const { notify, notifyMany } = require('../../services/notify');
const { logAction } = require('../../services/audit');

const router = express.Router();
const canEditDocs = requireAdmin('announcements');
const canHandleTickets = requireAdmin('support');

const LEGAL_KEY_RE = /^[a-z0-9_-]{1,50}$/;

// ---------- 法律文件 ----------

router.get('/legal', canEditDocs, async (req, res) => {
  const docs = await prisma.legal_documents.findMany({ orderBy: { doc_id: 'asc' } });
  res.status(200).json({ success: true, data: docs });
});

router.put('/legal/:key', canEditDocs, async (req, res) => {
  const key = String(req.params.key || '');
  if (!LEGAL_KEY_RE.test(key)) throw badRequest('文件代碼只能包含小寫英文、數字、底線與連字號');

  const title = v.text(req.body.title, { label: '標題', max: 255 });
  const content = v.text(req.body.content, { label: '內容', max: 200000 });
  const shouldNotify = req.body.notify === true;

  if (!title) throw badRequest('請填寫標題');
  if (!content) throw badRequest('請填寫內容');

  const existing = await prisma.legal_documents.findUnique({ where: { doc_key: key }, select: { content: true } });

  await prisma.legal_documents.upsert({
    where: { doc_key: key },
    update: { title, content, updated_by: req.user.userId, updated_at: new Date() },
    create: { doc_key: key, title, content, updated_by: req.user.userId }
  });

  let notified = 0;
  // 條款變更涉及全體使用者權益，逐帳號寫入通知而非僅發布公告。
  if (shouldNotify && existing?.content !== content) {
    const users = await prisma.users.findMany({
      where: { is_active: true, is_blacklisted: false },
      select: { user_id: true }
    });
    notified = await notifyMany(prisma, users.map((u) => u.user_id), {
      title: `${title}已更新`,
      content: `我們更新了${title}，請於設定中查看最新內容。`,
      relatedType: 'legal'
    });
  }

  await logAction(req.user.userId, '編輯法律文件', 'legal', null, notified > 0 ? `${key}｜已通知 ${notified} 人` : key);

  res.status(200).json({
    success: true,
    message: notified > 0 ? `已更新並通知 ${notified} 位使用者` : '已更新文件',
    data: { notified }
  });
});

// ---------- 常見問題 ----------

const parseFaq = (body) => {
  const data = {
    category: v.text(body.category, { label: '分類', max: 50 }) || 'general',
    question: v.text(body.question, { label: '問題', max: 255 }),
    answer: v.text(body.answer, { label: '答案', max: 10000 }),
    sort_order: v.isBlank(body.sort_order) ? 0 : v.int(body.sort_order, { label: '排序', min: 0, max: 100000 }),
    is_visible: body.is_visible === undefined ? true : v.bool(body.is_visible)
  };
  if (!data.question || !data.answer) throw badRequest('問題與答案都要填寫');
  return data;
};

router.get('/faqs', canEditDocs, async (req, res) => {
  const faqs = await prisma.faqs.findMany({
    orderBy: [{ category: 'asc' }, { sort_order: 'asc' }, { faq_id: 'asc' }]
  });
  res.status(200).json({ success: true, data: faqs });
});

router.post('/faqs', canEditDocs, async (req, res) => {
  const data = parseFaq(req.body);
  const created = await prisma.faqs.create({ data });
  await logAction(req.user.userId, '新增常見問題', 'faq', created.faq_id, data.question);
  res.status(201).json({ success: true, data: { faq_id: created.faq_id } });
});

// 必須排在 /faqs/:id 之前，否則 reorder 會被當成 id 吃掉。
router.put('/faqs/reorder', canEditDocs, async (req, res) => {
  const order = req.body.order;
  if (!Array.isArray(order) || order.length === 0) throw badRequest('請提供排序後的問題順序');
  if (order.length > 1000) throw badRequest('排序資料過多');

  const ids = order.map((fid) => v.toInt(fid)).filter((n) => Number.isSafeInteger(n) && n > 0);
  if (ids.length !== order.length || new Set(ids).size !== ids.length) {
    throw badRequest('排序資料格式不正確');
  }

  const existing = await prisma.faqs.findMany({
    where: { faq_id: { in: ids } },
    select: { faq_id: true, category: true }
  });
  if (existing.length !== ids.length) throw badRequest('排序資料含有不存在的問題');

  // 前台依分類分區顯示，跨分類排序沒有意義，也會讓順序在重讀後跳掉。
  const categories = new Set(existing.map((f) => f.category));
  if (categories.size > 1) throw badRequest('一次只能排序同一個分類');

  await prisma.$transaction(
    ids.map((fid, index) => prisma.faqs.update({ where: { faq_id: fid }, data: { sort_order: index } }))
  );

  await logAction(req.user.userId, '調整常見問題順序', 'faq', null, [...categories][0]);
  res.status(200).json({ success: true, message: '已更新順序' });
});

router.put('/faqs/:id', canEditDocs, async (req, res) => {
  const faqId = v.id(req.params.id, '問題編號');
  const data = parseFaq(req.body);
  await orNotFound(
    prisma.faqs.update({ where: { faq_id: faqId }, data: { ...data, updated_at: new Date() } }),
    '找不到這個問題'
  );
  await logAction(req.user.userId, '編輯常見問題', 'faq', faqId, data.question);
  res.status(200).json({ success: true, message: '已更新' });
});

router.delete('/faqs/:id', canEditDocs, async (req, res) => {
  const faqId = v.id(req.params.id, '問題編號');
  await orNotFound(prisma.faqs.delete({ where: { faq_id: faqId } }), '找不到這個問題');
  await logAction(req.user.userId, '刪除常見問題', 'faq', faqId);
  res.status(200).json({ success: true, message: '已刪除' });
});

// ---------- 客服工單 ----------

router.get('/tickets', canHandleTickets, async (req, res) => {
  const status = req.query.status;
  if (status && status !== 'all') v.oneOf(status, TICKET_STATUSES, '不支援的工單狀態');

  const tickets = await prisma.support_tickets.findMany({
    where: status && status !== 'all' ? { status } : {},
    orderBy: { updated_at: 'desc' },
    take: 100,
    include: {
      users: { select: { user_id: true, nickname: true, avatar_url: true } },
      _count: { select: { messages: true } },
      messages: { orderBy: { created_at: 'desc' }, take: 1 }
    }
  });

  res.status(200).json({
    success: true,
    data: tickets.map((t) => ({
      ticket_id: t.ticket_id,
      subject: t.subject,
      category: t.category,
      status: t.status,
      created_at: t.created_at,
      updated_at: t.updated_at,
      message_count: t._count.messages,
      last_message: t.messages[0]?.content ?? null,
      user: t.users
    }))
  });
});

router.patch('/tickets/:id/status', canHandleTickets, async (req, res) => {
  const ticketId = v.id(req.params.id, '工單編號');
  const status = v.oneOf(req.body.status, TICKET_STATUSES, '不支援的工單狀態');

  const ticket = await orNotFound(
    prisma.support_tickets.update({
      where: { ticket_id: ticketId },
      data: { status, updated_at: new Date(), closed_at: status === 'closed' ? new Date() : null }
    }),
    '找不到這張工單'
  );

  await notify(null, {
    userId: ticket.user_id,
    title: '工單狀態更新',
    content: `工單「${ticket.subject}」已更新為「${status}」。`,
    relatedId: ticketId,
    relatedType: 'ticket'
  });

  await logAction(req.user.userId, '調整工單狀態', 'ticket', ticketId, status);
  res.status(200).json({ success: true, message: '已更新' });
});

module.exports = router;
