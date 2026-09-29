const prisma = require('../lib/prisma');
const { HttpError } = require('../lib/errors');
const { notify } = require('./notify');
const doors = require('./cabinet-doors');
const { recordEvent, notifyAdmins } = require('./cabinet-events');

const LOCKING_STATUSES = ['matching', 'opening', 'open'];
const HOLDING_STATUSES = ['selecting', 'matching', 'opening', 'open', 'needs_review'];
const RETRIEVE_TITLE = '請取回書櫃中的書籍';

const REVIEW_REASONS = {
  OPENED: '開門後未完成取書',
  BLOCKED: '曾有無法辦理的紀錄',
  DOOR: '櫃門故障或待確認',
  MANUAL: '有待確認的手動回報'
};

const unique = (values) => [...new Set(values.filter((v) => v !== null && v !== undefined).map(Number))];

const assertNotInSession = async (orderId) => {
  const busy = await prisma.cabinet_session_items.count({
    where: { order_id: Number(orderId), selected: true, cabinet_sessions: { status: { in: LOCKING_STATUSES } } }
  });
  if (busy > 0) throw new HttpError(409, '此訂單正於書櫃辦理中，請稍後再試', 'ORDER_IN_CABINET_SESSION');
};

const reviewReason = async (db, order, items) => {
  const orderId = Number(order.order_id);
  const opened = items.filter((i) => i.kind === 'pickup' && i.cabinet_sessions?.opened_at && i.result !== 'done' && i.slot_id);
  if (opened.length > 0) {
    const doorRows = await db.cabinet_session_doors.findMany({
      where: { OR: opened.map((i) => ({ session_id: i.session_id, slot_id: i.slot_id })) },
      select: { state: true }
    });
    if (doorRows.some((d) => d.state !== 'failed')) return 'OPENED';
  }

  const blocked = await db.cabinet_events.count({
    where: { order_id: orderId, type: 'item_blocked', occurred_at: { gte: order.created_at } }
  });
  if (blocked > 0) return 'BLOCKED';

  const bookIds = (order.order_items ?? []).map((i) => i.book_id);
  const placed = await doors.bookDoors(bookIds, { tx: db });
  const troubled = [...placed.values()].some((d) => d.cabinet_id === Number(order.cabinet_id) && (d.fault_code || d.check_required_at));
  if (troubled) return 'DOOR';

  const manual = await db.cabinet_manual_reports.count({ where: { order_id: orderId, status: 'pending' } });
  return manual > 0 ? 'MANUAL' : null;
};

const HOLD_NOTICES = {
  overdue_review: { title: '逾期訂單待人工處理', lead: '已逾期' },
  delist_review: { title: '下架書籍訂單待人工處理', lead: '的書籍已經審核下架' }
};

// 逾期或書籍下架自動取消前呼叫：'wait' 表示作業進行中，下次排程再判斷；'review' 表示交由管理員處理，不取消也不退款。
const overdueHold = async (tx, order, now = new Date(), { type = 'overdue_review' } = {}) => {
  if (order.cabinet_id === null || order.cabinet_id === undefined) return null;
  const db = tx ?? prisma;
  const items = await db.cabinet_session_items.findMany({
    where: { order_id: Number(order.order_id), selected: true },
    include: { cabinet_sessions: { select: { status: true, opened_at: true } } }
  });
  if (items.some((i) => HOLDING_STATUSES.includes(i.cabinet_sessions?.status))) return 'wait';

  const reason = await reviewReason(db, order, items);
  if (!reason) return null;

  const reported = await db.cabinet_events.count({ where: { order_id: Number(order.order_id), type } });
  if (reported === 0) {
    await recordEvent(db, {
      cabinetId: order.cabinet_id, orderId: Number(order.order_id), type, source: 'server',
      detail: { reason }, occurredAt: now
    });
    await notifyAdmins(db, order.cabinet_id, {
      title: HOLD_NOTICES[type].title,
      content: `訂單 ${order.order_no} ${HOLD_NOTICES[type].lead}，但書櫃紀錄顯示${REVIEW_REASONS[reason]}，系統未自動取消，請確認後處理。`
    });
  }
  return 'review';
};

// 新存書一門一本，但舊資料仍可能一門多本：同門的多本書各自恢復為先行存書時，須暫停販售並請賣家整扇取回。回傳被暫停的書籍編號。
const splitSharedDoors = async (tx, order, bookIds, now = new Date()) => {
  const db = tx ?? prisma;
  const paused = new Set();
  const ids = unique(bookIds ?? []);
  if (ids.length < 2) return paused;

  const placed = await doors.bookDoors(ids, { tx: db });
  const bySlot = new Map();
  for (const [bookId, door] of placed) {
    if (!bySlot.has(door.slot_id)) bySlot.set(door.slot_id, { door, bookIds: [] });
    bySlot.get(door.slot_id).bookIds.push(bookId);
  }

  for (const { door, bookIds: shared } of bySlot.values()) {
    if (shared.length < 2) continue;
    for (const bookId of shared) {
      await db.book_deposits.updateMany({ where: { book_id: bookId }, data: { paused_at: now, reminded_at: now } });
      const delisted = await db.books.updateMany({ where: { book_id: bookId, status: 'on_sale' }, data: { status: 'removed', updated_at: now } });
      if (delisted.count > 0) await db.book_deposits.updateMany({ where: { book_id: bookId }, data: { auto_paused: true } });
      paused.add(bookId);
    }
    const [books, cabinet] = await Promise.all([
      db.books.findMany({ where: { book_id: { in: shared } }, select: { book_id: true, title: true, seller_id: true }, orderBy: { book_id: 'asc' } }),
      db.smart_cabinets.findUnique({ where: { cabinet_id: door.cabinet_id }, select: { cabinet_name: true } })
    ]);
    const sellerId = books[0]?.seller_id ?? order.seller_id;
    await notify(db, {
      userId: sellerId,
      type: 'order',
      title: RETRIEVE_TITLE,
      content: `訂單 ${order.order_no} 已取消，${books.map((b) => `《${b.title}》`).join('、')}存放於「${cabinet?.cabinet_name ?? ''}」的同一櫃門，`
        + '須取回後才能重新存書或販售，請至書櫃以 App 掃描 QR Code 取回。',
      relatedId: shared[0],
      relatedType: 'book'
    });
  }
  return paused;
};

module.exports = { assertNotInSession, overdueHold, splitSharedDoors, REVIEW_REASONS };
