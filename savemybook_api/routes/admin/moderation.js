const express = require('express');
const requireAdmin = require('../../middleware/requireAdmin');
const v = require('../../lib/validate');
const { actorOf } = require('../../lib/request-context');
const { REPORT_STATUSES, DISPUTE_STATUSES } = require('../../constants/domain');
const reports = require('../../services/reports');
const disputes = require('../../services/disputes');

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

router.get('/disputes', requireAdmin('transactions'), async (req, res) => {
  const status = req.query.status ? v.oneOf(req.query.status, DISPUTE_STATUSES, '不支援的爭議狀態') : null;
  res.status(200).json({ success: true, data: await disputes.adminList(status) });
});

router.patch('/disputes/:id', requireAdmin('transactions'), async (req, res) => {
  const disputeId = v.id(req.params.id, '爭議編號');
  const result = v.oneOf(req.body.result, disputes.RESULTS, `result 僅接受：${disputes.RESULTS.join(', ')}`);
  const adminNote = v.optionalText(req.body.admin_note, { label: '處理備註', max: 2000 }) ?? null;

  const updated = await disputes.resolve(disputeId, { result, adminNote }, actorOf(req));
  res.status(200).json({ success: true, message: '爭議已裁決', data: updated });
});

module.exports = router;
