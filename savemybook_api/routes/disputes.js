const express = require('express');
const prisma = require('../lib/prisma');
const authenticateToken = require('../middleware/auth');
const v = require('../lib/validate');
const { badRequest, forbidden, notFound, conflict } = require('../lib/errors');

const router = express.Router();

router.use(authenticateToken);

const disputeInclude = {
  orders: {
    select: {
      order_id: true,
      order_no: true,
      total_amount: true,
      status: true,
      order_items: {
        include: { books: { select: { title: true, book_images: { select: { image_url: true }, take: 1 } } } }
      }
    }
  },
  users_transaction_disputes_applicant_idTousers: { select: { user_id: true, nickname: true, avatar_url: true } }
};

/// 已取消（款項已退回）或已退款的訂單再申訴，裁決退款時會退第二次。
const NOT_DISPUTABLE = ['cancelled', 'refunded'];

router.get('/', async (req, res) => {
  const disputes = await prisma.transaction_disputes.findMany({
    where: { applicant_id: req.user.userId },
    orderBy: { created_at: 'desc' },
    include: disputeInclude
  });
  res.status(200).json({ success: true, data: disputes });
});

router.post('/', async (req, res) => {
  if (req.body.order_id === undefined) throw badRequest('請提供 order_id');
  const orderId = v.id(req.body.order_id, '訂單編號');
  const reason = v.text(req.body.reason, { label: '爭議說明', max: 2000 });
  const evidenceUrls = v.evidenceUrls(req.body.evidence_urls);

  if (!reason) throw badRequest('請填寫爭議說明');

  const order = await prisma.orders.findUnique({
    where: { order_id: orderId },
    select: { buyer_id: true, seller_id: true, status: true }
  });
  if (!order) throw notFound('找不到該訂單');
  if (order.buyer_id !== req.user.userId && order.seller_id !== req.user.userId) throw forbidden('存取被拒');
  if (NOT_DISPUTABLE.includes(order.status)) throw badRequest('這筆訂單已取消或已退款，無法提出爭議');

  const existing = await prisma.transaction_disputes.findFirst({
    where: { order_id: orderId, applicant_id: req.user.userId, status: { in: ['pending', 'processing'] } },
    select: { dispute_id: true }
  });
  if (existing) throw conflict('此訂單已有處理中的爭議申請');

  const dispute = await prisma.$transaction(async (tx) => {
    const created = await tx.transaction_disputes.create({
      data: { order_id: orderId, applicant_id: req.user.userId, reason, evidence_urls: evidenceUrls },
      include: disputeInclude
    });

    await tx.orders.update({
      where: { order_id: orderId },
      data: { status: 'refunding', updated_at: new Date() }
    });

    return created;
  });

  res.status(201).json({ success: true, message: '爭議申請已送出', data: dispute });
});

module.exports = router;
