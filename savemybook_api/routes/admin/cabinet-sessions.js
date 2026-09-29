const express = require('express');
const requireAdmin = require('../../middleware/requireAdmin');
const { requireVerification } = require('../../middleware/verification');
const { rateLimit, byUser } = require('../../middleware/rateLimit');
const v = require('../../lib/validate');
const { actorOf } = require('../../lib/request-context');
const { badRequest } = require('../../lib/errors');
const sessions = require('../../services/cabinet-sessions');
const manual = require('../../services/cabinet-manual');

const router = express.Router();
const canManage = requireAdmin('cabinets');
const openLimit = rateLimit({ windowMs: 10 * 60 * 1000, max: 10, key: byUser });

const cabinetIdOf = (req) => v.id(req.params.id, '書櫃編號');
const slotIdOf = (req) => v.id(req.params.slotId, '櫃門編號');

const requiredText = (value, label, max) => {
  const s = v.text(value, { label, max });
  if (!s) throw badRequest(`請填寫${label}`);
  return s;
};

router.post('/cabinets/:id/doors/:slotId/open', canManage, openLimit, requireVerification('admin'), async (req, res) => {
  const reason = requiredText(req.body.reason, '開啟原因', 255);
  const force = req.body.force === undefined ? false : v.bool(req.body.force);
  const data = await sessions.adminOpen(cabinetIdOf(req), slotIdOf(req), { reason, force }, actorOf(req));
  res.status(201).json({ success: true, message: force ? '已送出開門指令' : '請輸入書櫃螢幕上顯示的數字', data });
});

router.post('/cabinets/:id/doors/:slotId/clear', canManage, async (req, res) => {
  const mode = v.oneOf(req.body.mode, ['removed', 'correct'], '清空方式不正確');
  const reason = requiredText(req.body.reason, '原因', 255);
  const data = await sessions.clearDoor(cabinetIdOf(req), slotIdOf(req), { mode, reason }, actorOf(req));
  res.status(200).json({ success: true, message: '已清空櫃門存放紀錄', data });
});

router.get('/cabinets/:id/sessions', canManage, async (req, res) => {
  const { page, limit, skip } = v.pagination(req.query);
  const status = typeof req.query.status === 'string' && req.query.status ? req.query.status.slice(0, 20) : null;
  const { total, rows } = await sessions.listSessions(cabinetIdOf(req), { status, skip, limit });
  res.status(200).json({ success: true, pagination: v.pageMeta(total, { page, limit }), data: rows });
});

router.get('/cabinet-sessions/:sessionNo', canManage, async (req, res) => {
  res.set('Cache-Control', 'no-store');
  res.status(200).json({ success: true, data: await sessions.adminDetail(req.params.sessionNo) });
});

router.post('/cabinet-sessions/:sessionNo/match', canManage, async (req, res) => {
  const data = await sessions.adminMatch(req.params.sessionNo, req.body.code, actorOf(req));
  res.status(200).json({ success: true, data });
});

router.post('/cabinet-sessions/:sessionNo/close', canManage, async (req, res) => {
  const { requested, detail } = await sessions.adminClose(req.params.sessionNo, actorOf(req));
  res.status(200).json({ success: true, message: requested ? '已要求書櫃結束作業' : '此作業已結束', data: detail });
});

router.post('/cabinet-sessions/:sessionNo/resolve', canManage, async (req, res) => {
  const action = v.oneOf(req.body.action, ['commit', 'discard'], '處理方式不正確');
  const note = requiredText(req.body.note, '處理說明', 500);
  const data = await sessions.resolve(req.params.sessionNo, { action, note }, actorOf(req));
  res.status(200).json({ success: true, message: '書櫃作業已處理', data });
});

router.get('/cabinets/:id/manual-reports', canManage, async (req, res) => {
  const { page, limit, skip } = v.pagination(req.query);
  const status = typeof req.query.status === 'string' ? req.query.status : 'pending';
  const { total, rows } = await manual.listForCabinet(cabinetIdOf(req), { status, skip, limit });
  res.status(200).json({ success: true, pagination: v.pageMeta(total, { page, limit }), data: rows });
});

const MAX_DOOR_ASSIGNMENTS = 50;

const doorAssignments = (value) => {
  if (value === undefined || value === null) return [];
  if (!Array.isArray(value) || value.length > MAX_DOOR_ASSIGNMENTS) throw badRequest('櫃門指定格式不正確');
  return value.map((entry) => {
    if (!entry || typeof entry !== 'object') throw badRequest('櫃門指定格式不正確');
    return { bookId: v.id(entry.book_id, '書籍編號'), slotId: v.id(entry.slot_id, '櫃門編號') };
  });
};

router.post('/cabinet-manual-reports/:reportNo/confirm', canManage, async (req, res) => {
  const note = v.optionalText(req.body.note, { label: '處理說明', max: 500 }) ?? null;
  const slotId = req.body.slot_id === undefined || req.body.slot_id === null ? null : v.id(req.body.slot_id, '櫃門編號');
  const doors = doorAssignments(req.body.doors);
  if (slotId && doors.length > 0) throw badRequest('請擇一提供櫃門編號或逐本櫃門指定');
  const data = await manual.confirm(req.params.reportNo, { note, slotId, doors }, actorOf(req));
  res.status(200).json({ success: true, message: '已確認手動回報', data });
});

router.post('/cabinet-manual-reports/:reportNo/reject', canManage, async (req, res) => {
  const note = requiredText(req.body.note, '處理說明', 500);
  const data = await manual.reject(req.params.reportNo, { note }, actorOf(req));
  res.status(200).json({ success: true, message: '已駁回手動回報', data });
});

module.exports = router;
