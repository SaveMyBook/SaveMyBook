const express = require('express');
const requireAdmin = require('../../middleware/requireAdmin');
const v = require('../../lib/validate');
const { actorOf } = require('../../lib/request-context');
const { badRequest } = require('../../lib/errors');
const { SLOT_STATUSES } = require('../../constants/domain');
const cabinets = require('../../services/cabinets');

const router = express.Router();
const canManage = requireAdmin('cabinets');

const MAX_SLOTS = 200;
const TIME_RE = /^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/;

const time = (value, label) => {
  if (v.isBlank(value)) return null;
  if (typeof value !== 'string' || !TIME_RE.test(value)) throw badRequest(`${label}格式應為 HH:MM`);
  return new Date(`1970-01-01T${value.length === 5 ? `${value}:00` : value}Z`);
};

const name = (value) => v.text(value, { label: '書櫃名稱', max: 100 });
const address = (value) => v.text(value, { label: '地址', max: 500 });
const latitude = (value) => v.number(value, { label: '緯度', min: -90, max: 90 });
const longitude = (value) => v.number(value, { label: '經度', min: -180, max: 180 });

router.get('/cabinets', canManage, async (req, res) => {
  res.status(200).json({ success: true, data: await cabinets.adminList() });
});

router.post('/cabinets', canManage, async (req, res) => {
  const body = req.body;
  if (!body.cabinet_name || !body.address || body.latitude === undefined || body.longitude === undefined) {
    throw badRequest('請填寫書櫃名稱、地址與座標');
  }

  const cabinetName = name(body.cabinet_name);
  const addr = address(body.address);
  if (!cabinetName || !addr) throw badRequest('請填寫書櫃名稱、地址與座標');

  const slots = v.isBlank(body.total_slots) ? 20 : v.int(body.total_slots, { label: '櫃位數', min: 1, max: MAX_SLOTS });

  const cabinet = await cabinets.create({
    cabinet_name: cabinetName,
    address: addr,
    latitude: latitude(body.latitude),
    longitude: longitude(body.longitude),
    total_slots: slots,
    available_slots: slots,
    open_time: time(body.open_time, '開始營業時間'),
    close_time: time(body.close_time, '結束營業時間')
  }, actorOf(req));
  res.status(201).json({ success: true, message: '書櫃已新增', data: cabinet });
});

router.put('/cabinets/:id', canManage, async (req, res) => {
  const cabinetId = v.id(req.params.id, '書櫃編號');
  const body = req.body;

  const data = {
    ...(body.cabinet_name !== undefined && { cabinet_name: name(body.cabinet_name) }),
    ...(body.address !== undefined && { address: address(body.address) }),
    ...(body.latitude !== undefined && { latitude: latitude(body.latitude) }),
    ...(body.longitude !== undefined && { longitude: longitude(body.longitude) }),
    ...(body.is_active !== undefined && { is_active: v.bool(body.is_active) }),
    ...(body.open_time !== undefined && { open_time: time(body.open_time, '開始營業時間') }),
    ...(body.close_time !== undefined && { close_time: time(body.close_time, '結束營業時間') })
  };
  if (data.cabinet_name === '' || data.address === '') throw badRequest('書櫃名稱與地址不可為空');

  const cabinet = await cabinets.update(cabinetId, data, actorOf(req));
  res.status(200).json({ success: true, message: '書櫃已更新', data: cabinet });
});

router.patch('/cabinets/:id/maintenance', canManage, async (req, res) => {
  const cabinetId = v.id(req.params.id, '書櫃編號');
  if (req.body.is_maintenance === undefined) throw badRequest('請提供 is_maintenance');
  const on = v.bool(req.body.is_maintenance);

  const data = await cabinets.setMaintenance(cabinetId, on, actorOf(req));
  res.status(200).json({ success: true, message: on ? '書櫃已設為維修中' : '書櫃已結束維修', data });
});

router.patch('/cabinets/:cabinetId/slots/:slotId', canManage, async (req, res) => {
  const cabinetId = v.id(req.params.cabinetId, '書櫃編號');
  const slotId = v.id(req.params.slotId, '櫃位編號');
  const status = v.oneOf(req.body.status, SLOT_STATUSES, `status 僅接受：${SLOT_STATUSES.join(', ')}`);

  const slot = await cabinets.setSlotStatus(cabinetId, slotId, status, actorOf(req));
  res.status(200).json({ success: true, message: '櫃位狀態已更新', data: slot });
});

module.exports = router;
