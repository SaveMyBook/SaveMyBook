const express = require('express');
const requireAdmin = require('../../middleware/requireAdmin');
const { requireVerification } = require('../../middleware/verification');
const v = require('../../lib/validate');
const { actorOf } = require('../../lib/request-context');
const { badRequest } = require('../../lib/errors');
const devices = require('../../services/cabinet-devices');
const admin = require('../../services/cabinet-admin');

const router = express.Router();
const canManage = requireAdmin('cabinets');

const MAX_PLACE_BOOKS = 50;

const cabinetIdOf = (req) => v.id(req.params.id, '書櫃編號');
const slotIdOf = (req) => v.id(req.params.slotId, '櫃門編號');

router.get('/cabinets/:id/device', canManage, async (req, res) => {
  res.status(200).json({ success: true, data: await admin.summary(cabinetIdOf(req), { req }) });
});

router.post('/cabinets/:id/device/pairing-code', canManage, requireVerification('admin'), async (req, res) => {
  const cabinetId = cabinetIdOf(req);
  const kind = v.oneOf(req.body.kind, devices.KINDS, `kind 僅接受：${devices.KINDS.join(', ')}`);
  const doorCount = v.isBlank(req.body.door_count) ? 4 : v.int(req.body.door_count, { label: '櫃門數', min: 1, max: 8 });
  const data = await admin.createPairingCode(cabinetId, { kind, doorCount }, actorOf(req));
  res.status(201).json({ success: true, message: '配對碼已產生', data });
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
  if (hasBooks && bookIdsRaw.length > MAX_PLACE_BOOKS) throw badRequest(`書籍最多 ${MAX_PLACE_BOOKS} 本`);

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
