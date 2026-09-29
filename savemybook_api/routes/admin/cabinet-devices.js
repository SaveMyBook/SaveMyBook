const express = require('express');
const requireAdmin = require('../../middleware/requireAdmin');
const { requireVerification } = require('../../middleware/verification');
const { rateLimit, byUser } = require('../../middleware/rateLimit');
const v = require('../../lib/validate');
const { actorOf } = require('../../lib/request-context');
const { badRequest } = require('../../lib/errors');
const admin = require('../../services/cabinet-admin');
const doors = require('../../services/cabinet-doors');

const router = express.Router();
const canManage = requireAdmin('cabinets');
const pairLimit = rateLimit({ windowMs: 10 * 60 * 1000, max: 10, key: byUser, message: '嘗試次數過多，請稍後再試' });

const cabinetIdOf = (req) => v.id(req.params.id, '書櫃編號');
const slotIdOf = (req) => v.id(req.params.slotId, '櫃門編號');

router.get('/cabinets/:id/device', canManage, async (req, res) => {
  res.status(200).json({ success: true, data: await admin.summary(cabinetIdOf(req), { req }) });
});

router.post('/cabinets/:id/device/pair', canManage, pairLimit, requireVerification('admin'), async (req, res) => {
  const data = await admin.pairDevice(cabinetIdOf(req), { code: req.body.code }, actorOf(req));
  res.status(201).json({ success: true, message: '已送出配對，裝置連線後即完成', data });
});

router.delete('/cabinets/:id/device', canManage, async (req, res) => {
  const reason = v.optionalText(req.body.reason, { label: '撤銷原因', max: 255 }) ?? null;
  const data = await admin.revokeDevice(cabinetIdOf(req), { reason }, actorOf(req));
  res.status(200).json({ success: true, message: '書櫃裝置已撤銷', data });
});

router.post('/cabinets/:id/device/fault-clear', canManage, async (req, res) => {
  const data = await admin.clearDeviceFault(cabinetIdOf(req), actorOf(req));
  res.status(200).json({ success: true, message: '裝置故障紀錄已清除', data });
});

router.get('/cabinets/:id/events', canManage, async (req, res) => {
  const { page, limit, skip } = v.pagination(req.query);
  const type = typeof req.query.type === 'string' && req.query.type ? req.query.type.slice(0, 32) : null;
  const { total, rows } = await admin.listEvents(cabinetIdOf(req), { type, skip, limit });
  res.status(200).json({ success: true, pagination: v.pageMeta(total, { page, limit }), data: rows });
});

router.post('/cabinets/:id/doors/:slotId/place', canManage, async (req, res) => {
  const cabinetId = cabinetIdOf(req);
  const slotId = slotIdOf(req);
  const { order_id: orderIdRaw, book_ids: bookIdsRaw } = req.body;
  const hasOrder = !v.isBlank(orderIdRaw);
  const hasBooks = Array.isArray(bookIdsRaw) && bookIdsRaw.length > 0;
  if (hasOrder === hasBooks) throw badRequest('請擇一提供訂單編號或書籍編號');
  if (hasBooks && bookIdsRaw.length > 1) throw doors.singleBookDoor();

  const data = await admin.place(cabinetId, slotId, {
    orderId: hasOrder ? v.id(orderIdRaw, '訂單編號') : null,
    bookIds: hasBooks ? bookIdsRaw.map((id) => v.id(id, '書籍編號')) : []
  }, actorOf(req));
  res.status(200).json({ success: true, message: '已登記櫃門存放內容', data });
});

router.post('/cabinets/:id/doors/:slotId/check-clear', canManage, async (req, res) => {
  const note = v.optionalText(req.body.note, { label: '備註', max: 255 }) ?? null;
  const data = await admin.checkClear(cabinetIdOf(req), slotIdOf(req), { note }, actorOf(req));
  res.status(200).json({ success: true, message: '已確認櫃門內容', data });
});

router.post('/cabinets/:id/doors/:slotId/fault-clear', canManage, async (req, res) => {
  const data = await admin.clearDoorFault(cabinetIdOf(req), slotIdOf(req), actorOf(req));
  res.status(200).json({ success: true, message: '櫃門故障紀錄已清除', data });
});

module.exports = router;
