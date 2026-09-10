const express = require('express');
const prisma = require('../lib/prisma');
const authenticateToken = require('../middleware/auth');

const router = express.Router();

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

router.get('/', authenticateToken, async (req, res) => {
  try {
    const disputes = await prisma.transaction_disputes.findMany({
      where: { applicant_id: req.user.userId },
      orderBy: { created_at: 'desc' },
      include: disputeInclude
    });
    res.status(200).json({ success: true, data: disputes });
  } catch (err) {
    console.error('[取得申訴列表失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.post('/', authenticateToken, async (req, res) => {
  const orderId = parseInt(req.body.order_id);
  const reason = (req.body.reason || '').trim();
  const evidenceUrls = Array.isArray(req.body.evidence_urls)
    ? req.body.evidence_urls.join(',')
    : (req.body.evidence_urls || null);

  if (!orderId) return res.status(400).json({ success: false, message: '請提供 order_id' });
  if (!reason) return res.status(400).json({ success: false, message: '請填寫爭議說明' });

  try {
    const order = await prisma.orders.findUnique({ where: { order_id: orderId } });
    if (!order) return res.status(404).json({ success: false, message: '找不到該訂單' });
    if (order.buyer_id !== req.user.userId && order.seller_id !== req.user.userId) {
      return res.status(403).json({ success: false, message: '存取被拒' });
    }

    const existing = await prisma.transaction_disputes.findFirst({
      where: { order_id: orderId, applicant_id: req.user.userId, status: { in: ['pending', 'processing'] } }
    });
    if (existing) {
      return res.status(409).json({ success: false, message: '此訂單已有處理中的爭議申請' });
    }

    const dispute = await prisma.$transaction(async (tx) => {
      const d = await tx.transaction_disputes.create({
        data: { order_id: orderId, applicant_id: req.user.userId, reason, evidence_urls: evidenceUrls },
        include: disputeInclude
      });

      await tx.orders.update({
        where: { order_id: orderId },
        data: { status: 'refunding', updated_at: new Date() }
      });

      return d;
    });

    res.status(201).json({ success: true, message: '爭議申請已送出', data: dispute });
  } catch (err) {
    console.error('[建立爭議申請失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

module.exports = router;
