const express = require('express');
const prisma = require('../lib/prisma');
const authenticateToken = require('../middleware/auth');
const { hasPermission } = require('../middleware/requireAdmin');
const { rateLimit, byUser } = require('../middleware/rateLimit');
const v = require('../lib/validate');
const { badRequest, forbidden, notFound } = require('../lib/errors');
const { TICKET_CATEGORIES } = require('../constants/domain');
const { notify } = require('../services/notify');
const legal = require('../services/legal');

const router = express.Router();

const MAX_OPEN_TICKETS = 5;
const LEGAL_KEY_RE = /^[a-z0-9_-]{1,50}$/;

const ticketLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 20,
  key: byUser,
  message: '送出太頻繁，請稍後再試'
});

const shapeTicket = (t) => ({
  ticket_id: t.ticket_id,
  subject: t.subject,
  category: t.category,
  status: t.status,
  created_at: t.created_at,
  updated_at: t.updated_at,
  message_count: t._count?.messages ?? t.messages?.length ?? 0,
  last_message: t.messages?.length ? t.messages[t.messages.length - 1].content : null,
  user: t.users
    ? { user_id: t.users.user_id, nickname: t.users.nickname, avatar_url: t.users.avatar_url }
    : null
});

// 須檢查客服權限而非只看 role，否則無客服權限的管理員也能讀所有工單。
const findAccessibleTicket = async (ticketId, user, include) => {
  const ticket = await prisma.support_tickets.findUnique({ where: { ticket_id: ticketId }, include });
  if (!ticket) throw notFound('找不到這張工單');

  const isOwner = ticket.user_id === user.userId;
  const isStaff = !isOwner && (await hasPermission(user, 'support'));
  if (!isOwner && !isStaff) throw forbidden('存取被拒');

  return { ticket, isStaff };
};

router.get('/faqs', async (req, res) => {
  const faqs = await prisma.faqs.findMany({
    where: { is_visible: true },
    orderBy: [{ category: 'asc' }, { sort_order: 'asc' }, { faq_id: 'asc' }]
  });
  res.status(200).json({ success: true, data: faqs });
});

router.get('/legal', async (req, res) => {
  const docs = await prisma.legal_documents.findMany({
    orderBy: { doc_id: 'asc' },
    select: { doc_id: true, doc_key: true, title: true, updated_at: true }
  });
  res.status(200).json({ success: true, data: await legal.withMeta(docs) });
});

router.get('/legal/:key', async (req, res) => {
  const key = String(req.params.key || '');
  if (!LEGAL_KEY_RE.test(key)) throw notFound('找不到這份文件');

  const doc = await prisma.legal_documents.findUnique({ where: { doc_key: key } });
  if (!doc) throw notFound('找不到這份文件');
  const [withVersion] = await legal.withMeta([doc]);
  res.status(200).json({ success: true, data: withVersion });
});

router.get('/tickets', authenticateToken, async (req, res) => {
  const tickets = await prisma.support_tickets.findMany({
    where: { user_id: req.user.userId },
    orderBy: { updated_at: 'desc' },
    include: {
      _count: { select: { messages: true } },
      messages: { orderBy: { created_at: 'asc' }, take: 1 }
    }
  });
  res.status(200).json({ success: true, data: tickets.map(shapeTicket) });
});

router.get('/tickets/:id', authenticateToken, async (req, res) => {
  const { ticket } = await findAccessibleTicket(v.id(req.params.id, '工單編號'), req.user, {
    users: { select: { user_id: true, nickname: true, avatar_url: true } },
    messages: {
      orderBy: { created_at: 'asc' },
      include: { users: { select: { user_id: true, nickname: true, avatar_url: true } } }
    }
  });

  res.status(200).json({
    success: true,
    data: {
      ...shapeTicket(ticket),
      messages: ticket.messages.map((m) => ({
        message_id: m.message_id,
        content: m.content,
        is_staff: m.is_staff,
        created_at: m.created_at,
        sender: m.users
      }))
    }
  });
});

router.post('/tickets', authenticateToken, ticketLimiter, async (req, res) => {
  const subject = v.text(req.body.subject);
  const content = v.text(req.body.content, { label: '問題描述', max: 5000 });
  const category = TICKET_CATEGORIES.includes(req.body.category) ? req.body.category : 'other';

  if (!subject) throw badRequest('請填寫問題主旨');
  if (subject.length > 100) throw badRequest('主旨不可超過 100 字');
  if (!content) throw badRequest('請描述你遇到的問題');

  const openCount = await prisma.support_tickets.count({
    where: { user_id: req.user.userId, status: { in: ['open', 'pending'] } }
  });
  if (openCount >= MAX_OPEN_TICKETS) {
    throw badRequest(`你已有 ${MAX_OPEN_TICKETS} 張處理中的工單，請等客服回覆後再開新的`);
  }

  const ticket = await prisma.support_tickets.create({
    data: {
      user_id: req.user.userId,
      subject,
      category,
      messages: { create: { sender_id: req.user.userId, is_staff: false, content } }
    }
  });

  res.status(201).json({ success: true, data: { ticket_id: ticket.ticket_id } });
});

router.post('/tickets/:id/messages', authenticateToken, ticketLimiter, async (req, res) => {
  const ticketId = v.id(req.params.id, '工單編號');
  const content = v.text(req.body.content, { label: '內容', max: 5000 });
  if (!content) throw badRequest('請輸入內容');

  const { ticket, isStaff } = await findAccessibleTicket(ticketId, req.user);
  if (ticket.status === 'closed') throw badRequest('這張工單已結案，請開立新的工單');

  await prisma.$transaction(async (tx) => {
    await tx.support_ticket_messages.create({
      data: { ticket_id: ticketId, sender_id: req.user.userId, is_staff: isStaff, content }
    });

    await tx.support_tickets.update({
      where: { ticket_id: ticketId },
      data: { status: isStaff ? 'pending' : 'open', updated_at: new Date() }
    });

    if (isStaff) {
      await notify(tx, {
        userId: ticket.user_id,
        title: '客服回覆了你的問題',
        content: `工單「${ticket.subject}」有新的回覆。`,
        relatedId: ticketId,
        relatedType: 'ticket'
      });
    }
  });

  res.status(201).json({ success: true, message: '已送出' });
});

router.patch('/tickets/:id/close', authenticateToken, async (req, res) => {
  const ticketId = v.id(req.params.id, '工單編號');
  await findAccessibleTicket(ticketId, req.user);

  await prisma.support_tickets.update({
    where: { ticket_id: ticketId },
    data: { status: 'closed', closed_at: new Date(), updated_at: new Date() }
  });

  res.status(200).json({ success: true, message: '工單已結案' });
});

module.exports = router;
