const crypto = require('crypto');
const prisma = require('../lib/prisma');
const publicId = require('../lib/public-id');
const { HttpError, badRequest, notFound } = require('../lib/errors');
const { ORDER_UNSETTLED_STATUSES } = require('../constants/domain');
const policy = require('../constants/policy');
const { coverImage } = require('../lib/selects');
const { notify } = require('./notify');
const audit = require('./audit');
const realtime = require('./realtime');
const access = require('./cabinet-access');
const challenges = require('./cabinet-challenges');
const devices = require('./cabinet-devices');
const doors = require('./cabinet-doors');
const candidates = require('./cabinet-candidates');
const commit = require('./cabinet-commit');
const { recordEvent, notifyAdmins, parseDetail } = require('./cabinet-events');
const { violationLocked } = require('./book-violations');

const deposits = () => require('./book-deposits');
const cabinetAdmin = () => require('./cabinet-admin');

const REVIEW_GRACE_MS = 180000;
const COMMIT_STALL_MS = 60000;
const RESULT_HOLD_MS = 4000;
const ADMIN_OPEN_MS = 120000;
const LATE_EVENT_MS = 86400000;
const BLOCKED_NOTIFY_MS = 86400000;
const SWEEP_BATCH = 100;

const ACTIVE = ['selecting', 'matching', 'opening', 'open'];
const TERMINAL = ['completed', 'partial', 'cancelled', 'failed', 'expired'];
const CLOSABLE = ['opening', 'open', 'needs_review'];
const STATUSES = [...ACTIVE, 'needs_review', ...TERMINAL];
const COOLDOWN_CODES = ['SELECT_TIMEOUT', 'MATCH_TIMEOUT', 'MATCH_FAILED', 'CANCELLED_BY_USER'];
const DEPOSIT_KINDS = candidates.DEPOSIT_KINDS;
const ORDER_KINDS = ['pickup', 'order_deposit'];
const CLOSE_REASONS = ['button', 'timeout', 'sensor', 'cancel_button', 'reboot'];
const DOOR_CLOSE_REASONS = ['button', 'timeout', 'sensor'];

const RESULT_MESSAGES = {
  COMPLETED: '作業完成',
  PARTIAL: '部分項目未完成',
  ITEMS_FAILED: '項目未能完成，請查看各項目說明',
  MATCH_FAILED: '數字不符，本次作業已取消',
  MATCH_TIMEOUT: '未於時限內完成數字確認，本次作業已取消',
  SELECT_TIMEOUT: '未於時限內確認項目，本次作業已取消',
  DEVICE_NO_RESPONSE: '書櫃未回應，櫃門未開啟，請稍後再試',
  CANCELLED_BY_USER: '本次作業已取消',
  CANCELLED_AT_CABINET: '已於書櫃取消，狀態未變更',
  DEVICE_NO_ACK: '未收到書櫃的開門回報，本次作業待客服確認',
  DEVICE_LOST: '書櫃連線異常，本次作業待客服確認',
  DEVICE_INTERRUPTED: '書櫃重新啟動，本次作業待客服確認',
  ADMIN_RESOLVED_COMMIT: '客服已確認完成',
  ADMIN_RESOLVED_DISCARD: '客服已確認未完成，狀態未變更',
  ADMIN_CANCELLED: '客服已結束本次作業'
};

const ITEM_ERRORS = {
  ITEM_CHANGED: '項目狀態已變更，本項目未完成',
  DOOR_FAILED: '櫃門未能開啟，本項目未完成',
  DOOR_UNCONFIRMED: '未收到櫃門開啟回報，本項目待客服確認',
  DOOR_CONFLICT: '櫃門內有其他項目，本項目待客服確認'
};

const OPEN_CODES = { pickup: 'OPEN_PICKUP', deposit: 'OPEN_DEPOSIT', retrieve: 'OPEN_RETRIEVE', mixed: 'OPEN_MIXED', admin: 'OPEN_ADMIN' };
// 存書單位的容量受阻（CABINET_FULL）於開始時由分配重新判斷；櫃門問題與先行存書上限則視為項目已變更。
const RECHECK_BLOCKS = [...candidates.DOOR_CODES, 'PREDEPOSIT_LIMIT'];
const RESTART_CODES = ['CABINET_SELECTION_STALE', 'PREDEPOSIT_LIMIT'];

// ---------- 錯誤 ----------

const sessionNotFound = () => notFound('找不到此書櫃作業', 'CABINET_SESSION_NOT_FOUND');
const notReviewable = () => new HttpError(409, '此作業目前無法由客服處理', 'SESSION_NOT_REVIEWABLE');
const noSelection = () => badRequest('請至少選擇一個項目', 'CABINET_NO_SELECTION');
const codeExpired = () => new HttpError(410, '書櫃 QR Code 已更新，請重新掃描書櫃螢幕上的 QR Code', 'CABINET_CODE_EXPIRED');
const restartSelection = () => Object.assign(new Error('所選項目已變更'), { code: 'CABINET_SELECTION_STALE' });
const sessionSelfReview = () => new HttpError(403, '此書櫃作業與您本人相關，須由其他管理員處理', 'SESSION_SELF_REVIEW');
const doorNotEmpty = () => new HttpError(409, '櫃門內有存放紀錄或待確認，須由現場人員完成數字確認後開啟', 'DOOR_NOT_EMPTY');

// ---------- 讀取與格式 ----------

const sessionNo = (id) => publicId.encode('cabinet_session', id);

const sessionInclude = {
  cabinet_session_items: { orderBy: { item_id: 'asc' } },
  cabinet_session_doors: { include: { cabinet_slots: { select: { slot_id: true, slot_number: true, lock_channel: true } } } },
  smart_cabinets: true
};

const loadSession = (sessionId, db = prisma) =>
  db.cabinet_sessions.findUnique({ where: { session_id: Number(sessionId) }, include: sessionInclude });

const loadByNo = async (no) => {
  const id = publicId.decode('cabinet_session', no);
  return id === null ? null : loadSession(id);
};

const sessionDoors = (session) => (session.cabinet_session_doors ?? []).map((d) => ({
  slot_id: Number(d.slot_id),
  channel: d.lock_channel,
  label: doors.doorLabel(d.lock_channel),
  state: d.state,
  command_served_at: d.command_served_at ?? null,
  opened_at: d.opened_at ?? null,
  closed_at: d.closed_at ?? null,
  close_reason: d.close_reason ?? null
})).sort((a, b) => a.channel - b.channel);

const unitKeyOf = (item) => (ORDER_KINDS.includes(item.kind) ? `order:${item.order_id}` : `book:${item.book_id}`);

const groupItems = (items) => {
  const units = new Map();
  for (const item of items) {
    const key = unitKeyOf(item);
    if (!units.has(key)) units.set(key, { key, kind: item.kind, order_id: item.order_id ?? null, items: [] });
    units.get(key).items.push(item);
  }
  return units;
};

const remainingOf = (session, now) => {
  if (['selecting', 'matching', 'opening'].includes(session.status)) {
    return session.phase_deadline ? Math.max(0, new Date(session.phase_deadline).getTime() - now.getTime()) : null;
  }
  if (session.status === 'open' && session.opened_at && session.open_ms) {
    return Math.max(0, new Date(session.opened_at).getTime() + Number(session.open_ms) - now.getTime());
  }
  return null;
};

const cabinetShape = (cabinet) => {
  const hours = access.hoursOf(cabinet);
  return {
    cabinet_id: Number(cabinet.cabinet_id),
    cabinet_name: cabinet.cabinet_name,
    address: cabinet.address,
    latitude: cabinet.latitude === null || cabinet.latitude === undefined ? null : Number(cabinet.latitude),
    longitude: cabinet.longitude === null || cabinet.longitude === undefined ? null : Number(cabinet.longitude),
    open_time: hours.open_time,
    close_time: hours.close_time,
    available_doors: cabinet.available_slots === null || cabinet.available_slots === undefined ? null : Number(cabinet.available_slots)
  };
};

const presentUnits = async (units, { admin = false, labels = new Map() } = {}) => {
  const slotIds = [...new Set(units.flatMap((u) => u.books.map((b) => b.slot_id)).filter((id) => id && !labels.has(id)))];
  const slots = slotIds.length
    ? await prisma.cabinet_slots.findMany({ where: { slot_id: { in: slotIds } }, select: { slot_id: true, slot_number: true, lock_channel: true } })
    : [];
  const labelOf = new Map(labels);
  for (const slot of slots) labelOf.set(Number(slot.slot_id), doors.labelOf(slot));
  const channelOf = new Map(slots.map((s) => [Number(s.slot_id), s.lock_channel ?? 999]));

  const moveIds = units.filter((u) => u.note === 'MOVE_TO_ORDER_CABINET').flatMap((u) => u.books.map((b) => b.book_id));
  const openOrders = moveIds.length ? await candidates.openOrderOf(prisma, moveIds) : new Map();

  let people = null;
  if (admin) {
    const orderIds = [...new Set(units.map((u) => u.order_id).filter(Boolean))];
    const bookIds = [...new Set(units.flatMap((u) => u.books.map((b) => b.book_id)))];
    const [orderRows, bookRows] = await Promise.all([
      orderIds.length
        ? prisma.orders.findMany({ where: { order_id: { in: orderIds } }, select: { order_id: true, users_orders_buyer_idTousers: { select: { nickname: true } } } })
        : [],
      bookIds.length ? prisma.books.findMany({ where: { book_id: { in: bookIds } }, select: { book_id: true, users: { select: { nickname: true } } } }) : []
    ]);
    people = {
      buyer: new Map(orderRows.map((o) => [Number(o.order_id), o.users_orders_buyer_idTousers?.nickname ?? null])),
      seller: new Map(bookRows.map((b) => [Number(b.book_id), b.users?.nickname ?? null]))
    };
  }

  return units.map((unit) => {
    const doorLabels = [...new Set(unit.books.map((b) => b.slot_id).filter(Boolean))]
      .sort((a, b) => (channelOf.get(a) ?? 0) - (channelOf.get(b) ?? 0))
      .map((id) => labelOf.get(id))
      .filter(Boolean);
    let note = null;
    if (unit.note === 'MOVE_TO_ORDER_CABINET') {
      const target = unit.books.map((b) => openOrders.get(b.book_id)?.orders?.smart_cabinets?.cabinet_name).find(Boolean);
      note = { code: unit.note, message: `此書籍已售出，取回後請存入訂單指定的書櫃「${target ?? ''}」` };
    }
    return {
      key: unit.key,
      kind: unit.kind,
      order_id: ORDER_KINDS.includes(unit.kind) ? unit.order_id : null,
      order_no: ORDER_KINDS.includes(unit.kind) ? unit.order_no ?? null : null,
      books: unit.books.map((b) => ({
        book_id: b.book_id,
        title: b.title,
        image_url: b.image_url,
        door: b.slot_id ? labelOf.get(b.slot_id) ?? null : null
      })),
      doors: doorLabels,
      paused: Boolean(unit.paused),
      note,
      selected: Boolean(unit.selected),
      blocked: unit.blocked ? { code: unit.blocked, message: candidates.BLOCKED_MESSAGES[unit.blocked] ?? '' } : null,
      result: unit.result ?? 'pending',
      error: unit.error ? { code: unit.error, message: ITEM_ERRORS[unit.error] ?? '' } : null,
      ...(admin && {
        seller_nickname: people.seller.get(unit.books[0]?.book_id) ?? null,
        buyer_nickname: unit.order_id ? people.buyer.get(Number(unit.order_id)) ?? null : null
      })
    };
  });
};

const sessionUnits = async (session) => {
  const items = session.cabinet_session_items ?? [];
  if (items.length === 0) return [];
  const bookIds = [...new Set(items.map((i) => Number(i.book_id)))];
  const orderIds = [...new Set(items.map((i) => i.order_id).filter(Boolean).map(Number))];
  const [books, orderRows, depositRows] = await Promise.all([
    prisma.books.findMany({ where: { book_id: { in: bookIds } }, select: { book_id: true, title: true, book_images: coverImage } }),
    orderIds.length ? prisma.orders.findMany({ where: { order_id: { in: orderIds } }, select: { order_id: true, order_no: true } }) : [],
    prisma.book_deposits.findMany({ where: { book_id: { in: bookIds } }, select: { book_id: true, paused_at: true } })
  ]);
  const bookOf = new Map(books.map((b) => [Number(b.book_id), b]));
  const orderNo = new Map(orderRows.map((o) => [Number(o.order_id), o.order_no]));
  const pausedIds = new Set(depositRows.filter((d) => d.paused_at).map((d) => Number(d.book_id)));

  return [...groupItems(items).values()].map((unit) => {
    const first = unit.items[0];
    return {
      key: unit.key,
      kind: unit.kind,
      order_id: unit.order_id ? Number(unit.order_id) : null,
      order_no: unit.order_id ? orderNo.get(Number(unit.order_id)) ?? null : null,
      books: unit.items.map((i) => {
        const book = bookOf.get(Number(i.book_id));
        return {
          book_id: Number(i.book_id),
          title: book?.title ?? '',
          image_url: book?.book_images?.[0]?.image_url ?? null,
          slot_id: i.slot_id ? Number(i.slot_id) : null
        };
      }),
      paused: unit.kind === 'retrieval' && unit.items.some((i) => pausedIds.has(Number(i.book_id))),
      note: first.note_code ?? null,
      selected: unit.items.some((i) => i.selected),
      blocked: first.blocked_code ?? null,
      result: unit.items.find((i) => i.result !== 'done')?.result ?? first.result,
      error: unit.items.find((i) => i.error_code)?.error_code ?? null
    };
  }).sort((a, b) => candidates.KIND_ORDER.indexOf(a.kind) - candidates.KIND_ORDER.indexOf(b.kind)
    || Number(a.key.split(':')[1]) - Number(b.key.split(':')[1]));
};

const resultOf = (session) => ((TERMINAL.includes(session.status) || session.status === 'needs_review') && session.result_code
  ? { outcome: session.status, code: session.result_code, message: RESULT_MESSAGES[session.result_code] ?? '' }
  : null);

const shapeSession = async (session, { now = new Date(), admin = false } = {}) => {
  const doorList = sessionDoors(session);
  const labels = new Map(doorList.map((d) => [d.slot_id, d.label]));
  const units = await presentUnits(await sessionUnits(session), { admin, labels });
  const showMatch = session.status === 'matching' && (!admin || session.kind === 'admin');
  return {
    session_no: sessionNo(session.session_id),
    status: session.status,
    version: Number(session.version),
    cabinet: cabinetShape(session.smart_cabinets ?? {}),
    location_status: session.location_status ?? null,
    distance_m: session.distance_m ?? null,
    items: units,
    match: showMatch ? { code: Number(session.match_code) } : null,
    doors: doorList.map((d) => ({ label: d.label, state: d.state })),
    remaining_ms: remainingOf(session, now),
    open_ms: session.open_ms ?? null,
    result: resultOf(session),
    created_at: session.created_at,
    finished_at: session.finished_at ?? null
  };
};

// ---------- 推播 ----------

// 必須在交易提交後呼叫；推播失敗不影響作業本身。
const publish = async (sessionId) => {
  try {
    const session = await loadSession(sessionId);
    if (!session) return;
    realtime.emitToUser(Number(session.user_id), 'cabinet:session', { session: await shapeSession(session) });
  } catch (err) {
    console.error('[書櫃作業推播失敗]:', err.message);
  }
};

// ---------- 狀態轉換 ----------

const move = (db, session, from, data) => db.cabinet_sessions.updateMany({
  where: { session_id: Number(session.session_id), status: from, version: Number(session.version) },
  data: { ...data, version: { increment: 1 } }
});

const bump = (db, sessionId, statuses = [...ACTIVE, 'needs_review']) => db.cabinet_sessions.updateMany({
  where: { session_id: Number(sessionId), status: { in: statuses } },
  data: { version: { increment: 1 } }
});

const restoreHeld = async (tx, sessionId, now) => {
  const held = await tx.cabinet_session_items.findMany({ where: { session_id: Number(sessionId), held_on_sale: true }, select: { item_id: true, book_id: true } });
  for (const item of held) {
    const book = await tx.books.findUnique({ where: { book_id: Number(item.book_id) } });
    if (book && !(await violationLocked(book))) {
      await tx.books.updateMany({ where: { book_id: Number(item.book_id), status: 'removed' }, data: { status: 'on_sale', updated_at: now } });
    }
  }
  if (held.length) {
    await tx.cabinet_session_items.updateMany({ where: { item_id: { in: held.map((i) => i.item_id) } }, data: { held_on_sale: false } });
  }
};

// 狀態、釋放裝置、還原暫停販售與重算櫃門須在同一個交易內完成，否則中斷時書櫃會卡在使用中。
const finalize = async (tx, session, { from, status, resultCode, now = new Date(), data = {}, byVersion = true }) => {
  const done = await tx.cabinet_sessions.updateMany({
    where: {
      session_id: Number(session.session_id),
      status: Array.isArray(from) ? { in: from } : from,
      ...(byVersion ? { version: Number(session.version) } : {})
    },
    data: { ...data, status, result_code: resultCode, finished_at: now, version: { increment: 1 } }
  });
  if (done.count === 0) return false;
  await devices.releaseSession(tx, session.device_id, session.session_id);
  await restoreHeld(tx, session.session_id, now);
  const slotIds = (await tx.cabinet_session_doors.findMany({ where: { session_id: Number(session.session_id) }, select: { slot_id: true } }))
    .map((d) => d.slot_id);
  await doors.refresh(tx, slotIds);
  await recordEvent(tx, {
    cabinetId: session.cabinet_id, deviceId: session.device_id, sessionId: session.session_id, type: 'session_finished',
    detail: { status, result_code: resultCode }, source: 'server', occurredAt: now
  });
  return true;
};

const cabinetNameOf = (session) => session.smart_cabinets?.cabinet_name ?? '';

const notifyInitiator = (tx, session, { title, content }) => (session.kind === 'user'
  ? notify(tx, { userId: session.user_id, type: 'order', title, content })
  : null);

const toReview = async (tx, session, { from, resultCode, now, labels = [] }) => {
  const moved = await move(tx, session, from, { status: 'needs_review', result_code: resultCode, finished_at: now });
  if (moved.count === 0) return false;
  await devices.releaseSession(tx, session.device_id, session.session_id);
  await doors.refresh(tx, sessionDoors(session).map((d) => d.slot_id));
  await recordEvent(tx, {
    cabinetId: session.cabinet_id, deviceId: session.device_id, sessionId: session.session_id, type: 'session_finished',
    detail: { status: 'needs_review', result_code: resultCode }, source: 'server', occurredAt: now
  });
  const no = sessionNo(session.session_id);
  const name = cabinetNameOf(session);
  await notifyAdmins(tx, session.cabinet_id, {
    title: '書櫃作業待確認',
    content: resultCode === 'DEVICE_NO_ACK'
      ? `「${name}」的書櫃作業 ${no} 已送出開門指令，但未收到開門回報，請確認櫃門 ${labels.join('、')} 的狀態後於後台處理。`
      : `「${name}」的書櫃作業 ${no} 於櫃門開啟後未收到關門回報，請確認櫃門狀態後於後台處理。`
  });
  await notifyInitiator(tx, session, {
    title: '書櫃作業待確認',
    content: `您於「${name}」的書櫃作業 ${no} 待客服確認，確認後將另行通知。`
  });
  return true;
};

const applyDeadline = async (session, now = new Date()) => {
  if (!session || session.closed_at || !session.phase_deadline || new Date(session.phase_deadline) > now) return false;
  let changed = false;
  if (session.status === 'selecting' || session.status === 'matching') {
    const code = session.status === 'selecting' ? 'SELECT_TIMEOUT' : 'MATCH_TIMEOUT';
    changed = await prisma.$transaction((tx) => finalize(tx, session, { from: session.status, status: 'expired', resultCode: code, now }));
  } else if (session.status === 'opening') {
    const served = sessionDoors(session).filter((d) => d.command_served_at && d.state !== 'failed');
    changed = await prisma.$transaction((tx) => (served.length
      ? toReview(tx, session, { from: 'opening', resultCode: 'DEVICE_NO_ACK', now, labels: served.map((d) => d.label) })
      : finalize(tx, session, { from: 'opening', status: 'failed', resultCode: 'DEVICE_NO_RESPONSE', now })));
  } else if (session.status === 'open') {
    changed = await prisma.$transaction((tx) => toReview(tx, session, { from: 'open', resultCode: 'DEVICE_LOST', now }));
  }
  if (changed) await publish(session.session_id);
  return changed;
};

const fresh = async (session, now) => ((await applyDeadline(session, now)) ? loadSession(session.session_id) : session);

// ---------- 裝置畫面（4.5） ----------

const actionOf = (session) => {
  if (session.kind === 'admin') return 'admin';
  const items = session.cabinet_session_items ?? [];
  const chosen = items.filter((i) => i.selected);
  const kinds = new Set((chosen.length ? chosen : items).map((i) => i.kind));
  if (kinds.size === 0) return 'mixed';
  if ([...kinds].every((k) => k === 'pickup')) return 'pickup';
  if ([...kinds].every((k) => DEPOSIT_KINDS.includes(k))) return 'deposit';
  if ([...kinds].every((k) => k === 'retrieval')) return 'retrieve';
  return 'mixed';
};

const deviceResultCode = (session) => {
  if (session.status === 'needs_review') return 'RESULT_REVIEW';
  if (session.status === 'completed') return 'RESULT_DONE';
  if (session.status === 'partial') return 'RESULT_PARTIAL';
  if (session.status === 'cancelled') return 'RESULT_CANCELLED';
  if (session.status === 'expired') return 'RESULT_TIMEOUT';
  if (session.result_code === 'MATCH_FAILED') return 'RESULT_MATCH_FAILED';
  return 'RESULT_DEVICE_ERROR';
};

const message = (code, params = {}) => ({ code, params });

const deviceSession = (session, { phase, remaining, choices = null, result = null }) => ({
  id: sessionNo(session.session_id),
  phase,
  action: actionOf(session),
  remaining_ms: remaining,
  open_ms: session.open_ms ?? null,
  choices,
  doors: sessionDoors(session).map((d) => ({ channel: d.channel, label: d.label, state: d.state })),
  result
});

const activeView = async (device, session, now) => {
  const remaining = remainingOf(session, now);
  const labelText = sessionDoors(session).map((d) => d.label).join('、');
  const admin = session.kind === 'admin';
  const poll = devices.SESSION_POLL_MS;

  if (session.status === 'selecting') {
    return { screen: 'select', message: message('SELECT_ON_PHONE'), poll_ms: poll, session: deviceSession(session, { phase: 'select', remaining }), commands: [] };
  }
  if (session.status === 'matching') {
    const choices = String(session.match_choices ?? '').split(',').filter(Boolean).map(Number);
    return { screen: 'match', message: message('MATCH_PROMPT'), poll_ms: poll, session: deviceSession(session, { phase: 'match', remaining, choices }), commands: [] };
  }
  if (session.status === 'opening') {
    const list = sessionDoors(session);
    const commands = devices.unlockCommands({
      sessionNo: sessionNo(session.session_id),
      matchedAt: session.matched_at,
      doors: list.map((d) => ({ lock_channel: d.channel, state: d.state })),
      pulseMs: Number(device.unlock_pulse_ms)
    }, now);
    if (commands.length) {
      const channels = new Set(commands.map((c) => c.channel));
      await devices.markCommandsServed(prisma, session.session_id, list.filter((d) => channels.has(d.channel)).map((d) => d.slot_id), now);
    }
    return {
      screen: admin ? 'admin' : 'opening',
      message: message(admin ? 'OPEN_ADMIN' : 'OPENING', { doors: labelText }),
      poll_ms: poll,
      session: deviceSession(session, { phase: 'opening', remaining }),
      commands
    };
  }
  return {
    screen: admin ? 'admin' : 'open',
    message: message(OPEN_CODES[actionOf(session)], { doors: labelText }),
    poll_ms: poll,
    session: deviceSession(session, { phase: 'open', remaining }),
    commands: []
  };
};

const deviceView = async (device, now = new Date()) => {
  if (device.active_session_id) {
    let session = await loadSession(device.active_session_id);
    if (session && ACTIVE.includes(session.status)) session = await fresh(session, now);
    if (session && ACTIVE.includes(session.status)) return activeView(device, session, now);
    await devices.releaseSession(prisma, device.device_id, device.active_session_id);
  }
  const recent = await prisma.cabinet_sessions.findFirst({
    where: { device_id: Number(device.device_id), finished_at: { gte: new Date(now.getTime() - RESULT_HOLD_MS) } },
    orderBy: { finished_at: 'desc' },
    include: sessionInclude
  });
  if (!recent || ACTIVE.includes(recent.status)) return null;
  const code = deviceResultCode(recent);
  const remaining = Math.max(0, new Date(recent.finished_at).getTime() + RESULT_HOLD_MS - now.getTime());
  return {
    screen: 'result',
    message: message(code),
    poll_ms: devices.SESSION_POLL_MS,
    session: deviceSession(recent, { phase: 'result', remaining, result: { outcome: recent.status, code } }),
    commands: []
  };
};

// ---------- 裝置事件（4.6） ----------

const ok = () => ({ status: 'ok' });
const rejected = (code) => ({ status: 'rejected', code });

const doorForChannel = (session, channel) => sessionDoors(session).find((d) => d.channel === channel) ?? null;

const onMatch = async (device, session, event, now) => {
  if (session.status !== 'matching') return rejected('STALE');
  if (await applyDeadline(session, now)) return rejected('STALE');
  // 比對只有一次機會：並行送出多個數字時，先以同一個條件更新認領，再依數值決定結果；
  // 若正確與錯誤各走不同的寫入路徑，步驟較少的正確路徑通常先搶到列鎖，猜中率會高於九分之一。
  const claimed = await prisma.cabinet_sessions.updateMany({
    where: { session_id: Number(session.session_id), status: 'matching', version: Number(session.version), matched_at: null },
    data: { matched_at: now, version: { increment: 1 } }
  });
  if (claimed.count === 0) return rejected('STALE');
  const current = { ...session, version: Number(session.version) + 1, matched_at: now };
  if (Number(event.data?.value) === Number(session.match_code)) {
    const count = Math.max(1, sessionDoors(session).length);
    const deadline = new Date(now.getTime() + devices.openingAckMs(count, Number(device.unlock_pulse_ms)));
    const moved = await move(prisma, current, 'matching', { status: 'opening', phase_deadline: deadline });
    if (moved.count === 0) return rejected('STALE');
  } else {
    const done = await prisma.$transaction((tx) => finalize(tx, current, {
      from: 'matching', status: 'failed', resultCode: 'MATCH_FAILED', now, data: { matched_at: null }
    }));
    if (!done) return rejected('STALE');
  }
  await publish(session.session_id);
  return ok();
};

const onCabinetCancel = async (session, now) => {
  if (TERMINAL.includes(session.status)) return ok();
  if (!['selecting', 'matching'].includes(session.status)) return rejected('STALE');
  const done = await prisma.$transaction((tx) => finalize(tx, session, {
    from: session.status, status: 'cancelled', resultCode: 'CANCELLED_AT_CABINET', now
  }));
  if (!done) return rejected('STALE');
  await publish(session.session_id);
  return ok();
};

const lateOpen = async (session, door, at, now) => {
  const no = sessionNo(session.session_id);
  await prisma.$transaction(async (tx) => {
    await tx.cabinet_session_doors.updateMany({
      where: { session_id: Number(session.session_id), slot_id: door.slot_id, state: { in: ['pending', 'failed'] } },
      data: { state: 'open', opened_at: at }
    });
    await recordEvent(tx, {
      cabinetId: session.cabinet_id, deviceId: session.device_id, sessionId: session.session_id, type: 'late_door_opened',
      channel: door.channel, detail: { label: door.label }, source: 'server', occurredAt: now
    });
    await doors.markCheck(tx, [door.slot_id], { reason: 'LATE_OPEN', sessionId: session.session_id, now });
    await notifyAdmins(tx, session.cabinet_id, {
      title: '書櫃櫃門異常開啟',
      content: `「${cabinetNameOf(session)}」櫃門 ${door.label} 於書櫃作業 ${no} 結束後回報開啟，請確認櫃內書籍。`
    });
  });
  return ok();
};

const onDoorOpened = async (session, event, now) => {
  const door = doorForChannel(session, event.channel);
  if (!door) return rejected('EVENT_INVALID');
  const at = event.occurred_at ?? now;
  const id = Number(session.session_id);
  if (TERMINAL.includes(session.status)) return lateOpen(session, door, at, now);
  if (!['opening', 'open', 'needs_review'].includes(session.status)) return rejected('STALE');

  await prisma.$transaction(async (tx) => {
    await tx.cabinet_session_doors.updateMany({
      where: { session_id: id, slot_id: door.slot_id, state: { in: ['pending', 'failed'] } },
      data: { state: 'open', opened_at: at }
    });
    if (session.status === 'opening') {
      const moved = await tx.cabinet_sessions.updateMany({
        where: { session_id: id, status: 'opening' },
        data: {
          status: 'open', opened_at: at, phase_deadline: new Date(at.getTime() + Number(session.open_ms ?? 0) + REVIEW_GRACE_MS),
          version: { increment: 1 }
        }
      });
      if (moved.count > 0) return;
    }
    if (session.status === 'needs_review' && !session.opened_at) {
      await tx.cabinet_sessions.updateMany({ where: { session_id: id, opened_at: null }, data: { opened_at: at } });
    }
    await bump(tx, id);
  });
  await publish(id);
  return ok();
};

const onDoorClosed = async (session, event, now) => {
  const door = doorForChannel(session, event.channel);
  if (!door) return rejected('EVENT_INVALID');
  const reason = DOOR_CLOSE_REASONS.includes(event.data?.reason) ? event.data.reason : null;
  const closed = await prisma.cabinet_session_doors.updateMany({
    where: { session_id: Number(session.session_id), slot_id: door.slot_id, state: 'open' },
    data: { state: 'closed', closed_at: event.occurred_at ?? now, close_reason: reason }
  });
  if (closed.count > 0 && !TERMINAL.includes(session.status)) {
    await bump(prisma, session.session_id);
    await publish(session.session_id);
  }
  return ok();
};

const onSessionClosed = async (session, event, now) => {
  const outcome = event.data?.outcome;
  const reason = CLOSE_REASONS.includes(event.data?.reason) ? event.data.reason : null;
  if (!['completed', 'cancelled', 'interrupted'].includes(outcome)) return rejected('EVENT_INVALID');
  if (TERMINAL.includes(session.status)) return ok();

  if (outcome === 'interrupted') {
    if (['opening', 'open'].includes(session.status)) {
      const moved = await prisma.$transaction((tx) => toReview(tx, session, { from: session.status, resultCode: 'DEVICE_INTERRUPTED', now }));
      if (moved) await publish(session.session_id);
    }
    return ok();
  }
  if (!CLOSABLE.includes(session.status)) return rejected('STALE');
  if (session.status === 'needs_review' && !session.closed_at) {
    const since = session.opened_at ?? session.finished_at ?? session.created_at;
    if (now.getTime() - new Date(since).getTime() > LATE_EVENT_MS) return rejected('STALE');
  }
  return commit.commitSession(session.session_id, { outcome, reason, source: 'device', now });
};

const onDoorFault = async (session, event, now) => {
  const door = doorForChannel(session, event.channel);
  if (!door || TERMINAL.includes(session.status)) return ok();
  const id = Number(session.session_id);
  const failed = await prisma.cabinet_session_doors.updateMany({
    where: { session_id: id, slot_id: door.slot_id, state: 'pending' },
    data: { state: 'failed' }
  });
  if (failed.count === 0) return ok();
  const current = await loadSession(id);
  if (current.status === 'opening' && sessionDoors(current).every((d) => d.state === 'failed')) {
    await prisma.$transaction((tx) => finalize(tx, current, { from: 'opening', status: 'failed', resultCode: 'DEVICE_NO_RESPONSE', now }));
  } else {
    await bump(prisma, id);
  }
  await publish(id);
  return ok();
};

const handleEvent = async (device, event, now = new Date()) => {
  const session = await loadSession(event.session_id);
  if (!session || Number(session.device_id) !== Number(device.device_id)) return rejected('SESSION_MISMATCH');
  switch (event.type) {
    case 'match_selected': return onMatch(device, session, event, now);
    case 'session_cancel': return onCabinetCancel(session, now);
    case 'door_opened': return onDoorOpened(session, event, now);
    case 'door_closed': return onDoorClosed(session, event, now);
    case 'session_closed': return onSessionClosed(session, event, now);
    case 'fault': return onDoorFault(session, event, now);
    default: return rejected('EVENT_INVALID');
  }
};

// ---------- 排程（3.9） ----------

const sweep = async (now = new Date()) => {
  const due = await prisma.cabinet_sessions.findMany({
    where: { status: { in: ACTIVE }, closed_at: null, phase_deadline: { lt: now } },
    include: sessionInclude,
    orderBy: { session_id: 'asc' },
    take: SWEEP_BATCH
  });
  for (const session of due) {
    try {
      await applyDeadline(session, now);
    } catch (err) {
      console.error(`[書櫃作業逾時處理失敗] session_id=${session.session_id}:`, err.message);
    }
  }

  const stalled = await prisma.cabinet_sessions.findMany({
    where: { status: { in: CLOSABLE }, closed_at: { lt: new Date(now.getTime() - COMMIT_STALL_MS) } },
    select: { session_id: true },
    orderBy: { session_id: 'asc' },
    take: SWEEP_BATCH
  });
  for (const { session_id: id } of stalled) {
    try {
      await commit.commitSession(id, { source: 'sweep', now });
    } catch (err) {
      console.error(`[書櫃作業提交續做失敗] session_id=${id}:`, err.message);
    }
  }

  const locked = await prisma.cabinet_devices.findMany({ where: { active_session_id: { not: null } }, select: { device_id: true, active_session_id: true } });
  for (const device of locked) {
    const session = await prisma.cabinet_sessions.findUnique({ where: { session_id: Number(device.active_session_id) }, select: { status: true } });
    if (!session || !ACTIVE.includes(session.status)) await devices.releaseSession(prisma, device.device_id, device.active_session_id);
  }
  return { expired: due.length, resumed: stalled.length };
};

devices.registerSessionHandler({ deviceView, handleEvent, sweep });

// ---------- 使用者 API（第 5 節） ----------

const sessionStateError = async (session, now) => new HttpError(
  409,
  session.status === 'open' ? '櫃門已開啟，請於書櫃螢幕操作' : '目前無法執行此操作',
  'CABINET_SESSION_STATE',
  { session: await shapeSession(session, { now }) }
);

const ownSession = async (no, user) => {
  const session = await loadByNo(no);
  if (!session || Number(session.user_id) !== Number(user.userId)) throw sessionNotFound();
  return session;
};

// 定位格式錯誤時拋出 400；這裡只驗證格式，距離在建立作業時判斷。
const validateLocation = (body) => access.checkDistance({ latitude: 0, longitude: 0 }, body);

const recordRejection = async ({ cabinet, device, user, code, now }) => {
  try {
    await recordEvent(prisma, {
      cabinetId: cabinet.cabinet_id, deviceId: device.device_id, type: 'scan_rejected', source: 'server',
      detail: { code: code ?? null, user_no: publicId.encode('user', user.userId) }, occurredAt: now
    });
  } catch (err) {
    console.error('[書櫃掃碼拒絕紀錄失敗]:', err.message);
  }
};

const targetLabel = (unit) => (unit.order_id ? `訂單 ${unit.order_no}` : `書籍 ${publicId.encode('book', unit.books[0].book_id)}`);

const notifyBlocked = async (cabinet, units, now) => {
  for (const unit of units.filter((u) => u.notify)) {
    const target = unit.order_id ? { order_id: Number(unit.order_id) } : { book_id: Number(unit.books[0].book_id) };
    try {
      const recent = await prisma.cabinet_events.count({
        where: { type: 'item_blocked', ...target, occurred_at: { gte: new Date(now.getTime() - BLOCKED_NOTIFY_MS) } }
      });
      await prisma.$transaction(async (tx) => {
        await recordEvent(tx, {
          cabinetId: cabinet.cabinet_id, orderId: target.order_id ?? null, bookId: target.book_id ?? null, type: 'item_blocked',
          detail: { code: unit.blocked, kind: unit.kind }, source: 'server', occurredAt: now
        });
        if (recent === 0) {
          await notifyAdmins(tx, cabinet, {
            title: '書櫃項目無法辦理',
            content: `「${cabinet.cabinet_name}」有使用者無法辦理${targetLabel(unit)}（${candidates.BLOCKED_LABELS[unit.blocked] ?? unit.blocked}），請協助處理。`
          });
        }
      });
    } catch (err) {
      console.error('[書櫃受阻通知失敗]:', err.message);
    }
  }
};

const cooldownLeft = async (userId, cabinetId, now) => {
  const recent = await prisma.cabinet_sessions.findMany({
    where: { user_id: Number(userId), cabinet_id: Number(cabinetId), kind: 'user' },
    orderBy: [{ created_at: 'desc' }, { session_id: 'desc' }],
    take: policy.CABINET_COOLDOWN_STRIKES,
    select: { status: true, result_code: true, opened_at: true, finished_at: true }
  });
  if (recent.length < policy.CABINET_COOLDOWN_STRIKES) return 0;
  const strike = (s) => TERMINAL.includes(s.status)
    && (COOLDOWN_CODES.includes(s.result_code) || (s.result_code === 'CANCELLED_AT_CABINET' && !s.opened_at));
  if (!recent.every(strike) || !recent[0].finished_at) return 0;
  const until = new Date(recent[0].finished_at).getTime() + policy.CABINET_COOLDOWN_MINUTES * 60000;
  return Math.max(0, Math.ceil((until - now.getTime()) / 1000));
};

const itemRows = (sessionId, units) => units.flatMap((unit) => unit.books.map((book) => ({
  session_id: sessionId,
  kind: unit.kind,
  order_id: ORDER_KINDS.includes(unit.kind) ? unit.order_id : null,
  book_id: book.book_id,
  slot_id: DEPOSIT_KINDS.includes(unit.kind) ? null : book.slot_id ?? null,
  selected: Boolean(unit.selected),
  blocked_code: unit.blocked ?? null,
  note_code: unit.note ?? null,
  result: 'pending'
})));

// 5.2 第 2 至 9 步；失敗時挑戰碼不會被用掉。
const screen = async ({ user, device, cabinet, context, location, now }) => {
  if (!cabinet.is_active) throw new HttpError(409, '此書櫃暫停服務', 'CABINET_UNAVAILABLE');
  const underMaintenance = (await require('./cabinets').maintenanceIds()).has(Number(cabinet.cabinet_id));
  if (underMaintenance || device.fault_code) throw new HttpError(409, '此書櫃維修中，暫停服務', 'CABINET_MAINTENANCE');
  if (!access.isOpenAt(cabinet, now)) {
    const hours = access.hoursOf(cabinet);
    throw new HttpError(409, `目前非書櫃營業時間，營業時間為 ${hours.open_time}–${hours.close_time}`, 'CABINET_CLOSED', hours);
  }
  if (!access.isOnline(device, now)) {
    const mode = (await access.accessFor([cabinet.cabinet_id], now)).get(Number(cabinet.cabinet_id))?.mode;
    throw new HttpError(409, '書櫃目前連線中斷，暫時無法使用', 'CABINET_OFFLINE', { manual_allowed: mode === 'manual' });
  }

  const active = await prisma.cabinet_sessions.findFirst({
    where: { user_id: user.userId, kind: 'user', status: { in: ACTIVE } },
    include: sessionInclude,
    orderBy: { created_at: 'desc' }
  });
  if (active && ACTIVE.includes((await fresh(active, now)).status)) {
    throw new HttpError(409, '您有進行中的書櫃作業，請先完成或取消', 'CABINET_ACTIVE_SESSION', { session_no: sessionNo(active.session_id) });
  }

  const wait = await cooldownLeft(user.userId, cabinet.cabinet_id, now);
  if (wait > 0) {
    throw new HttpError(429, `您在此書櫃的作業多次未完成，請於 ${Math.ceil(wait / 60)} 分鐘後再試`, 'CABINET_COOLDOWN', { retry_after_s: wait });
  }

  const place = access.checkDistance(cabinet, location);
  if (!place.ok) {
    throw new HttpError(403, `您目前的位置距離書櫃約 ${place.distance_m} 公尺，請於書櫃旁操作`, 'CABINET_TOO_FAR', { distance_m: place.distance_m });
  }

  const listing = await candidates.list({ userId: user.userId, cabinet, context });
  await notifyBlocked(cabinet, listing.units, now);
  if (listing.units.length === 0) {
    throw new HttpError(404, '您在此書櫃沒有待辦理的項目', 'CABINET_NOTHING_TO_DO', {
      other_cabinets: await candidates.otherCabinets(user.userId, cabinet.cabinet_id)
    });
  }
  if (listing.units.every((u) => u.blocked)) {
    const first = listing.units[0];
    throw new HttpError(409, candidates.BLOCKED_MESSAGES[first.blocked], 'CABINET_ITEM_BLOCKED', {
      items: await presentUnits(listing.units)
    });
  }
  return { listing, place };
};

const create = async ({ user, code, context = null, location, now = new Date() }) => {
  const found = await challenges.lookup(code, now, { userId: user.userId });
  if (found.used) {
    const existing = await prisma.cabinet_sessions.findFirst({
      where: { challenge_id: found.challenge.challenge_id, user_id: user.userId }, include: sessionInclude
    });
    const current = existing ? await fresh(existing, now) : null;
    if (current && ACTIVE.includes(current.status)) return { created: false, session: await shapeSession(current, { now }) };
    throw codeExpired();
  }

  const { device, cabinet, challenge } = found;
  let screened;
  try {
    screened = await screen({ user, device, cabinet, context, location, now });
  } catch (err) {
    if (err instanceof HttpError) await recordRejection({ cabinet, device, user, code: err.code, now });
    throw err;
  }
  const { listing, place } = screened;

  // 兩人同時兌換同一組碼時，後到者會撞上 challenge_id 的唯一索引，視同碼已被使用。
  const created = await prisma.$transaction(async (tx) => {
    const row = await tx.cabinet_sessions.create({
      data: {
        cabinet_id: Number(cabinet.cabinet_id),
        device_id: Number(device.device_id),
        user_id: user.userId,
        kind: 'user',
        status: 'selecting',
        version: 1,
        challenge_id: challenge.challenge_id,
        context_type: listing.context?.type ?? null,
        context_id: listing.context?.id ?? null,
        location_status: place.status,
        distance_m: place.distance_m ?? null,
        accuracy_m: place.accuracy_m ?? null,
        phase_deadline: new Date(now.getTime() + policy.CABINET_SELECT_SECONDS * 1000),
        created_at: now
      }
    });
    await tx.cabinet_session_items.createMany({ data: itemRows(row.session_id, listing.units) });
    await challenges.claim(tx, { challenge, device, sessionId: row.session_id, userId: user.userId, now });
    await recordEvent(tx, {
      cabinetId: cabinet.cabinet_id, deviceId: device.device_id, sessionId: row.session_id, type: 'session_created',
      actorId: user.userId, detail: { user_no: publicId.encode('user', user.userId), units: listing.units.length },
      source: 'server', occurredAt: now
    });
    return row;
  }).catch((err) => {
    throw err?.code === 'P2002' ? codeExpired() : err;
  });

  await publish(created.session_id);
  return { created: true, session: await shapeSession(await loadSession(created.session_id), { now }) };
};

const active = async (user, now = new Date()) => {
  const session = await prisma.cabinet_sessions.findFirst({
    where: { user_id: user.userId, kind: 'user', status: { in: [...ACTIVE, 'needs_review'] } },
    include: sessionInclude,
    orderBy: [{ created_at: 'desc' }, { session_id: 'desc' }]
  });
  if (!session) return null;
  const current = await fresh(session, now);
  return TERMINAL.includes(current.status) ? null : shapeSession(current, { now });
};

const get = async (no, user, now = new Date()) => shapeSession(await fresh(await ownSession(no, user), now), { now });

const randomChoices = (code) => {
  const pool = new Set([code]);
  while (pool.size < policy.CABINET_MATCH_CHOICES) pool.add(crypto.randomInt(10, 100));
  const list = [...pool];
  for (let i = list.length - 1; i > 0; i -= 1) {
    const j = crypto.randomInt(0, i + 1);
    [list[i], list[j]] = [list[j], list[i]];
  }
  return list;
};

const openMsFor = (doorCount) => Math.min(
  policy.CABINET_DOOR_OPEN_MAX_SECONDS,
  policy.CABINET_DOOR_OPEN_SECONDS + policy.CABINET_DOOR_EXTRA_SECONDS * Math.max(0, doorCount - 1)
) * 1000;

const unitSignature = (unit) => candidates.signature({
  kind: unit.kind,
  books: unit.items.map((i) => ({ book_id: Number(i.book_id), slot_id: i.slot_id ? Number(i.slot_id) : null })),
  blocked: unit.items[0].blocked_code ?? null
});

const rebuildItems = async (session, freshUnits, keep, now) => {
  for (const unit of freshUnits) unit.selected = !unit.blocked && keep.has(unit.key);
  await prisma.$transaction(async (tx) => {
    await tx.cabinet_session_items.deleteMany({ where: { session_id: Number(session.session_id) } });
    await tx.cabinet_session_items.createMany({ data: itemRows(Number(session.session_id), freshUnits) });
    await bump(tx, session.session_id, ['selecting']);
  });
  await publish(session.session_id);
  const current = await loadSession(session.session_id);
  return new HttpError(409, '部分項目狀態已變更，請重新確認', 'CABINET_ITEMS_CHANGED', { session: await shapeSession(current, { now }) });
};

const itemsForDoors = (session, units, keys) => {
  const chosen = new Set(keys);
  for (const key of keys) {
    const unit = units.get(key);
    if (unit.kind !== 'retrieval') continue;
    const slots = new Set(unit.items.map((i) => i.slot_id).filter(Boolean).map(Number));
    for (const other of units.values()) {
      if (other.kind === 'retrieval' && other.items.some((i) => slots.has(Number(i.slot_id)))) chosen.add(other.key);
    }
  }
  return [...chosen];
};

const allocateDoors = async (tx, session, units, keys, userId) => {
  const depositUnits = keys.map((k) => units.get(k)).filter((u) => DEPOSIT_KINDS.includes(u.kind));
  if (depositUnits.length === 0) return { result: new Map(), placed: new Map() };
  const bookIds = depositUnits.flatMap((u) => u.items.map((i) => Number(i.book_id)));
  const placed = await doors.bookDoors(bookIds, { tx });
  const cabinetId = Number(session.cabinet_id);
  const result = await doors.allocate(tx, {
    cabinetId,
    sessionId: Number(session.session_id),
    sellerId: userId,
    units: depositUnits.map((u) => ({
      key: u.key,
      kind: u.kind,
      orderId: u.order_id ? Number(u.order_id) : undefined,
      bookIds: u.items.map((i) => Number(i.book_id)).filter((id) => placed.get(id)?.cabinet_id !== cabinetId)
    }))
  });
  return { result, placed };
};

const start = async (no, user, keys, now = new Date()) => {
  let session = await fresh(await ownSession(no, user), now);
  if (session.status !== 'selecting') throw await sessionStateError(session, now);
  if (!Array.isArray(keys) || keys.length === 0) throw noSelection();
  if (keys.length > 50 || keys.some((k) => typeof k !== 'string')) throw badRequest('所選項目格式不正確');

  const units = groupItems(session.cabinet_session_items ?? []);
  for (const key of keys) {
    if (!units.has(key)) throw badRequest('所選項目不正確');
  }
  const selectedKeys = itemsForDoors(session, units, [...new Set(keys)]);
  const cabinet = session.smart_cabinets;
  const context = session.context_type ? { type: session.context_type, id: Number(session.context_id) } : null;
  // 須在列項之前記下：列項之後才被買走的取回書籍，在交易內暫停販售時會影響 0 列，以此判斷為項目已變更。
  const retrievalIds = selectedKeys.map((k) => units.get(k)).filter((u) => u.kind === 'retrieval')
    .flatMap((u) => u.items.map((i) => Number(i.book_id)));
  const onSale = new Set(retrievalIds.length
    ? (await prisma.books.findMany({ where: { book_id: { in: retrievalIds }, status: 'on_sale' }, select: { book_id: true } }))
        .map((b) => Number(b.book_id))
    : []);
  const relist = async () => (await candidates.list({ userId: user.userId, cabinet, context, strictContext: false })).units;
  const listing = { units: await relist() };
  const freshByKey = new Map(listing.units.map((u) => [u.key, u]));
  const changed = selectedKeys.some((key) => {
    const unit = units.get(key);
    const next = freshByKey.get(key);
    if (unit.items[0].blocked_code || !next) return true;
    if (next.blocked && (!DEPOSIT_KINDS.includes(next.kind) || RECHECK_BLOCKS.includes(next.blocked))) return true;
    return candidates.signature(next) !== unitSignature(unit);
  });
  if (changed) throw await rebuildItems(session, listing.units, new Set(selectedKeys), now);

  const chosen = new Set(selectedKeys);
  const matchCode = crypto.randomInt(10, 100);
  let slotIds = [];
  try {
    await prisma.$transaction(async (tx) => {
      const { result: allocation, placed } = await allocateDoors(tx, session, units, selectedKeys, user.userId);
      const doorSlots = new Map();
      const assign = async (item, slotId) => {
        await tx.cabinet_session_items.updateMany({ where: { item_id: item.item_id }, data: { selected: true, slot_id: slotId } });
      };

      for (const unit of units.values()) {
        if (!chosen.has(unit.key)) {
          await tx.cabinet_session_items.updateMany({ where: { item_id: { in: unit.items.map((i) => i.item_id) } }, data: { selected: false } });
          continue;
        }
        if (DEPOSIT_KINDS.includes(unit.kind)) {
          const entries = allocation.get(unit.key) ?? [];
          for (const entry of entries) doorSlots.set(entry.slot_id, entry.lock_channel);
          for (const item of unit.items) {
            const entry = entries.find((e) => e.book_ids.includes(Number(item.book_id)));
            await assign(item, entry ? entry.slot_id : placed.get(Number(item.book_id))?.slot_id ?? entries[0]?.slot_id ?? null);
          }
          continue;
        }
        for (const item of unit.items) {
          await assign(item, item.slot_id);
          if (item.slot_id) doorSlots.set(Number(item.slot_id), null);
        }
        if (unit.kind === 'retrieval') {
          for (const item of unit.items) {
            const held = await tx.books.updateMany({ where: { book_id: Number(item.book_id), status: 'on_sale' }, data: { status: 'removed', updated_at: now } });
            if (held.count > 0) await tx.cabinet_session_items.updateMany({ where: { item_id: item.item_id }, data: { held_on_sale: true } });
            else if (onSale.has(Number(item.book_id))) throw restartSelection();
          }
        }
      }

      const slots = await tx.cabinet_slots.findMany({ where: { slot_id: { in: [...doorSlots.keys()] } }, select: { slot_id: true, lock_channel: true } });
      if (slots.length === 0) throw restartSelection();
      for (const slot of slots) {
        await tx.cabinet_session_doors.create({
          data: { session_id: Number(session.session_id), slot_id: Number(slot.slot_id), lock_channel: slot.lock_channel, state: 'pending' }
        });
      }
      slotIds = slots.map((s) => Number(s.slot_id));

      const moved = await move(tx, session, 'selecting', {
        status: 'matching',
        started_at: now,
        match_code: matchCode,
        match_choices: randomChoices(matchCode).join(','),
        open_ms: openMsFor(slots.length),
        phase_deadline: new Date(now.getTime() + policy.CABINET_MATCH_SECONDS * 1000)
      });
      if (moved.count === 0) throw new HttpError(409, '目前無法執行此操作', 'CABINET_SESSION_STATE');
      await doors.refresh(tx, slotIds);
    });
  } catch (err) {
    if (err?.code === 'CABINET_FULL') {
      const blocked = [...units.values()].filter((u) => chosen.has(u.key) && u.kind === 'order_deposit').map((u) => ({
        key: u.key, kind: u.kind, order_id: u.order_id, blocked: 'CABINET_FULL', notify: true,
        books: u.items.map((i) => ({ book_id: Number(i.book_id) }))
      }));
      if (blocked.length) await notifyBlocked(cabinet, blocked, now);
    }
    if (err?.code === 'CABINET_SESSION_STATE') {
      session = await loadSession(session.session_id);
      throw await sessionStateError(session, now);
    }
    if (RESTART_CODES.includes(err?.code)) throw await rebuildItems(session, await relist(), chosen, now);
    throw err;
  }

  await publish(session.session_id);
  return shapeSession(await loadSession(session.session_id), { now });
};

const cancel = async (no, user, now = new Date()) => {
  const session = await fresh(await ownSession(no, user), now);
  if (TERMINAL.includes(session.status)) return shapeSession(session, { now });
  if (!['selecting', 'matching'].includes(session.status)) throw await sessionStateError(session, now);
  const done = await prisma.$transaction((tx) => finalize(tx, session, {
    from: session.status, status: 'cancelled', resultCode: 'CANCELLED_BY_USER', now
  }));
  const current = await loadSession(session.session_id);
  if (!done && !TERMINAL.includes(current.status)) throw await sessionStateError(current, now);
  if (done) await publish(session.session_id);
  return shapeSession(current, { now });
};

// ---------- 後台（7.2） ----------

const notPaired = () => new HttpError(409, '此書櫃尚未配對裝置', 'DEVICE_NOT_PAIRED');
const doorNotFound = () => new HttpError(404, '找不到此櫃門', 'DOOR_NOT_FOUND');

const cabinetOf = async (cabinetId) => {
  const cabinet = await prisma.smart_cabinets.findUnique({ where: { cabinet_id: Number(cabinetId) } });
  if (!cabinet) throw notFound('找不到該書櫃');
  return cabinet;
};

const doorOf = async (cabinetId, slotId) => {
  const slot = await prisma.cabinet_slots.findFirst({
    where: { slot_id: Number(slotId), cabinet_id: Number(cabinetId), lock_channel: { not: null } }
  });
  if (!slot) throw doorNotFound();
  return slot;
};

// 不經比對開門只限確定是空的櫃門：沒有存放紀錄、不在待確認，也沒有未結束作業（含待確認作業）保留此門。
const assertForceable = async (db, slotId) => {
  const id = Number(slotId);
  const [slot, items, held] = await Promise.all([
    db.cabinet_slots.findUnique({ where: { slot_id: id } }),
    db.cabinet_slot_items.count({ where: { slot_id: id } }),
    db.cabinet_session_doors.count({
      where: { slot_id: id, state: { not: 'failed' }, cabinet_sessions: { status: { in: doors.OPEN_SESSION_STATUSES } } }
    })
  ]);
  if (!slot || slot.check_required_at || items > 0 || held > 0) throw doorNotEmpty();
};

const adminOpen = async (cabinetId, slotId, { reason, force = false }, { adminId, req }) => {
  const cabinet = await cabinetOf(cabinetId);
  const device = await devices.activeDeviceOf(cabinet.cabinet_id);
  if (!device) throw notPaired();
  const slot = await doorOf(cabinet.cabinet_id, slotId);
  const now = new Date();
  if (!access.isOnline(device, now)) throw new HttpError(409, '書櫃裝置目前離線，無法遠端開啟櫃門', 'DEVICE_OFFLINE');

  const matchCode = force ? null : crypto.randomInt(10, 100);
  const label = doors.labelOf(slot);
  const created = await prisma.$transaction(async (tx) => {
    if (force) await assertForceable(tx, slot.slot_id);
    const row = await tx.cabinet_sessions.create({
      data: {
        cabinet_id: Number(cabinet.cabinet_id),
        device_id: Number(device.device_id),
        user_id: adminId,
        kind: 'admin',
        status: force ? 'opening' : 'matching',
        version: 1,
        admin_reason: reason,
        admin_force: Boolean(force),
        open_ms: ADMIN_OPEN_MS,
        started_at: now,
        created_at: now,
        ...(force
          ? { matched_at: now, phase_deadline: new Date(now.getTime() + devices.openingAckMs(1, Number(device.unlock_pulse_ms))) }
          : {
              match_code: matchCode,
              match_choices: randomChoices(matchCode).join(','),
              phase_deadline: new Date(now.getTime() + policy.CABINET_MATCH_SECONDS * 1000)
            })
      }
    });
    await devices.lockForSession(tx, device.device_id, row.session_id);
    await tx.cabinet_session_doors.create({
      data: { session_id: row.session_id, slot_id: Number(slot.slot_id), lock_channel: slot.lock_channel, state: 'pending' }
    });
    await doors.refresh(tx, [slot.slot_id]);
    await recordEvent(tx, {
      cabinetId: cabinet.cabinet_id, deviceId: device.device_id, sessionId: row.session_id, type: 'admin_open',
      channel: slot.lock_channel, actorId: adminId, detail: { reason, force: Boolean(force), label }, source: 'admin', occurredAt: now
    });
    await audit.record(tx, {
      adminId,
      action: '遠端開啟書櫃櫃門',
      targetType: 'cabinet',
      targetId: Number(cabinet.cabinet_id),
      summary: `遠端開啟「${cabinet.cabinet_name}」櫃門 ${label}${force ? '（未經現場數字確認）' : ''}，原因：${reason}`,
      req
    });
    return row;
  });

  await publish(created.session_id);
  const session = await loadSession(created.session_id);
  return {
    session_no: sessionNo(created.session_id),
    match: force ? null : { code: matchCode },
    remaining_ms: remainingOf(session, new Date())
  };
};

const clearDoor = async (cabinetId, slotId, { mode, reason }, { adminId, req }) => {
  const cabinet = await cabinetOf(cabinetId);
  const slot = await doorOf(cabinet.cabinet_id, slotId);
  const bookIds = await doors.booksInSlot(prisma, slot.slot_id);
  if (mode === 'removed' && bookIds.length) {
    const inOrder = await prisma.order_items.count({
      where: { book_id: { in: bookIds }, orders: { status: { in: ORDER_UNSETTLED_STATUSES } } }
    });
    if (inOrder > 0) throw new HttpError(409, '此櫃門存放進行中訂單的書籍，請先於訂單管理調整訂單狀態', 'DOOR_HAS_ORDER');
  }
  const now = new Date();
  const label = doors.labelOf(slot);
  await prisma.$transaction(async (tx) => {
    if (mode === 'removed') {
      for (const bookId of bookIds) {
        const row = await tx.book_deposits.findUnique({ where: { book_id: bookId }, include: deposits().adminInclude });
        if (row) {
          await deposits().adminClearInTx(tx, { row, adminId, req, now });
          continue;
        }
        const book = await tx.books.findUnique({ where: { book_id: bookId }, include: { users: { select: { anonymized_at: true } } } });
        if (!book) continue;
        await tx.books.updateMany({ where: { book_id: bookId, status: 'on_sale' }, data: { status: 'removed', updated_at: now } });
        if (!book.users?.anonymized_at) {
          await deposits().notifyTakenOut(tx, { sellerId: book.seller_id, bookId, title: book.title, cabinet: cabinet.cabinet_name });
        }
      }
    }
    await doors.removeBooks(tx, bookIds);
    await doors.clearCheck(tx, slot.slot_id, { actorId: adminId, note: reason, mode, now });
    await recordEvent(tx, {
      cabinetId: cabinet.cabinet_id, type: 'door_cleared', channel: slot.lock_channel, actorId: adminId,
      detail: { mode, reason, label, book_ids: bookIds }, source: 'admin', occurredAt: now
    });
    await audit.record(tx, {
      adminId,
      action: '清空書櫃櫃門存放紀錄',
      targetType: 'cabinet',
      targetId: Number(cabinet.cabinet_id),
      summary: `清空「${cabinet.cabinet_name}」櫃門 ${label} 的存放紀錄（${mode === 'removed' ? '書籍已取出' : '僅更正紀錄'}），原因：${reason}`,
      req
    });
  });
  return (await cabinetAdmin().shapeDoors([await prisma.cabinet_slots.findUnique({ where: { slot_id: Number(slot.slot_id) } })]))[0];
};

const userBriefOf = (user) => (user ? { user_no: publicId.encode('user', user.user_id), nickname: user.nickname } : null);

const listSessions = async (cabinetId, { status = null, skip = 0, limit = 20 } = {}) => {
  const cabinet = await cabinetOf(cabinetId);
  const wanted = status === 'review' ? 'needs_review' : STATUSES.includes(status) ? status : null;
  const where = { cabinet_id: Number(cabinet.cabinet_id), ...(wanted ? { status: wanted } : {}) };
  const [rows, total] = await Promise.all([
    prisma.cabinet_sessions.findMany({
      where,
      include: { ...sessionInclude, users: { select: { user_id: true, nickname: true } } },
      orderBy: [{ created_at: 'desc' }, { session_id: 'desc' }],
      skip,
      take: limit
    }),
    prisma.cabinet_sessions.count({ where })
  ]);
  return {
    total,
    rows: rows.map((s) => {
      const items = s.cabinet_session_items ?? [];
      const chosen = items.filter((i) => i.selected);
      return {
        session_no: sessionNo(s.session_id),
        kind: s.kind,
        status: s.status,
        result_code: s.result_code ?? null,
        user: userBriefOf(s.users),
        item_kinds: candidates.KIND_ORDER.filter((k) => (chosen.length ? chosen : items).some((i) => i.kind === k)),
        doors: sessionDoors(s).map((d) => d.label),
        location_status: s.location_status ?? null,
        distance_m: s.distance_m ?? null,
        close_reason: s.close_reason ?? null,
        created_at: s.created_at,
        opened_at: s.opened_at ?? null,
        finished_at: s.finished_at ?? null
      };
    })
  };
};

const adminDetail = async (no, now = new Date()) => {
  let session = await loadByNo(no);
  if (!session) throw sessionNotFound();
  session = await fresh(session, now);
  const [shaped, events, people] = await Promise.all([
    shapeSession(session, { now, admin: true }),
    prisma.cabinet_events.findMany({ where: { session_id: Number(session.session_id) }, orderBy: [{ occurred_at: 'asc' }, { event_id: 'asc' }] }),
    prisma.users.findMany({
      where: { user_id: { in: [session.user_id, session.reviewed_by].filter(Boolean).map(Number) } },
      select: { user_id: true, nickname: true }
    })
  ]);
  const byId = new Map(people.map((u) => [Number(u.user_id), u]));
  const reviewer = session.reviewed_by ? byId.get(Number(session.reviewed_by)) : null;
  return {
    ...shaped,
    kind: session.kind,
    result_code: session.result_code ?? null,
    user: userBriefOf(byId.get(Number(session.user_id))),
    close_reason: session.close_reason ?? null,
    started_at: session.started_at ?? null,
    matched_at: session.matched_at ?? null,
    opened_at: session.opened_at ?? null,
    closed_at: session.closed_at ?? null,
    accuracy_m: session.accuracy_m ?? null,
    admin_reason: session.admin_reason ?? null,
    admin_force: Boolean(session.admin_force),
    doors_timeline: sessionDoors(session).map((d) => ({
      label: d.label, state: d.state, command_served_at: d.command_served_at, opened_at: d.opened_at,
      closed_at: d.closed_at, close_reason: d.close_reason
    })),
    events: events.map((e) => ({
      type: e.type,
      source: e.source,
      label: e.lock_channel ? doors.doorLabel(e.lock_channel) : null,
      detail: parseDetail(e.detail),
      result: e.result ?? null,
      occurred_at: e.occurred_at
    })),
    review: session.reviewed_at
      ? { note: session.review_note ?? null, reviewed_at: session.reviewed_at, reviewer_nickname: reviewer?.nickname ?? null }
      : null
  };
};

// 使用者作業的發起人或所選項目的當事人不得處理該作業，否則管理員可自行確認自己的取書或存書。
const assertNotInvolved = async (session, adminId) => {
  if (session.kind !== 'user') return;
  const id = Number(adminId);
  if (Number(session.user_id) === id) throw sessionSelfReview();
  const chosen = (session.cabinet_session_items ?? []).filter((i) => i.selected);
  const orderIds = [...new Set(chosen.map((i) => i.order_id).filter(Boolean).map(Number))];
  const bookIds = [...new Set(chosen.map((i) => Number(i.book_id)))];
  const [orderRows, bookRows] = await Promise.all([
    orderIds.length ? prisma.orders.findMany({ where: { order_id: { in: orderIds } }, select: { buyer_id: true, seller_id: true } }) : [],
    bookIds.length ? prisma.books.findMany({ where: { book_id: { in: bookIds } }, select: { seller_id: true } }) : []
  ]);
  if (orderRows.some((o) => Number(o.buyer_id) === id || Number(o.seller_id) === id)
    || bookRows.some((b) => Number(b.seller_id) === id)) {
    throw sessionSelfReview();
  }
};

const resolve = async (no, { action, note }, { adminId, req }) => {
  const session = await loadByNo(no);
  if (!session) throw sessionNotFound();
  await assertNotInvolved(session, adminId);
  const now = new Date();
  const name = cabinetNameOf(session);
  const label = sessionNo(session.session_id);

  if (session.status === 'needs_review') {
    await commit.commitSession(session.session_id, {
      outcome: action === 'commit' ? 'completed' : 'cancelled',
      reason: action === 'commit' ? 'admin' : 'admin_discard',
      source: 'admin', actorId: adminId, note, now
    });
  } else if (['selecting', 'matching', 'opening'].includes(session.status) && action === 'discard') {
    const done = await prisma.$transaction(async (tx) => {
      const finished = await finalize(tx, session, {
        from: session.status, status: 'cancelled', resultCode: 'ADMIN_CANCELLED', now,
        data: { reviewed_by: adminId, reviewed_at: now, review_note: note }
      });
      if (!finished) return false;
      const served = sessionDoors(session).filter((d) => d.state === 'pending' && d.command_served_at).map((d) => d.slot_id);
      if (served.length) {
        await doors.markCheck(tx, served, { reason: session.kind === 'admin' ? 'ADMIN_OPEN' : 'DOOR_UNCONFIRMED', sessionId: session.session_id, now });
      }
      await recordEvent(tx, {
        cabinetId: session.cabinet_id, deviceId: session.device_id, sessionId: session.session_id, type: 'review_resolved',
        actorId: adminId, detail: { action, note }, source: 'admin', occurredAt: now
      });
      return true;
    });
    if (!done) throw notReviewable();
    await publish(session.session_id);
  } else {
    throw notReviewable();
  }

  await audit.record(null, {
    adminId,
    action: '處理書櫃作業',
    targetType: 'cabinet',
    targetId: Number(session.cabinet_id),
    summary: `將「${name}」的書櫃作業 ${label} ${action === 'commit' ? '確認為已完成' : '確認為未完成'}，說明：${note}`,
    req
  });
  return adminDetail(no, now);
};

module.exports = {
  REVIEW_GRACE_MS, COMMIT_STALL_MS, RESULT_HOLD_MS, ADMIN_OPEN_MS, LATE_EVENT_MS, BLOCKED_NOTIFY_MS,
  ACTIVE, TERMINAL, CLOSABLE, STATUSES, RESULT_MESSAGES, ITEM_ERRORS,
  sessionNo, loadSession, sessionDoors, groupItems, unitKeyOf, shapeSession, publish, finalize, notifyInitiator,
  applyDeadline, deviceView, handleEvent, sweep, validateLocation,
  create, active, get, start, cancel, adminOpen, clearDoor, listSessions, adminDetail, resolve
};
