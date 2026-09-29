const prisma = require('../lib/prisma');
const publicId = require('../lib/public-id');
const { HttpError, badRequest, notFound, conflict } = require('../lib/errors');
const { ORDER_FINAL_STATUSES } = require('../constants/domain');
const policy = require('../constants/policy');
const { notify } = require('./notify');
const audit = require('./audit');
const doors = require('./cabinet-doors');
const { recordEvent, notifyAdmins } = require('./cabinet-events');
const { violationLocked } = require('./book-violations');
const { orderInclude } = require('./orders/selects');

const orders = () => require('./orders');
const deposits = () => require('./book-deposits');

// 故障備援的手動回報（業主決策）：一般使用者的回報先成為待確認，由管理員確認後才變更訂單或存書狀態。
const PENDING = Symbol('cabinetManualReportPending');

const KINDS = ['deposit', 'pickup', 'retrieve'];
const STATUSES = ['pending', 'confirmed', 'rejected', 'cancelled'];
const KIND_LABELS = { deposit: '存書', pickup: '取書', retrieve: '取回' };
const REASON_LABELS = { offline: '裝置離線', fault: '裝置故障', no_device: '未配對裝置' };
const PRE_DEPOSIT = ['pending_payment', 'pending_deposit'];
const IN_CABINET = ['deposited', 'pending_pickup'];

const reportNo = (id) => publicId.encode('cabinet_manual_report', id);
const pendingKey = (kind, { orderId, bookId }) => `${kind}:${orderId ? `order:${orderId}` : `book:${bookId}`}`;

const pendingExists = () => new HttpError(409, '此項目已有待客服確認的手動回報', 'MANUAL_REPORT_PENDING');
const notPending = () => new HttpError(409, '此手動回報已處理', 'MANUAL_REPORT_NOT_PENDING');
const staleReport = () => new HttpError(409, '項目狀態已變更，此手動回報已失效', 'MANUAL_REPORT_STALE');
const selfReview = () => new HttpError(403, '此手動回報與您本人相關，須由其他管理員處理', 'MANUAL_REPORT_SELF_REVIEW');
const doorRequired = () => badRequest('請指定書籍存放的櫃門', 'DOOR_REQUIRED');
const doorNotFound = () => new HttpError(404, '找不到此櫃門', 'DOOR_NOT_FOUND');
const assignInvalid = () => new HttpError(409, '此項目不在本書櫃、已有櫃門紀錄，或櫃門作業進行中', 'DOOR_ASSIGN_INVALID');

// 這些錯誤代表管理員的輸入或政策限制，回報維持待確認，不可當成「項目狀態已變更」而作廢。
const KEEP_PENDING = ['MANUAL_REPORT_NOT_PENDING', 'DOOR_ASSIGN_INVALID', 'DOOR_SINGLE_BOOK', 'DOOR_REQUIRED', 'PREDEPOSIT_LIMIT'];

const shape = (report) => ({
  report_no: reportNo(report.report_id),
  kind: report.kind,
  status: report.status,
  target_status: report.target_status ?? null,
  reason: report.reason ?? null,
  created_at: report.created_at,
  reviewed_at: report.reviewed_at ?? null,
  review_note: report.review_note ?? null
});

const isPending = (result) => Boolean(result?.[PENDING]);

const targetLabel = ({ order, orderNo, bookId }) => (order || orderNo ? `訂單 ${orderNo ?? order.order_no}` : `書籍 ${publicId.encode('book', bookId)}`);

const cabinetNameOf = async (db, cabinetId) =>
  (await db.smart_cabinets.findUnique({ where: { cabinet_id: Number(cabinetId) }, select: { cabinet_name: true } }))?.cabinet_name ?? '';

const pendingResult = async ({ kind, order, book, report }) => {
  const manualReport = shape(report);
  if (order) {
    const current = await prisma.orders.findUnique({
      where: { order_id: order.order_id }, include: orderInclude, omit: { pickup_code: true }
    });
    return { ...current, manual_report: manualReport, [PENDING]: true };
  }
  if (kind === 'deposit') {
    const cabinet = book.smart_cabinets;
    return {
      book_id: Number(book.book_id),
      in_cabinet: false,
      cabinet: cabinet ? { cabinet_id: cabinet.cabinet_id, cabinet_name: cabinet.cabinet_name, address: cabinet.address } : null,
      deposit: null,
      manual_report: manualReport,
      [PENDING]: true
    };
  }
  const current = await prisma.books.findUnique({ where: { book_id: Number(book.book_id) }, select: { status: true } });
  return {
    book_id: Number(book.book_id), status: current?.status ?? book.status, restored: false, manual_report: manualReport, [PENDING]: true
  };
};

// 送出時連同待確認的回報一起計入上限，避免一次送出多筆；確認時只計入已生效的存書，先確認者優先。
const assertPreDepositRoom = async (db, { cabinetId, sellerId, confirming = false }) => {
  if (await doors.predepositQuota(db, cabinetId, sellerId, { includeReports: !confirming }) === 0) throw doors.predepositLimit();
  if (confirming) return;
  const doorList = await doors.doorsOf(cabinetId, { tx: db });
  if (doorList.length === 0) return;
  const free = doorList.filter(doors.isFree).length;
  if (free - 1 < policy.CABINET_ORDER_RESERVED_DOORS) throw doors.cabinetFull(free, 1 + policy.CABINET_ORDER_RESERVED_DOORS);
};

const submit = async ({ kind, order = null, book = null, user, targetStatus = null, reason, cabinetId = null }) => {
  const now = new Date();
  const orderId = order ? Number(order.order_id) : null;
  const bookId = order ? null : Number(book.book_id);
  const cabinet = Number(cabinetId ?? (order ? order.cabinet_id : book.cabinet_id));
  const key = pendingKey(kind, { orderId, bookId });
  if (await prisma.cabinet_manual_reports.count({ where: { pending_key: key } })) throw pendingExists();
  if (kind === 'deposit' && !order) await assertPreDepositRoom(prisma, { cabinetId: cabinet, sellerId: user.userId });

  let report;
  try {
    report = await prisma.$transaction(async (tx) => {
      // 取回待確認期間書已在賣家手上，須比照掃碼取回暫停販售，否則結帳會把它當成仍在書櫃而直接成為已存書訂單。
      const held = kind === 'retrieve'
        ? (await tx.books.updateMany({ where: { book_id: bookId, status: 'on_sale' }, data: { status: 'removed', updated_at: now } })).count > 0
        : false;
      const created = await tx.cabinet_manual_reports.create({
        data: {
          cabinet_id: cabinet, user_id: user.userId, kind, order_id: orderId, book_id: bookId, target_status: targetStatus,
          reason, status: 'pending', pending_key: key, held_on_sale: held, created_at: now, updated_at: now
        }
      });
      await recordEvent(tx, {
        cabinetId: cabinet, orderId, bookId, type: 'manual_report', source: 'server', actorId: user.userId,
        detail: {
          reason, kind, report_no: reportNo(created.report_id), user_no: publicId.encode('user', user.userId),
          ...(order ? { order_no: order.order_no } : { book_no: publicId.encode('book', bookId) })
        },
        occurredAt: now
      });
      const name = await cabinetNameOf(tx, cabinet);
      await notifyAdmins(tx, cabinet, {
        title: '書櫃手動回報待確認',
        content: `「${name}」於${REASON_LABELS[reason] ?? '故障備援'}期間收到${KIND_LABELS[kind]}的手動回報`
          + `（${targetLabel({ order, bookId })}），請確認後於後台處理。`
      });
      return created;
    });
  } catch (err) {
    if (err?.code === 'P2002') throw pendingExists();
    throw err;
  }
  return pendingResult({ kind, order, book, report });
};

const applicableToOrder = (report, order) => {
  if (report.kind === 'deposit') return PRE_DEPOSIT.includes(order.status);
  if (report.kind === 'pickup') return IN_CABINET.includes(order.status) && !order.picked_up_at;
  return false;
};

const decorateOrders = async (list) => {
  const items = Array.isArray(list) ? list : [list];
  if (items.length === 0 || !items[0]) return list;
  const reports = await prisma.cabinet_manual_reports.findMany({
    where: { order_id: { in: items.map((o) => Number(o.order_id)) }, status: 'pending' },
    orderBy: { report_id: 'desc' }
  });
  const shaped = items.map((o) => {
    const report = reports.find((r) => Number(r.order_id) === Number(o.order_id) && applicableToOrder(r, o));
    return { ...o, manual_report: report ? shape(report) : null };
  });
  return Array.isArray(list) ? shaped : shaped[0];
};

const pendingForBooks = async (bookIds) => {
  const ids = [...new Set(bookIds.map(Number))];
  const map = new Map();
  if (ids.length === 0) return map;
  const reports = await prisma.cabinet_manual_reports.findMany({
    where: { book_id: { in: ids }, status: 'pending' }, orderBy: { report_id: 'desc' }
  });
  for (const report of reports) if (!map.has(Number(report.book_id))) map.set(Number(report.book_id), shape(report));
  return map;
};

const releaseHeld = async (tx, report, now) => {
  if (!report.held_on_sale || !report.book_id) return;
  const book = await tx.books.findUnique({ where: { book_id: Number(report.book_id) } });
  if (book && !(await violationLocked(book))) {
    await tx.books.updateMany({ where: { book_id: book.book_id, status: 'removed' }, data: { status: 'on_sale', updated_at: now } });
  }
  await tx.cabinet_manual_reports.updateMany({ where: { report_id: report.report_id }, data: { held_on_sale: false } });
};

const cancelPending = async (tx, { orderId = null, bookId = null, kinds = KINDS, note = '已於書櫃掃碼完成', now = new Date() }) => {
  const db = tx ?? prisma;
  const where = {
    status: 'pending', kind: { in: kinds },
    ...(orderId ? { order_id: Number(orderId) } : { book_id: Number(bookId) })
  };
  for (const report of await db.cabinet_manual_reports.findMany({ where: { ...where, held_on_sale: true } })) {
    await releaseHeld(db, report, now);
  }
  return db.cabinet_manual_reports.updateMany({
    where,
    data: { status: 'cancelled', pending_key: null, review_note: note, reviewed_at: now, updated_at: now }
  });
};

const loadReport = async (no) => {
  const id = publicId.decode('cabinet_manual_report', no);
  const report = id === null ? null : await prisma.cabinet_manual_reports.findUnique({ where: { report_id: id } });
  if (!report) throw notFound('找不到此手動回報', 'MANUAL_REPORT_NOT_FOUND');
  return report;
};

// 回報者本人或該訂單、書籍的當事人不得處理這筆回報，否則管理員可自行回報、自行確認。
const assertNotParty = async (report, adminId) => {
  const id = Number(adminId);
  if (Number(report.user_id) === id) throw selfReview();
  if (report.order_id) {
    const order = await prisma.orders.findUnique({ where: { order_id: Number(report.order_id) }, select: { buyer_id: true, seller_id: true } });
    if (order && (Number(order.buyer_id) === id || Number(order.seller_id) === id)) throw selfReview();
  }
  if (report.book_id) {
    const book = await prisma.books.findUnique({ where: { book_id: Number(report.book_id) }, select: { seller_id: true } });
    if (book && Number(book.seller_id) === id) throw selfReview();
  }
};

// 已配對過裝置的書櫃有櫃門；確認存書時須逐本指定書實際放入的櫃門，否則這扇門仍被視為空門而分配給其他人。
// 回傳 null 表示書櫃沒有櫃門；bookId 為 null 的項目是只帶 slot_id 的舊格式，僅適用於一本書。
const doorsForDeposit = async (report, { slotId = null, assignments = [] }) => {
  if (report.kind !== 'deposit') return null;
  const doorList = await doors.doorsOf(report.cabinet_id);
  if (doorList.length === 0) return null;
  const entries = assignments.length > 0 ? assignments : slotId ? [{ bookId: null, slotId }] : [];
  const slotIds = entries.map((e) => Number(e.slotId));
  const bookIds = entries.map((e) => e.bookId).filter((id) => id != null).map(Number);
  if (new Set(slotIds).size !== slotIds.length || new Set(bookIds).size !== bookIds.length) throw doors.singleBookDoor();
  return entries.map((e) => {
    const slot = doorList.find((d) => Number(d.slot_id) === Number(e.slotId));
    if (!slot) throw doorNotFound();
    return { bookId: e.bookId == null ? null : Number(e.bookId), slot };
  });
};

const matchDoors = (assignments, targets) => {
  if (!assignments || targets.length === 0) return [];
  if (assignments.length === 0) throw doorRequired();
  if (assignments.length === 1 && assignments[0].bookId == null) {
    if (targets.length > 1) throw doors.singleBookDoor();
    return [{ bookId: targets[0], slot: assignments[0].slot }];
  }
  if (assignments.some((a) => a.bookId == null || !targets.includes(a.bookId))) throw assignInvalid();
  if (targets.some((id) => !assignments.some((a) => a.bookId === id))) throw doors.singleBookDoor();
  return assignments;
};

const changed = () => conflict('項目狀態已變更');

const removeAndCheck = async (tx, bookIds, now) => {
  const slotIds = await doors.removeBooks(tx, bookIds);
  if (slotIds.length) await doors.markCheck(tx, slotIds, { reason: 'MANUAL_REPORT', now });
};

const placeInDoor = async (tx, report, { bookId, slot }, { adminId, now }) => {
  const current = await tx.cabinet_slots.findUnique({ where: { slot_id: Number(slot.slot_id) } });
  const reserved = await tx.cabinet_session_doors.count({
    where: { slot_id: Number(slot.slot_id), state: { not: 'failed' }, cabinet_sessions: { status: { in: doors.OPEN_SESSION_STATUSES } } }
  });
  if (!current || reserved > 0) throw assignInvalid();
  if ((await doors.booksInSlot(tx, slot.slot_id)).some((id) => id !== bookId)) throw doors.singleBookDoor();
  await doors.placeBooks(tx, {
    cabinetId: Number(report.cabinet_id), slotId: Number(slot.slot_id), bookIds: [bookId], sessionId: null, source: 'admin', now
  });
  await recordEvent(tx, {
    cabinetId: report.cabinet_id, type: 'door_placed', channel: current.lock_channel ?? null, orderId: report.order_id ?? null,
    bookId, source: 'admin', actorId: adminId,
    detail: { label: doors.labelOf(current), book_ids: [bookId], report_no: reportNo(report.report_id) }, occurredAt: now
  });
};

const apply = async (tx, report, { assignments = null, adminId = null, now }) => {
  if (report.order_id) {
    const order = await tx.orders.findUnique({ where: { order_id: Number(report.order_id) }, include: { order_items: true } });
    if (!order) throw changed();
    const bookIds = order.order_items.map((i) => Number(i.book_id));
    if (report.kind === 'deposit') {
      if (!PRE_DEPOSIT.includes(order.status)) throw changed();
      const placed = await doors.bookDoors(bookIds, { tx });
      const plan = matchDoors(assignments, bookIds.filter((id) => placed.get(id)?.cabinet_id !== Number(report.cabinet_id)));
      await orders().markDepositedInTx(tx, order);
      for (const entry of plan) await placeInDoor(tx, report, entry, { adminId, now });
      if (plan.length > 0) {
        await tx.orders.updateMany({ where: { order_id: order.order_id, slot_id: null }, data: { slot_id: Number(plan[0].slot.slot_id) } });
      }
      return;
    }
    if (!IN_CABINET.includes(order.status) || order.picked_up_at) throw changed();
    await orders().markPickedUpInTx(tx, order);
    await removeAndCheck(tx, bookIds, now);
    return;
  }

  const bookId = Number(report.book_id);
  const book = await tx.books.findUnique({ where: { book_id: bookId } });
  if (!book) throw changed();
  if (report.kind === 'deposit') {
    if (Number(book.cabinet_id) !== Number(report.cabinet_id)) throw changed();
    const open = await tx.order_items.count({ where: { book_id: bookId, orders: { status: { notIn: ORDER_FINAL_STATUSES } } } });
    if (open > 0) throw changed();
    const plan = matchDoors(assignments, [bookId]);
    await assertPreDepositRoom(tx, { cabinetId: report.cabinet_id, sellerId: book.seller_id, confirming: true });
    await deposits().registerInTx(tx, { bookId, cabinetId: Number(report.cabinet_id), now });
    for (const entry of plan) await placeInDoor(tx, report, entry, { adminId, now });
    return;
  }
  const row = await tx.book_deposits.findUnique({ where: { book_id: bookId } });
  if (!row) throw changed();
  const restore = (await deposits().restorable(row, book)) || (Boolean(report.held_on_sale) && !(await violationLocked(book)));
  await deposits().retrieveInTx(tx, { book, row, restore, now });
  if (report.held_on_sale) await tx.cabinet_manual_reports.updateMany({ where: { report_id: report.report_id }, data: { held_on_sale: false } });
  await removeAndCheck(tx, [bookId], now);
};

const reviewContext = async (db, report) => {
  const [cabinetName, order] = await Promise.all([
    cabinetNameOf(db, report.cabinet_id),
    report.order_id ? db.orders.findUnique({ where: { order_id: Number(report.order_id) }, select: { order_no: true } }) : null
  ]);
  return { cabinetName, target: targetLabel({ orderNo: order?.order_no, bookId: report.book_id }) };
};

const notifyReporter = (tx, report, { title, content }) => notify(tx, {
  userId: report.user_id,
  type: 'order',
  title,
  content,
  relatedId: Number(report.order_id ?? report.book_id),
  relatedType: report.order_id ? 'order' : 'book'
});

const review = async (report, { status, note, adminId, req, now, assignments = null }) => {
  await prisma.$transaction(async (tx) => {
    const claimed = await tx.cabinet_manual_reports.updateMany({
      where: { report_id: report.report_id, status: 'pending' },
      data: { status, pending_key: null, reviewed_by: adminId, reviewed_at: now, review_note: note, updated_at: now }
    });
    if (claimed.count === 0) throw notPending();
    const current = await tx.cabinet_manual_reports.findUnique({ where: { report_id: report.report_id } });
    if (status === 'confirmed') await apply(tx, current, { assignments, adminId, now });
    else await releaseHeld(tx, current, now);

    const { cabinetName, target } = await reviewContext(tx, report);
    const kind = KIND_LABELS[report.kind];
    await notifyReporter(tx, report, status === 'confirmed'
      ? { title: '手動回報已確認', content: `您於「${cabinetName}」的${kind}手動回報（${target}）已由客服確認。` }
      : {
          title: '手動回報未通過確認',
          content: `您於「${cabinetName}」的${kind}手動回報（${target}）未通過客服確認，狀態未變更。${note ? `說明：${note}` : ''}`
        });
    await recordEvent(tx, {
      cabinetId: report.cabinet_id, orderId: report.order_id ?? null, bookId: report.book_id ?? null,
      type: 'manual_report_reviewed', source: 'admin', actorId: adminId,
      detail: { report_no: reportNo(report.report_id), status, note: note || null }, occurredAt: now
    });
    const labels = (assignments ?? []).map((a) => doors.labelOf(a.slot));
    const doorText = labels.length > 0 ? `，存放於櫃門 ${labels.join('、')}` : '';
    await audit.record(tx, {
      adminId,
      action: status === 'confirmed' ? '確認書櫃手動回報' : '駁回書櫃手動回報',
      targetType: 'cabinet',
      targetId: Number(report.cabinet_id),
      summary: `${status === 'confirmed' ? '確認' : '駁回'}「${cabinetName}」的${kind}手動回報（${target}）${doorText}${note ? `，說明：${note}` : ''}`,
      req
    });
  });
};

const confirm = async (no, { note = null, slotId = null, doors: assigned = [] }, { adminId, req }) => {
  const report = await loadReport(no);
  if (report.status !== 'pending') throw notPending();
  await assertNotParty(report, adminId);
  const assignments = await doorsForDeposit(report, { slotId, assignments: assigned });
  const now = new Date();
  try {
    await review(report, { status: 'confirmed', note, adminId, req, now, assignments });
  } catch (err) {
    if (!(err instanceof HttpError) || err.status >= 500 || KEEP_PENDING.includes(err.code)) throw err;
    await prisma.$transaction(async (tx) => {
      const cancelled = await tx.cabinet_manual_reports.updateMany({
        where: { report_id: report.report_id, status: 'pending' },
        data: { status: 'cancelled', pending_key: null, reviewed_by: adminId, reviewed_at: now, review_note: '項目狀態已變更，回報已失效', updated_at: now }
      });
      if (cancelled.count > 0) await releaseHeld(tx, await tx.cabinet_manual_reports.findUnique({ where: { report_id: report.report_id } }), now);
    });
    throw staleReport();
  }
  return detailOf(report.report_id);
};

const reject = async (no, { note }, { adminId, req }) => {
  const report = await loadReport(no);
  if (report.status !== 'pending') throw notPending();
  await assertNotParty(report, adminId);
  await review(report, { status: 'rejected', note, adminId, req, now: new Date() });
  return detailOf(report.report_id);
};

const doorBooksOf = (report, { order, book, withDoors, placedIn }) => {
  if (report.status !== 'pending' || report.kind !== 'deposit' || !withDoors.has(Number(report.cabinet_id))) return [];
  const items = order
    ? (order.order_items ?? []).map((i) => ({ book_id: Number(i.book_id), title: i.books?.title ?? '' }))
    : book ? [{ book_id: Number(book.book_id), title: book.title }] : [];
  return items.filter((i) => placedIn.get(i.book_id) !== Number(report.cabinet_id));
};

const shapeAdmin = (report, { users = new Map(), ordersById = new Map(), books = new Map(), withDoors = new Set(), placedIn = new Map() } = {}) => {
  const user = users.get(Number(report.user_id));
  const reviewer = report.reviewed_by ? users.get(Number(report.reviewed_by)) : null;
  const order = report.order_id ? ordersById.get(Number(report.order_id)) : null;
  const book = report.book_id ? books.get(Number(report.book_id)) : null;
  const doorBooks = doorBooksOf(report, { order, book, withDoors, placedIn });
  return {
    ...shape(report),
    user: user ? { user_no: publicId.encode('user', user.user_id), nickname: user.nickname } : null,
    order: order ? { order_id: Number(order.order_id), order_no: order.order_no, status: order.status } : null,
    book: book ? { book_id: Number(book.book_id), book_no: publicId.encode('book', book.book_id), title: book.title } : null,
    titles: order ? (order.order_items ?? []).map((i) => i.books?.title ?? '') : book ? [book.title] : [],
    requires_door: doorBooks.length > 0,
    door_books: doorBooks,
    reviewer_nickname: reviewer?.nickname ?? null
  };
};

const shapeRows = async (rows) => {
  const userIds = [...new Set(rows.flatMap((r) => [r.user_id, r.reviewed_by]).filter(Boolean).map(Number))];
  const orderIds = [...new Set(rows.map((r) => r.order_id).filter(Boolean).map(Number))];
  const bookIds = [...new Set(rows.map((r) => r.book_id).filter(Boolean).map(Number))];
  const cabinetIds = [...new Set(rows.map((r) => Number(r.cabinet_id)))];
  const [users, orderRows, bookRows, doorRows] = await Promise.all([
    userIds.length ? prisma.users.findMany({ where: { user_id: { in: userIds } }, select: { user_id: true, nickname: true } }) : [],
    orderIds.length
      ? prisma.orders.findMany({
          where: { order_id: { in: orderIds } },
          select: {
            order_id: true, order_no: true, status: true, order_items: { select: { book_id: true, books: { select: { title: true } } } }
          }
        })
      : [],
    bookIds.length ? prisma.books.findMany({ where: { book_id: { in: bookIds } }, select: { book_id: true, title: true } }) : [],
    prisma.cabinet_slots.findMany({ where: { cabinet_id: { in: cabinetIds }, lock_channel: { not: null } }, select: { cabinet_id: true } })
  ]);
  const itemBookIds = [...new Set([...bookIds, ...orderRows.flatMap((o) => o.order_items.map((i) => Number(i.book_id)))])];
  const placed = itemBookIds.length
    ? await prisma.cabinet_slot_items.findMany({ where: { book_id: { in: itemBookIds } }, select: { book_id: true, cabinet_id: true } })
    : [];
  const maps = {
    users: new Map(users.map((u) => [Number(u.user_id), u])),
    ordersById: new Map(orderRows.map((o) => [Number(o.order_id), o])),
    books: new Map(bookRows.map((b) => [Number(b.book_id), b])),
    withDoors: new Set(doorRows.map((d) => Number(d.cabinet_id))),
    placedIn: new Map(placed.map((p) => [Number(p.book_id), Number(p.cabinet_id)]))
  };
  return rows.map((r) => shapeAdmin(r, maps));
};

const detailOf = async (reportId) =>
  (await shapeRows([await prisma.cabinet_manual_reports.findUnique({ where: { report_id: Number(reportId) } })]))[0];

const listForCabinet = async (cabinetId, { status = 'pending', skip = 0, limit = 20 } = {}) => {
  const cabinet = await prisma.smart_cabinets.findUnique({ where: { cabinet_id: Number(cabinetId) }, select: { cabinet_id: true } });
  if (!cabinet) throw notFound('找不到該書櫃');
  const where = { cabinet_id: Number(cabinetId), ...(STATUSES.includes(status) ? { status } : {}) };
  const [rows, total] = await Promise.all([
    prisma.cabinet_manual_reports.findMany({ where, orderBy: [{ created_at: 'desc' }, { report_id: 'desc' }], skip, take: limit }),
    prisma.cabinet_manual_reports.count({ where })
  ]);
  return { total, rows: await shapeRows(rows) };
};

module.exports = {
  PENDING, KINDS, STATUSES, KIND_LABELS, REASON_LABELS,
  isPending, submit, decorateOrders, pendingForBooks, cancelPending, confirm, reject, listForCabinet, shape
};
