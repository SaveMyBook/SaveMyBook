// 書櫃作業（工作包 B）測試的共用設定：在 harness 之上補交易回復，並提供掃碼、比對、開門、關門的輔助函式。
const assert = require('assert');
const { AsyncLocalStorage } = require('async_hooks');
const h = require('./harness');

const { prisma, api, request } = h;

const ago = (ms) => new Date(Date.now() - ms);

// ---------- 交易回復 ----------

// 共用的假 Prisma 不會回復交易；提交中斷與兌換競爭的測試需要真正的回復語意，否則半套寫入會留在記憶體中。
const journals = new AsyncLocalStorage();
const MUTATIONS = new Set(['create', 'createMany', 'update', 'updateMany', 'upsert', 'delete', 'deleteMany']);

const sameValue = (a, b) => (a instanceof Date || b instanceof Date
  ? a instanceof Date && b instanceof Date && a.getTime() === b.getTime()
  : a === b);

const changed = (row, before) => {
  const keys = new Set([...Object.keys(row), ...Object.keys(before)]);
  return [...keys].some((k) => !sameValue(row[k], before[k]));
};

let journalInstalled = false;

const installJournal = () => {
  if (journalInstalled) return;
  journalInstalled = true;
  const baseModel = prisma.model;
  prisma.model = (table) => {
    const m = baseModel(table);
    const wrapped = { ...m };
    for (const op of MUTATIONS) {
      if (typeof m[op] !== 'function') continue;
      // 假 Prisma 在呼叫當下同步寫入，必須在 await 之前比對，否則並行的交易會混進本交易的紀錄。
      wrapped[op] = (args) => {
        const journal = journals.getStore();
        if (!journal) return m[op](args);
        const before = prisma.rows(table).slice();
        const copies = new Map(before.map((r) => [r, { ...r }]));
        const result = m[op](args);
        const after = prisma.rows(table);
        const alive = new Set(after);
        for (const row of before) {
          if (!alive.has(row)) journal.push({ type: 'deleted', table, row, copy: copies.get(row) });
          else if (changed(row, copies.get(row))) journal.push({ type: 'updated', table, row, copy: copies.get(row) });
        }
        for (const row of after) if (!copies.has(row)) journal.push({ type: 'created', table, row });
        return result;
      };
    }
    return wrapped;
  };

  const undo = (journal) => {
    for (const entry of journal.reverse()) {
      if (entry.type === 'created') {
        prisma.store[entry.table] = prisma.rows(entry.table).filter((r) => r !== entry.row);
        continue;
      }
      for (const key of Object.keys(entry.row)) delete entry.row[key];
      Object.assign(entry.row, entry.copy);
      if (entry.type === 'deleted') prisma.rows(entry.table).push(entry.row);
    }
  };

  prisma.$transaction = (work) => {
    if (Array.isArray(work)) return Promise.all(work);
    const parent = journals.getStore();
    const journal = [];
    return journals.run(journal, async () => {
      try {
        const result = await work(prisma);
        if (parent) parent.push(...journal);
        return result;
      } catch (err) {
        undo(journal);
        throw err;
      }
    });
  };
};

installJournal();

// ---------- 情境 ----------

const sessionsService = api('services/cabinet-sessions');
const realtime = api('services/realtime');

// 裝置端點以 device_id 限流，而資料表每個測試都會清空；編號跨測試遞增，限流才不會在同一分鐘內累積。
let deviceSeq = 0;
const uniqueDeviceId = (row) => {
  deviceSeq += 1;
  row.device_id = 100000 + deviceSeq;
  return row;
};

const scene = ({ doorCount = 4, kind = 'esp32', unlockPulseMs = 800, cabinet: cabinetOptions = {} } = {}) => {
  const admin = h.addAdmin();
  const seller = h.addUser({ nickname: '賣家', balance: 0 });
  const buyer = h.addUser({ nickname: '買家', balance: 1000 });
  const cabinet = h.addCabinet({ name: '北商大書櫃', ...cabinetOptions });
  const device = h.addDevice({ cabinetId: cabinet.cabinet_id, doorCount, kind, unlockPulseMs });
  uniqueDeviceId(device.device);
  return {
    admin, seller, buyer, cabinet, ...device,
    adminToken: h.tokenFor(admin), sellerToken: h.tokenFor(seller), buyerToken: h.tokenFor(buyer)
  };
};

const listedBook = (ctx, overrides = {}) => h.addBook({ sellerId: ctx.seller.user_id, cabinet_id: ctx.cabinet.cabinet_id, ...overrides });

// 買家已付款、訂單在此書櫃待存書（或已存書）。
const orderFor = (ctx, bookIds, { status = 'pending_deposit', amount = 100, buyer = ctx.buyer, ...rest } = {}) => {
  const ids = [bookIds].flat();
  const order = h.addPaidOrder({
    buyerId: buyer.user_id, sellerId: ctx.seller.user_id, bookId: ids[0], amount, status, cabinetId: ctx.cabinet.cabinet_id,
    ...(status === 'deposited' ? { deposited_at: new Date() } : {}), ...rest
  });
  for (const bookId of ids.slice(1)) {
    prisma.rows('order_items').push({
      item_id: prisma.nextId('order_items'), order_id: order.order_id, book_id: bookId, quantity: 1, unit_price: amount, subtotal: amount
    });
  }
  for (const bookId of ids) {
    const book = h.bookOf(bookId);
    if (book && book.status === 'on_sale') book.status = 'reserved';
  }
  return order;
};

// 作業結束後書櫃會顯示 4 秒結果畫面；測試直接讓結果畫面過期，才能立即取得下一組 QR Code。
const scan = (ctx) => {
  const past = ago(sessionsService.RESULT_HOLD_MS + 1000);
  for (const row of prisma.rows('cabinet_sessions')) {
    if (Number(row.device_id) === Number(ctx.device.device_id) && row.finished_at && row.finished_at > past) row.finished_at = past;
  }
  return h.scanCode(ctx.token, ctx.bootId);
};

const createSession = async (ctx, token, { code, context, location_status = 'denied', location } = {}) => request('POST', '/api/cabinet-sessions', {
  token,
  body: { code: code ?? await scan(ctx), ...(context ? { context } : {}), location_status, ...(location ? { location } : {}) }
});

const startSession = (token, no, keys) => request('POST', `/api/cabinet-sessions/${no}/start`, { token, body: { keys } });

const getSession = (token, no) => request('GET', `/api/cabinet-sessions/${no}`, { token });

const cancelSession = (token, no) => request('POST', `/api/cabinet-sessions/${no}/cancel`, { token });

const matchCodeOf = (no) => Number(h.sessionOf(no).match_code);

const events = (ctx, list) => h.postEvents(ctx.token, ctx.bootId, list);

const selectNumber = (ctx, no, value = matchCodeOf(no)) => events(ctx, [{ type: 'match_selected', session_id: no, data: { value } }]);

// 讀取 /state 取得開鎖指令（會記錄 command_served_at），再逐扇回報開門。
const openDoors = async (ctx, no) => {
  const state = await h.deviceState(ctx.token, ctx.bootId);
  const commands = state.body.data.commands ?? [];
  assert.ok(commands.length > 0, `沒有開鎖指令：${JSON.stringify(state.body.data)}`);
  const res = await events(ctx, commands.map((c) => ({
    type: 'door_opened', session_id: no, channel: c.channel, data: { command_id: c.id }
  })));
  return { commands, res };
};

const closeSession = (ctx, no, { outcome = 'completed', reason = 'button', channels = [] } = {}) => events(ctx, [
  ...(outcome === 'completed' ? channels.map((channel) => ({ type: 'door_closed', session_id: no, channel, data: { reason } })) : []),
  { type: 'session_closed', session_id: no, data: { outcome, reason: outcome === 'cancelled' ? 'cancel_button' : reason } }
]);

// 掃碼到關門的完整流程；回傳最後一次讀取的作業。
const runSession = async (ctx, token, { context, keys, outcome = 'completed' } = {}) => {
  const created = await createSession(ctx, token, { context });
  assert.strictEqual(created.status, 201, created.text);
  const no = created.body.data.session_no;
  const chosen = keys ?? created.body.data.items.filter((i) => i.selected).map((i) => i.key);
  const started = await startSession(token, no, chosen);
  assert.strictEqual(started.status, 200, started.text);
  const matched = await selectNumber(ctx, no);
  assert.strictEqual(matched.body.data.results[0].status, 'ok', matched.text);
  const { commands } = await openDoors(ctx, no);
  const closed = await closeSession(ctx, no, { outcome, channels: commands.map((c) => c.channel) });
  assert.ok(closed.body.data.results.every((r) => r.status === 'ok'), closed.text);
  const final = await getSession(token, no);
  return { no, created, started, final: final.body.data };
};

// 攔截推播；每個測試前還原。
const originalEmit = realtime.emitToUser;
require('../lib/server').onReset(() => { realtime.emitToUser = originalEmit; });

const captureEmits = () => {
  const calls = [];
  realtime.emitToUser = (userId, event, payload) => {
    calls.push({ userId, event, payload });
    return originalEmit(userId, event, payload);
  };
  return calls;
};

const itemsOf = (no) => {
  const id = h.sessionOf(no).session_id;
  return prisma.rows('cabinet_session_items').filter((i) => Number(i.session_id) === Number(id));
};
const doorsOf = (no) => {
  const id = h.sessionOf(no).session_id;
  return prisma.rows('cabinet_session_doors').filter((d) => Number(d.session_id) === Number(id));
};
const slotItemOf = (bookId) => prisma.rows('cabinet_slot_items').find((r) => Number(r.book_id) === Number(bookId)) ?? null;
const depositOf = (bookId) => prisma.rows('book_deposits').find((r) => Number(r.book_id) === Number(bookId)) ?? null;
const adminNotices = (ctx, title) => h.notificationsOf(ctx.admin.user_id).filter((n) => !title || n.title === title);

module.exports = {
  ...h, sessionsService, realtime,
  uniqueDeviceId, scene, listedBook, orderFor, scan, createSession, startSession, getSession, cancelSession, matchCodeOf, events,
  selectNumber, openDoors, closeSession, runSession, captureEmits, itemsOf, doorsOf, slotItemOf, depositOf, adminNotices, ago
};
