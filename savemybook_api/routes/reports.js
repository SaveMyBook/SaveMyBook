const express = require('express');
const prisma = require('../lib/prisma');
const authenticateToken = require('../middleware/auth');
const v = require('../lib/validate');
const { badRequest, notFound, conflict } = require('../lib/errors');
const { REPORT_TARGET_TYPES } = require('../constants/domain');
const { notify } = require('../services/notify');

const router = express.Router();

router.use(authenticateToken);

router.get('/', async (req, res) => {
  const reports = await prisma.reports.findMany({
    where: { reporter_id: req.user.userId },
    orderBy: { created_at: 'desc' }
  });
  res.status(200).json({ success: true, data: reports });
});

const resolveOwner = async (targetType, targetId, userId) => {
  if (targetType === 'book') {
    const book = await prisma.books.findUnique({ where: { book_id: targetId }, select: { seller_id: true } });
    if (!book) throw notFound('找不到該書籍');
    if (book.seller_id === userId) throw badRequest('無法檢舉自己上架的商品');
    return book.seller_id;
  }

  if (targetType === 'user') {
    if (targetId === userId) throw badRequest('無法檢舉自己');
    const target = await prisma.users.findUnique({ where: { user_id: targetId }, select: { user_id: true } });
    if (!target) throw notFound('找不到該使用者');
    return target.user_id;
  }

  const message = await prisma.chat_messages.findUnique({
    where: { message_id: targetId },
    select: { sender_id: true }
  });
  if (!message) throw notFound('找不到該訊息');
  if (message.sender_id === userId) throw badRequest('無法檢舉自己的訊息');
  return null;
};

router.post('/', async (req, res) => {
  const targetType = v.oneOf(req.body.target_type, REPORT_TARGET_TYPES,
    `target_type 僅接受：${REPORT_TARGET_TYPES.join(', ')}`);
  if (req.body.target_id === undefined) throw badRequest('請提供 target_id');
  const targetId = v.id(req.body.target_id, '檢舉對象編號');
  const reason = v.text(req.body.reason, { label: '檢舉原因', max: 2000 });
  const evidenceUrls = v.evidenceUrls(req.body.evidence_urls);

  if (!reason) throw badRequest('請填寫檢舉原因');

  const ownerId = await resolveOwner(targetType, targetId, req.user.userId);

  const duplicate = await prisma.reports.findFirst({
    where: {
      reporter_id: req.user.userId,
      target_type: targetType,
      target_id: targetId,
      status: { in: ['pending', 'reviewing'] }
    },
    select: { report_id: true }
  });
  if (duplicate) throw conflict('你已經檢舉過了，我們正在處理中');

  const report = await prisma.$transaction(async (tx) => {
    const created = await tx.reports.create({
      data: {
        reporter_id: req.user.userId,
        target_type: targetType,
        target_id: targetId,
        reason,
        evidence_urls: evidenceUrls
      }
    });

    if (ownerId) {
      await notify(tx, {
        userId: ownerId,
        title: targetType === 'book' ? '你的商品被檢舉' : '你的帳號被檢舉',
        content: '我們已收到一則檢舉並開始審核，審核期間商品仍可正常販售。若違規成立將會通知你。',
        relatedId: targetId,
        relatedType: targetType
      });
    }

    return created;
  });

  res.status(201).json({ success: true, message: '檢舉已送出，我們會盡快處理', data: report });
});

router.get('/against-me', async (req, res) => {
  const myBooks = await prisma.books.findMany({
    where: { seller_id: req.user.userId },
    select: { book_id: true }
  });

  const bookIds = myBooks.map((b) => b.book_id);
  if (bookIds.length === 0) return res.status(200).json({ success: true, data: [] });

  const reports = await prisma.reports.findMany({
    where: { target_type: 'book', target_id: { in: bookIds } },
    orderBy: { created_at: 'desc' },
    select: { report_id: true, target_id: true, status: true, reason: true, created_at: true, resolved_at: true }
  });

  res.status(200).json({ success: true, data: reports });
});

module.exports = router;
