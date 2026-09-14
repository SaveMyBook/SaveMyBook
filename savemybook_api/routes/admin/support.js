const express = require('express');
const prisma = require('../../lib/prisma');
const requireAdmin = require('../../middleware/requireAdmin');
const v = require('../../lib/validate');
const { badRequest, notFound } = require('../../lib/errors');
const { TICKET_STATUSES } = require('../../constants/domain');
const { notify, notifyMany } = require('../../services/notify');
const audit = require('../../services/audit');
const legal = require('../../services/legal');

const TICKET_STATUS_LABELS = { open: '待處理', pending: '等待使用者回覆', resolved: '已解決', closed: '已結案' };
const FAQ_FIELDS = {
  category: '分類',
  question: '問題',
  answer: '答案',
  sort_order: '排序',
  is_visible: { label: '顯示', format: (v) => (v ? '顯示' : '隱藏') }
};

const router = express.Router();
const canEditDocs = requireAdmin('announcements');
const canHandleTickets = requireAdmin('support');

const LEGAL_KEY_RE = /^[a-z0-9_-]{1,50}$/;

router.get('/legal', canEditDocs, async (req, res) => {
  const docs = await prisma.legal_documents.findMany({ orderBy: { doc_id: 'asc' } });
  res.status(200).json({ success: true, data: await legal.withMeta(docs) });
});

router.put('/legal/:key', canEditDocs, async (req, res) => {
  const key = String(req.params.key || '');
  if (!LEGAL_KEY_RE.test(key)) throw badRequest('文件代碼只能包含小寫英文、數字、底線與連字號');

  const title = v.text(req.body.title, { label: '標題', max: 255 });
  const content = v.text(req.body.content, { label: '內容', max: 200000 });
  // 舊版 App 送的欄位是 notify。
  const major = req.body.major === true || req.body.notify === true;

  if (!title) throw badRequest('請填寫標題');
  if (!content) throw badRequest('請填寫內容');

  const existing = await prisma.legal_documents.findUnique({ where: { doc_key: key } });

  const saved = await prisma.legal_documents.upsert({
    where: { doc_key: key },
    update: { title, content, updated_by: req.user.userId, updated_at: new Date() },
    create: { doc_key: key, title, content, updated_by: req.user.userId }
  });

  const contentChanged = !existing || existing.content !== content;
  let version = null;
  let notified = 0;
  let requiresConsent = false;

  if (major && contentChanged) {
    version = existing ? await legal.bumpVersion(key) : 1;
    requiresConsent = (await legal.metaByKey()).get(key)?.requires_consent ?? false;

    const users = await prisma.users.findMany({
      where: { is_active: true, is_blacklisted: false, anonymized_at: null },
      select: { user_id: true }
    });
    notified = await notifyMany(prisma, users.map((u) => u.user_id), {
      title: `${title}已更新`,
      content: requiresConsent
        ? `我們更新了${title}，下次開啟 App 時需要重新閱讀並同意才能繼續使用。`
        : `我們更新了${title}，歡迎查看最新內容。`,
      relatedId: saved.doc_id,
      relatedType: 'legal'
    });
  }

  const fields = { title: '標題', content: '內容' };
  const changes = audit.diff(existing, { title, content }, fields);
  await audit.record(null, {
    adminId: req.user.userId,
    action: '編輯法律文件',
    targetType: 'legal',
    targetId: saved.doc_id,
    summary: `${existing ? '編輯' : '建立'}了「${title}」`
      + (version ? `，列為重大更新（第 ${version} 版）並通知 ${notified} 位使用者${requiresConsent ? '重新同意' : ''}` : '，小幅修改未通知使用者'),
    changes,
    undo: existing && changes.length ? [audit.undoUpdate('legal_documents', key, existing, { title, content }, fields)] : null,
    req
  });

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
  await audit.record(null, {
    adminId: req.user.userId,
    action: '新增常見問題',
    targetType: 'faq',
    targetId: created.faq_id,
    summary: `新增了常見問題「${data.question}」`,
    undo: [audit.undoCreate('faqs', created.faq_id)],
    req
  });
  res.status(201).json({ success: true, data: { faq_id: created.faq_id } });
});

// 必須排在 /faqs/:id 之前，否則 reorder 會被當成 id。
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
    select: { faq_id: true, category: true, question: true, sort_order: true }
  });
  if (existing.length !== ids.length) throw badRequest('排序資料含有不存在的問題');

  const categories = new Set(existing.map((f) => f.category));
  if (categories.size > 1) throw badRequest('一次只能排序同一個分類');

  await prisma.$transaction(
    ids.map((fid, index) => prisma.faqs.update({ where: { faq_id: fid }, data: { sort_order: index } }))
  );

  const byId = new Map(existing.map((f) => [f.faq_id, f]));
  const clip = (q) => (q.length > 20 ? `${q.slice(0, 19)}…` : q);
  await audit.record(null, {
    adminId: req.user.userId,
    action: '調整常見問題順序',
    targetType: 'faq',
    summary: `調整了「${[...categories][0]}」分類的問題順序`,
    changes: [{
      label: '順序',
      from: [...existing].sort((a, b) => a.sort_order - b.sort_order).map((f) => clip(f.question)).join('、'),
      to: ids.map((fid) => clip(byId.get(fid).question)).join('、')
    }],
    undo: [audit.undoReorder('faqs', ids.map((fid, index) => ({ id: fid, before: byId.get(fid).sort_order, after: index })))],
    req
  });
  res.status(200).json({ success: true, message: '已更新順序' });
});

router.put('/faqs/:id', canEditDocs, async (req, res) => {
  const faqId = v.id(req.params.id, '問題編號');
  const data = parseFaq(req.body);
  const before = await prisma.faqs.findUnique({ where: { faq_id: faqId } });
  if (!before) throw notFound('找不到這個問題');

  await prisma.faqs.update({ where: { faq_id: faqId }, data: { ...data, updated_at: new Date() } });

  const changes = audit.diff(before, data, FAQ_FIELDS);
  await audit.record(null, {
    adminId: req.user.userId,
    action: '編輯常見問題',
    targetType: 'faq',
    targetId: faqId,
    summary: changes.length
      ? `修改了常見問題「${before.question}」的${changes.map((c) => c.label).join('、')}`
      : `重新儲存了常見問題「${before.question}」（沒有實際變動）`,
    changes,
    undo: changes.length ? [audit.undoUpdate('faqs', faqId, before, data, FAQ_FIELDS)] : null,
    req
  });
  res.status(200).json({ success: true, message: '已更新' });
});

router.delete('/faqs/:id', canEditDocs, async (req, res) => {
  const faqId = v.id(req.params.id, '問題編號');
  const before = await prisma.faqs.findUnique({ where: { faq_id: faqId } });
  if (!before) throw notFound('找不到這個問題');
  await prisma.faqs.delete({ where: { faq_id: faqId } });
  await audit.record(null, {
    adminId: req.user.userId,
    action: '刪除常見問題',
    targetType: 'faq',
    targetId: faqId,
    summary: `刪除了常見問題「${before.question}」`,
    undo: [audit.undoDelete('faqs', before)],
    req
  });
  res.status(200).json({ success: true, message: '已刪除' });
});

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

  const before = await prisma.support_tickets.findUnique({ where: { ticket_id: ticketId } });
  if (!before) throw notFound('找不到這張工單');

  const ticket = await prisma.support_tickets.update({
    where: { ticket_id: ticketId },
    data: { status, updated_at: new Date(), closed_at: status === 'closed' ? new Date() : null }
  });

  await notify(null, {
    userId: ticket.user_id,
    title: '工單狀態更新',
    content: `工單「${ticket.subject}」已更新為「${TICKET_STATUS_LABELS[status]}」。`,
    relatedId: ticketId,
    relatedType: 'ticket'
  });

  const fields = { status: { label: '狀態', format: (s) => TICKET_STATUS_LABELS[s] ?? s } };
  await audit.record(null, {
    adminId: req.user.userId,
    action: '調整工單狀態',
    targetType: 'ticket',
    targetId: ticketId,
    summary: `把工單「${ticket.subject}」改為${TICKET_STATUS_LABELS[status]}，並通知使用者`,
    changes: audit.diff(before, ticket, fields),
    undo: before.status === status ? null : [audit.undoUpdate('support_tickets', ticketId, before, ticket, ['status', 'closed_at'])],
    req
  });
  res.status(200).json({ success: true, message: '已更新' });
});

module.exports = router;
