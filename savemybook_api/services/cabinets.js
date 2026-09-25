const prisma = require('../lib/prisma');
const { notFound } = require('../lib/errors');
const { SLOT_STATUSES, SLOT_STATUS_LABELS } = require('../constants/domain');
const audit = require('./audit');

const EARTH_RADIUS_M = 6371000;

const toRad = (deg) => (deg * Math.PI) / 180;

const distanceMeters = (lat1, lng1, lat2, lng2) => {
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return Math.round(2 * EARTH_RADIUS_M * Math.asin(Math.min(1, Math.sqrt(a))));
};

const formatTime = (v) => (v instanceof Date ? v.toISOString().slice(11, 16) : String(v).slice(11, 16));

const CABINET_FIELDS = {
  cabinet_name: '名稱',
  address: '地址',
  latitude: '緯度',
  longitude: '經度',
  is_active: { label: '啟用', format: (v) => (v ? '啟用' : '停用') },
  open_time: { label: '開始營業', format: formatTime },
  close_time: { label: '結束營業', format: formatTime }
};

const SLOT_FIELDS = { status: { label: '櫃位狀態', format: (s) => SLOT_STATUS_LABELS[s] ?? s } };

const maintenanceIds = async () => {
  const rows = await prisma.$queryRaw`SELECT cabinet_id FROM smart_cabinets WHERE is_maintenance = 1`;
  return new Set(rows.map((r) => Number(r.cabinet_id)));
};

const isUnderMaintenance = async (cabinetId) => (await maintenanceIds()).has(Number(cabinetId));

// 維修中的書櫃不開放選用，與停用的書櫃一樣不出現在使用者端的清單。
const listActive = async (point) => {
  const [all, underMaintenance] = await Promise.all([prisma.smart_cabinets.findMany({
    where: { is_active: true },
    select: {
      cabinet_id: true,
      cabinet_name: true,
      address: true,
      available_slots: true,
      latitude: true,
      longitude: true,
      open_time: true,
      close_time: true
    },
    orderBy: { cabinet_id: 'asc' }
  }), maintenanceIds()]);
  const cabinets = all.filter((c) => !underMaintenance.has(Number(c.cabinet_id)));

  const data = cabinets.map((c) => ({
    ...c,
    distance_m: point ? distanceMeters(point.lat, point.lng, Number(c.latitude), Number(c.longitude)) : null
  }));
  if (point) data.sort((a, b) => a.distance_m - b.distance_m);
  return data;
};

const adminList = async () => {
  const [cabinets, underMaintenance] = await Promise.all([
    prisma.smart_cabinets.findMany({
      orderBy: { cabinet_id: 'asc' },
      include: {
        cabinet_slots: { select: { slot_id: true, slot_number: true, status: true, updated_at: true } },
        _count: { select: { orders: true } }
      }
    }),
    maintenanceIds()
  ]);

  return cabinets.map((c) => {
    const counts = Object.fromEntries(SLOT_STATUSES.map((s) => [s, 0]));
    for (const slot of c.cabinet_slots) counts[slot.status] = (counts[slot.status] ?? 0) + 1;
    return {
      ...c,
      is_maintenance: underMaintenance.has(Number(c.cabinet_id)),
      slot_summary: counts
    };
  });
};

const create = async (data, { adminId, req }) => {
  const slots = data.total_slots;
  const cabinet = await prisma.smart_cabinets.create({
    data: {
      ...data,
      cabinet_slots: {
        create: Array.from({ length: slots }, (_, i) => ({ slot_number: `A${String(i + 1).padStart(2, '0')}` }))
      }
    },
    include: { cabinet_slots: true }
  });

  // 還原「新增」用停用而非刪除：書櫃可能已被書籍或訂單引用。
  await audit.record(null, {
    adminId,
    action: '新增書櫃',
    targetType: 'cabinet',
    targetId: cabinet.cabinet_id,
    summary: `新增書櫃「${data.cabinet_name}」（${slots} 格），地址：${data.address}`,
    undo: [audit.undoUpdate('smart_cabinets', cabinet.cabinet_id, { is_active: false }, { is_active: true }, ['is_active'])],
    req
  });
  return cabinet;
};

const update = async (cabinetId, data, { adminId, req }) => {
  const before = await prisma.smart_cabinets.findUnique({ where: { cabinet_id: cabinetId } });
  if (!before) throw notFound('找不到該書櫃');

  const cabinet = await prisma.smart_cabinets.update({
    where: { cabinet_id: cabinetId },
    data: { ...data, updated_at: new Date() }
  });

  const changes = audit.diff(before, data, CABINET_FIELDS);
  await audit.record(null, {
    adminId,
    action: '修改書櫃',
    targetType: 'cabinet',
    targetId: cabinetId,
    summary: changes.length
      ? `修改書櫃「${before.cabinet_name}」的${changes.map((c) => c.label).join('、')}`
      : `重新儲存書櫃「${before.cabinet_name}」（無實際變更）`,
    changes,
    undo: changes.length ? [audit.undoUpdate('smart_cabinets', cabinetId, before, data, CABINET_FIELDS)] : null,
    req
  });
  return cabinet;
};

const setMaintenance = async (cabinetId, on, { adminId, req }) => {
  const before = await prisma.smart_cabinets.findUnique({ where: { cabinet_id: cabinetId }, select: { cabinet_name: true } });
  if (!before) throw notFound('找不到該書櫃');

  const wasOn = await isUnderMaintenance(cabinetId);
  if (wasOn !== on) {
    await prisma.$executeRaw`
      UPDATE smart_cabinets SET is_maintenance = ${on ? 1 : 0}, updated_at = ${new Date()} WHERE cabinet_id = ${cabinetId}`;
  }

  const label = (v) => (v ? '維修中' : '正常');
  await audit.record(null, {
    adminId,
    action: on ? '書櫃設為維修中' : '書櫃結束維修',
    targetType: 'cabinet',
    targetId: cabinetId,
    summary: wasOn === on
      ? `重新設定書櫃「${before.cabinet_name}」為${label(on)}（無實際變更）`
      : `將書櫃「${before.cabinet_name}」${on ? '設為維修中，暫停存書與選用' : '結束維修，恢復開放'}`,
    changes: wasOn === on ? [] : [{ field: 'is_maintenance', label: '維修狀態', from: label(wasOn), to: label(on) }],
    req
  });
  return { cabinet_id: cabinetId, is_maintenance: on };
};

const setSlotStatus = async (cabinetId, slotId, status, { adminId, req }) => {
  // 櫃位必須屬於網址上的書櫃，否則可改到別台書櫃的格子。
  const before = await prisma.cabinet_slots.findFirst({
    where: { slot_id: slotId, cabinet_id: cabinetId },
    include: { smart_cabinets: { select: { cabinet_name: true } } }
  });
  if (!before) throw notFound('找不到該櫃位');

  const slot = await prisma.cabinet_slots.update({
    where: { slot_id: slotId },
    data: { status, updated_at: new Date() }
  });

  await audit.record(null, {
    adminId,
    action: '變更櫃位狀態',
    targetType: 'cabinet_slot',
    targetId: slotId,
    summary: `將「${before.smart_cabinets.cabinet_name}」的 ${slot.slot_number} 改為${SLOT_STATUS_LABELS[status]}`,
    changes: audit.diff(before, slot, SLOT_FIELDS),
    undo: before.status === status ? null : [audit.undoUpdate('cabinet_slots', slotId, before, slot, SLOT_FIELDS)],
    req
  });
  return slot;
};

module.exports = { listActive, adminList, create, update, setMaintenance, maintenanceIds, isUnderMaintenance, setSlotStatus };
