// 端對端：以模擬書櫃的 device-core（與 ESP32 韌體相同的邏輯）搭配使用者 API 跑完整流程。device-core 使用假時鐘，
// HTTP 請求則實際送到測試伺服器。
const assert = require('assert');
const server = require('../lib/server');
const h = require('./session-harness');

const { api, prisma } = h;
const { DeviceCore } = api('views/kiosk/device-core');

const TERMINAL = ['completed', 'partial', 'cancelled', 'failed', 'expired', 'needs_review'];

class FakeClock {
  constructor() {
    this.t = 1000;
    this.seq = 0;
    this.timers = new Map();
  }

  now() {
    return this.t;
  }

  setTimeout(fn, ms) {
    this.seq += 1;
    this.timers.set(this.seq, { id: this.seq, at: this.t + Math.max(0, Number(ms) || 0), fn });
    return this.seq;
  }

  clearTimeout(id) {
    this.timers.delete(id);
  }
}

const createKiosk = () => {
  const clock = new FakeClock();
  const storage = new Map();
  let pending = 0;
  const core = new DeviceCore({
    baseUrl: server.baseUrl(),
    fetch: async (url, init) => {
      pending += 1;
      try {
        return await server.realFetch(url, { ...init, headers: { ...init.headers, 'x-forwarded-for': h.clientIp() } });
      } finally {
        pending -= 1;
      }
    },
    storage: {
      get: (key) => (storage.has(key) ? storage.get(key) : null),
      set: (key, value) => storage.set(key, String(value)),
      remove: (key) => storage.delete(key)
    },
    clock,
    kind: 'simulator',
    firmware: 'sim-1.0.0',
    doorCount: 4,
    unlockPulseMs: 800,
    hasDoorSensor: false,
    autoCloseOnTimeout: true,
    random: Math.random
  });

  // 等待進行中的 HTTP 請求與其後續處理全部完成，才推進假時鐘。
  const idle = async () => {
    let quiet = 0;
    for (let i = 0; i < 5000 && quiet < 4; i += 1) {
      await new Promise((resolve) => setImmediate(resolve));
      if (pending === 0) quiet += 1;
      else {
        quiet = 0;
        await new Promise((resolve) => setTimeout(resolve, 1));
      }
    }
  };

  const advance = async (ms) => {
    const target = clock.t + ms;
    for (;;) {
      await idle();
      let next = null;
      for (const timer of clock.timers.values()) {
        if (timer.at <= target && (!next || timer.at < next.at || (timer.at === next.at && timer.id < next.id))) next = timer;
      }
      if (!next) break;
      clock.timers.delete(next.id);
      clock.t = Math.max(clock.t, next.at);
      next.fn();
    }
    clock.t = target;
    await idle();
  };

  const until = async (check, { within = 60000, label = '條件' } = {}) => {
    for (let spent = 0; spent <= within; spent += 100) {
      if (check()) return;
      await advance(100);
    }
    throw new Error(`等待逾時：${label}（書櫃畫面 ${core.view.screen}）`);
  };

  return { core, clock, advance, until, idle, storage };
};

const pairKiosk = async (ctx) => {
  const kiosk = createKiosk();
  const code = await h.request('POST', `/api/admin/cabinets/${ctx.cabinet.cabinet_id}/device/pairing-code`, {
    token: ctx.adminToken, headers: h.adminVerifyHeaders(ctx.adminToken), body: { kind: 'simulator', door_count: 4 }
  });
  assert.strictEqual(code.status, 201, code.text);
  h.uniqueDeviceId(prisma.rows('cabinet_devices').find((d) => d.status === 'pending'));
  kiosk.core.start();
  const paired = await kiosk.core.pair(code.body.data.code);
  assert.strictEqual(paired.ok, true, JSON.stringify(paired));
  await kiosk.until(() => kiosk.core.view.screen === 'idle' && kiosk.core.view.qr, { label: '閒置畫面與 QR Code' });
  return kiosk;
};

const setup = () => {
  const admin = h.addAdmin();
  const seller = h.addUser({ nickname: '賣家', balance: 0 });
  const buyer = h.addUser({ nickname: '買家', balance: 1000 });
  const cabinet = h.addCabinet({ name: '北商大書櫃' });
  return {
    admin, seller, buyer, cabinet,
    adminToken: h.tokenFor(admin), sellerToken: h.tokenFor(seller), buyerToken: h.tokenFor(buyer)
  };
};

// 掃碼、選取、在書櫃螢幕點選數字、開門、關門。close 為 'done'、'cancel_close' 或 null（等待倒數自動關門）。
const visit = async (kiosk, token, { context, keys, close = 'done' } = {}) => {
  // 假時鐘推進得比伺服器的真實時間快，結果畫面的 4 秒改以調整結束時間略過。
  for (const row of prisma.rows('cabinet_sessions')) {
    if (row.finished_at) row.finished_at = h.ago(h.sessionsService.RESULT_HOLD_MS + 1000);
  }
  await kiosk.until(() => kiosk.core.view.screen === 'idle' && kiosk.core.view.qr, { label: '閒置畫面與 QR Code' });
  const code = kiosk.core.view.qr.payload;
  const created = await h.request('POST', '/api/cabinet-sessions', {
    token, body: { code, location_status: 'unavailable', ...(context ? { context } : {}) }
  });
  assert.strictEqual(created.status, 201, created.text);
  const no = created.body.data.session_no;
  await kiosk.until(() => kiosk.core.view.screen === 'select', { label: '書櫃顯示確認項目' });

  const chosen = keys ?? created.body.data.items.filter((i) => i.selected).map((i) => i.key);
  const started = await h.request('POST', `/api/cabinet-sessions/${no}/start`, { token, body: { keys: chosen } });
  assert.strictEqual(started.status, 200, started.text);
  const match = started.body.data.match.code;
  await kiosk.until(() => kiosk.core.view.buttons.some((b) => b.id === `match:${match}`), { label: '書櫃顯示比對數字' });
  assert.strictEqual(kiosk.core.view.buttons.filter((b) => b.id.startsWith('match:')).length, 9);
  kiosk.core.tap(`match:${match}`);
  await kiosk.until(() => ['open', 'admin'].includes(kiosk.core.view.screen) && kiosk.core.view.buttons.some((b) => b.id === 'done' && b.enabled),
    { label: '櫃門開啟' });
  await kiosk.until(() => h.sessionOf(no).status === 'open', { label: '伺服器記錄開門' });
  const opened = (await h.request('GET', `/api/cabinet-sessions/${no}`, { token })).body.data;

  if (close) kiosk.core.tap(close);
  await kiosk.until(() => TERMINAL.includes(h.sessionOf(no).status), { within: 60000, label: '作業結束' });
  await kiosk.until(() => kiosk.core.view.screen === 'result' || kiosk.core.view.screen === 'idle', { label: '結果畫面' });
  const final = (await h.request('GET', `/api/cabinet-sessions/${no}`, { token })).body.data;
  return { no, created: created.body.data, opened, final };
};

module.exports = {
  name: '端對端：模擬書櫃 device-core 與使用者 API',
  tests: [
    ['配對後依序完成：依訂單存書、取書、先行存書、取回', async () => {
      const ctx = setup();
      const kiosk = await pairKiosk(ctx);
      try {
        const [a, b] = [
          h.addBook({ sellerId: ctx.seller.user_id, cabinet_id: ctx.cabinet.cabinet_id, title: '資料庫系統概論', status: 'reserved' }),
          h.addBook({ sellerId: ctx.seller.user_id, cabinet_id: ctx.cabinet.cabinet_id, title: '作業系統', status: 'reserved' })
        ];
        const order = h.addPaidOrder({ buyerId: ctx.buyer.user_id, sellerId: ctx.seller.user_id, bookId: a.book_id, cabinetId: ctx.cabinet.cabinet_id });
        prisma.rows('order_items').push({ item_id: prisma.nextId('order_items'), order_id: order.order_id, book_id: b.book_id, quantity: 1, unit_price: 100, subtotal: 100 });

        const deposit = await visit(kiosk, ctx.sellerToken, { context: { type: 'order', id: order.order_id } });
        assert.strictEqual(deposit.opened.doors[0].label, 'A01');
        assert.strictEqual(deposit.final.status, 'completed', JSON.stringify(deposit.final));
        assert.strictEqual(h.orderOf(order.order_id).status, 'deposited');
        assert.ok(h.notificationsOf(ctx.buyer.user_id).some((n) => n.title === '書籍已存入書櫃'));
        assert.deepStrictEqual(kiosk.core.view.doors.map((d) => d.locked), [true, true, true, true]);

        const pickup = await visit(kiosk, ctx.buyerToken, { context: { type: 'order', id: order.order_id } });
        assert.strictEqual(pickup.created.items[0].kind, 'pickup');
        assert.deepStrictEqual(pickup.created.items[0].doors, ['A01']);
        assert.strictEqual(pickup.final.status, 'completed');
        assert.ok(h.orderOf(order.order_id).picked_up_at);
        assert.strictEqual(prisma.rows('cabinet_slot_items').length, 0);

        const book = h.addBook({ sellerId: ctx.seller.user_id, cabinet_id: ctx.cabinet.cabinet_id, title: '小王子' });
        const pre = await visit(kiosk, ctx.sellerToken, { context: { type: 'book', id: book.book_id }, keys: [`book:${book.book_id}`] });
        assert.strictEqual(pre.final.status, 'completed');
        assert.ok(h.depositOf(book.book_id));
        const own = await h.request('GET', `/api/books/${book.book_id}`, { token: ctx.sellerToken });
        assert.strictEqual(own.body.data.deposit.door, 'A01');
        assert.strictEqual(own.body.data.location.retrievable, true);

        const back = await visit(kiosk, ctx.sellerToken, { context: { type: 'book', id: book.book_id }, keys: [`book:${book.book_id}`] });
        assert.strictEqual(back.created.items.find((i) => i.key === `book:${book.book_id}`).kind, 'retrieval');
        assert.strictEqual(back.final.status, 'completed');
        assert.strictEqual(h.depositOf(book.book_id), null);
        assert.strictEqual(h.bookOf(book.book_id).status, 'on_sale');
        assert.strictEqual(h.cabinetRow(ctx.cabinet.cabinet_id).available_slots, 4);
      } finally {
        kiosk.core.stop();
      }
    }],

    ['「取消並關門」不變更狀態並設為待確認；倒數結束自動關門並完成', async () => {
      const ctx = setup();
      const kiosk = await pairKiosk(ctx);
      try {
        const book = h.addBook({ sellerId: ctx.seller.user_id, cabinet_id: ctx.cabinet.cabinet_id });
        const cancelled = await visit(kiosk, ctx.sellerToken, { context: { type: 'book', id: book.book_id }, keys: [`book:${book.book_id}`], close: 'cancel_close' });
        assert.strictEqual(cancelled.final.status, 'cancelled');
        assert.strictEqual(cancelled.final.result.code, 'CANCELLED_AT_CABINET');
        assert.strictEqual(h.depositOf(book.book_id), null);
        const door = h.doorOf(ctx.cabinet.cabinet_id, 1);
        assert.strictEqual(door.check_reason, 'CANCELLED_AFTER_OPEN');
        assert.ok(h.adminNotices(ctx, '書櫃作業開門後取消').length === 1);

        const cleared = await h.request('POST', `/api/admin/cabinets/${ctx.cabinet.cabinet_id}/doors/${door.slot_id}/check-clear`, {
          token: ctx.adminToken, body: { note: '現場確認櫃門為空' }
        });
        assert.strictEqual(cleared.status, 200, cleared.text);

        const auto = await visit(kiosk, ctx.sellerToken, { context: { type: 'book', id: book.book_id }, keys: [`book:${book.book_id}`], close: null });
        assert.strictEqual(auto.final.status, 'completed');
        assert.strictEqual(h.sessionOf(auto.no).close_reason, 'timeout');
        assert.ok(h.depositOf(book.book_id));
      } finally {
        kiosk.core.stop();
      }
    }],

    ['書櫃離線超過 2 分鐘：手動回報成為待確認，管理員確認後生效；恢復連線後回到掃碼模式', async () => {
      const ctx = setup();
      const kiosk = await pairKiosk(ctx);
      try {
        const book = h.addBook({ sellerId: ctx.seller.user_id, cabinet_id: ctx.cabinet.cabinet_id, status: 'reserved' });
        const order = h.addPaidOrder({ buyerId: ctx.buyer.user_id, sellerId: ctx.seller.user_id, bookId: book.book_id, cabinetId: ctx.cabinet.cabinet_id });

        const scanOnly = await h.request('PATCH', `/api/orders/${order.order_id}/status`, { token: ctx.sellerToken, body: { status: 'deposited' } });
        assert.strictEqual(scanOnly.body.code, 'CABINET_SCAN_REQUIRED');

        kiosk.core.setOffline(true);
        await kiosk.advance(10000);
        assert.strictEqual(kiosk.core.view.screen, 'offline');
        prisma.rows('cabinet_devices').find((d) => d.status === 'active').last_seen_at = h.ago(130000);
        await h.devices.sweep(new Date());

        const listed = await h.request('GET', `/api/orders/${order.order_id}`, { token: ctx.sellerToken });
        assert.strictEqual(listed.body.data.cabinet_access.mode, 'manual');
        assert.strictEqual(listed.body.data.cabinet_access.reason, 'offline');

        const reported = await h.request('PATCH', `/api/orders/${order.order_id}/status`, { token: ctx.sellerToken, body: { status: 'deposited' } });
        assert.strictEqual(reported.status, 202, reported.text);
        assert.strictEqual(h.orderOf(order.order_id).status, 'pending_deposit');

        const queue = await h.request('GET', `/api/admin/cabinets/${ctx.cabinet.cabinet_id}/manual-reports`, { token: ctx.adminToken });
        assert.strictEqual(queue.body.data.length, 1);
        const confirmUrl = `/api/admin/cabinet-manual-reports/${queue.body.data[0].report_no}/confirm`;
        const noDoor = await h.request('POST', confirmUrl, { token: ctx.adminToken, body: { note: '客服人員已協助存入' } });
        assert.strictEqual(noDoor.status, 400);
        assert.strictEqual(noDoor.body.code, 'DOOR_REQUIRED');
        const door = h.doorOf(ctx.cabinet.cabinet_id, 2);
        const confirmed = await h.request('POST', confirmUrl, {
          token: ctx.adminToken, body: { note: '客服人員已協助存入', slot_id: door.slot_id }
        });
        assert.strictEqual(confirmed.status, 200, confirmed.text);
        assert.strictEqual(h.orderOf(order.order_id).status, 'deposited');
        assert.strictEqual(h.orderOf(order.order_id).slot_id, door.slot_id);
        assert.strictEqual(h.slotItemOf(book.book_id).slot_id, door.slot_id);
        assert.strictEqual(door.status, 'occupied');
        assert.ok(h.notificationsOf(ctx.buyer.user_id).some((n) => n.title === '書籍已存入書櫃'));

        kiosk.core.setOffline(false);
        await kiosk.until(() => kiosk.core.view.screen === 'idle' && kiosk.core.view.qr, { label: '恢復連線' });
        const after = await h.request('GET', `/api/orders/${order.order_id}`, { token: ctx.sellerToken });
        assert.strictEqual(after.body.data.cabinet_access.mode, 'scan');
        assert.ok(h.eventsOf('connection_restored').length >= 1);
      } finally {
        kiosk.core.stop();
      }
    }],

    ['門磁：沒有作業時櫃門遭強制開啟再關上，伺服器的門磁狀態依序為開啟、關閉', async () => {
      const ctx = setup();
      const kiosk = await pairKiosk(ctx);
      try {
        const device = () => prisma.rows('cabinet_devices').find((d) => d.status === 'active');
        const sensor = () => h.doorOf(ctx.cabinet.cabinet_id, 1).sensor_state;
        assert.strictEqual(kiosk.core.setOptions({ hasDoorSensor: true }), true);
        await kiosk.until(() => device().has_door_sensor === true, { label: '門磁設定' });

        kiosk.core.setDoorPhysical(1, 'open');
        await kiosk.until(() => sensor() === 'open', { label: '門磁顯示開啟' });
        assert.strictEqual(h.eventsOf('door_forced').length, 1);

        kiosk.core.setDoorPhysical(1, 'closed');
        await kiosk.until(() => sensor() === 'closed', { label: '門磁顯示關閉' });
        const closedEvent = h.eventsOf('door_closed').at(-1);
        assert.strictEqual(closedEvent.session_id, null);
        assert.strictEqual(closedEvent.result, 'ok');

        const summary = await h.request('GET', `/api/admin/cabinets/${ctx.cabinet.cabinet_id}/device`, { token: ctx.adminToken });
        assert.strictEqual(summary.body.data.doors[0].sensor, 'closed');
      } finally {
        kiosk.core.stop();
      }
    }]
  ]
};
