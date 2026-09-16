const express = require('express');
const authenticateToken = require('../middleware/auth');
const v = require('../lib/validate');
const { badRequest } = require('../lib/errors');
const { REPORT_TARGET_TYPES } = require('../constants/domain');
const reports = require('../services/reports');

const router = express.Router();

router.use(authenticateToken);

router.get('/', async (req, res) => {
  res.status(200).json({ success: true, data: await reports.listMine(req.user.userId) });
});

router.post('/', async (req, res) => {
  const targetType = v.oneOf(req.body.target_type, REPORT_TARGET_TYPES,
    '檢舉類型不正確');
  if (req.body.target_id === undefined) throw badRequest('請指定檢舉對象');
  const targetId = v.id(req.body.target_id, '檢舉對象編號');
  const reason = v.text(req.body.reason, { label: '檢舉原因', max: 2000 });
  const evidenceUrls = v.evidenceUrls(req.body.evidence_urls);

  if (!reason) throw badRequest('請填寫檢舉原因');

  const report = await reports.create(req.user.userId, { targetType, targetId, reason, evidenceUrls });
  res.status(201).json({ success: true, message: '檢舉已送出，我們將盡快處理', data: report });
});

router.get('/against-me', async (req, res) => {
  res.status(200).json({ success: true, data: await reports.againstSeller(req.user.userId) });
});

module.exports = router;
