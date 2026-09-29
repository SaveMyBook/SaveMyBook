const prisma = require('../lib/prisma');
const { HttpError } = require('../lib/errors');
const { ORDER_UNSETTLED_STATUSES } = require('../constants/domain');
const policy = require('../constants/policy');
const { coverImage } = require('../lib/selects');
const doors = require('./cabinet-doors');
const { keptInCabinet } = require('./orders/settlement');

const deposits = () => require('./book-deposits');

const KIND_ORDER = ['pickup', 'order_deposit', 'pre_deposit', 'retrieval'];
const DEPOSIT_KINDS = ['order_deposit', 'pre_deposit'];
const IN_CABINET = ['deposited', 'pending_pickup'];
const PRE_DEPOSIT = ['pending_payment', 'pending_deposit'];
const DOOR_CODES = ['DOOR_UNKNOWN', 'DOOR_FAULT', 'DOOR_CHECK', 'DOOR_SHARED'];

const BLOCKED_MESSAGES = {
  DOOR_UNKNOWN: '無法確認此項目的櫃門，請聯絡客服',
  DOOR_FAULT: '此項目的櫃門故障，請聯絡客服',
  DOOR_CHECK: '此項目的櫃門待客服確認，請聯絡客服',
  CABINET_FULL: '書櫃目前沒有可用的櫃門',
  PREDEPOSIT_LIMIT: '您在此書櫃的先行存書已達上限，請待售出或取回後再存入',
  DOOR_SHARED: '此櫃門存放其他項目，請聯絡客服'
};

const BLOCKED_LABELS = {
  DOOR_UNKNOWN: '無法確認櫃門',
  DOOR_FAULT: '櫃門故障',
  DOOR_CHECK: '櫃門待確認',
  DOOR_SHARED: '櫃門存放其他項目',
  CABINET_FULL: '可用櫃門不足'
};

const bookSelect = { book_id: true, title: true, status: true, seller_id: true, is_approved: true, book_images: coverImage };

const unique = (values) => [...new Set(values.filter((v) => v !== null && v !== undefined).map(Number))];

const bookEntry = (book, slotId = null) => ({
  book_id: Number(book.book_id),
  title: book.title ?? '',
  image_url: book.book_images?.[0]?.image_url ?? null,
  slot_id: slotId
});

const byKind = (a, b) => KIND_ORDER.indexOf(a.kind) - KIND_ORDER.indexOf(b.kind)
  || Number(a.key.split(':')[1]) - Number(b.key.split(':')[1]);

const wrongCabinet = (type, cabinet) => new HttpError(
  409,
  `此${type === 'order' ? '訂單' : '書籍'}的指定書櫃為「${cabinet?.cabinet_name ?? ''}」，請至該書櫃辦理`,
  'CABINET_WRONG_CABINET',
  {
    cabinet: cabinet
      ? {
          cabinet_id: Number(cabinet.cabinet_id),
          cabinet_name: cabinet.cabinet_name,
          address: cabinet.address,
          latitude: cabinet.latitude === null || cabinet.latitude === undefined ? null : Number(cabinet.latitude),
          longitude: cabinet.longitude === null || cabinet.longitude === undefined ? null : Number(cabinet.longitude)
        }
      : null
  }
);

const contextChanged = (type) => new HttpError(
  409, type === 'order' ? '訂單狀態已變更，請重新整理後再試' : '書籍狀態已變更，請重新整理後再試', 'CABINET_CONTEXT_CHANGED'
);

const openOrderOf = async (db, bookIds) => {
  const ids = unique(bookIds);
  const map = new Map();
  if (ids.length === 0) return map;
  const items = await db.order_items.findMany({
    where: { book_id: { in: ids }, orders: { status: { in: ORDER_UNSETTLED_STATUSES } } },
    orderBy: { item_id: 'desc' },
    select: {
      book_id: true,
      pre_deposited: true,
      orders: {
        select: {
          order_id: true, order_no: true, status: true, cabinet_id: true, deposited_at: true, picked_up_at: true,
          smart_cabinets: { select: { cabinet_name: true } }
        }
      }
    }
  });
  for (const item of items) if (!map.has(Number(item.book_id))) map.set(Number(item.book_id), item);
  return map;
};

const retrievalRule = (book, item, cabinetId) => {
  if (book.status === 'sold') return null;
  const order = item?.orders;
  if (!order) return { note: null };
  if (order.status === 'refunding') return keptInCabinet(order, item) ? null : { note: null };
  if (Number(order.cabinet_id) === Number(cabinetId)) return order.picked_up_at ? { note: null } : null;
  return { note: PRE_DEPOSIT.includes(order.status) ? 'MOVE_TO_ORDER_CABINET' : null };
};

const retrievableBooks = async (bookIds, db = prisma) => {
  const ids = unique(bookIds);
  const result = new Set();
  if (ids.length === 0) return result;
  const placed = await doors.bookDoors(ids, { tx: db });
  if (placed.size === 0) return result;
  const [books, orders] = await Promise.all([
    db.books.findMany({ where: { book_id: { in: [...placed.keys()] } }, select: { book_id: true, status: true } }),
    openOrderOf(db, [...placed.keys()])
  ]);
  for (const book of books) {
    const door = placed.get(Number(book.book_id));
    if (retrievalRule(book, orders.get(Number(book.book_id)), door.cabinet_id)) result.add(Number(book.book_id));
  }
  return result;
};

const slotContents = async (db, slotIds) => {
  const ids = unique(slotIds);
  const map = new Map();
  if (ids.length === 0) return map;
  const rows = await db.cabinet_slot_items.findMany({
    where: { slot_id: { in: ids } },
    include: { books: { select: { book_id: true, seller_id: true } } }
  });
  const units = await doors.custodyUnits(rows.map((r) => r.book_id), { tx: db });
  for (const row of rows) {
    const slotId = Number(row.slot_id);
    if (!map.has(slotId)) map.set(slotId, []);
    map.get(slotId).push({
      book_id: Number(row.book_id),
      seller_id: Number(row.books?.seller_id),
      unit: units.get(Number(row.book_id))
    });
  }
  return map;
};

const doorProblem = (slotIds, placedBySlot, contents, allowed) => {
  for (const slotId of slotIds) {
    const door = placedBySlot.get(slotId);
    if (door?.fault_code) return 'DOOR_FAULT';
    if (door?.check_required_at) return 'DOOR_CHECK';
  }
  for (const slotId of slotIds) {
    if ((contents.get(slotId) ?? []).some((entry) => !allowed(entry))) return 'DOOR_SHARED';
  }
  return null;
};

const orderDepositFull = (order, cabinetId, placed, doorList) => {
  const bookIds = order.order_items.map((i) => Number(i.book_id));
  const here = bookIds.filter((id) => placed.get(id)?.cabinet_id === Number(cabinetId));
  const needed = bookIds.length - here.length;
  if (needed === 0) return false;
  const perDoor = Math.max(policy.CABINET_DOOR_MAX_BOOKS, Math.ceil(bookIds.length / Math.max(1, doorList.length)));
  const counts = new Map();
  for (const id of here) {
    const door = placed.get(id);
    if (door.fault_code || door.check_required_at) continue;
    counts.set(door.slot_id, (counts.get(door.slot_id) ?? 0) + 1);
  }
  const space = [...counts.values()].reduce((sum, n) => sum + Math.max(0, perDoor - n), 0);
  const required = Math.ceil(Math.max(0, needed - space) / perDoor);
  return required > doorList.filter(doors.isFree).length;
};

const loadRaw = async (db, userId, cabinetId) => {
  const orderInclude = { order_items: { orderBy: { item_id: 'asc' }, include: { books: { select: bookSelect } } } };
  const [buyerOrders, sellerOrders, placedRows, depositRows, listed] = await Promise.all([
    db.orders.findMany({
      where: { buyer_id: userId, cabinet_id: cabinetId, status: { in: IN_CABINET }, picked_up_at: null },
      include: orderInclude,
      orderBy: { order_id: 'asc' }
    }),
    db.orders.findMany({
      where: { seller_id: userId, cabinet_id: cabinetId, status: { in: PRE_DEPOSIT } },
      include: orderInclude,
      orderBy: { order_id: 'asc' }
    }),
    db.cabinet_slot_items.findMany({
      where: { cabinet_id: cabinetId, books: { seller_id: userId } },
      include: { books: { select: bookSelect } },
      orderBy: { book_id: 'asc' }
    }),
    db.book_deposits.findMany({
      where: { cabinet_id: cabinetId, books: { seller_id: userId } },
      include: { books: { select: bookSelect } },
      orderBy: { book_id: 'asc' }
    }),
    db.books.findMany({
      where: { seller_id: userId, cabinet_id: cabinetId, status: 'on_sale', is_approved: true },
      include: { book_images: coverImage, smart_cabinets: { select: { cabinet_id: true, cabinet_name: true, address: true, is_active: true } } },
      orderBy: { book_id: 'asc' }
    })
  ]);
  return { buyerOrders, sellerOrders, placedRows, depositRows, listed };
};

const buildUnits = async (db, userId, cabinet) => {
  const cabinetId = Number(cabinet.cabinet_id);
  const raw = await loadRaw(db, userId, cabinetId);
  const orderBooks = [...raw.buyerOrders, ...raw.sellerOrders].flatMap((o) => o.order_items.map((i) => i.book_id));
  const placed = await doors.bookDoors([
    ...orderBooks, ...raw.placedRows.map((r) => r.book_id), ...raw.depositRows.map((r) => r.book_id), ...raw.listed.map((b) => b.book_id)
  ], { tx: db });
  const placedBySlot = new Map([...placed.values()].map((d) => [d.slot_id, d]));
  const here = (bookId) => {
    const door = placed.get(Number(bookId));
    return door && door.cabinet_id === cabinetId ? door : null;
  };
  const contents = await slotContents(db, [...placed.values()].filter((d) => d.cabinet_id === cabinetId).map((d) => d.slot_id));
  const doorList = await doors.doorsOf(cabinetId, { tx: db });
  const units = [];

  for (const order of raw.buyerOrders) {
    const books = order.order_items.map((i) => bookEntry(i.books ?? { book_id: i.book_id }, here(i.book_id)?.slot_id ?? null));
    const slotIds = unique(books.map((b) => b.slot_id));
    const key = `order:${order.order_id}`;
    const blocked = books.some((b) => !b.slot_id)
      ? 'DOOR_UNKNOWN'
      : doorProblem(slotIds, placedBySlot, contents, (entry) => entry.unit?.key === key);
    units.push({ key, kind: 'pickup', order_id: Number(order.order_id), order_no: order.order_no, books, blocked, note: null, paused: false });
  }

  for (const order of raw.sellerOrders) {
    const key = `order:${order.order_id}`;
    const books = order.order_items.map((i) => bookEntry(i.books ?? { book_id: i.book_id }));
    // 書已全部在本書櫃時只會開啟既有的櫃門；這些門故障或待確認時作業將沒有可開的門，須在列項時就標示受阻。
    const allHere = order.order_items.length > 0 && order.order_items.every((i) => here(i.book_id));
    let blocked = null;
    if (allHere) {
      const hereSlots = unique(order.order_items.map((i) => here(i.book_id).slot_id));
      blocked = doorProblem(hereSlots, placedBySlot, contents, (entry) => entry.unit?.key === key);
    } else if (orderDepositFull(order, cabinetId, placed, doorList)) {
      blocked = 'CABINET_FULL';
    }
    units.push({
      key, kind: 'order_deposit', order_id: Number(order.order_id), order_no: order.order_no,
      books, blocked, note: null, paused: false
    });
  }

  const depositOf = new Map(raw.depositRows.map((r) => [Number(r.book_id), r]));
  const retrievalIds = raw.placedRows.map((r) => Number(r.book_id));
  const retrievalOrders = await openOrderOf(db, retrievalIds);
  const retrievable = new Map();
  for (const row of raw.placedRows) {
    const rule = retrievalRule(row.books ?? {}, retrievalOrders.get(Number(row.book_id)), cabinetId);
    if (rule) retrievable.set(Number(row.book_id), rule);
  }
  for (const row of raw.placedRows) {
    const bookId = Number(row.book_id);
    const rule = retrievable.get(bookId);
    if (!rule) continue;
    const slotId = Number(row.slot_id);
    const blocked = doorProblem([slotId], placedBySlot, contents,
      (entry) => entry.seller_id === Number(userId) && retrievable.has(entry.book_id));
    units.push({
      key: `book:${bookId}`, kind: 'retrieval', order_id: null, order_no: null, books: [bookEntry(row.books ?? { book_id: bookId }, slotId)],
      blocked, note: rule.note, paused: depositOf.get(bookId)?.paused_at != null
    });
  }
  for (const row of raw.depositRows) {
    const bookId = Number(row.book_id);
    if (placed.has(bookId)) continue;
    units.push({
      key: `book:${bookId}`, kind: 'retrieval', order_id: null, order_no: null, books: [bookEntry(row.books ?? { book_id: bookId })],
      blocked: 'DOOR_UNKNOWN', note: null, paused: row.paused_at != null
    });
  }

  const preBooks = [];
  for (const book of raw.listed) {
    if (placed.has(Number(book.book_id)) || depositOf.has(Number(book.book_id))) continue;
    try {
      await deposits().assertDepositAllowed(book);
      preBooks.push(book);
    } catch (err) {
      if (!(err instanceof HttpError)) throw err;
    }
  }
  if (preBooks.length > 0) {
    const capacity = await doors.previewCapacity(cabinetId, { sellerId: userId, tx: db });
    // 本書自己的待確認手動回報不佔用它的額度，賣家才能在裝置恢復後改以掃碼完成同一本書的存書。
    const reported = new Set((await db.cabinet_manual_reports.findMany({
      where: { cabinet_id: cabinetId, user_id: Number(userId), kind: 'deposit', status: 'pending', book_id: { in: preBooks.map((b) => Number(b.book_id)) } },
      select: { book_id: true }
    })).map((r) => Number(r.book_id)));
    for (const book of preBooks) {
      const used = capacity.seller_pre_deposit_doors - (reported.has(Number(book.book_id)) ? 1 : 0);
      let blocked = null;
      if (used >= policy.CABINET_PREDEPOSIT_MAX_PER_SELLER) blocked = 'PREDEPOSIT_LIMIT';
      else if (capacity.pre_deposit_doors < 1) blocked = 'CABINET_FULL';
      units.push({
        key: `book:${book.book_id}`, kind: 'pre_deposit', order_id: null, order_no: null, books: [bookEntry(book)],
        blocked, note: null, paused: false
      });
    }
  }

  return units.sort(byKind);
};

const sameDoorKeys = (units, unit) => {
  if (unit.kind !== 'retrieval') return [unit.key];
  const slots = new Set(unit.books.map((b) => b.slot_id).filter(Boolean));
  if (slots.size === 0) return [unit.key];
  return units.filter((u) => u.kind === 'retrieval' && u.books.some((b) => slots.has(b.slot_id))).map((u) => u.key);
};

const resolveContext = async (db, { userId, cabinet, context, units }) => {
  if (!context || !['order', 'book'].includes(context.type)) return null;
  const cabinetId = Number(cabinet.cabinet_id);
  const id = Number(context.id);
  const cabinetOf = (targetId) => db.smart_cabinets.findUnique({
    where: { cabinet_id: Number(targetId) },
    select: { cabinet_id: true, cabinet_name: true, address: true, latitude: true, longitude: true }
  });

  if (context.type === 'order') {
    const order = await db.orders.findUnique({ where: { order_id: id }, include: { order_items: { select: { book_id: true } } } });
    if (!order || (order.buyer_id !== userId && order.seller_id !== userId)) return null;
    const effective = { type: 'order', id };
    if (Number(order.cabinet_id) !== cabinetId) {
      const bookIds = new Set(order.order_items.map((i) => Number(i.book_id)));
      const keys = order.seller_id === userId
        ? units.filter((u) => u.kind === 'retrieval' && u.books.some((b) => bookIds.has(b.book_id))).map((u) => u.key)
        : [];
      if (keys.length === 0) throw wrongCabinet('order', order.cabinet_id ? await cabinetOf(order.cabinet_id) : null);
      for (const unit of units) {
        if (keys.includes(unit.key) && !unit.note) unit.note = 'MOVE_TO_ORDER_CABINET';
      }
      return { effective, keys: [...new Set(keys.flatMap((key) => sameDoorKeys(units, units.find((u) => u.key === key))))] };
    }
    const kind = order.buyer_id === userId ? 'pickup' : 'order_deposit';
    const unit = units.find((u) => u.key === `order:${id}` && u.kind === kind);
    if (!unit) throw contextChanged('order');
    return { effective, keys: [unit.key] };
  }

  const book = await db.books.findUnique({ where: { book_id: id }, select: { book_id: true, seller_id: true, cabinet_id: true } });
  if (!book || book.seller_id !== userId) return null;
  const effective = { type: 'book', id };
  const [placed, deposit] = await Promise.all([
    doors.bookDoors([id], { tx: db }),
    db.book_deposits.findUnique({ where: { book_id: id }, select: { cabinet_id: true } })
  ]);
  const target = placed.get(id)?.cabinet_id ?? deposit?.cabinet_id ?? book.cabinet_id;
  if (Number(target) !== cabinetId) throw wrongCabinet('book', target ? await cabinetOf(target) : null);
  const unit = units.find((u) => u.kind !== 'pickup' && u.books.some((b) => b.book_id === id));
  if (!unit) throw contextChanged('book');
  return { effective, keys: sameDoorKeys(units, unit) };
};

// context 只決定預設勾選，本人無權時視同未帶（3.8.1）。
const list = async ({ userId, cabinet, context = null, db = prisma, strictContext = true }) => {
  const units = await buildUnits(db, Number(userId), cabinet);
  let resolved = null;
  try {
    resolved = await resolveContext(db, { userId: Number(userId), cabinet, context, units });
  } catch (err) {
    if (strictContext || !(err instanceof HttpError)) throw err;
  }
  const keys = new Set(resolved?.keys ?? []);
  for (const unit of units) {
    const defaulted = unit.kind === 'pickup' || unit.kind === 'order_deposit';
    unit.selected = !unit.blocked && (resolved ? keys.has(unit.key) : defaulted);
    const notifiable = DOOR_CODES.includes(unit.blocked) || (unit.blocked === 'CABINET_FULL' && unit.kind === 'order_deposit');
    unit.notify = notifiable && (resolved ? keys.has(unit.key) : defaulted);
  }
  return { units, context: resolved?.effective ?? null };
};

const signature = (unit) => {
  const books = unit.books.map((b) => b.book_id).sort((a, b) => a - b).join(',');
  if (DEPOSIT_KINDS.includes(unit.kind)) return `${unit.kind}|${books}`;
  const slots = [...new Set(unit.books.map((b) => b.slot_id ?? 0))].sort((a, b) => a - b).join(',');
  return `${unit.kind}|${books}|${slots}|${unit.blocked ?? ''}`;
};

const otherCabinets = async (userId, cabinetId, db = prisma) => {
  const [pickups, depositsDue, placed, stored] = await Promise.all([
    db.orders.findMany({
      where: { buyer_id: userId, status: { in: IN_CABINET }, picked_up_at: null, cabinet_id: { not: null } },
      select: { cabinet_id: true }
    }),
    db.orders.findMany({ where: { seller_id: userId, status: { in: PRE_DEPOSIT }, cabinet_id: { not: null } }, select: { cabinet_id: true } }),
    db.cabinet_slot_items.findMany({ where: { books: { seller_id: userId } }, select: { cabinet_id: true } }),
    db.book_deposits.findMany({ where: { books: { seller_id: userId } }, select: { cabinet_id: true } })
  ]);
  const kinds = new Map();
  const add = (rows, kind) => {
    for (const row of rows) {
      const id = Number(row.cabinet_id);
      if (id === Number(cabinetId)) continue;
      if (!kinds.has(id)) kinds.set(id, new Set());
      kinds.get(id).add(kind);
    }
  };
  add(pickups, 'pickup');
  add(depositsDue, 'order_deposit');
  add([...placed, ...stored], 'retrieval');
  const ids = [...kinds.keys()].sort((a, b) => a - b).slice(0, 3);
  if (ids.length === 0) return [];
  const cabinets = await db.smart_cabinets.findMany({
    where: { cabinet_id: { in: ids } }, select: { cabinet_id: true, cabinet_name: true, address: true }
  });
  const byId = new Map(cabinets.map((c) => [Number(c.cabinet_id), c]));
  return ids.filter((id) => byId.has(id)).map((id) => ({
    cabinet_id: id,
    cabinet_name: byId.get(id).cabinet_name,
    address: byId.get(id).address,
    kinds: KIND_ORDER.filter((k) => kinds.get(id).has(k))
  }));
};

module.exports = {
  KIND_ORDER, DEPOSIT_KINDS, BLOCKED_MESSAGES, BLOCKED_LABELS, DOOR_CODES,
  list, signature, sameDoorKeys, retrievableBooks, retrievalRule, openOrderOf, otherCabinets, wrongCabinet, contextChanged
};
