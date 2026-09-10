const express = require('express');
const prisma = require('../lib/prisma');
const authenticateToken = require('../middleware/auth');

const router = express.Router();

const CATEGORIES = ['account', 'trade', 'wallet', 'cabinet', 'bug', 'other'];

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

// ---------- 公開內容 ----------

router.get('/faqs', async (req, res) => {
  try {
    const faqs = await prisma.faqs.findMany({
      where: { is_visible: true },
      orderBy: [{ category: 'asc' }, { sort_order: 'asc' }, { faq_id: 'asc' }]
    });
    res.status(200).json({ success: true, data: faqs });
  } catch (err) {
    console.error('[取得常見問題失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.get('/legal/:key', async (req, res) => {
  try {
    const doc = await prisma.legal_documents.findUnique({
      where: { doc_key: req.params.key }
    });
    if (!doc) return res.status(404).json({ success: false, message: '找不到這份文件' });
    res.status(200).json({ success: true, data: doc });
  } catch (err) {
    console.error('[取得文件失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

// ---------- 我的工單 ----------

router.get('/tickets', authenticateToken, async (req, res) => {
  try {
    const tickets = await prisma.support_tickets.findMany({
      where: { user_id: req.user.userId },
      orderBy: { updated_at: 'desc' },
      include: {
        _count: { select: { messages: true } },
        messages: { orderBy: { created_at: 'asc' }, take: 1 }
      }
    });
    res.status(200).json({ success: true, data: tickets.map(shapeTicket) });
  } catch (err) {
    console.error('[取得工單失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.get('/tickets/:id', authenticateToken, async (req, res) => {
  const ticketId = parseInt(req.params.id);

  try {
    const ticket = await prisma.support_tickets.findUnique({
      where: { ticket_id: ticketId },
      include: {
        users: { select: { user_id: true, nickname: true, avatar_url: true } },
        messages: {
          orderBy: { created_at: 'asc' },
          include: { users: { select: { user_id: true, nickname: true, avatar_url: true } } }
        }
      }
    });

    if (!ticket) return res.status(404).json({ success: false, message: '找不到這張工單' });
    if (ticket.user_id !== req.user.userId && req.user.role !== 'admin') {
      return res.status(403).json({ success: false, message: '存取被拒' });
    }

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
  } catch (err) {
    console.error('[取得工單內容失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.post('/tickets', authenticateToken, async (req, res) => {
  const subject = (req.body.subject || '').trim();
  const content = (req.body.content || '').trim();
  const category = CATEGORIES.includes(req.body.category) ? req.body.category : 'other';

  if (!subject) return res.status(400).json({ success: false, message: '請填寫問題主旨' });
  if (subject.length > 100) return res.status(400).json({ success: false, message: '主旨不可超過 100 字' });
  if (!content) return res.status(400).json({ success: false, message: '請描述你遇到的問題' });

  try {
    // 同時開太多張未處理的工單會癱瘓客服，這裡先擋。
    const openCount = await prisma.support_tickets.count({
      where: { user_id: req.user.userId, status: { in: ['open', 'pending'] } }
    });
    if (openCount >= 5) {
      return res.status(400).json({
        success: false,
        message: '你已有 5 張處理中的工單，請等客服回覆後再開新的'
      });
    }

    const ticket = await prisma.support_tickets.create({
      data: {
        user_id: req.user.userId,
        subject,
        category,
        messages: {
          create: { sender_id: req.user.userId, is_staff: false, content }
        }
      }
    });

    res.status(201).json({ success: true, data: { ticket_id: ticket.ticket_id } });
  } catch (err) {
    console.error('[建立工單失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.post('/tickets/:id/messages', authenticateToken, async (req, res) => {
  const ticketId = parseInt(req.params.id);
  const content = (req.body.content || '').trim();

  if (!content) return res.status(400).json({ success: false, message: '請輸入內容' });

  try {
    const ticket = await prisma.support_tickets.findUnique({ where: { ticket_id: ticketId } });
    if (!ticket) return res.status(404).json({ success: false, message: '找不到這張工單' });

    const isAdmin = req.user.role === 'admin';
    if (ticket.user_id !== req.user.userId && !isAdmin) {
      return res.status(403).json({ success: false, message: '存取被拒' });
    }
    if (ticket.status === 'closed') {
      return res.status(400).json({ success: false, message: '這張工單已結案，請開立新的工單' });
    }

    await prisma.$transaction(async (tx) => {
      await tx.support_ticket_messages.create({
        data: {
          ticket_id: ticketId,
          sender_id: req.user.userId,
          is_staff: isAdmin,
          content
        }
      });

      await tx.support_tickets.update({
        where: { ticket_id: ticketId },
        data: {
          // 客服回覆 -> 等使用者看；使用者回覆 -> 回到待處理。
          status: isAdmin ? 'pending' : 'open',
          updated_at: new Date()
        }
      });

      if (isAdmin) {
        await tx.notifications.create({
          data: {
            user_id: ticket.user_id,
            type: 'system',
            title: '客服回覆了你的問題',
            content: `工單「${ticket.subject}」有新的回覆。`,
            related_id: ticketId,
            related_type: 'ticket'
          }
        });
      }
    });

    res.status(201).json({ success: true, message: '已送出' });
  } catch (err) {
    console.error('[回覆工單失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.patch('/tickets/:id/close', authenticateToken, async (req, res) => {
  const ticketId = parseInt(req.params.id);

  try {
    const ticket = await prisma.support_tickets.findUnique({ where: { ticket_id: ticketId } });
    if (!ticket) return res.status(404).json({ success: false, message: '找不到這張工單' });
    if (ticket.user_id !== req.user.userId && req.user.role !== 'admin') {
      return res.status(403).json({ success: false, message: '存取被拒' });
    }

    await prisma.support_tickets.update({
      where: { ticket_id: ticketId },
      data: { status: 'closed', closed_at: new Date(), updated_at: new Date() }
    });

    res.status(200).json({ success: true, message: '工單已結案' });
  } catch (err) {
    console.error('[結案工單失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

module.exports = router;
