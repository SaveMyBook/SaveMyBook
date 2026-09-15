const express = require('express');
const authenticateToken = require('../middleware/auth');
const v = require('../lib/validate');
const { badRequest } = require('../lib/errors');
const disputes = require('../services/disputes');

const router = express.Router();

router.use(authenticateToken);

router.get('/', async (req, res) => {
  res.status(200).json({ success: true, data: await disputes.listMine(req.user.userId) });
});

router.post('/', async (req, res) => {
  if (req.body.order_id === undefined) throw badRequest('請提供 order_id');
  const orderId = v.id(req.body.order_id, '訂單編號');
  const reason = v.text(req.body.reason, { label: '爭議說明', max: 2000 });
  const evidenceUrls = v.evidenceUrls(req.body.evidence_urls);

  if (!reason) throw badRequest('請填寫爭議說明');

  const dispute = await disputes.create(req.user.userId, { orderId, reason, evidenceUrls });
  res.status(201).json({ success: true, message: '爭議申請已送出', data: dispute });
});

module.exports = router;
