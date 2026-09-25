const express = require('express');
const requireAdmin = require('../../middleware/requireAdmin');
const v = require('../../lib/validate');
const { actorOf } = require('../../lib/request-context');
const { REPORT_STATUSES, DISPUTE_STATUSES } = require('../../constants/domain');
const reports = require('../../services/reports');
const disputes = require('../../services/disputes');
const disputeAssist = require('../../services/ai/dispute-assist');
const chatRisk = require('../../services/chat/risk');
const { rateLimit, byUser } = require('../../middleware/rateLimit');

const router = express.Router();

router.get('/reports', requireAdmin('reports'), async (req, res) => {
  const status = req.query.status ? v.oneOf(req.query.status, REPORT_STATUSES, '不支援的檢舉狀態') : null;
  res.status(200).json({ success: true, data: await reports.adminList(status) });
});

router.patch('/reports/:id', requireAdmin('reports'), async (req, res) => {
  const reportId = v.id(req.params.id, '檢舉編號');
  const status = v.oneOf(req.body.status, reports.RESULTS, `status 僅接受：${reports.RESULTS.join(', ')}`);
  const adminNote = v.optionalText(req.body.admin_note, { label: '處理備註', max: 2000 }) ?? null;
  const removeTarget = v.bool(req.body.remove_target);

  const updated = await reports.review(reportId, { status, adminNote, removeTarget }, actorOf(req));
  res.status(200).json({ success: true, message: '檢舉已處理', data: updated });
});

router.get('/chat-risk-alerts', requireAdmin('reports'), async (req, res) => {
  const status = req.query.status ? v.oneOf(req.query.status, chatRisk.ALERT_STATUSES, '不支援的警示狀態') : null;
  res.status(200).json({ success: true, data: await chatRisk.adminList(status) });
});

router.patch('/chat-risk-alerts/:id', requireAdmin('reports'), async (req, res) => {
  const alertId = v.id(req.params.id, '警示編號');
  const actions = Object.keys(chatRisk.ACTIONS);
  const action = v.oneOf(req.body.action, actions, `action 僅接受：${actions.join(', ')}`);
  const data = await chatRisk.handle(alertId, action, req.user.userId);
  res.status(200).json({ success: true, message: '警示已處理', data });
});

router.get('/disputes', requireAdmin('transactions'), async (req, res) => {
  const status = req.query.status ? v.oneOf(req.query.status, DISPUTE_STATUSES, '不支援的爭議狀態') : null;
  res.status(200).json({ success: true, data: await disputes.adminList(status) });
});

const assistLimiter = rateLimit({ windowMs: 10 * 60 * 1000, max: 30, key: byUser, message: 'AI 分析次數過多，請稍後再試' });

router.post('/disputes/:id/ai-analysis', requireAdmin('transactions'), assistLimiter, async (req, res) => {
  const disputeId = v.id(req.params.id, '爭議編號');
  res.status(200).json({ success: true, data: await disputeAssist.analyze(disputeId, req.user.userId) });
});

router.patch('/disputes/:id', requireAdmin('transactions'), async (req, res) => {
  const disputeId = v.id(req.params.id, '爭議編號');
  const result = v.oneOf(req.body.result, disputes.RESULTS, `result 僅接受：${disputes.RESULTS.join(', ')}`);
  const adminNote = v.optionalText(req.body.admin_note, { label: '處理備註', max: 2000 }) ?? null;

  const updated = await disputes.resolve(disputeId, { result, adminNote }, actorOf(req));
  res.status(200).json({ success: true, message: '爭議已裁決', data: updated });
});

module.exports = router;
