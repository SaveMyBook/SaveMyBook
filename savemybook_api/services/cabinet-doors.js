const prisma = require('../lib/prisma');
const { HttpError } = require('../lib/errors');
const policy = require('../constants/policy');
const { ORDER_UNSETTLED_STATUSES } = require('../constants/domain');
const { recordEvent } = require('./cabinet-events');

const OPEN_SESSION_STATUSES = ['matching', 'opening', 'open', 'needs_review'];

const doorLabel = (channel) => `A${String(channel).padStart(2, '0')}`;

const labelOf = (slot) => (slot.lock_channel ? doorLabel(slot.lock_channel) : slot.slot_number);

const isFree = (slot) => slot.status === 'empty' && !slot.fault_code && !slot.check_required_at;

const isUsable = (slot) => slot.status !== 'maintenance' && !slot.fault_code && !slot.check_required_at;

const unique = (values) => [...new Set(values.filter((v) => v !== null && v !== undefined).map(Number))];

const cabinetFull = (available, required) => new HttpError(
  409, '此書櫃可用的櫃門不足，請減少存書項目或稍後再試', 'CABINET_FULL',
  { available_doors: available, required_doors: required }
);

const predepositLimit = () =>
  new HttpError(409, '您在此書櫃的先行存書已達上限，請待售出或取回後再存入', 'PREDEPOSIT_LIMIT');

const doorsOf = (cabinetId, { tx } = {}) => (tx ?? prisma).cabinet_slots.findMany({
  where: { cabinet_id: Number(cabinetId), lock_channel: { not: null } },
  orderBy: { lock_channel: 'asc' }
});

const recountAvailable = async (tx, cabinetId) => {
  const db = tx ?? prisma;
  const doors = await doorsOf(cabinetId, { tx: db });
  if (doors.length === 0) return null;
  const available = doors.filter(isFree).length;
  await db.smart_cabinets.updateMany({ where: { cabinet_id: Number(cabinetId) }, data: { available_slots: available } });
  return available;
};

const refresh = async (tx, slotIds) => {
  const db = tx ?? prisma;
  const ids = unique(slotIds ?? []);
  if (ids.length === 0) return;

  const [slots, items, reserved] = await Promise.all([
    db.cabinet_slots.findMany({ where: { slot_id: { in: ids }, lock_channel: { not: null } } }),
    db.cabinet_slot_items.findMany({ where: { slot_id: { in: ids } }, select: { slot_id: true } }),
    db.cabinet_session_doors.findMany({
      where: { slot_id: { in: ids }, state: { not: 'failed' }, cabinet_sessions: { status: { in: OPEN_SESSION_STATUSES } } },
      select: { slot_id: true }
    })
  ]);
  const occupied = new Set(items.map((i) => Number(i.slot_id)));
  const held = new Set(reserved.map((r) => Number(r.slot_id)));
  const now = new Date();

  for (const slot of slots) {
    const id = Number(slot.slot_id);
    let next = 'empty';
    if (slot.status === 'maintenance') next = 'maintenance';
    else if (occupied.has(id)) next = 'occupied';
    else if (held.has(id)) next = 'reserved';
    if (next !== slot.status) {
      await db.cabinet_slots.updateMany({ where: { slot_id: id }, data: { status: next, updated_at: now } });
    }
  }
  for (const cabinetId of unique(slots.map((s) => s.cabinet_id))) await recountAvailable(db, cabinetId);
};

const syncChannels = async (tx, cabinetId, doorCount) => {
  const db = tx ?? prisma;
  const id = Number(cabinetId);
  const labels = Array.from({ length: doorCount }, (_, i) => doorLabel(i + 1));
  const slots = await db.cabinet_slots.findMany({ where: { cabinet_id: id } });
  const now = new Date();

  // 先清掉不符合的通道再逐一設定，避免 (cabinet_id, lock_channel) 唯一索引在過程中衝突。
  for (const slot of slots) {
    const wanted = labels.indexOf(slot.slot_number) + 1 || null;
    if (slot.lock_channel !== null && slot.lock_channel !== undefined && slot.lock_channel !== wanted) {
      await db.cabinet_slots.updateMany({ where: { slot_id: slot.slot_id }, data: { lock_channel: null, updated_at: now } });
    }
  }

  const doorIds = [];
  for (const [index, label] of labels.entries()) {
    const channel = index + 1;
    const slot = slots.find((s) => s.slot_number === label);
    if (!slot) {
      const created = await db.cabinet_slots.create({
        data: { cabinet_id: id, slot_number: label, status: 'empty', lock_channel: channel, updated_at: now }
      });
      doorIds.push(created.slot_id);
    } else {
      if (slot.lock_channel !== channel) {
        await db.cabinet_slots.updateMany({ where: { slot_id: slot.slot_id }, data: { lock_channel: channel, updated_at: now } });
      }
      doorIds.push(slot.slot_id);
    }
  }

  await db.smart_cabinets.updateMany({ where: { cabinet_id: id }, data: { total_slots: doorCount, updated_at: now } });
  await refresh(db, doorIds);
  await recountAvailable(db, id);
  return doorIds;
};

const bookDoors = async (bookIds, { tx } = {}) => {
  const ids = unique(bookIds ?? []);
  const map = new Map();
  if (ids.length === 0) return map;
  const items = await (tx ?? prisma).cabinet_slot_items.findMany({
    where: { book_id: { in: ids } },
    include: {
      cabinet_slots: {
        select: { slot_id: true, slot_number: true, lock_channel: true, fault_code: true, check_required_at: true }
      }
    }
  });
  for (const item of items) {
    const slot = item.cabinet_slots ?? {};
    map.set(Number(item.book_id), {
      slot_id: Number(item.slot_id),
      cabinet_id: Number(item.cabinet_id),
      channel: slot.lock_channel ?? null,
      label: slot.lock_channel ? doorLabel(slot.lock_channel) : slot.slot_number ?? null,
      fault_code: slot.fault_code ?? null,
      check_required_at: slot.check_required_at ?? null
    });
  }
  return map;
};

const byChannel = (a, b) => (a.channel ?? 999) - (b.channel ?? 999) || a.slot_id - b.slot_id;

const orderDoors = async (orderIds, { tx } = {}) => {
  const ids = unique(orderIds ?? []);
  const map = new Map();
  if (ids.length === 0) return map;
  const db = tx ?? prisma;
  const orders = await db.orders.findMany({
    where: { order_id: { in: ids } },
    select: { order_id: true, cabinet_id: true, order_items: { select: { book_id: true } } }
  });
  const doors = await bookDoors(orders.flatMap((o) => o.order_items.map((i) => i.book_id)), { tx: db });
  for (const order of orders) {
    const seen = new Map();
    for (const item of order.order_items) {
      const door = doors.get(Number(item.book_id));
      if (!door || door.cabinet_id !== Number(order.cabinet_id) || seen.has(door.slot_id)) continue;
      seen.set(door.slot_id, { slot_id: door.slot_id, label: door.label, channel: door.channel });
    }
    map.set(Number(order.order_id), [...seen.values()].sort(byChannel));
  }
  return map;
};

const booksInSlot = async (tx, slotId) => {
  const rows = await (tx ?? prisma).cabinet_slot_items.findMany({
    where: { slot_id: Number(slotId) }, select: { book_id: true }, orderBy: { book_id: 'asc' }
  });
  return rows.map((r) => Number(r.book_id));
};

const custodyUnits = async (bookIds, { tx } = {}) => {
  const ids = unique(bookIds ?? []);
  const map = new Map();
  if (ids.length === 0) return map;
  const db = tx ?? prisma;
  const [books, items, deposits] = await Promise.all([
    db.books.findMany({ where: { book_id: { in: ids } }, select: { book_id: true, seller_id: true } }),
    db.order_items.findMany({
      where: { book_id: { in: ids }, orders: { status: { in: ORDER_UNSETTLED_STATUSES } } },
      select: { book_id: true, order_id: true },
      orderBy: { item_id: 'desc' }
    }),
    db.book_deposits.findMany({ where: { book_id: { in: ids } }, select: { book_id: true } })
  ]);
  const orderOf = new Map();
  for (const item of items) if (!orderOf.has(Number(item.book_id))) orderOf.set(Number(item.book_id), Number(item.order_id));
  const deposited = new Set(deposits.map((d) => Number(d.book_id)));
  for (const book of books) {
    const id = Number(book.book_id);
    if (orderOf.has(id)) map.set(id, { key: `order:${orderOf.get(id)}`, kind: 'order', order_id: orderOf.get(id) });
    else if (deposited.has(id)) map.set(id, { key: `book:${id}`, kind: 'deposit', order_id: null });
    else map.set(id, { key: `seller:${book.seller_id}`, kind: 'other', order_id: null });
  }
  return map;
};

const placeBooks = async (tx, { cabinetId, slotId, bookIds, sessionId = null, source = 'session', now = new Date() }) => {
  const db = tx ?? prisma;
  const ids = unique(bookIds ?? []);
  if (ids.length === 0) return { moved: [] };
  const existing = await db.cabinet_slot_items.findMany({ where: { book_id: { in: ids } } });
  const current = new Map(existing.map((e) => [Number(e.book_id), e]));

  for (const bookId of ids) {
    const row = current.get(bookId);
    if (row && Number(row.slot_id) === Number(slotId)) continue;
    const data = {
      slot_id: Number(slotId), cabinet_id: Number(cabinetId), session_id: sessionId, placed_by: source, placed_at: now
    };
    await db.cabinet_slot_items.upsert({ where: { book_id: bookId }, create: { book_id: bookId, ...data }, update: data });
  }

  const moved = existing.filter((e) => Number(e.slot_id) !== Number(slotId));
  await refresh(db, [slotId, ...moved.map((e) => e.slot_id)]);
  return { moved: moved.map((e) => Number(e.book_id)) };
};

const removeBooks = async (tx, bookIds) => {
  const db = tx ?? prisma;
  const ids = unique(bookIds ?? []);
  if (ids.length === 0) return [];
  const rows = await db.cabinet_slot_items.findMany({ where: { book_id: { in: ids } }, select: { slot_id: true } });
  if (rows.length === 0) return [];
  await db.cabinet_slot_items.deleteMany({ where: { book_id: { in: ids } } });
  const slotIds = unique(rows.map((r) => r.slot_id));
  await refresh(db, slotIds);
  return slotIds;
};

const markCheck = async (tx, slotIds, { reason, sessionId = null, now = new Date() }) => {
  const db = tx ?? prisma;
  const ids = unique(slotIds ?? []);
  if (ids.length === 0) return [];
  const slots = await db.cabinet_slots.findMany({ where: { slot_id: { in: ids } } });
  for (const slot of slots) {
    await db.cabinet_slots.updateMany({ where: { slot_id: slot.slot_id, check_required_at: null }, data: { check_required_at: now } });
    await db.cabinet_slots.updateMany({
      where: { slot_id: slot.slot_id },
      data: { check_session_id: sessionId, check_reason: reason, updated_at: now }
    });
    await recordEvent(db, {
      cabinetId: slot.cabinet_id,
      sessionId,
      type: 'door_check_required',
      channel: slot.lock_channel ?? null,
      detail: { reason, label: labelOf(slot) },
      source: 'server',
      occurredAt: now
    });
  }
  for (const cabinetId of unique(slots.map((s) => s.cabinet_id))) await recountAvailable(db, cabinetId);
  return slots.map((s) => ({ slot_id: Number(s.slot_id), cabinet_id: Number(s.cabinet_id), label: labelOf(s) }));
};

const clearCheck = async (tx, slotId, { actorId = null, note = null, mode = 'confirm', now = new Date() } = {}) => {
  const db = tx ?? prisma;
  const slot = await db.cabinet_slots.findUnique({ where: { slot_id: Number(slotId) } });
  if (!slot?.check_required_at) return false;
  const cleared = await db.cabinet_slots.updateMany({
    where: { slot_id: slot.slot_id, check_required_at: { not: null } },
    data: { check_required_at: null, check_session_id: null, check_reason: null, updated_at: now }
  });
  if (cleared.count === 0) return false;
  await recordEvent(db, {
    cabinetId: slot.cabinet_id,
    sessionId: slot.check_session_id ?? null,
    type: 'door_check_cleared',
    channel: slot.lock_channel ?? null,
    detail: { mode, reason: slot.check_reason, note: note || null, label: labelOf(slot) },
    source: actorId ? 'admin' : 'server',
    actorId,
    occurredAt: now
  });
  await recountAvailable(db, slot.cabinet_id);
  return true;
};

// 每位賣家的先行存書上限計入所有管道：門內的非訂單單位、沒有櫃門紀錄的存書登記（手動存書、配對前的存書）、
// 待確認的先行存書手動回報，以及進行中作業已分配的先行存書櫃門；漏算任一種都能繞過上限。
const sellerPreDepositDoors = async (db, cabinetId, sellerId, { excludeSessionId = null, includeReports = true, excludeBookIds = [] } = {}) => {
  if (!sellerId) return 0;
  const cabinet = Number(cabinetId);
  const seller = Number(sellerId);
  const units = new Set();
  const [items, deposits, reports, pending] = await Promise.all([
    db.cabinet_slot_items.findMany({ where: { cabinet_id: cabinet, books: { seller_id: seller } }, select: { slot_id: true, book_id: true } }),
    db.book_deposits.findMany({ where: { cabinet_id: cabinet, books: { seller_id: seller } }, select: { book_id: true } }),
    includeReports
      ? db.cabinet_manual_reports.findMany({
          where: { cabinet_id: cabinet, user_id: seller, kind: 'deposit', status: 'pending', book_id: { not: null } },
          select: { book_id: true }
        })
      : [],
    db.cabinet_session_items.findMany({
      where: {
        kind: 'pre_deposit',
        selected: true,
        slot_id: { not: null },
        ...(excludeSessionId ? { session_id: { not: Number(excludeSessionId) } } : {}),
        cabinet_sessions: { cabinet_id: cabinet, user_id: seller, status: { in: OPEN_SESSION_STATUSES } }
      },
      select: { slot_id: true }
    })
  ]);
  if (items.length > 0) {
    const custody = await custodyUnits(items.map((i) => i.book_id), { tx: db });
    for (const item of items) {
      if (custody.get(Number(item.book_id))?.kind !== 'order') units.add(`slot:${item.slot_id}`);
    }
  }
  const depositIds = unique(deposits.map((d) => d.book_id));
  if (depositIds.length > 0) {
    const placed = new Set((await db.cabinet_slot_items.findMany({ where: { book_id: { in: depositIds } }, select: { book_id: true } }))
      .map((p) => Number(p.book_id)));
    for (const id of depositIds) if (!placed.has(id)) units.add(`book:${id}`);
  }
  const own = new Set(unique(excludeBookIds));
  for (const report of reports) if (!own.has(Number(report.book_id))) units.add(`book:${Number(report.book_id)}`);
  for (const item of pending) units.add(`slot:${item.slot_id}`);
  return units.size;
};

const predepositQuota = async (db, cabinetId, sellerId, options = {}) =>
  Math.max(0, policy.CABINET_PREDEPOSIT_MAX_PER_SELLER - await sellerPreDepositDoors(db, cabinetId, sellerId, options));

const previewCapacity = async (cabinetId, { sellerId = null, tx } = {}) => {
  const db = tx ?? prisma;
  const available = (await doorsOf(cabinetId, { tx: db })).filter(isFree).length;
  return {
    available_doors: available,
    pre_deposit_doors: Math.max(0, available - policy.CABINET_ORDER_RESERVED_DOORS),
    seller_pre_deposit_doors: await sellerPreDepositDoors(db, cabinetId, sellerId)
  };
};

const split = (list, parts) => {
  const base = Math.floor(list.length / parts);
  const extra = list.length % parts;
  const chunks = [];
  let start = 0;
  for (let i = 0; i < parts; i += 1) {
    const size = base + (i < extra ? 1 : 0);
    chunks.push(list.slice(start, start + size));
    start += size;
  }
  return chunks;
};

const planOrderUnit = async (db, { cabinetId, doors, unit }) => {
  const orderItems = await db.order_items.findMany({
    where: { order_id: Number(unit.orderId) }, select: { book_id: true }, orderBy: { item_id: 'asc' }
  });
  const sequence = orderItems.map((i) => Number(i.book_id));
  const rank = (id) => (sequence.includes(id) ? sequence.indexOf(id) : sequence.length + id);
  const wanted = unique(unit.bookIds ?? []).sort((a, b) => rank(a) - rank(b));

  const placed = sequence.length
    ? await db.cabinet_slot_items.findMany({
        where: { book_id: { in: sequence }, cabinet_id: Number(cabinetId) },
        select: { book_id: true, slot_id: true }
      })
    : [];
  const perSlot = new Map();
  for (const row of placed) {
    if (wanted.includes(Number(row.book_id))) continue;
    perSlot.set(Number(row.slot_id), (perSlot.get(Number(row.slot_id)) ?? 0) + 1);
  }

  const total = unique([...placed.map((p) => p.book_id), ...wanted]).length;
  const perDoor = Math.max(policy.CABINET_DOOR_MAX_BOOKS, Math.ceil(total / Math.max(1, doors.length)));
  const ownDoors = doors.filter((d) => perSlot.has(Number(d.slot_id)) && !d.fault_code && !d.check_required_at);

  if (wanted.length === 0) {
    return { entries: ownDoors.map((d) => ({ door: d, bookIds: [] })), chunks: [] };
  }

  const remaining = [...wanted];
  const entries = [];
  for (const door of ownDoors) {
    const space = perDoor - perSlot.get(Number(door.slot_id));
    if (space <= 0 || remaining.length === 0) continue;
    entries.push({ door, bookIds: remaining.splice(0, space) });
  }
  const chunks = remaining.length ? split(remaining, Math.ceil(remaining.length / perDoor)) : [];
  return { entries, chunks };
};

const allocate = async (tx, { cabinetId, sessionId = null, sellerId = null, units = [] }) => {
  const db = tx ?? prisma;
  const doors = await doorsOf(cabinetId, { tx: db });
  const candidates = doors.filter(isFree);
  const orderUnits = units.filter((u) => u.kind === 'order_deposit');
  const preUnits = units.filter((u) => u.kind === 'pre_deposit');

  const plans = [];
  for (const unit of orderUnits) plans.push({ unit, ...(await planOrderUnit(db, { cabinetId, doors, unit })) });
  const orderDoorsNeeded = plans.reduce((sum, p) => sum + p.chunks.length, 0);
  const required = orderDoorsNeeded + preUnits.length;

  // orderShortage：依訂單存書本身放不下（須通知管理員），有別於先行存書的容量政策。
  const orderFull = () => Object.assign(cabinetFull(candidates.length, required), { orderShortage: true });
  if (orderDoorsNeeded > candidates.length) throw orderFull();
  if (preUnits.length > 0) {
    const quota = await predepositQuota(db, cabinetId, sellerId, {
      excludeSessionId: sessionId, excludeBookIds: preUnits.flatMap((u) => u.bookIds ?? [])
    });
    if (quota === 0) throw predepositLimit();
    if (candidates.length - orderDoorsNeeded - preUnits.length < policy.CABINET_ORDER_RESERVED_DOORS) {
      throw cabinetFull(candidates.length, required + policy.CABINET_ORDER_RESERVED_DOORS);
    }
    // 尚有額度但一次選取過多：以 CABINET_FULL 回應，App 依此回到確認步驟讓使用者減少先行存書項目。
    if (preUnits.length > quota) throw cabinetFull(orderDoorsNeeded + quota, required);
  }

  const pool = [...candidates];
  const now = new Date();
  const reserve = async (forOrder) => {
    while (pool.length > 0) {
      const door = pool.shift();
      const taken = await db.cabinet_slots.updateMany({
        where: { slot_id: door.slot_id, status: 'empty', fault_code: null, check_required_at: null },
        data: { status: 'reserved', updated_at: now }
      });
      if (taken.count > 0) return door;
    }
    throw forOrder ? orderFull() : cabinetFull(candidates.length, required);
  };
  const entryOf = (door, bookIds) => ({ slot_id: Number(door.slot_id), lock_channel: door.lock_channel, book_ids: bookIds });

  const result = new Map();
  for (const plan of plans) {
    const list = plan.entries.map((e) => entryOf(e.door, e.bookIds));
    for (const chunk of plan.chunks) list.push(entryOf(await reserve(true), chunk));
    result.set(plan.unit.key, list);
  }
  for (const unit of preUnits) result.set(unit.key, [entryOf(await reserve(false), unique(unit.bookIds ?? []))]);

  if (required > 0) await recountAvailable(db, cabinetId);
  return result;
};

module.exports = {
  OPEN_SESSION_STATUSES, doorLabel, labelOf, isFree, isUsable, doorsOf, syncChannels, allocate, previewCapacity,
  placeBooks, removeBooks, markCheck, clearCheck, bookDoors, orderDoors, booksInSlot, custodyUnits,
  sellerPreDepositDoors, predepositQuota, cabinetFull, predepositLimit, refresh, recountAvailable
};
