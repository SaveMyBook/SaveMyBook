const prisma = require('../lib/prisma');
const publicId = require('../lib/public-id');
const { badRequest, conflict, forbidden, notFound } = require('../lib/errors');
const { ORDER_FINAL_STATUSES, ORDER_UNSETTLED_STATUSES, BOOK_STATUS_LABELS } = require('../constants/domain');
const policy = require('../constants/policy');
const { cabinetBrief, coverImage, userBrief } = require('../lib/selects');
const { notify, notifyMany } = require('./notify');
const { adminIdsWith } = require('./admin-permissions');
const audit = require('./audit');
const cabinets = require('./cabinets');
const { violationLocked } = require('./book-violations');
const { keptInCabinet } = require('./orders/settlement');
const cabinetAccess = require('./cabinet-access');
const doors = require('./cabinet-doors');

const cabinetManual = () => require('./cabinet-manual');
const candidates = () => require('./cabinet-candidates');

const DAY_MS = 24 * 60 * 60 * 1000;
const PAUSE_DAYS = policy.DEPOSIT_PAUSE_DAYS;
const REMIND_DAYS = policy.DEPOSIT_REMIND_DAYS;
const ESCALATE_DAYS = policy.DEPOSIT_ESCALATE_DAYS;
const BATCH = 100;
const IN_CABINET_ORDER = ['deposited', 'pending_pickup'];

const RETRIEVE_TITLE = '請取回書櫃中的書籍';

const daysAgo = (days, now) => new Date(now.getTime() - days * DAY_MS);

const daysStored = (row, now = new Date()) =>
  Math.max(0, Math.floor((now.getTime() - new Date(row.deposited_at).getTime()) / DAY_MS));

const summary = (row, now = new Date()) => ({
  deposited_at: row.deposited_at,
  paused: row.paused_at != null,
  days_stored: daysStored(row, now)
});

const deposited = () => conflict('此書籍已登記存放於書櫃', 'BOOK_DEPOSITED');
const notDeposited = () => conflict('此書籍目前未登記存放於書櫃', 'NOT_DEPOSITED');
const stale = () => conflict('存書狀態已變更，請重新整理後再試');

const rowOf = (bookId) => prisma.book_deposits.findUnique({ where: { book_id: bookId } });

// 所有同時更新書籍與存書紀錄的交易都先鎖書籍列，與結帳、排程、管理員下架的順序一致，避免死結。
const lockBook = (tx, bookId, now) => tx.books.updateMany({ where: { book_id: bookId }, data: { updated_at: now } });

const ownerExtras = async (books) => {
  const ids = books.map((b) => Number(b.book_id));
  const placed = await doors.bookDoors(ids);
  const placedCabinets = [...new Set([...placed.values()].map((d) => d.cabinet_id))];
  const [accessMap, names, retrievable, reports] = await Promise.all([
    cabinetAccess.accessFor([...books.map((b) => b.cabinet_id), ...placedCabinets]),
    placedCabinets.length
      ? prisma.smart_cabinets.findMany({ where: { cabinet_id: { in: placedCabinets } }, select: { cabinet_id: true, cabinet_name: true } })
      : [],
    candidates().retrievableBooks(ids),
    cabinetManual().pendingForBooks(ids)
  ]);
  const nameOf = new Map(names.map((c) => [Number(c.cabinet_id), c.cabinet_name]));
  const accessOf = (cabinetId) => (cabinetId == null ? null : cabinetAccess.publicAccess(accessMap.get(Number(cabinetId))));
  return new Map(books.map((b) => {
    const door = placed.get(Number(b.book_id));
    return [Number(b.book_id), {
      door: door?.label ?? null,
      cabinet_access: accessOf(b.cabinet_id),
      location: door
        ? {
            cabinet_id: door.cabinet_id,
            cabinet_name: nameOf.get(door.cabinet_id) ?? '',
            door: door.label,
            retrievable: retrievable.has(Number(b.book_id)),
            access: accessOf(door.cabinet_id)
          }
        : null,
      manual_report: reports.get(Number(b.book_id)) ?? null
    }];
  }));
};

const withCabinetFlag = async (books, { owner = false } = {}) => {
  if (books.length === 0) return books;
  const now = new Date();
  const rows = await prisma.book_deposits.findMany({
    where: { book_id: { in: books.map((b) => b.book_id) } },
    select: { book_id: true, cabinet_id: true, deposited_at: true, paused_at: true, smart_cabinets: { select: { is_active: true } } }
  });
  const underMaintenance = rows.length > 0 ? await cabinets.maintenanceIds() : new Set();
  const byId = new Map(rows.map((r) => [Number(r.book_id), r]));
  const extras = owner ? await ownerExtras(books) : null;
  return books.map((b) => {
    const row = byId.get(Number(b.book_id));
    const open = Boolean(row?.smart_cabinets?.is_active) && !underMaintenance.has(Number(row?.cabinet_id));
    const extra = extras?.get(Number(b.book_id));
    return {
      ...b,
      in_cabinet: Boolean(row) && open && b.status === 'on_sale',
      ...(owner && {
        deposit: row ? { ...summary(row, now), door: extra.door } : null,
        cabinet_access: extra.cabinet_access,
        location: extra.location,
        manual_report: extra.manual_report
      })
    };
  });
};

const decorate = async (book, options) => (await withCabinetFlag([book], options))[0];

const countForSeller = async (db, sellerId) => {
  const books = await db.books.findMany({ where: { seller_id: sellerId }, select: { book_id: true } });
  if (books.length === 0) return 0;
  return db.book_deposits.count({ where: { book_id: { in: books.map((b) => b.book_id) } } });
};

const assertCabinetUnchanged = async (bookId) => {
  if (await rowOf(bookId)) {
    throw conflict('此書籍已存放於書櫃，無法變更書櫃；請先至書櫃取回書籍後再變更', 'BOOK_DEPOSITED');
  }
};

const assertRelistable = async (bookId) => {
  if (await rowOf(bookId)) {
    throw conflict('此書籍仍存放於書櫃，請先至書櫃以 App 掃描 QR Code 取回後再重新上架', 'RETRIEVAL_REQUIRED');
  }
};

const assertDeletable = async (db, bookId) => {
  if (await db.book_deposits.count({ where: { book_id: bookId } })) {
    throw conflict('此書籍仍存放於書櫃，請先於書櫃管理登記取出後再刪除', 'BOOK_DEPOSITED');
  }
};

// 管理員、檢舉或審核下架的書，不得在取回結束時被當成暫停販售而改回上架。
const releaseAutoPause = async (tx, bookId) => {
  await tx.cabinet_session_items.updateMany({ where: { book_id: bookId, held_on_sale: true }, data: { held_on_sale: false } });
  await tx.cabinet_manual_reports.updateMany({ where: { book_id: bookId, held_on_sale: true }, data: { held_on_sale: false } });
  return tx.book_deposits.updateMany({ where: { book_id: bookId }, data: { auto_paused: false } });
};

const syncAdminStatus = (tx, bookId, status, now = new Date()) => (status === 'on_sale'
  ? tx.book_deposits.updateMany({
      where: { book_id: bookId, paused_at: { not: null } },
      data: { deposited_at: now, paused_at: null, reminded_at: null, escalated_at: null, auto_paused: false }
    })
  : releaseAutoPause(tx, bookId));

const ownBook = async (bookId, user, deniedMessage) => {
  const book = await prisma.books.findUnique({
    where: { book_id: bookId },
    include: { smart_cabinets: { select: { ...cabinetBrief, is_active: true } } }
  });
  if (!book) throw notFound('找不到該書籍', 'BOOK_NOT_FOUND');
  if (book.seller_id !== user.userId) throw forbidden(deniedMessage);
  return book;
};

// book 須含 smart_cabinets（cabinetBrief 與 is_active）。
const assertDepositAllowed = async (book) => {
  if (book.status !== 'on_sale' || !book.is_approved) {
    throw conflict('書籍須為上架中且已公開販售，才能存入書櫃', 'DEPOSIT_NOT_ALLOWED');
  }
  const cabinet = book.smart_cabinets;
  if (!cabinet) throw badRequest('請先於書籍資料中指定存放的書櫃', 'CABINET_REQUIRED');
  if (!cabinet.is_active) throw badRequest('此書櫃已停用，請先變更存放的書櫃', 'CABINET_UNAVAILABLE');
  if (await cabinets.isUnderMaintenance(cabinet.cabinet_id)) {
    throw badRequest('此書櫃維修中，暫時無法存書', 'CABINET_MAINTENANCE');
  }
  if (await rowOf(book.book_id)) throw deposited();
  const openOrders = await prisma.order_items.count({
    where: { book_id: book.book_id, orders: { status: { notIn: ORDER_FINAL_STATUSES } } }
  });
  if (openOrders > 0) throw conflict('此書籍已有進行中的訂單，請依訂單流程存書', 'DEPOSIT_NOT_ALLOWED');
  return cabinet;
};

const registerInTx = async (tx, { bookId, cabinetId, now = new Date() }) => {
  // 條件更新會鎖住書籍列，與結帳把書改為保留的更新互斥，避免訂單成立的同時登記存書。
  const locked = await tx.books.updateMany({
    where: { book_id: bookId, status: 'on_sale', is_approved: true },
    data: { updated_at: now }
  });
  if (locked.count === 0) throw conflict('書籍狀態已變更，請重新整理後再試');
  try {
    return await tx.book_deposits.create({ data: { book_id: bookId, cabinet_id: cabinetId, deposited_at: now } });
  } catch (err) {
    if (err?.code === 'P2002') throw deposited();
    throw err;
  }
};

// 只有賣家本人能呼叫，不會是「非當事人的管理員」，所以手動模式下一律成為待客服確認的回報（業主決策）。
const deposit = async (bookId, user) => {
  const book = await ownBook(bookId, user, '僅賣家本人可登記存書');
  const cabinet = await assertDepositAllowed(book);
  const manual = await cabinetAccess.assertManualAllowed(cabinet.cabinet_id, user, { sellerId: book.seller_id });
  return cabinetManual().submit({ kind: 'deposit', book, user, reason: manual.reason, cabinetId: cabinet.cabinet_id });
};

const restorable = async (row, book) => Boolean(row.paused_at) && Boolean(row.auto_paused)
  && book.status === 'removed' && !(await violationLocked(book));

// 存書期間與訂單進行中賣家都無法變更書籍的書櫃，恢復存書時也會同步，因此書籍的書櫃即為下單前實際存放的書櫃。
const missingDeposit = async (book) => {
  const item = await prisma.order_items.findFirst({
    where: { book_id: book.book_id, orders: { status: { in: ORDER_UNSETTLED_STATUSES }, picked_up_at: null } },
    orderBy: { item_id: 'desc' },
    select: {
      pre_deposited: true,
      orders: {
        select: {
          order_no: true, status: true, cabinet_id: true, deposited_at: true, picked_up_at: true,
          smart_cabinets: { select: { cabinet_name: true } }
        }
      }
    }
  });
  if (!item?.orders) return notDeposited();
  const { order_no: orderNo, status, cabinet_id: cabinetId, smart_cabinets: cabinet } = item.orders;
  if (status === 'refunding') {
    return keptInCabinet(item.orders, item)
      ? conflict(`此書籍已售出（訂單 ${orderNo}），訂單爭議處理中，請勿取回；如已取出，請儘速放回書櫃`, 'BOOK_SOLD_IN_CABINET')
      : notDeposited();
  }
  if (IN_CABINET_ORDER.includes(status)) {
    return conflict(`此書籍已售出（訂單 ${orderNo}），買家將至書櫃取書，請勿取回；如已取出，請儘速放回書櫃`, 'BOOK_SOLD_IN_CABINET');
  }
  if (!item.pre_deposited) return notDeposited();
  if (cabinetId !== book.cabinet_id) {
    const target = cabinet ? `「${cabinet.cabinet_name}」` : '訂單指定的書櫃';
    return conflict(`此書籍已售出（訂單 ${orderNo}），請至書櫃以 App 掃描 QR Code 取回，再存入${target}`, 'BOOK_SOLD_IN_CABINET');
  }
  return conflict(`此書籍已售出（訂單 ${orderNo}），請將書籍留在書櫃，並以 App 掃描 QR Code 辦理訂單存書`, 'BOOK_SOLD_IN_CABINET');
};

const retrieveInTx = async (tx, { book, row, restore, now = new Date() }) => {
  const bookId = Number(book.book_id);
  await lockBook(tx, bookId, now);
  // 以讀取時的暫停狀態為刪除條件：排程暫停販售或管理員下架若在讀取後才完成，須重新判斷是否恢復上架。
  const removed = await tx.book_deposits.deleteMany({
    where: { book_id: bookId, paused_at: row.paused_at, auto_paused: row.auto_paused }
  });
  if (removed.count === 0) {
    throw (await tx.book_deposits.count({ where: { book_id: bookId } })) ? stale() : await missingDeposit(book);
  }
  const relisted = restore
    ? await tx.books.updateMany({ where: { book_id: bookId, status: 'removed' }, data: { status: 'on_sale', updated_at: now } })
    : { count: 0 };
  const current = await tx.books.findUnique({ where: { book_id: bookId }, select: { status: true } });
  return { status: current?.status ?? book.status, restored: relisted.count > 0 };
};

const retrieve = async (bookId, user) => {
  const book = await ownBook(bookId, user, '僅賣家本人可回報取回書籍');
  const row = await rowOf(bookId);
  if (!row) throw await missingDeposit(book);

  const manual = await cabinetAccess.assertManualAllowed(row.cabinet_id ?? book.cabinet_id, user, { sellerId: book.seller_id });
  return cabinetManual().submit({ kind: 'retrieve', book, user, reason: manual.reason, cabinetId: row.cabinet_id });
};

const dueInclude = {
  books: {
    select: {
      book_id: true, title: true, seller_id: true, status: true, is_approved: true, users: { select: { nickname: true } }
    }
  },
  smart_cabinets: { select: { cabinet_name: true } }
};

const labelsOf = (row) => ({
  title: row.books?.title ?? '',
  cabinet: row.smart_cabinets?.cabinet_name ?? '',
  sellerId: row.books?.seller_id,
  nickname: row.books?.users?.nickname ?? ''
});

const eachDeposit = async (where, handler) => {
  const due = await prisma.book_deposits.findMany({ where, include: dueInclude, orderBy: { book_id: 'asc' }, take: BATCH });
  const result = { done: 0, flagged: 0 };
  for (const row of due) {
    try {
      if (await prisma.$transaction((tx) => handler(tx, row))) result.flagged += 1;
      result.done += 1;
    } catch (err) {
      if (err.status !== 409) console.error(`[書櫃存書自動處理失敗] book_id=${row.book_id}:`, err.message);
    }
  }
  return result;
};

const changed = () => conflict('存書狀態已變更');

const holdWhere = (now) => ({ status: 'confirmed', pickup_deadline: { gt: now } });

const outsideMaintenance = async () => {
  const ids = [...(await cabinets.maintenanceIds())];
  return ids.length > 0 ? { cabinet_id: { notIn: ids } } : {};
};

const pauseDue = async (now = new Date()) => {
  const { done, flagged } = await eachDeposit(
    {
      paused_at: null,
      deposited_at: { lte: daysAgo(PAUSE_DAYS, now) },
      ...(await outsideMaintenance()),
      books: {
        reservations: { none: holdWhere(now) },
        cabinet_session_items: { none: { held_on_sale: true } },
        cabinet_manual_reports: { none: { status: 'pending', held_on_sale: true } }
      }
    },
    async (tx, row) => {
      if (await tx.reservations.count({ where: { book_id: row.book_id, ...holdWhere(now) } })) throw changed();
      const paused = await tx.books.updateMany({
        where: { book_id: row.book_id, status: 'on_sale' },
        data: { status: 'removed', updated_at: now }
      });
      const autoPaused = paused.count > 0;
      const claimed = await tx.book_deposits.updateMany({
        where: { book_id: row.book_id, paused_at: null },
        data: { paused_at: now, reminded_at: now, auto_paused: autoPaused }
      });
      if (claimed.count === 0) throw changed();

      const { title, cabinet, sellerId } = labelsOf(row);
      const promise = autoPaused && !(await violationLocked(row.books));
      await notify(tx, {
        userId: sellerId,
        type: 'order',
        title: RETRIEVE_TITLE,
        content: `《${title}》存放於「${cabinet}」已滿 ${PAUSE_DAYS} 天仍未售出${autoPaused ? '，已暫停販售' : ''}。`
          + `請至書櫃以 App 掃描 QR Code 取回書籍${promise ? '；取回後書籍將恢復上架' : ''}。`,
        relatedId: row.book_id,
        relatedType: 'book'
      });
      return autoPaused;
    }
  );
  return { notified: done, paused: flagged };
};

const remindDue = async (now = new Date()) => (await eachDeposit(
  {
    paused_at: { not: null },
    reminded_at: { lte: daysAgo(REMIND_DAYS, now) },
    books: { users: { anonymized_at: null } },
    ...(await outsideMaintenance())
  },
  async (tx, row) => {
    const claimed = await tx.book_deposits.updateMany({
      where: { book_id: row.book_id, reminded_at: row.reminded_at },
      data: { reminded_at: now }
    });
    if (claimed.count === 0) throw changed();

    const { title, cabinet, sellerId } = labelsOf(row);
    const promise = row.books ? await restorable(row, row.books) : false;
    await notify(tx, {
      userId: sellerId,
      type: 'order',
      title: RETRIEVE_TITLE,
      content: `《${title}》已存放於「${cabinet}」${daysStored(row, now)} 天，請儘速至書櫃以 App 掃描 QR Code 取回書籍`
        + `${promise ? '；取回後書籍將恢復上架' : ''}。`,
      relatedId: row.book_id,
      relatedType: 'book'
    });
  }
)).done;

const notifyAdmins = async (db, sellerId, bookId, { title, content }) => {
  const adminIds = (await adminIdsWith('cabinets')).filter((id) => id !== sellerId);
  if (adminIds.length === 0) return;
  await notifyMany(db, adminIds, {
    title,
    content,
    relatedId: bookId,
    relatedType: 'cabinet_deposit'
  });
};

const escalateDue = async (now = new Date()) => (await eachDeposit(
  { escalated_at: null, deposited_at: { lte: daysAgo(ESCALATE_DAYS, now) }, ...(await outsideMaintenance()) },
  async (tx, row) => {
    const claimed = await tx.book_deposits.updateMany({
      where: { book_id: row.book_id, escalated_at: null },
      data: { escalated_at: now }
    });
    if (claimed.count === 0) throw changed();

    const { title, cabinet, sellerId, nickname } = labelsOf(row);
    await notifyAdmins(tx, sellerId, row.book_id, {
      title: '書櫃書籍逾期未取回',
      content: `賣家「${nickname}」存放於「${cabinet}」的《${title}》已滿 ${daysStored(row, now)} 天仍未取回，請安排人員處理。`
    });
  }
)).done;

const runAutomation = async (now = new Date()) => {
  const { notified, paused } = await pauseDue(now);
  return { notified, paused, reminded: await remindDue(now), escalated: await escalateDue(now) };
};

const retainForDeletedSeller = async (tx, sellerId, now = new Date()) => {
  const books = await tx.books.findMany({ where: { seller_id: sellerId }, select: { book_id: true, title: true } });
  if (books.length === 0) return 0;
  const rows = await tx.book_deposits.findMany({ where: { book_id: { in: books.map((b) => b.book_id) } } });
  if (rows.length === 0) return 0;

  const titles = new Map(books.map((b) => [Number(b.book_id), b.title]));
  const names = new Map((await tx.smart_cabinets.findMany({
    where: { cabinet_id: { in: [...new Set(rows.map((r) => r.cabinet_id))] } },
    select: { cabinet_id: true, cabinet_name: true }
  })).map((c) => [Number(c.cabinet_id), c.cabinet_name]));

  for (const row of rows) {
    await tx.book_deposits.update({
      where: { book_id: row.book_id },
      data: { paused_at: row.paused_at ?? now, auto_paused: false, reminded_at: now, escalated_at: now }
    });
    await notifyAdmins(tx, sellerId, row.book_id, {
      title: '書櫃書籍待人員取出',
      content: `賣家帳號已刪除，《${titles.get(Number(row.book_id)) ?? ''}》仍存放於「${names.get(Number(row.cabinet_id)) ?? ''}」，請安排人員取出。`
    });
  }
  return rows.length;
};

const adminInclude = {
  books: {
    select: {
      book_id: true, title: true, status: true, seller_id: true, book_images: coverImage,
      users: { select: { ...userBrief, anonymized_at: true } }
    }
  },
  smart_cabinets: { select: cabinetBrief }
};

const shapeAdmin = (row, now, door = null) => {
  const seller = row.books?.users;
  const days = daysStored(row, now);
  return {
    book_id: row.book_id,
    book_no: publicId.encode('book', row.book_id),
    title: row.books?.title ?? '',
    book_status: row.books?.status ?? null,
    image_url: row.books?.book_images?.[0]?.image_url ?? null,
    seller: seller
      ? {
          user_id: seller.user_id,
          user_no: publicId.encode('user', seller.user_id),
          nickname: seller.nickname,
          avatar_url: seller.avatar_url,
          deleted: seller.anonymized_at != null
        }
      : null,
    cabinet: row.smart_cabinets ?? null,
    deposited_at: row.deposited_at,
    days_stored: days,
    paused: row.paused_at != null,
    paused_at: row.paused_at,
    reminded_at: row.reminded_at,
    escalated: row.escalated_at != null,
    escalated_at: row.escalated_at,
    overdue: days >= ESCALATE_DAYS || row.escalated_at != null,
    door: door ? { slot_id: door.slot_id, label: door.label } : null
  };
};

const adminList = async ({ overdue = false, cabinetId = null, skip, limit }, now = new Date()) => {
  const where = {
    ...(overdue && { OR: [{ deposited_at: { lte: daysAgo(ESCALATE_DAYS, now) } }, { escalated_at: { not: null } }] }),
    ...(cabinetId && { cabinet_id: cabinetId })
  };
  const [rows, total] = await Promise.all([
    prisma.book_deposits.findMany({
      where,
      include: adminInclude,
      orderBy: [{ deposited_at: 'asc' }, { book_id: 'asc' }],
      skip,
      take: limit
    }),
    prisma.book_deposits.count({ where })
  ]);
  const placed = await doors.bookDoors(rows.map((r) => r.book_id));
  return { total, rows: rows.map((r) => shapeAdmin(r, now, placed.get(Number(r.book_id)))) };
};

const notifyTakenOut = (tx, { sellerId, bookId, title, cabinet }) => notify(tx, {
  userId: sellerId,
  type: 'order',
  title: '書櫃中的書籍已由客服取出',
  content: `《${title}》已由客服人員自「${cabinet}」取出並下架，本平台將代為保管 ${policy.DEPOSIT_REMOVED_KEEP_DAYS} 日。請於期限內聯絡客服，至指定地點免費領回或申請寄回（運費由您負擔，貨到付款）；逾期未領回者視為拋棄。`,
  relatedId: bookId,
  relatedType: 'book'
});

// row 須以 adminInclude 讀取。回傳書籍是否因此改為下架。
const adminClearInTx = async (tx, { row, adminId, req, now = new Date() }) => {
  const bookId = Number(row.book_id);
  const shaped = shapeAdmin(row, now);
  const cabinet = row.smart_cabinets?.cabinet_name ?? '';
  const sellerId = row.books?.seller_id;
  const notifySeller = Boolean(sellerId) && !shaped.seller?.deleted;

  await lockBook(tx, bookId, now);
  const removed = await tx.book_deposits.deleteMany({ where: { book_id: bookId } });
  if (removed.count === 0) throw conflict('存書紀錄已變更，請重新整理後再試');
  const paused = await tx.books.updateMany({
    where: { book_id: bookId, status: 'on_sale' },
    data: { status: 'removed', updated_at: now }
  });
  await doors.removeBooks(tx, [bookId]);
  if (notifySeller) await notifyTakenOut(tx, { sellerId, bookId, title: shaped.title, cabinet });
  await audit.record(tx, {
    adminId,
    action: '登記書櫃書籍取出',
    targetType: 'book',
    targetId: bookId,
    summary: `登記《${shaped.title}》已由人員自「${cabinet}」取出（賣家：${shaped.seller?.nickname ?? '－'}，存放 ${shaped.days_stored} 天）`
      + `${paused.count > 0 ? '，書籍改為下架' : ''}${notifySeller ? '，並通知賣家' : ''}`,
    changes: paused.count > 0
      ? [{ field: 'status', label: '狀態', from: BOOK_STATUS_LABELS.on_sale, to: BOOK_STATUS_LABELS.removed }]
      : [],
    req
  });
  return paused.count > 0;
};

const adminClear = async (bookId, { adminId, req }, now = new Date()) => {
  const row = await prisma.book_deposits.findUnique({ where: { book_id: bookId }, include: adminInclude });
  if (!row) throw notFound('找不到此書籍的存書紀錄');

  const delisted = await prisma.$transaction((tx) => adminClearInTx(tx, { row, adminId, req, now }));
  return { book_id: bookId, book_status: delisted ? 'removed' : row.books?.status ?? null };
};

module.exports = {
  PAUSE_DAYS, REMIND_DAYS, ESCALATE_DAYS, RETRIEVE_TITLE, adminInclude,
  withCabinetFlag, decorate, countForSeller, assertCabinetUnchanged, assertRelistable, assertDeletable,
  releaseAutoPause, syncAdminStatus, deposit, retrieve, pauseDue, remindDue, escalateDue, runAutomation,
  retainForDeletedSeller, adminList, adminClear,
  rowOf, restorable, missingDeposit, lockBook, assertDepositAllowed, registerInTx, retrieveInTx, adminClearInTx, notifyTakenOut
};
