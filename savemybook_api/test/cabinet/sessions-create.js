const assert = require('assert');
const h = require('./session-harness');
const { gate, concurrently } = require('../lib/gate');

const { prisma, api } = h;
const challenges = api('services/cabinet-challenges');

const HERE = { lat: 25.0301, lng: 121.5101 };

const pickupScene = (options) => {
  const ctx = h.scene(options);
  const book = h.listedBook(ctx);
  const order = h.orderFor(ctx, book.book_id, { status: 'deposited' });
  h.addPlaced(book.book_id, h.doorOf(ctx.cabinet.cabinet_id, 1).slot_id);
  return { ...ctx, book, order };
};

const otherCabinet = (name = '師大書櫃') => {
  const cabinet = h.addCabinet({ name });
  return { cabinet, ...h.addDevice({ cabinetId: cabinet.cabinet_id }) };
};

const hhmm = (offsetMinutes) => {
  const parts = new Intl.DateTimeFormat('en-GB', { timeZone: 'Asia/Taipei', hour: '2-digit', minute: '2-digit', hourCycle: 'h23' })
    .format(new Date(Date.now() + offsetMinutes * 60000));
  return parts;
};

module.exports = {
  name: '書櫃作業：掃碼建立作業',
  tests: [
    ['QR Code 格式錯誤為 400；查無或已過期為 410；定位格式錯誤為 400', async () => {
      const ctx = pickupScene();
      const bad = await h.createSession(ctx, ctx.buyerToken, { code: 'https://savemybook.today/k/abc' });
      assert.strictEqual(bad.status, 400);
      assert.strictEqual(bad.body.code, 'CABINET_CODE_INVALID');
      const missing = await h.createSession(ctx, ctx.buyerToken, { code: `savemybook://k/${'0'.repeat(32)}` });
      assert.strictEqual(missing.status, 410);
      assert.strictEqual(missing.body.code, 'CABINET_CODE_EXPIRED');
      const location = await h.createSession(ctx, ctx.buyerToken, { location_status: 'granted', location: { lat: 0, lng: 0, accuracy_m: 5, age_ms: 0 } });
      assert.strictEqual(location.status, 400);
      assert.strictEqual(location.body.message, '定位資料格式不正確');
      const missingStatus = await h.request('POST', '/api/cabinet-sessions', { token: ctx.buyerToken, body: { code: await h.scan(ctx) } });
      assert.strictEqual(missingStatus.status, 400);
    }],

    ['兩人同時兌換同一組碼：只有一人成功，另一人的作業不會留下', async () => {
      const ctx = pickupScene();
      const second = h.addUser({ nickname: '第二位買家' });
      const book = h.listedBook(ctx);
      h.orderFor(ctx, book.book_id, { status: 'deposited', buyer: second });
      h.addPlaced(book.book_id, h.doorOf(ctx.cabinet.cabinet_id, 2).slot_id);
      const code = await h.scan(ctx);

      const g = gate(2);
      const original = challenges.claim;
      challenges.claim = async (...args) => {
        await g.wait();
        return original(...args);
      };
      try {
        const results = await concurrently(g.open, [
          h.createSession(ctx, ctx.buyerToken, { code }),
          h.createSession(ctx, h.tokenFor(second), { code })
        ]);
        const statuses = results.map((r) => r.status).sort();
        assert.deepStrictEqual(statuses, [201, 410], results.map((r) => r.text).join('\n'));
      } finally {
        challenges.claim = original;
      }
      assert.strictEqual(prisma.rows('cabinet_sessions').length, 1);
      assert.strictEqual(prisma.rows('cabinet_session_items').length, 1);
      assert.strictEqual(h.eventsOf('session_created').length, 1);
    }],

    ['書櫃正由其他作業使用時為 CABINET_BUSY', async () => {
      const ctx = pickupScene();
      const code = await h.scan(ctx);
      await h.sessionsService.adminOpen(ctx.cabinet.cabinet_id, h.doorOf(ctx.cabinet.cabinet_id, 3).slot_id,
        { reason: '測試', force: false }, { adminId: ctx.admin.user_id, req: null });
      const res = await h.createSession(ctx, ctx.buyerToken, { code });
      assert.strictEqual(res.status, 409);
      assert.strictEqual(res.body.code, 'CABINET_BUSY');
    }],

    ['裝置連線中斷：15 秒以上為 CABINET_OFFLINE，超過 2 分鐘時 manual_allowed 為 true', async () => {
      const ctx = pickupScene();
      const code = await h.scan(ctx);
      h.deviceRow(ctx.device.device_id).last_seen_at = h.ago(30000);
      const brief = await h.createSession(ctx, ctx.buyerToken, { code });
      assert.strictEqual(brief.status, 409);
      assert.strictEqual(brief.body.code, 'CABINET_OFFLINE');
      assert.strictEqual(brief.body.manual_allowed, false);
      h.deviceRow(ctx.device.device_id).last_seen_at = h.ago(130000);
      const long = await h.createSession(ctx, ctx.buyerToken, { code });
      assert.strictEqual(long.body.manual_allowed, true);
      const rejected = h.eventsOf('scan_rejected');
      assert.strictEqual(rejected.length, 2);
      assert.deepStrictEqual(JSON.parse(rejected[0].detail), { code: 'CABINET_OFFLINE', user_no: h.publicId.encode('user', ctx.buyer.user_id) });
    }],

    ['停用、維修中、裝置故障與非營業時間都會拒絕', async () => {
      const ctx = pickupScene();
      const code = await h.scan(ctx);
      h.deviceRow(ctx.device.device_id).fault_code = 'POWER';
      assert.strictEqual((await h.createSession(ctx, ctx.buyerToken, { code })).body.code, 'CABINET_MAINTENANCE');
      h.deviceRow(ctx.device.device_id).fault_code = null;
      Object.assign(h.cabinetRow(ctx.cabinet.cabinet_id), { open_time: hhmm(120), close_time: hhmm(180) });
      const closed = await h.createSession(ctx, ctx.buyerToken, { code });
      assert.strictEqual(closed.body.code, 'CABINET_CLOSED');
      assert.strictEqual(closed.body.open_time, hhmm(120));
      assert.ok(closed.body.message.startsWith('目前非書櫃營業時間，營業時間為 '));
      Object.assign(h.cabinetRow(ctx.cabinet.cabinet_id), { open_time: null, close_time: null, is_active: false });
      assert.strictEqual((await h.createSession(ctx, ctx.buyerToken, { code })).body.code, 'CABINET_UNAVAILABLE');
    }],

    ['距離過遠被拒；書櫃旁的新鮮定位可建立作業且不保存座標', async () => {
      const ctx = pickupScene();
      const far = await h.createSession(ctx, ctx.buyerToken, {
        location_status: 'granted', location: { lat: 25.0377, lng: 121.51, accuracy_m: 20, age_ms: 500 }
      });
      assert.strictEqual(far.status, 403);
      assert.strictEqual(far.body.code, 'CABINET_TOO_FAR');
      assert.ok(far.body.distance_m > 800);
      assert.strictEqual(far.body.message, `您目前的位置距離書櫃約 ${far.body.distance_m} 公尺，請於書櫃旁操作`);

      const near = await h.createSession(ctx, ctx.buyerToken, { location_status: 'granted', location: { ...HERE, accuracy_m: 12, age_ms: 800 } });
      assert.strictEqual(near.status, 201, near.text);
      assert.strictEqual(near.body.data.location_status, 'granted');
      assert.ok(near.body.data.distance_m < 50);
      const row = h.sessionOf(near.body.data.session_no);
      assert.strictEqual(row.accuracy_m, 12);
      assert.ok(!('lat' in row) && !('latitude' in row));
    }],

    ['定位為必要條件：拒絕權限、無法取得、精度超過 500 公尺、定位超過 60 秒都拒絕，留下拒絕紀錄且挑戰碼未被用掉', async () => {
      const ctx = pickupScene();
      const code = await h.scan(ctx);
      const cases = [
        [{ location_status: 'denied', location: null }, 'CABINET_LOCATION_REQUIRED', '使用書櫃須允許存取位置資訊，請於系統設定中開啟後再試'],
        [{ location_status: 'unavailable', location: null }, 'CABINET_LOCATION_UNAVAILABLE', '目前無法確認您的位置，請開啟定位服務後再試'],
        [{ location_status: 'granted', location: { ...HERE, accuracy_m: 800, age_ms: 500 } }, 'CABINET_LOCATION_UNAVAILABLE', null],
        [{ location_status: 'granted', location: { ...HERE, accuracy_m: 10, age_ms: 70000 } }, 'CABINET_LOCATION_UNAVAILABLE', null]
      ];
      for (const [place, errorCode, message] of cases) {
        const res = await h.createSession(ctx, ctx.buyerToken, { code, ...place });
        assert.strictEqual(res.status, 403, res.text);
        assert.strictEqual(res.body.code, errorCode);
        if (message) assert.strictEqual(res.body.message, message);
      }
      const rejected = h.eventsOf('scan_rejected').map((e) => JSON.parse(e.detail).code);
      assert.deepStrictEqual(rejected, cases.map(([, errorCode]) => errorCode));
      assert.strictEqual(prisma.rows('cabinet_sessions').length, 0);
      assert.strictEqual(prisma.rows('cabinet_challenges').filter((c) => c.used_at).length, 0);

      const ok = await h.createSession(ctx, ctx.buyerToken, { code });
      assert.strictEqual(ok.status, 201, ok.text);
    }],

    ['管理員遠端開櫃不需定位', async () => {
      const ctx = pickupScene();
      const res = await h.request('POST', `/api/admin/cabinets/${ctx.cabinet.cabinet_id}/doors/${h.doorOf(ctx.cabinet.cabinet_id, 2).slot_id}/open`, {
        token: ctx.adminToken, headers: h.adminVerifyHeaders(ctx.adminToken), body: { reason: '測試' }
      });
      assert.strictEqual(res.status, 201, res.text);
      assert.strictEqual(h.sessionOf(res.body.data.session_no).location_status, null);
    }],

    ['掃錯書櫃：訂單情境回 CABINET_WRONG_CABINET 並附訂單的書櫃', async () => {
      const ctx = h.scene();
      const elsewhere = otherCabinet();
      const book = h.addBook({ sellerId: ctx.seller.user_id, cabinet_id: elsewhere.cabinet.cabinet_id });
      const order = h.addPaidOrder({
        buyerId: ctx.buyer.user_id, sellerId: ctx.seller.user_id, bookId: book.book_id, status: 'deposited',
        cabinetId: elsewhere.cabinet.cabinet_id, deposited_at: new Date()
      });
      const res = await h.createSession(ctx, ctx.buyerToken, { context: { type: 'order', id: order.order_id } });
      assert.strictEqual(res.status, 409);
      assert.strictEqual(res.body.code, 'CABINET_WRONG_CABINET');
      assert.strictEqual(res.body.message, '此訂單的指定書櫃為「師大書櫃」，請至該書櫃辦理');
      assert.deepStrictEqual(Object.keys(res.body.cabinet).sort(), ['address', 'cabinet_id', 'cabinet_name', 'latitude', 'longitude']);
      assert.strictEqual(res.body.cabinet.cabinet_id, elsewhere.cabinet.cabinet_id);
      assert.strictEqual(prisma.rows('cabinet_challenges').filter((c) => c.used_at).length, 0);
    }],

    ['他人訂單或書籍的情境被忽略，不回 CABINET_WRONG_CABINET 或 CABINET_CONTEXT_CHANGED', async () => {
      const ctx = pickupScene();
      const elsewhere = otherCabinet();
      const stranger = h.addUser();
      const book = h.addBook({ sellerId: stranger.user_id, cabinet_id: elsewhere.cabinet.cabinet_id });
      const order = h.addOrder({
        buyerId: h.addUser().user_id, sellerId: stranger.user_id, bookId: book.book_id, cabinetId: elsewhere.cabinet.cabinet_id
      });
      const viaOrder = await h.createSession(ctx, ctx.buyerToken, { context: { type: 'order', id: order.order_id } });
      assert.strictEqual(viaOrder.status, 201, viaOrder.text);
      assert.strictEqual(viaOrder.body.data.items[0].selected, true);
      assert.strictEqual(h.sessionOf(viaOrder.body.data.session_no).context_type, null);
      await h.cancelSession(ctx.buyerToken, viaOrder.body.data.session_no);

      const viaBook = await h.createSession(ctx, ctx.buyerToken, { context: { type: 'book', id: book.book_id } });
      assert.strictEqual(viaBook.status, 201, viaBook.text);
    }],

    ['訂單在其他書櫃、但書存放在此書櫃時，列為預設勾選的取回並提示存入訂單書櫃', async () => {
      const ctx = h.scene();
      const elsewhere = otherCabinet();
      const book = h.listedBook(ctx);
      h.addPlaced(book.book_id, h.doorOf(ctx.cabinet.cabinet_id, 2).slot_id);
      book.cabinet_id = elsewhere.cabinet.cabinet_id;
      book.status = 'reserved';
      const order = h.addPaidOrder({
        buyerId: ctx.buyer.user_id, sellerId: ctx.seller.user_id, bookId: book.book_id, cabinetId: elsewhere.cabinet.cabinet_id
      });
      const res = await h.createSession(ctx, ctx.sellerToken, { context: { type: 'order', id: order.order_id } });
      assert.strictEqual(res.status, 201, res.text);
      const unit = res.body.data.items[0];
      assert.strictEqual(unit.kind, 'retrieval');
      assert.strictEqual(unit.selected, true);
      assert.deepStrictEqual(unit.note, { code: 'MOVE_TO_ORDER_CABINET', message: '此書籍已售出，取回後請存入訂單指定的書櫃「師大書櫃」' });
    }],

    ['沒有可辦理的項目時為 404，附本人在其他書櫃的待辦項目', async () => {
      const ctx = h.scene();
      const elsewhere = otherCabinet();
      const book = h.addBook({ sellerId: ctx.seller.user_id, cabinet_id: elsewhere.cabinet.cabinet_id });
      h.addPaidOrder({
        buyerId: ctx.buyer.user_id, sellerId: ctx.seller.user_id, bookId: book.book_id, status: 'deposited',
        cabinetId: elsewhere.cabinet.cabinet_id, deposited_at: new Date()
      });
      const res = await h.createSession(ctx, ctx.buyerToken);
      assert.strictEqual(res.status, 404);
      assert.strictEqual(res.body.code, 'CABINET_NOTHING_TO_DO');
      assert.deepStrictEqual(res.body.other_cabinets, [{
        cabinet_id: elsewhere.cabinet.cabinet_id, cabinet_name: '師大書櫃', address: elsewhere.cabinet.address, kinds: ['pickup']
      }]);
    }],

    ['已有進行中的作業時為 CABINET_ACTIVE_SESSION；管理員遠端開櫃的作業不算', async () => {
      const ctx = pickupScene();
      const first = await h.createSession(ctx, ctx.buyerToken);
      assert.strictEqual(first.status, 201);
      const elsewhere = otherCabinet();
      const code = await h.scanCode(elsewhere.token, elsewhere.bootId);
      const second = await h.createSession(ctx, ctx.buyerToken, { code });
      assert.strictEqual(second.status, 409);
      assert.strictEqual(second.body.code, 'CABINET_ACTIVE_SESSION');
      assert.strictEqual(second.body.session_no, first.body.data.session_no);

      await h.sessionsService.adminOpen(elsewhere.cabinet.cabinet_id, h.doorOf(elsewhere.cabinet.cabinet_id, 1).slot_id,
        { reason: '測試', force: false }, { adminId: ctx.admin.user_id, req: null });
      const book = h.listedBook(ctx);
      h.orderFor(ctx, book.book_id, { status: 'deposited', buyer: ctx.admin });
      h.addPlaced(book.book_id, h.doorOf(ctx.cabinet.cabinet_id, 3).slot_id);
      await h.cancelSession(ctx.buyerToken, first.body.data.session_no);
      const admin = await h.createSession(ctx, ctx.adminToken);
      assert.strictEqual(admin.status, 201, admin.text);
    }],

    ['冷卻：連續兩個作業在開門前結束後回 429 CABINET_COOLDOWN', async () => {
      const ctx = pickupScene();
      const one = await h.createSession(ctx, ctx.buyerToken);
      h.expireSession(one.body.data.session_no);
      await h.sessionsService.sweep(new Date());
      const two = await h.createSession(ctx, ctx.buyerToken);
      assert.strictEqual(two.status, 201);
      await h.cancelSession(ctx.buyerToken, two.body.data.session_no);
      const three = await h.createSession(ctx, ctx.buyerToken);
      assert.strictEqual(three.status, 429);
      assert.strictEqual(three.body.code, 'CABINET_COOLDOWN');
      assert.ok(three.body.retry_after_s > 500 && three.body.retry_after_s <= 600);
      assert.strictEqual(three.body.message, '您在此書櫃的作業多次未完成，請於 10 分鐘後再試');

      for (const row of prisma.rows('cabinet_sessions')) row.finished_at = h.ago(11 * 60000);
      const later = await h.createSession(ctx, ctx.buyerToken);
      assert.strictEqual(later.status, 201);
    }],

    ['本人重送同一組碼：回 200 與同一個作業；作業結束後改回 410', async () => {
      const ctx = pickupScene();
      const code = await h.scan(ctx);
      const first = await h.createSession(ctx, ctx.buyerToken, { code });
      assert.strictEqual(first.status, 201);
      const again = await h.createSession(ctx, ctx.buyerToken, { code });
      assert.strictEqual(again.status, 200);
      assert.strictEqual(again.body.data.session_no, first.body.data.session_no);
      assert.strictEqual(prisma.rows('cabinet_sessions').length, 1);

      const stranger = h.addUser();
      const other = await h.createSession(ctx, h.tokenFor(stranger), { code });
      assert.strictEqual(other.status, 410);

      await h.cancelSession(ctx.buyerToken, first.body.data.session_no);
      const after = await h.createSession(ctx, ctx.buyerToken, { code });
      assert.strictEqual(after.status, 410);
    }],

    ['情境只決定預設勾選：兩筆取書只勾選情境對應的訂單', async () => {
      const ctx = pickupScene();
      const book = h.listedBook(ctx);
      const second = h.orderFor(ctx, book.book_id, { status: 'deposited' });
      h.addPlaced(book.book_id, h.doorOf(ctx.cabinet.cabinet_id, 2).slot_id);
      const res = await h.createSession(ctx, ctx.buyerToken, { context: { type: 'order', id: second.order_id } });
      const selected = res.body.data.items.filter((i) => i.selected).map((i) => i.key);
      assert.deepStrictEqual(selected, [`order:${second.order_id}`]);
      assert.strictEqual(res.body.data.items.length, 2);
      assert.strictEqual(h.sessionOf(res.body.data.session_no).context_type, 'order');

      const noContext = h.addUser();
      assert.ok(noContext);
    }],

    ['情境對應的訂單已變更時為 CABINET_CONTEXT_CHANGED', async () => {
      const ctx = pickupScene();
      ctx.order.picked_up_at = new Date();
      const book = h.listedBook(ctx);
      h.orderFor(ctx, book.book_id, { status: 'deposited' });
      h.addPlaced(book.book_id, h.doorOf(ctx.cabinet.cabinet_id, 2).slot_id);
      const res = await h.createSession(ctx, ctx.buyerToken, { context: { type: 'order', id: ctx.order.order_id } });
      assert.strictEqual(res.status, 409);
      assert.strictEqual(res.body.code, 'CABINET_CONTEXT_CHANGED');
      assert.strictEqual(res.body.message, '訂單狀態已變更，請重新整理後再試');
    }],

    ['DOOR_UNKNOWN：全部受阻時回 CABINET_ITEM_BLOCKED，記錄 item_blocked，24 小時內只通知一次，挑戰碼未被用掉', async () => {
      const ctx = h.scene();
      const book = h.listedBook(ctx);
      const order = h.orderFor(ctx, book.book_id, { status: 'deposited' });
      const code = await h.scan(ctx);
      const res = await h.createSession(ctx, ctx.buyerToken, { code });
      assert.strictEqual(res.status, 409);
      assert.strictEqual(res.body.code, 'CABINET_ITEM_BLOCKED');
      assert.strictEqual(res.body.message, '無法確認此項目的櫃門，請聯絡客服');
      assert.strictEqual(res.body.items[0].blocked.code, 'DOOR_UNKNOWN');
      assert.strictEqual(res.body.items[0].selected, false);
      const again = await h.createSession(ctx, ctx.buyerToken, { code });
      assert.strictEqual(again.body.code, 'CABINET_ITEM_BLOCKED');

      const events = h.eventsOf('item_blocked');
      assert.strictEqual(events.length, 2);
      assert.strictEqual(events[0].order_id, order.order_id);
      assert.deepStrictEqual(JSON.parse(events[0].detail), { code: 'DOOR_UNKNOWN', kind: 'pickup' });
      const notices = h.adminNotices(ctx, '書櫃項目無法辦理');
      assert.strictEqual(notices.length, 1);
      assert.strictEqual(notices[0].content, `「北商大書櫃」有使用者無法辦理訂單 ${order.order_no}（無法確認櫃門），請協助處理。`);

      h.addPlaced(book.book_id, h.doorOf(ctx.cabinet.cabinet_id, 1).slot_id);
      const ok = await h.createSession(ctx, ctx.buyerToken, { code });
      assert.strictEqual(ok.status, 201, ok.text);
    }],

    ['DOOR_CHECK 與 DOOR_FAULT：櫃門待確認或故障時不能勾選', async () => {
      const ctx = pickupScene();
      h.doorOf(ctx.cabinet.cabinet_id, 1).check_required_at = new Date();
      const checked = await h.createSession(ctx, ctx.buyerToken);
      assert.strictEqual(checked.body.items[0].blocked.code, 'DOOR_CHECK');
      h.doorOf(ctx.cabinet.cabinet_id, 1).check_required_at = null;
      h.doorOf(ctx.cabinet.cabinet_id, 1).fault_code = 'LOCK_NO_RELEASE';
      const faulty = await h.createSession(ctx, ctx.buyerToken);
      assert.strictEqual(faulty.body.items[0].blocked.code, 'DOOR_FAULT');
    }],

    ['PREDEPOSIT_LIMIT：已有一扇先行存書櫃門時，其他書不能再先行存書，但可取回', async () => {
      const ctx = h.scene();
      const stored = h.listedBook(ctx, { title: '已存書' });
      prisma.rows('book_deposits').push({
        book_id: stored.book_id, cabinet_id: ctx.cabinet.cabinet_id, deposited_at: new Date(), paused_at: null,
        auto_paused: false, reminded_at: null, escalated_at: null
      });
      h.addPlaced(stored.book_id, h.doorOf(ctx.cabinet.cabinet_id, 1).slot_id);
      const fresh = h.listedBook(ctx, { title: '新書' });

      const res = await h.createSession(ctx, ctx.sellerToken, { context: { type: 'book', id: fresh.book_id } });
      assert.strictEqual(res.status, 201, res.text);
      const pre = res.body.data.items.find((i) => i.key === `book:${fresh.book_id}`);
      assert.strictEqual(pre.kind, 'pre_deposit');
      assert.strictEqual(pre.blocked.code, 'PREDEPOSIT_LIMIT');
      assert.strictEqual(pre.selected, false);
      const back = res.body.data.items.find((i) => i.key === `book:${stored.book_id}`);
      assert.strictEqual(back.kind, 'retrieval');
      assert.strictEqual(back.blocked, null);
      assert.strictEqual(h.eventsOf('item_blocked').length, 0);
    }],

    ['可用櫃門只剩 1 扇時，先行存書為 CABINET_FULL，保留給依訂單存書', async () => {
      const ctx = h.scene({ doorCount: 2 });
      const stranger = h.addUser();
      const other = h.addBook({ sellerId: stranger.user_id, cabinet_id: ctx.cabinet.cabinet_id });
      h.addPlaced(other.book_id, h.doorOf(ctx.cabinet.cabinet_id, 1).slot_id);
      const book = h.listedBook(ctx);
      const res = await h.createSession(ctx, ctx.sellerToken, { context: { type: 'book', id: book.book_id } });
      assert.strictEqual(res.status, 409);
      assert.strictEqual(res.body.code, 'CABINET_ITEM_BLOCKED');
      assert.strictEqual(res.body.items[0].blocked.code, 'CABINET_FULL');
      assert.strictEqual(h.adminNotices(ctx, '書櫃項目無法辦理').length, 0);
    }],

    ['依訂單存書沒有空門時為 CABINET_FULL 並通知管理員；空門少於待存書籍時標示 DEPOSIT_PARTIAL，可先存入部分書籍', async () => {
      const ctx = h.scene({ doorCount: 2 });
      const stranger = h.addUser();
      const fillers = [1, 2].map((channel) => {
        const book = h.addBook({ sellerId: stranger.user_id, cabinet_id: ctx.cabinet.cabinet_id });
        h.addPlaced(book.book_id, h.doorOf(ctx.cabinet.cabinet_id, channel).slot_id);
        return book;
      });
      const [a, b] = [h.listedBook(ctx), h.listedBook(ctx)];
      const order = h.orderFor(ctx, [a.book_id, b.book_id]);
      const code = await h.scan(ctx);
      const full = await h.createSession(ctx, ctx.sellerToken, { code });
      assert.strictEqual(full.status, 409);
      assert.strictEqual(full.body.code, 'CABINET_ITEM_BLOCKED');
      assert.strictEqual(full.body.items[0].blocked.code, 'CABINET_FULL');
      assert.strictEqual(full.body.items[0].note, null);
      assert.strictEqual(h.adminNotices(ctx, '書櫃項目無法辦理')[0].content,
        `「北商大書櫃」有使用者無法辦理訂單 ${order.order_no}（可用櫃門不足），請協助處理。`);

      await api('services/cabinet-doors').removeBooks(prisma, [fillers[0].book_id]);
      const partial = await h.createSession(ctx, ctx.sellerToken, { code });
      assert.strictEqual(partial.status, 201, partial.text);
      const unit = partial.body.data.items[0];
      assert.strictEqual(unit.blocked, null);
      assert.strictEqual(unit.selected, true);
      assert.strictEqual(unit.note.code, 'DEPOSIT_PARTIAL');
    }],

    ['被拒絕時挑戰碼沒有被用掉，其他人仍可使用', async () => {
      const ctx = pickupScene();
      const code = await h.scan(ctx);
      const far = await h.createSession(ctx, ctx.buyerToken, {
        code, location_status: 'granted', location: { lat: 25.05, lng: 121.51, accuracy_m: 10, age_ms: 0 }
      });
      assert.strictEqual(far.status, 403);
      const owner = await h.createSession(ctx, ctx.buyerToken, { code });
      assert.strictEqual(owner.status, 201, owner.text);
      assert.ok(prisma.rows('cabinet_challenges').some((c) => c.used_at));
    }]
  ]
};
