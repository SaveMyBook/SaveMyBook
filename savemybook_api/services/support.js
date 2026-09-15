const prisma = require('../lib/prisma');
const { badRequest, forbidden, notFound } = require('../lib/errors');
const { userBrief } = require('../lib/selects');
const { TICKET_STATUS_LABELS } = require('../constants/domain');
const { hasPermission, adminIdsWith } = require('./admin-permissions');
const { notify, notifyMany } = require('./notify');
const audit = require('./audit');

const MAX_OPEN_TICKETS = 5;

const notifySupportStaff = async (actorId, { title, content, ticketId }) => {
  try {
    const staffIds = (await adminIdsWith('support')).filter((id) => id !== actorId);
    if (staffIds.length === 0) return;
    await notifyMany(null, staffIds, { title, content, relatedId: ticketId, relatedType: 'admin_ticket', actorId });
  } catch (err) {
    console.error('[通知客服人員失敗]:', err.message);
  }
};

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
  if (!ticket) throw notFound('找不到此工單');

  const isOwner = ticket.user_id === user.userId;
  const isStaff = !isOwner && (await hasPermission(user, 'support'));
  if (!isOwner && !isStaff) throw forbidden('存取被拒');

  return { ticket, isStaff };
};

const listMine = async (userId) => {
  const tickets = await prisma.support_tickets.findMany({
    where: { user_id: userId },
    orderBy: { updated_at: 'desc' },
    include: {
      _count: { select: { messages: true } },
      messages: { orderBy: { created_at: 'asc' }, take: 1 }
    }
  });
  return tickets.map(shapeTicket);
};

const detail = async (ticketId, user) => {
  const { ticket } = await findAccessibleTicket(ticketId, user, {
    users: { select: userBrief },
    messages: {
      orderBy: { created_at: 'asc' },
      include: { users: { select: userBrief } }
    }
  });

  return {
    ...shapeTicket(ticket),
    messages: ticket.messages.map((m) => ({
      message_id: m.message_id,
      content: m.content,
      is_staff: m.is_staff,
      created_at: m.created_at,
      sender: m.users
    }))
  };
};

const open = async (userId, { subject, category, content }) => {
  const openCount = await prisma.support_tickets.count({
    where: { user_id: userId, status: { in: ['open', 'pending'] } }
  });
  if (openCount >= MAX_OPEN_TICKETS) {
    throw badRequest(`您已有 ${MAX_OPEN_TICKETS} 張處理中的工單，請待客服回覆後再建立新工單`);
  }

  const ticket = await prisma.support_tickets.create({
    data: {
      user_id: userId,
      subject,
      category,
      messages: { create: { sender_id: userId, is_staff: false, content } }
    }
  });

  await notifySupportStaff(userId, {
    title: '新的客服工單',
    content: `「${subject}」等待處理。`,
    ticketId: ticket.ticket_id
  });
  return ticket;
};

const reply = async (ticketId, user, content) => {
  const { ticket, isStaff } = await findAccessibleTicket(ticketId, user);
  if (ticket.status === 'closed') throw badRequest('此工單已結案，請建立新工單');

  await prisma.$transaction(async (tx) => {
    await tx.support_ticket_messages.create({
      data: { ticket_id: ticketId, sender_id: user.userId, is_staff: isStaff, content }
    });

    await tx.support_tickets.update({
      where: { ticket_id: ticketId },
      data: { status: isStaff ? 'pending' : 'open', updated_at: new Date() }
    });

    if (isStaff) {
      await notify(tx, {
        userId: ticket.user_id,
        title: '客服已回覆您的問題',
        content: `工單「${ticket.subject}」有新的回覆。`,
        relatedId: ticketId,
        relatedType: 'ticket'
      });
    }
  });

  if (!isStaff) {
    await notifySupportStaff(user.userId, {
      title: '客服工單有新回覆',
      content: `工單「${ticket.subject}」有新的回覆。`,
      ticketId
    });
  }
};

const close = async (ticketId, user) => {
  await findAccessibleTicket(ticketId, user);

  await prisma.support_tickets.update({
    where: { ticket_id: ticketId },
    data: { status: 'closed', closed_at: new Date(), updated_at: new Date() }
  });
};

const adminList = async (status) => {
  const tickets = await prisma.support_tickets.findMany({
    where: status && status !== 'all' ? { status } : {},
    orderBy: { updated_at: 'desc' },
    take: 100,
    include: {
      users: { select: userBrief },
      _count: { select: { messages: true } },
      messages: { orderBy: { created_at: 'desc' }, take: 1 }
    }
  });

  return tickets.map((t) => ({
    ticket_id: t.ticket_id,
    subject: t.subject,
    category: t.category,
    status: t.status,
    created_at: t.created_at,
    updated_at: t.updated_at,
    message_count: t._count.messages,
    last_message: t.messages[0]?.content ?? null,
    user: t.users
  }));
};

const setStatus = async (ticketId, status, { adminId, req }) => {
  const before = await prisma.support_tickets.findUnique({ where: { ticket_id: ticketId } });
  if (!before) throw notFound('找不到此工單');

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
    adminId,
    action: '調整工單狀態',
    targetType: 'ticket',
    targetId: ticketId,
    summary: `將工單「${ticket.subject}」改為${TICKET_STATUS_LABELS[status]}，並通知使用者`,
    changes: audit.diff(before, ticket, fields),
    undo: before.status === status ? null : [audit.undoUpdate('support_tickets', ticketId, before, ticket, ['status', 'closed_at'])],
    req
  });
};

module.exports = { listMine, detail, open, reply, close, adminList, setStatus };
