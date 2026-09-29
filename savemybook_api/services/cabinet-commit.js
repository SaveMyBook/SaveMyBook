const prisma = require('../lib/prisma');
const { HttpError, conflict } = require('../lib/errors');
const { ORDER_FINAL_STATUSES } = require('../constants/domain');
const orders = require('./orders');
const deposits = require('./book-deposits');
const doors = require('./cabinet-doors');
const { recordEvent, notifyAdmins } = require('./cabinet-events');

const sessions = () => require('./cabinet-sessions');
const manual = () => require('./cabinet-manual');
const candidates = () => require('./cabinet-candidates');

const CLOSABLE = ['opening', 'open', 'needs_review'];
const TERMINAL = ['completed', 'partial', 'cancelled', 'failed', 'expired'];
const DEPOSIT_KINDS = ['order_deposit', 'pre_deposit'];
const TAKE_KINDS = ['pickup', 'retrieval'];
const IN_CABINET = ['deposited', 'pending_pickup'];
const PRE_DEPOSIT = ['pending_payment', 'pending_deposit'];
const ADMIN_REASONS = ['admin', 'admin_discard'];

const notReviewable = () => new HttpError(409, '此作業目前無法由客服處理', 'SESSION_NOT_REVIEWABLE');
const itemChanged = () => conflict('項目狀態已變更', 'ITEM_CHANGED');

// 業務規則造成的失敗記為 ITEM_CHANGED；其餘（例如資料庫連線中斷）向上拋出，交由裝置重送或排程續做，不可記為失敗。
const isBusinessError = (err) => (err instanceof HttpError && err.status < 500) || ['P2002', 'P2025'].includes(err?.code);

const unitKey = (item) => (['pickup', 'order_deposit'].includes(item.kind) ? `order:${item.order_id}` : `book:${item.book_id}`);

const groupUnits = (items) => {
  const units = new Map();
  for (const item of items) {
    const key = unitKey(item);
    if (!units.has(key)) units.set(key, { key, kind: item.kind, order_id: item.order_id ?? null, items: [] });
    units.get(key).items.push(item);
  }
  return [...units.values()];
};

// 同一作業、同一原因已設為待確認的櫃門不重複記錄，重跑提交時才不會多出事件。
const markOnce = async (tx, slotIds, { reason, sessionId, now }) => {
  const ids = [...new Set(slotIds.map(Number))];
  if (ids.length === 0) return [];
  const slots = await tx.cabinet_slots.findMany({ where: { slot_id: { in: ids } } });
  const todo = slots.filter((s) => !(s.check_required_at && Number(s.check_session_id) === Number(sessionId) && s.check_reason === reason))
    .map((s) => Number(s.slot_id));
  if (todo.length) await doors.markCheck(tx, todo, { reason, sessionId, now });
  return todo;
};

const commitPickup = async (tx, session, unit, now) => {
  const order = await tx.orders.findUnique({ where: { order_id: Number(unit.order_id) }, include: { order_items: true } });
  if (!order || Number(order.buyer_id) !== Number(session.user_id) || Number(order.cabinet_id) !== Number(session.cabinet_id)
    || !IN_CABINET.includes(order.status) || order.picked_up_at) {
    throw itemChanged();
  }
  await orders.markPickedUpInTx(tx, order);
  const bookIds = order.order_items.map((i) => Number(i.book_id));
  const placed = await doors.bookDoors(bookIds, { tx });
  await doors.removeBooks(tx, bookIds.filter((id) => placed.get(id)?.cabinet_id === Number(session.cabinet_id)));
  await manual().cancelPending(tx, { orderId: order.order_id, kinds: ['pickup'], now });
};

const commitOrderDeposit = async (tx, session, unit, now) => {
  const order = await tx.orders.findUnique({ where: { order_id: Number(unit.order_id) }, include: { order_items: true } });
  if (!order || Number(order.seller_id) !== Number(session.user_id) || Number(order.cabinet_id) !== Number(session.cabinet_id)
    || !PRE_DEPOSIT.includes(order.status)) {
    throw itemChanged();
  }
  await orders.markDepositedInTx(tx, order);
  if (!order.slot_id) {
    const slotIds = [...new Set(unit.items.map((i) => i.slot_id).filter(Boolean).map(Number))];
    const slots = slotIds.length
      ? await tx.cabinet_slots.findMany({ where: { slot_id: { in: slotIds } }, select: { slot_id: true, lock_channel: true } })
      : [];
    const primary = slots.sort((a, b) => (a.lock_channel ?? 999) - (b.lock_channel ?? 999))[0];
    if (primary) await tx.orders.updateMany({ where: { order_id: order.order_id, slot_id: null }, data: { slot_id: Number(primary.slot_id) } });
  }
  await manual().cancelPending(tx, { orderId: order.order_id, kinds: ['deposit'], now });
};

const commitPreDeposit = async (tx, session, unit, now) => {
  const bookId = Number(unit.items[0].book_id);
  const book = await tx.books.findUnique({ where: { book_id: bookId } });
  if (!book || Number(book.seller_id) !== Number(session.user_id) || Number(book.cabinet_id) !== Number(session.cabinet_id)) {
    throw itemChanged();
  }
  const open = await tx.order_items.count({ where: { book_id: bookId, orders: { status: { notIn: ORDER_FINAL_STATUSES } } } });
  if (open > 0) throw itemChanged();
  await deposits.registerInTx(tx, { bookId, cabinetId: Number(session.cabinet_id), now });
  await manual().cancelPending(tx, { bookId, kinds: ['deposit'], now });
};

const commitRetrieval = async (tx, session, unit, now) => {
  const bookIds = unit.items.map((i) => Number(i.book_id));
  const [placed, openOrders] = await Promise.all([doors.bookDoors(bookIds, { tx }), candidates().openOrderOf(tx, bookIds)]);
  for (const bookId of bookIds) {
    const book = await tx.books.findUnique({ where: { book_id: bookId } });
    const item = openOrders.get(bookId);
    if (!book || Number(book.seller_id) !== Number(session.user_id)
      || placed.get(bookId)?.cabinet_id !== Number(session.cabinet_id)
      || !candidates().retrievalRule(book, item, session.cabinet_id)) {
      throw itemChanged();
    }
    const row = await tx.book_deposits.findUnique({ where: { book_id: bookId } });
    if (row) {
      const restore = await deposits.restorable(row, book);
      await deposits.retrieveInTx(tx, { book, row, restore, now });
    }
    // 已售出的書被取出後不再存放於原書櫃；不清除此標記，訂單取消時會依它在原書櫃重建存書登記。
    if (item?.pre_deposited) {
      await tx.order_items.updateMany({
        where: { book_id: bookId, order_id: Number(item.orders.order_id), pre_deposited: true }, data: { pre_deposited: false }
      });
    }
    await manual().cancelPending(tx, { bookId, kinds: ['retrieve'], now });
  }
  await doors.removeBooks(tx, bookIds);
};

const commitUnit = async (tx, session, unit, now) => {
  if (unit.kind === 'pickup') return commitPickup(tx, session, unit, now);
  if (unit.kind === 'order_deposit') return commitOrderDeposit(tx, session, unit, now);
  if (unit.kind === 'pre_deposit') return commitPreDeposit(tx, session, unit, now);
  return commitRetrieval(tx, session, unit, now);
};

// 客服確認完成時，已送出開門指令而未收到回報的櫃門視為客服已確認開啟。
const doorClassifier = (doorList, { adminCommit = false } = {}) => {
  const bySlot = new Map(doorList.map((d) => [d.slot_id, d]));
  return (slotId) => {
    if (!slotId) return 'not_opened';
    const door = bySlot.get(Number(slotId));
    if (!door) return 'placed';
    if (door.state === 'open' || door.state === 'closed') return 'opened';
    if (door.state === 'pending' && door.command_served_at) return adminCommit ? 'opened' : 'unconfirmed';
    return 'not_opened';
  };
};

// 存書類項目的實體位置必須先於業務提交寫入：業務提交失敗時，書仍在門內。
const placeDeposits = async (session, selected, classify, now) => {
  const conflicts = new Set();
  const bySlot = new Map();
  for (const item of selected) {
    if (!DEPOSIT_KINDS.includes(item.kind) || classify(item.slot_id) !== 'opened') continue;
    const slotId = Number(item.slot_id);
    if (!bySlot.has(slotId)) bySlot.set(slotId, []);
    bySlot.get(slotId).push(item);
  }
  for (const [slotId, items] of bySlot) {
    await prisma.$transaction(async (tx) => {
      const bookIds = items.map((i) => Number(i.book_id));
      const orderIds = [...new Set(items.map((i) => i.order_id).filter(Boolean).map(Number))];
      const orderBooks = orderIds.length
        ? (await tx.order_items.findMany({ where: { order_id: { in: orderIds } }, select: { book_id: true } })).map((i) => Number(i.book_id))
        : [];
      const allowed = new Set([...bookIds, ...orderBooks]);
      const foreign = (await doors.booksInSlot(tx, slotId)).filter((id) => !allowed.has(id));
      await doors.placeBooks(tx, {
        cabinetId: Number(session.cabinet_id), slotId, bookIds, sessionId: Number(session.session_id), source: 'session', now
      });
      if (foreign.length) {
        conflicts.add(slotId);
        await markOnce(tx, [slotId], { reason: 'DOOR_CONFLICT', sessionId: session.session_id, now });
      }
    });
  }
  return conflicts;
};

// 一個單位內只要有一本不能提交，整個單位都不提交，否則會出現只登記部分書籍的訂單。
const settleBlocked = async (session, units, classify, conflicts, outcome, now) => {
  const unconfirmed = new Set();
  await prisma.$transaction(async (tx) => {
    for (const unit of units) {
      let code = null;
      for (const item of unit.items) {
        const state = classify(item.slot_id);
        if (state === 'unconfirmed') unconfirmed.add(Number(item.slot_id));
        if (code) continue;
        if (state === 'not_opened') code = 'DOOR_FAILED';
        else if (state === 'unconfirmed') code = 'DOOR_UNCONFIRMED';
        else if (conflicts.has(Number(item.slot_id))) code = 'DOOR_CONFLICT';
      }
      if (outcome === 'cancelled') {
        await tx.cabinet_session_items.updateMany({
          where: { item_id: { in: unit.items.map((i) => i.item_id) }, result: 'pending' }, data: { result: 'skipped' }
        });
      } else if (code) {
        await tx.cabinet_session_items.updateMany({
          where: { item_id: { in: unit.items.map((i) => i.item_id) }, result: 'pending' }, data: { result: 'failed', error_code: code }
        });
        unit.blocked = true;
      }
    }
    await tx.cabinet_session_items.updateMany({
      where: { session_id: Number(session.session_id), selected: false, result: 'pending' }, data: { result: 'skipped' }
    });
    if (session.kind === 'user' && unconfirmed.size) {
      await markOnce(tx, [...unconfirmed], { reason: 'DOOR_UNCONFIRMED', sessionId: session.session_id, now });
    }
  });
};

const commitUnits = async (session, units, now) => {
  for (const unit of units) {
    if (unit.blocked) continue;
    const ids = unit.items.map((i) => i.item_id);
    try {
      await prisma.$transaction(async (tx) => {
        const claimed = await tx.cabinet_session_items.updateMany({ where: { item_id: { in: ids }, result: 'pending' }, data: { result: 'done' } });
        if (claimed.count !== ids.length) return;
        await module.exports.commitUnit(tx, session, unit, now);
      });
    } catch (err) {
      if (!isBusinessError(err)) throw err;
      await prisma.cabinet_session_items.updateMany({
        where: { item_id: { in: ids }, result: 'pending' }, data: { result: 'failed', error_code: 'ITEM_CHANGED' }
      });
    }
  }
};

const outcomeOf = (session, items) => {
  const byAdmin = ADMIN_REASONS.includes(session.close_reason);
  if (session.close_outcome === 'cancelled') {
    return { status: 'cancelled', code: byAdmin ? 'ADMIN_RESOLVED_DISCARD' : 'CANCELLED_AFTER_OPEN' };
  }
  const selected = items.filter((i) => i.selected);
  const done = selected.filter((i) => i.result === 'done').length;
  let status = 'completed';
  let code = 'COMPLETED';
  if (done < selected.length) {
    status = 'partial';
    code = done > 0 ? 'PARTIAL' : 'ITEMS_FAILED';
  }
  return { status, code: byAdmin ? 'ADMIN_RESOLVED_COMMIT' : code };
};

const RESOLVED_TEXT = { completed: '完成', partial: '部分完成', cancelled: '確認未完成，狀態未變更' };

const finish = async (session, classify, doorList, now) => {
  const items = await prisma.cabinet_session_items.findMany({ where: { session_id: Number(session.session_id) } });
  const { status, code } = outcomeOf(session, items);
  const byAdmin = ADMIN_REASONS.includes(session.close_reason);
  const wasReview = session.status === 'needs_review';
  const opened = doorList.filter((d) => classify(d.slot_id) === 'opened');
  const labelOf = new Map(doorList.map((d) => [d.slot_id, d.label]));
  const selected = items.filter((i) => i.selected);
  const no = sessions().sessionNo(session.session_id);
  const name = session.smart_cabinets?.cabinet_name ?? '';

  const finished = await prisma.$transaction(async (tx) => {
    const done = await sessions().finalize(tx, session, { from: CLOSABLE, status, resultCode: code, now, byVersion: false });
    if (!done) return false;

    if (session.kind === 'admin') {
      const touched = doorList.filter((d) => ['opened', 'unconfirmed'].includes(classify(d.slot_id))).map((d) => d.slot_id);
      await markOnce(tx, touched, { reason: 'ADMIN_OPEN', sessionId: session.session_id, now });
    } else if (session.close_outcome === 'cancelled') {
      const depositSlots = new Set(selected.filter((i) => DEPOSIT_KINDS.includes(i.kind)).map((i) => Number(i.slot_id)));
      const touched = opened.filter((d) => depositSlots.has(d.slot_id)).map((d) => d.slot_id);
      await markOnce(tx, touched, { reason: byAdmin ? 'DISCARDED_AFTER_OPEN' : 'CANCELLED_AFTER_OPEN', sessionId: session.session_id, now });
    } else {
      // 取書或取回提交失敗而櫃門曾開啟：書可能已被取走，紀錄卻仍在門內。
      const taken = selected.filter((i) => TAKE_KINDS.includes(i.kind) && i.result === 'failed' && i.error_code === 'ITEM_CHANGED'
        && classify(i.slot_id) === 'opened').map((i) => Number(i.slot_id));
      await markOnce(tx, taken, { reason: 'ITEM_FAILED_AFTER_OPEN', sessionId: session.session_id, now });
    }

    if (byAdmin) {
      await recordEvent(tx, {
        cabinetId: session.cabinet_id, deviceId: session.device_id, sessionId: session.session_id, type: 'review_resolved',
        actorId: session.reviewed_by ?? null,
        detail: { action: session.close_outcome === 'completed' ? 'commit' : 'discard', note: session.review_note ?? null },
        source: 'admin', occurredAt: now
      });
    }

    if (session.kind === 'user') {
      if (session.close_outcome === 'cancelled' && !byAdmin && opened.length) {
        await notifyAdmins(tx, session.cabinet_id, {
          title: '書櫃作業開門後取消',
          content: `「${name}」的書櫃作業 ${no} 於櫃門開啟後取消，請確認櫃門 ${opened.map((d) => d.label).join('、')} 內的書籍是否與紀錄相符。`
        });
      }
      const troubled = [...new Set(selected
        .filter((i) => i.result === 'failed' && ['opened', 'unconfirmed'].includes(classify(i.slot_id)))
        .map((i) => Number(i.slot_id)))];
      if (troubled.length) {
        await notifyAdmins(tx, session.cabinet_id, {
          title: '書櫃作業部分未完成',
          content: `「${name}」的書櫃作業 ${no} 有項目未能完成，請確認櫃門 ${troubled.map((id) => labelOf.get(id)).filter(Boolean).join('、')} 內的書籍是否與紀錄相符。`
        });
      }
      if (wasReview) {
        await sessions().notifyInitiator(tx, session, {
          title: '書櫃作業已確認',
          content: `您於「${name}」的書櫃作業 ${no} 已${RESOLVED_TEXT[status]}。`
        });
      } else if (status === 'partial') {
        await sessions().notifyInitiator(tx, session, {
          title: '書櫃作業未全部完成',
          content: `您於「${name}」的書櫃作業 ${no} 有項目未能完成，請查看訂單或書籍狀態；如有疑問，請聯絡客服。`
        });
      }
    }
    return true;
  });
  if (finished) await sessions().publish(session.session_id);
};

// 可重複呼叫（3.10）：不論在哪一步中斷，重送關門回報或由排程續做都會得到相同結果，且不重複提交。
const commitSession = async (sessionId, { outcome = null, reason = null, source = 'device', actorId = null, note = null, now = new Date() } = {}) => {
  const id = Number(sessionId);
  if (outcome) {
    await prisma.cabinet_sessions.updateMany({
      where: { session_id: id, status: { in: source === 'admin' ? ['needs_review'] : CLOSABLE }, closed_at: null },
      data: {
        closed_at: now, close_outcome: outcome, close_reason: reason, version: { increment: 1 },
        ...(source === 'admin' && { reviewed_by: actorId, reviewed_at: now, review_note: note })
      }
    });
  }
  const session = await sessions().loadSession(id);
  if (!session) return { status: 'rejected', code: 'STALE' };
  if (TERMINAL.includes(session.status)) return { status: 'ok' };
  if (!CLOSABLE.includes(session.status) || !session.closed_at || !session.close_outcome) {
    if (source === 'admin') throw notReviewable();
    return { status: 'rejected', code: 'STALE' };
  }

  const doorList = sessions().sessionDoors(session);
  const classify = doorClassifier(doorList, { adminCommit: session.close_reason === 'admin' && session.close_outcome === 'completed' });
  const selected = (session.cabinet_session_items ?? []).filter((i) => i.selected);
  const units = groupUnits(selected);

  const conflicts = session.close_outcome === 'completed' ? await placeDeposits(session, selected, classify, now) : new Set();
  await settleBlocked(session, units, classify, conflicts, session.close_outcome, now);
  if (session.close_outcome === 'completed') await commitUnits(session, units, now);
  await finish(session, classify, doorList, now);
  return { status: 'ok' };
};

module.exports = { commitSession, commitUnit, isBusinessError, markOnce };
