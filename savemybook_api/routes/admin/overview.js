const express = require('express');
const requireAdmin = require('../../middleware/requireAdmin');
const { requireVerification } = require('../../middleware/verification');
const v = require('../../lib/validate');
const stats = require('../../services/stats');
const operationLogs = require('../../services/operation-logs');

const router = express.Router();

router.get('/overview', async (req, res) => {
  res.status(200).json({ success: true, data: await stats.overview() });
});

router.get('/stats', requireAdmin('stats'), async (req, res) => {
  const days = Math.min(Math.max(v.toInt(req.query.days) || 7, 1), 90);
  res.status(200).json({ success: true, data: await stats.trends(days) });
});

router.get('/operation-logs', async (req, res) => {
  const { page, limit, skip } = v.pagination(req.query, { limit: 50 });
  const targetType = req.query.target_type ? v.oneOf(req.query.target_type, operationLogs.TARGET_TYPES, '不支援的對象類型') : null;
  const adminId = v.optionalId(req.query.admin_id, '管理員編號');
  const keyword = v.text(req.query.keyword, { label: '關鍵字', max: 100 });

  const { rows, total } = await operationLogs.operationLogs({ targetType, adminId, keyword, skip, limit });
  res.status(200).json({ success: true, pagination: v.pageMeta(total, { page, limit }), data: rows });
});

router.post('/operation-logs/:id/undo', requireVerification('sensitive'), async (req, res) => {
  const entry = await operationLogs.revert(v.id(req.params.id, '紀錄編號'), { user: req.user, req });
  res.status(200).json({ success: true, message: '已還原', data: { log_id: entry.log_id } });
});

router.get('/maintenance-logs', async (req, res) => {
  const { page, limit, skip } = v.pagination(req.query, { limit: 30 });
  const { rows, total } = await operationLogs.maintenanceLogs({ skip, limit });
  res.status(200).json({ success: true, pagination: v.pageMeta(total, { page, limit }), data: rows });
});

module.exports = router;
