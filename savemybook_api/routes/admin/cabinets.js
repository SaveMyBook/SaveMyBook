const express = require('express');
const prisma = require('../../lib/prisma');
const requireAdmin = require('../../middleware/requireAdmin');
const v = require('../../lib/validate');
const { badRequest, notFound, orNotFound } = require('../../lib/errors');
const { SLOT_STATUSES } = require('../../constants/domain');
const { logAction } = require('../../services/audit');

const router = express.Router();
const canManage = requireAdmin('cabinets');

const MAX_SLOTS = 200;
const TIME_RE = /^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/;

/// TIME 欄位在 Prisma 端是 DateTime，只取時間部分。格式不對時 new Date 會得到
/// Invalid Date，寫進資料庫前就要擋下來。
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
  const cabinets = await prisma.smart_cabinets.findMany({
    orderBy: { cabinet_id: 'asc' },
    include: {
      cabinet_slots: { select: { slot_id: true, slot_number: true, status: true, updated_at: true } },
      _count: { select: { orders: true } }
    }
  });

  const data = cabinets.map((c) => {
    const counts = Object.fromEntries(SLOT_STATUSES.map((s) => [s, 0]));
    for (const slot of c.cabinet_slots) counts[slot.status] = (counts[slot.status] ?? 0) + 1;
    return { ...c, slot_summary: counts };
  });

  res.status(200).json({ success: true, data });
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

  const cabinet = await prisma.smart_cabinets.create({
    data: {
      cabinet_name: cabinetName,
      address: addr,
      latitude: latitude(body.latitude),
      longitude: longitude(body.longitude),
      total_slots: slots,
      available_slots: slots,
      open_time: time(body.open_time, '開始營業時間'),
      close_time: time(body.close_time, '結束營業時間'),
      cabinet_slots: {
        create: Array.from({ length: slots }, (_, i) => ({ slot_number: `A${String(i + 1).padStart(2, '0')}` }))
      }
    },
    include: { cabinet_slots: true }
  });

  await logAction(req.user.userId, '新增書櫃', 'cabinet', cabinet.cabinet_id, cabinetName);
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

  const cabinet = await orNotFound(
    prisma.smart_cabinets.update({ where: { cabinet_id: cabinetId }, data: { ...data, updated_at: new Date() } }),
    '找不到該書櫃'
  );

  await logAction(req.user.userId, '修改書櫃', 'cabinet', cabinetId, data.cabinet_name ?? '');
  res.status(200).json({ success: true, message: '書櫃已更新', data: cabinet });
});

router.patch('/cabinets/:cabinetId/slots/:slotId', canManage, async (req, res) => {
  const cabinetId = v.id(req.params.cabinetId, '書櫃編號');
  const slotId = v.id(req.params.slotId, '櫃位編號');
  const status = v.oneOf(req.body.status, SLOT_STATUSES, `status 僅接受：${SLOT_STATUSES.join(', ')}`);

  // 櫃位必須屬於網址上的書櫃，不然改的可能是別台書櫃的格子。
  const owned = await prisma.cabinet_slots.count({ where: { slot_id: slotId, cabinet_id: cabinetId } });
  if (!owned) throw notFound('找不到該櫃位');

  const slot = await prisma.cabinet_slots.update({
    where: { slot_id: slotId },
    data: { status, updated_at: new Date() }
  });

  await logAction(req.user.userId, '變更櫃位狀態', 'cabinet_slot', slotId, `${slot.slot_number} -> ${status}`);
  res.status(200).json({ success: true, message: '櫃位狀態已更新', data: slot });
});

module.exports = router;
