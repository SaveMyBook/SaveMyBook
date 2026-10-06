const prisma = require('../lib/prisma');
const publicId = require('../lib/public-id');
const { env } = require('../config/env');
const { HttpError, notFound } = require('../lib/errors');
const audit = require('./audit');
const cabinets = require('./cabinets');
const access = require('./cabinet-access');
const doors = require('./cabinet-doors');
const devices = require('./cabinet-devices');
const { recordEvent, parseDetail } = require('./cabinet-events');

const IN_CABINET_ORDER = ['deposited', 'pending_pickup'];

const notPaired = () => new HttpError(409, '此書櫃尚未配對裝置', 'DEVICE_NOT_PAIRED');
const doorNotFound = () => new HttpError(404, '找不到此櫃門', 'DOOR_NOT_FOUND');
const assignInvalid = () => new HttpError(409, '此項目不在本書櫃，或已有櫃門紀錄', 'DOOR_ASSIGN_INVALID');

const cabinetOf = async (cabinetId, db = prisma) => {
  const cabinet = await db.smart_cabinets.findUnique({ where: { cabinet_id: Number(cabinetId) } });
  if (!cabinet) throw notFound('找不到該書櫃');
  return cabinet;
};

const doorOf = async (cabinetId, slotId, db = prisma) => {
  const slot = await db.cabinet_slots.findFirst({
    where: { slot_id: Number(slotId), cabinet_id: Number(cabinetId), lock_channel: { not: null } }
  });
  if (!slot) throw doorNotFound();
  return slot;
};

const bookNo = (id) => publicId.encode('book', id);
const orderNoMap = async (orderIds) => {
  const ids = [...new Set(orderIds.filter(Boolean).map(Number))];
  if (ids.length === 0) return new Map();
  const rows = await prisma.orders.findMany({ where: { order_id: { in: ids } }, select: { order_id: true, order_no: true } });
  return new Map(rows.map((r) => [Number(r.order_id), r.order_no]));
};

const unplacedOf = async (cabinetId) => {
  const [deposits, orders] = await Promise.all([
    prisma.book_deposits.findMany({
      where: { cabinet_id: Number(cabinetId) },
      include: { books: { select: { book_id: true, title: true } } }
    }),
    prisma.orders.findMany({
      where: { cabinet_id: Number(cabinetId), status: { in: IN_CABINET_ORDER }, picked_up_at: null },
      select: { order_id: true, order_no: true, order_items: { select: { book_id: true, books: { select: { title: true } } } } }
    })
  ]);
  const entries = [
    ...orders.flatMap((o) => o.order_items.map((i) => ({
      kind: 'order', order_id: Number(o.order_id), order_no: o.order_no, book_id: Number(i.book_id), title: i.books?.title ?? ''
    }))),
    ...deposits.map((d) => ({
      kind: 'deposit', order_id: null, order_no: null, book_id: Number(d.book_id), title: d.books?.title ?? ''
    }))
  ];
  if (entries.length === 0) return [];
  const placed = await prisma.cabinet_slot_items.findMany({
    where: { book_id: { in: entries.map((e) => e.book_id) } }, select: { book_id: true }
  });
  const placedIds = new Set(placed.map((p) => Number(p.book_id)));
  const seen = new Set();
  return entries.filter((e) => {
    if (placedIds.has(e.book_id) || seen.has(e.book_id)) return false;
    seen.add(e.book_id);
    return true;
  }).map((e) => ({ ...e, book_no: bookNo(e.book_id) }));
};

const candidatesOf = async (slots) => {
  const checked = slots.filter((s) => s.check_required_at && s.check_session_id);
  const map = new Map();
  if (checked.length === 0) return map;
  const items = await prisma.cabinet_session_items.findMany({
    where: {
      session_id: { in: [...new Set(checked.map((s) => Number(s.check_session_id)))] },
      slot_id: { in: checked.map((s) => Number(s.slot_id)) }
    },
    include: { books: { select: { title: true } } },
    orderBy: { item_id: 'asc' }
  });
  const placed = items.length
    ? new Set((await prisma.cabinet_slot_items.findMany({
        where: { book_id: { in: items.map((i) => i.book_id) } }, select: { book_id: true }
      })).map((p) => Number(p.book_id)))
    : new Set();
  for (const slot of checked) {
    const seen = new Set();
    const list = [];
    for (const item of items) {
      const bookId = Number(item.book_id);
      if (Number(item.session_id) !== Number(slot.check_session_id) || Number(item.slot_id) !== Number(slot.slot_id)) continue;
      if (placed.has(bookId) || seen.has(bookId)) continue;
      seen.add(bookId);
      list.push({ book_id: bookId, book_no: bookNo(bookId), title: item.books?.title ?? '', kind: item.kind, order_id: item.order_id ?? null });
    }
    map.set(Number(slot.slot_id), list);
  }
  return map;
};

const shapeDoors = async (slots) => {
  if (slots.length === 0) return [];
  const items = await prisma.cabinet_slot_items.findMany({
    where: { slot_id: { in: slots.map((s) => Number(s.slot_id)) } },
    include: { books: { select: { title: true, users: { select: { nickname: true } } } } },
    orderBy: { placed_at: 'asc' }
  });
  const [units, candidates] = await Promise.all([doors.custodyUnits(items.map((i) => i.book_id)), candidatesOf(slots)]);
  const orderNos = await orderNoMap([...units.values()].map((u) => u.order_id));

  return slots.map((slot) => {
    const id = Number(slot.slot_id);
    return {
      slot_id: id,
      slot_no: publicId.encode('cabinet_slot', id),
      label: doors.labelOf(slot),
      channel: slot.lock_channel,
      status: slot.status,
      fault_code: slot.fault_code ?? null,
      sensor: slot.sensor_state ?? null,
      check: slot.check_required_at
        ? {
            at: slot.check_required_at,
            reason: slot.check_reason ?? null,
            session_no: slot.check_session_id ? publicId.encode('cabinet_session', slot.check_session_id) : null,
            candidates: candidates.get(id) ?? []
          }
        : null,
      items: items.filter((i) => Number(i.slot_id) === id).map((i) => {
        const unit = units.get(Number(i.book_id));
        const orderId = unit?.order_id ?? null;
        return {
          kind: unit?.kind ?? 'other',
          book_id: Number(i.book_id),
          book_no: bookNo(i.book_id),
          title: i.books?.title ?? '',
          order_id: orderId,
          order_no: orderId ? orderNos.get(orderId) ?? null : null,
          seller_nickname: i.books?.users?.nickname ?? null,
          placed_at: i.placed_at
        };
      })
    };
  });
};

const kioskUrl = (req) => {
  if (!access.isSimulatorEnabled()) return null;
  const origin = env.publicWebUrl || (req ? `${req.protocol}://${req.get('host')}` : '');
  return `${origin}/kiosk`;
};

const summary = async (cabinetId, { req = null, now = new Date() } = {}) => {
  const cabinet = await cabinetOf(cabinetId);
  const id = Number(cabinet.cabinet_id);
  const [maintenance, accessMap, rows, slots, unplaced, pending] = await Promise.all([
    cabinets.isUnderMaintenance(id),
    access.accessFor([id], now),
    prisma.cabinet_devices.findMany({ where: { cabinet_id: id, status: 'active' } }),
    doors.doorsOf(id),
    unplacedOf(id),
    prisma.cabinet_pair_requests.findFirst({
      where: { cabinet_id: id, delivered_at: null, expires_at: { gt: now } }, orderBy: { claimed_at: 'desc' }
    })
  ]);
  const state = accessMap.get(id);
  const active = rows.find(access.isUsableDevice) ?? null;
  const hours = access.hoursOf(cabinet);

  return {
    cabinet: {
      cabinet_id: id,
      cabinet_name: cabinet.cabinet_name,
      is_active: Boolean(cabinet.is_active),
      is_maintenance: maintenance,
      open_time: hours.open_time,
      close_time: hours.close_time,
      screen_brightness: devices.brightnessOf(cabinet)
    },
    access: { mode: state.mode, reason: state.reason, online: state.online, open_now: state.open_now },
    simulator_enabled: access.isSimulatorEnabled(),
    kiosk_url: kioskUrl(req),
    device: active
      ? {
          device_no: devices.deviceNo(active),
          kind: active.kind,
          status: active.status,
          online: access.isOnline(active, now),
          last_seen_at: active.last_seen_at ?? null,
          paired_at: active.paired_at ?? null,
          firmware: active.firmware ?? null,
          door_count: Number(active.door_count),
          has_door_sensor: Boolean(active.has_door_sensor),
          unlock_pulse_ms: Number(active.unlock_pulse_ms),
          fault_code: active.fault_code ?? null
        }
      : null,
    pairing: pending
      ? {
          kind: pending.kind,
          door_count: Number(pending.door_count),
          has_door_sensor: Boolean(pending.has_door_sensor),
          firmware: pending.firmware,
          expires_at: pending.expires_at
        }
      : null,
    active_session_no: active?.active_session_id ? publicId.encode('cabinet_session', active.active_session_id) : null,
    doors: await shapeDoors(slots),
    unplaced
  };
};

const doorSummary = async (slotId) => {
  const slot = await prisma.cabinet_slots.findUnique({ where: { slot_id: Number(slotId) } });
  return (await shapeDoors([slot]))[0];
};

const pairDevice = async (cabinetId, { code }, { adminId, req }) => {
  const { cabinet, device } = await devices.claimPairing({ cabinetId, code, adminId });
  await audit.record(null, {
    adminId,
    action: '配對書櫃裝置',
    targetType: 'cabinet',
    targetId: Number(cabinet.cabinet_id),
    summary: `為「${cabinet.cabinet_name}」配對${devices.KIND_LABELS[device.kind]}（${device.door_count} 扇櫃門，韌體 ${device.firmware}）`,
    req
  });
  return {
    kind: device.kind,
    door_count: Number(device.door_count),
    has_door_sensor: Boolean(device.has_door_sensor),
    firmware: device.firmware,
    summary: await summary(cabinet.cabinet_id, { req })
  };
};

const revokeDevice = async (cabinetId, { reason = null }, { adminId, req }) => {
  const cabinet = await cabinetOf(cabinetId);
  const id = Number(cabinet.cabinet_id);
  const rows = await prisma.cabinet_devices.findMany({ where: { cabinet_id: id, status: { in: ['active', 'pending'] } } });
  if (rows.length === 0) throw notPaired();
  const now = new Date();

  const revoked = await prisma.$transaction(async (tx) => {
    const done = [];
    for (const device of rows.filter((d) => d.status === 'active')) {
      if (await devices.revoke(tx, device, { reason: 'admin', actorId: adminId, note: reason, now, source: 'admin' })) {
        done.push(devices.deviceNo(device));
      }
    }
    await tx.cabinet_devices.deleteMany({ where: { cabinet_id: id, status: 'pending' } });
    await tx.cabinet_pair_requests.deleteMany({ where: { cabinet_id: id, delivered_at: null } });
    await audit.record(tx, {
      adminId,
      action: '撤銷書櫃裝置',
      targetType: 'cabinet',
      targetId: id,
      summary: `撤銷「${cabinet.cabinet_name}」的${done.length ? `裝置 ${done.join('、')}` : '待完成的配對'}${reason ? `，原因：${reason}` : ''}`,
      req
    });
    return done;
  });
  return { cabinet_id: id, revoked };
};

const TYPE_RE = /^[a-z_]{1,32}$/;

const listEvents = async (cabinetId, { type = null, skip, limit }) => {
  const cabinet = await cabinetOf(cabinetId);
  const where = { cabinet_id: Number(cabinet.cabinet_id), ...(type && TYPE_RE.test(type) ? { type } : {}) };
  const [rows, total] = await Promise.all([
    prisma.cabinet_events.findMany({ where, orderBy: [{ occurred_at: 'desc' }, { event_id: 'desc' }], skip, take: limit }),
    prisma.cabinet_events.count({ where })
  ]);
  const actorIds = [...new Set(rows.map((r) => r.actor_id).filter(Boolean).map(Number))];
  const actors = actorIds.length
    ? new Map((await prisma.users.findMany({ where: { user_id: { in: actorIds } }, select: { user_id: true, nickname: true } }))
        .map((u) => [Number(u.user_id), u]))
    : new Map();
  const orderNos = await orderNoMap(rows.map((r) => r.order_id));

  return {
    total,
    rows: rows.map((r) => {
      const actor = r.actor_id ? actors.get(Number(r.actor_id)) : null;
      return {
        type: r.type,
        source: r.source,
        channel: r.lock_channel ?? null,
        label: r.lock_channel ? doors.doorLabel(r.lock_channel) : null,
        device_no: r.device_id ? publicId.encode('cabinet_device', r.device_id) : null,
        session_no: r.session_id ? publicId.encode('cabinet_session', r.session_id) : null,
        order_id: r.order_id ?? null,
        order_no: r.order_id ? orderNos.get(Number(r.order_id)) ?? null : null,
        book_id: r.book_id ?? null,
        book_no: r.book_id ? bookNo(r.book_id) : null,
        actor: actor ? { user_no: publicId.encode('user', actor.user_id), nickname: actor.nickname } : null,
        detail: parseDetail(r.detail),
        result: r.result ?? null,
        occurred_at: r.occurred_at,
        received_at: r.received_at
      };
    })
  };
};

const placeTargets = async (cabinetId, slot, { orderId, bookIds }) => {
  const [unplaced, candidates] = await Promise.all([unplacedOf(cabinetId), candidatesOf([slot])]);
  const eligible = new Map();
  for (const entry of unplaced) eligible.set(entry.book_id, entry);
  for (const entry of candidates.get(Number(slot.slot_id)) ?? []) if (!eligible.has(entry.book_id)) eligible.set(entry.book_id, entry);

  if (orderId) {
    const items = await prisma.order_items.findMany({
      where: { order_id: Number(orderId) }, select: { book_id: true }, orderBy: { item_id: 'asc' }
    });
    const targets = items.map((i) => Number(i.book_id)).filter((id) => eligible.has(id));
    if (targets.length === 0) throw assignInvalid();
    return targets;
  }
  const targets = [...new Set(bookIds.map(Number))];
  if (targets.length === 0 || targets.some((id) => !eligible.has(id))) throw assignInvalid();
  return targets;
};

const place = async (cabinetId, slotId, { orderId = null, bookIds = [] }, { adminId, req }) => {
  const cabinet = await cabinetOf(cabinetId);
  const slot = await doorOf(cabinet.cabinet_id, slotId);
  const targets = await placeTargets(cabinet.cabinet_id, slot, { orderId, bookIds });

  const existing = await doors.booksInSlot(prisma, slot.slot_id);
  if (targets.length > 1 || existing.some((id) => !targets.includes(id))) throw doors.singleBookDoor();

  const now = new Date();
  const label = doors.labelOf(slot);
  const titles = await prisma.books.findMany({ where: { book_id: { in: targets } }, select: { book_id: true, title: true } });
  await prisma.$transaction(async (tx) => {
    await doors.placeBooks(tx, {
      cabinetId: cabinet.cabinet_id, slotId: slot.slot_id, bookIds: targets, sessionId: null, source: 'admin', now
    });
    await recordEvent(tx, {
      cabinetId: cabinet.cabinet_id,
      type: 'door_placed',
      channel: slot.lock_channel,
      orderId: orderId ?? null,
      bookId: targets.length === 1 ? targets[0] : null,
      source: 'admin',
      actorId: adminId,
      detail: { label, book_ids: targets, order_id: orderId ?? null },
      occurredAt: now
    });
    await doors.clearCheck(tx, slot.slot_id, { actorId: adminId, mode: 'place', now });
    await audit.record(tx, {
      adminId,
      action: '登記書櫃櫃門存放內容',
      targetType: 'cabinet',
      targetId: Number(cabinet.cabinet_id),
      summary: `登記「${cabinet.cabinet_name}」櫃門 ${label} 存放${titles.map((b) => `《${b.title}》`).join('、')}`,
      req
    });
  });
  return doorSummary(slot.slot_id);
};

const checkClear = async (cabinetId, slotId, { note = null }, { adminId, req }) => {
  const cabinet = await cabinetOf(cabinetId);
  const slot = await doorOf(cabinet.cabinet_id, slotId);
  if (slot.check_required_at) {
    const now = new Date();
    await prisma.$transaction(async (tx) => {
      if (!(await doors.clearCheck(tx, slot.slot_id, { actorId: adminId, note, mode: 'confirm', now }))) return;
      await audit.record(tx, {
        adminId,
        action: '確認書櫃櫃門內容',
        targetType: 'cabinet',
        targetId: Number(cabinet.cabinet_id),
        summary: `確認「${cabinet.cabinet_name}」櫃門 ${doors.labelOf(slot)} 的存放內容與紀錄相符${note ? `（${note}）` : ''}`,
        req
      });
    });
  }
  return doorSummary(slot.slot_id);
};

const clearDoorFault = async (cabinetId, slotId, { adminId, req }) => {
  const cabinet = await cabinetOf(cabinetId);
  const slot = await doorOf(cabinet.cabinet_id, slotId);
  if (slot.fault_code) {
    const now = new Date();
    await prisma.$transaction(async (tx) => {
      const cleared = await tx.cabinet_slots.updateMany({
        where: { slot_id: slot.slot_id, fault_code: slot.fault_code },
        data: { fault_code: null, updated_at: now }
      });
      if (cleared.count === 0) return;
      await doors.recountAvailable(tx, cabinet.cabinet_id);
      await recordEvent(tx, {
        cabinetId: cabinet.cabinet_id, type: 'fault_cleared', channel: slot.lock_channel, source: 'admin', actorId: adminId,
        detail: { code: slot.fault_code, label: doors.labelOf(slot) }, occurredAt: now
      });
      await audit.record(tx, {
        adminId,
        action: '清除書櫃櫃門故障',
        targetType: 'cabinet',
        targetId: Number(cabinet.cabinet_id),
        summary: `清除「${cabinet.cabinet_name}」櫃門 ${doors.labelOf(slot)} 的故障紀錄（${devices.faultLabel(slot.fault_code)}）`,
        req
      });
    });
  }
  return doorSummary(slot.slot_id);
};

const clearDeviceFault = async (cabinetId, { adminId, req }) => {
  const cabinet = await cabinetOf(cabinetId);
  const device = await prisma.cabinet_devices.findFirst({ where: { cabinet_id: cabinet.cabinet_id, status: 'active' } });
  if (!device) throw notPaired();
  if (device.fault_code) {
    const now = new Date();
    await prisma.$transaction(async (tx) => {
      const cleared = await tx.cabinet_devices.updateMany({
        where: { device_id: device.device_id, fault_code: device.fault_code },
        data: { fault_code: null, fault_since: null, updated_at: now }
      });
      if (cleared.count === 0) return;
      await recordEvent(tx, {
        cabinetId: cabinet.cabinet_id, deviceId: device.device_id, type: 'fault_cleared', source: 'admin', actorId: adminId,
        detail: { code: device.fault_code }, occurredAt: now
      });
      await audit.record(tx, {
        adminId,
        action: '清除書櫃裝置故障',
        targetType: 'cabinet',
        targetId: Number(cabinet.cabinet_id),
        summary: `清除「${cabinet.cabinet_name}」書櫃裝置的故障紀錄（${devices.faultLabel(device.fault_code)}）`,
        req
      });
    });
  }
  return { device_no: devices.deviceNo(device), fault_code: null };
};

// 書櫃螢幕亮度存在書櫃上：重新配對裝置後沿用，裝置於下一次 GET /state 取得。
const updateScreenSettings = async (cabinetId, { screenBrightness }, { adminId, req }) => {
  const cabinet = await cabinetOf(cabinetId);
  const before = devices.brightnessOf(cabinet);
  if (before !== screenBrightness) {
    await prisma.$transaction(async (tx) => {
      await tx.smart_cabinets.update({
        where: { cabinet_id: cabinet.cabinet_id },
        data: { screen_brightness: screenBrightness, updated_at: new Date() }
      });
      await audit.record(tx, {
        adminId,
        action: '調整書櫃螢幕亮度',
        targetType: 'cabinet',
        targetId: Number(cabinet.cabinet_id),
        summary: `將「${cabinet.cabinet_name}」書櫃螢幕亮度由 ${before}% 調整為 ${screenBrightness}%`,
        req
      });
    });
  }
  return { screen_brightness: screenBrightness };
};

module.exports = {
  summary, pairDevice, revokeDevice, listEvents, place, checkClear, clearDoorFault, clearDeviceFault, updateScreenSettings,
  unplacedOf, shapeDoors
};
