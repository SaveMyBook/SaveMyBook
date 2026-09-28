const assert = require('assert');
const h = require('./harness');

const { prisma, api, request } = h;
const doors = api('services/cabinet-doors');

const rejects = async (promise, status, code) => {
  await assert.rejects(promise, (err) => {
    assert.strictEqual(err.status, status, err.message);
    assert.strictEqual(err.code, code);
    return true;
  });
};

const setup = ({ doorCount = 4 } = {}) => {
  const cabinet = h.addCabinet({ name: '中正書櫃' });
  const { device } = h.addDevice({ cabinetId: cabinet.cabinet_id, doorCount });
  const seller = h.addUser({ nickname: '小明' });
  const buyer = h.addUser();
  const door = (channel) => h.doorOf(cabinet.cabinet_id, channel);
  return { cabinet, device, seller, buyer, door };
};

const addOrderWith = ({ seller, buyer, cabinet, count, status = 'pending_deposit' }) => {
  const books = Array.from({ length: count }, (_, i) =>
    h.addBook({ sellerId: seller.user_id, title: `第 ${i + 1} 本`, status: 'reserved', cabinet_id: cabinet.cabinet_id }));
  const order = h.addOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: books[0].book_id, cabinetId: cabinet.cabinet_id, status });
  for (const book of books.slice(1)) {
    prisma.rows('order_items').push({
      item_id: prisma.nextId('order_items'), order_id: order.order_id, book_id: book.book_id, quantity: 1, unit_price: 100, subtotal: 100
    });
  }
  return { order, books, ids: books.map((b) => b.book_id) };
};

const addDeposit = (book, cabinet) => {
  prisma.rows('book_deposits').push({
    book_id: book.book_id, cabinet_id: cabinet.cabinet_id, deposited_at: new Date(), paused_at: null, auto_paused: false,
    reminded_at: null, escalated_at: null
  });
};

const addSession = (cabinet, device, userId, status) => {
  const row = {
    session_id: prisma.nextId('cabinet_sessions'), cabinet_id: cabinet.cabinet_id, device_id: device.device_id, user_id: userId,
    kind: 'user', status, version: 1, created_at: new Date()
  };
  prisma.rows('cabinet_sessions').push(row);
  return row;
};

const summary = (entries) => entries.map((e) => [doors.doorLabel(e.lock_channel), e.book_ids]);

module.exports = {
  name: '書櫃櫃門：分配、內容紀錄與待確認',
  tests: [
    ['依通道由小到大分配，跳過故障、維修、待確認、保留（含待確認作業）與有書的櫃門', async () => {
      const ctx = setup({ doorCount: 6 });
      const other = h.addBook({ sellerId: h.addUser().user_id, cabinet_id: ctx.cabinet.cabinet_id });
      ctx.door(1).fault_code = 'LOCK_NO_RELEASE';
      ctx.door(2).status = 'maintenance';
      ctx.door(3).check_required_at = new Date();
      h.addPlaced(other.book_id, ctx.door(4).slot_id);
      const review = addSession(ctx.cabinet, ctx.device, ctx.buyer.user_id, 'needs_review');
      prisma.rows('cabinet_session_doors').push({ session_id: review.session_id, slot_id: ctx.door(5).slot_id, lock_channel: 5, state: 'open' });
      await doors.refresh(prisma, [ctx.door(5).slot_id]);
      assert.strictEqual(ctx.door(5).status, 'reserved');

      const { order, ids } = addOrderWith({ ...ctx, count: 1 });
      const result = await doors.allocate(prisma, {
        cabinetId: ctx.cabinet.cabinet_id, sessionId: 99, sellerId: ctx.seller.user_id,
        units: [{ key: `order:${order.order_id}`, kind: 'order_deposit', bookIds: ids, orderId: order.order_id }]
      });
      assert.deepStrictEqual(summary(result.get(`order:${order.order_id}`)), [['A06', ids]]);
      assert.strictEqual(ctx.door(6).status, 'reserved');
      assert.strictEqual(h.cabinetRow(ctx.cabinet.cabinet_id).available_slots, 0);

      await rejects(doors.allocate(prisma, {
        cabinetId: ctx.cabinet.cabinet_id, sellerId: ctx.seller.user_id,
        units: [{ key: 'order:x', kind: 'order_deposit', bookIds: ids, orderId: order.order_id }]
      }), 409, 'CABINET_FULL');
    }],

    ['依訂單存書：先補進同一訂單未滿的櫃門，再以最少的門數平均分配', async () => {
      const ctx = setup();
      const { order, ids } = addOrderWith({ ...ctx, count: 6 });
      h.addPlaced(ids[0], ctx.door(3).slot_id);

      const result = await doors.allocate(prisma, {
        cabinetId: ctx.cabinet.cabinet_id, sellerId: ctx.seller.user_id,
        units: [{ key: 'order', kind: 'order_deposit', bookIds: [ids[5], ids[1], ids[2], ids[3], ids[4]], orderId: order.order_id }]
      });
      assert.deepStrictEqual(summary(result.get('order')), [
        ['A03', [ids[1], ids[2]]],
        ['A01', [ids[3], ids[4], ids[5]]]
      ]);
      assert.strictEqual(ctx.door(3).status, 'occupied', '既有的門不改變狀態');
      assert.strictEqual(ctx.door(1).status, 'reserved');

      const seven = setup();
      const big = addOrderWith({ ...seven, count: 7 });
      const split = await doors.allocate(prisma, {
        cabinetId: seven.cabinet.cabinet_id, sellerId: seven.seller.user_id,
        units: [{ key: 'o', kind: 'order_deposit', bookIds: big.ids, orderId: big.order.order_id }]
      });
      assert.deepStrictEqual(split.get('o').map((e) => e.book_ids.length), [3, 2, 2]);
    }],

    ['本數超過門數 × 3 時放寬每門本數；書都已在書櫃時改為開啟現有的櫃門', async () => {
      const ctx = setup();
      const { order, ids } = addOrderWith({ ...ctx, count: 13 });
      const result = await doors.allocate(prisma, {
        cabinetId: ctx.cabinet.cabinet_id, sellerId: ctx.seller.user_id,
        units: [{ key: 'o', kind: 'order_deposit', bookIds: ids, orderId: order.order_id }]
      });
      assert.deepStrictEqual(result.get('o').map((e) => [doors.doorLabel(e.lock_channel), e.book_ids.length]),
        [['A01', 4], ['A02', 3], ['A03', 3], ['A04', 3]]);

      const again = setup();
      const placed = addOrderWith({ ...again, count: 2 });
      h.addPlaced(placed.ids[0], again.door(2).slot_id);
      h.addPlaced(placed.ids[1], again.door(4).slot_id);
      const reopen = await doors.allocate(prisma, {
        cabinetId: again.cabinet.cabinet_id, sellerId: again.seller.user_id,
        units: [{ key: 'o', kind: 'order_deposit', bookIds: [], orderId: placed.order.order_id }]
      });
      assert.deepStrictEqual(summary(reopen.get('o')), [['A02', []], ['A04', []]]);
      assert.strictEqual(h.cabinetRow(again.cabinet.cabinet_id).available_slots, 2, '沒有占用新的門');
    }],

    ['先行存書保留 1 扇門給依訂單存書，且每位賣家在同一台書櫃最多 1 扇', async () => {
      const ctx = setup();
      const filler = h.addUser();
      h.addPlaced(h.addBook({ sellerId: filler.user_id }).book_id, ctx.door(3).slot_id);
      h.addPlaced(h.addBook({ sellerId: filler.user_id }).book_id, ctx.door(4).slot_id);
      const book = h.addBook({ sellerId: ctx.seller.user_id, cabinet_id: ctx.cabinet.cabinet_id });

      const first = await doors.allocate(prisma, {
        cabinetId: ctx.cabinet.cabinet_id, sellerId: ctx.seller.user_id,
        units: [{ key: `book:${book.book_id}`, kind: 'pre_deposit', bookIds: [book.book_id] }]
      });
      assert.deepStrictEqual(summary(first.get(`book:${book.book_id}`)), [['A01', [book.book_id]]]);

      const late = h.addUser();
      const lateBook = h.addBook({ sellerId: late.user_id, cabinet_id: ctx.cabinet.cabinet_id });
      await assert.rejects(doors.allocate(prisma, {
        cabinetId: ctx.cabinet.cabinet_id, sellerId: late.user_id,
        units: [{ key: 'b', kind: 'pre_deposit', bookIds: [lateBook.book_id] }]
      }), (err) => {
        assert.strictEqual(err.code, 'CABINET_FULL');
        assert.deepStrictEqual(err.extra, { available_doors: 1, required_doors: 2 });
        return true;
      });
      assert.deepStrictEqual(await doors.previewCapacity(ctx.cabinet.cabinet_id, { sellerId: late.user_id }),
        { available_doors: 1, pre_deposit_doors: 0, seller_pre_deposit_doors: 0 });

      const roomy = setup();
      const stored = h.addBook({ sellerId: roomy.seller.user_id, cabinet_id: roomy.cabinet.cabinet_id });
      addDeposit(stored, roomy.cabinet);
      h.addPlaced(stored.book_id, roomy.door(4).slot_id);
      const second = h.addBook({ sellerId: roomy.seller.user_id, cabinet_id: roomy.cabinet.cabinet_id });
      assert.strictEqual((await doors.previewCapacity(roomy.cabinet.cabinet_id, { sellerId: roomy.seller.user_id })).seller_pre_deposit_doors, 1);
      await rejects(doors.allocate(prisma, {
        cabinetId: roomy.cabinet.cabinet_id, sellerId: roomy.seller.user_id,
        units: [{ key: 'b', kind: 'pre_deposit', bookIds: [second.book_id] }]
      }), 409, 'PREDEPOSIT_LIMIT');
    }],

    ['賣家上限計入進行中與待確認作業的先行存書櫃門，不計入訂單的櫃門', async () => {
      const ctx = setup();
      const sold = addOrderWith({ ...ctx, count: 1, status: 'deposited' });
      h.addPlaced(sold.ids[0], ctx.door(4).slot_id);
      assert.strictEqual((await doors.previewCapacity(ctx.cabinet.cabinet_id, { sellerId: ctx.seller.user_id })).seller_pre_deposit_doors, 0);

      const pending = h.addBook({ sellerId: ctx.seller.user_id, cabinet_id: ctx.cabinet.cabinet_id });
      const review = addSession(ctx.cabinet, ctx.device, ctx.seller.user_id, 'needs_review');
      prisma.rows('cabinet_session_items').push({
        item_id: prisma.nextId('cabinet_session_items'), session_id: review.session_id, kind: 'pre_deposit', book_id: pending.book_id,
        slot_id: ctx.door(1).slot_id, selected: true, result: 'pending'
      });
      assert.strictEqual((await doors.previewCapacity(ctx.cabinet.cabinet_id, { sellerId: ctx.seller.user_id })).seller_pre_deposit_doors, 1);

      const next = h.addBook({ sellerId: ctx.seller.user_id, cabinet_id: ctx.cabinet.cabinet_id });
      await rejects(doors.allocate(prisma, {
        cabinetId: ctx.cabinet.cabinet_id, sellerId: ctx.seller.user_id,
        units: [{ key: 'b', kind: 'pre_deposit', bookIds: [next.book_id] }]
      }), 409, 'PREDEPOSIT_LIMIT');

      review.status = 'completed';
      const ok = await doors.allocate(prisma, {
        cabinetId: ctx.cabinet.cabinet_id, sessionId: 500, sellerId: ctx.seller.user_id,
        units: [{ key: 'b', kind: 'pre_deposit', bookIds: [next.book_id] }]
      });
      assert.strictEqual(ok.get('b').length, 1);
    }],

    ['placeBooks 寫入實體位置並搬移既有紀錄；removeBooks 回傳受影響的櫃門', async () => {
      const ctx = setup();
      const book = h.addBook({ sellerId: ctx.seller.user_id, cabinet_id: ctx.cabinet.cabinet_id });
      await doors.placeBooks(prisma, { cabinetId: ctx.cabinet.cabinet_id, slotId: ctx.door(1).slot_id, bookIds: [book.book_id], sessionId: 7 });
      let [item] = prisma.rows('cabinet_slot_items');
      assert.deepStrictEqual([item.slot_id, item.session_id, item.placed_by], [ctx.door(1).slot_id, 7, 'session']);
      assert.strictEqual(ctx.door(1).status, 'occupied');
      assert.strictEqual(h.cabinetRow(ctx.cabinet.cabinet_id).available_slots, 3);

      const placedAt = item.placed_at;
      await doors.placeBooks(prisma, { cabinetId: ctx.cabinet.cabinet_id, slotId: ctx.door(1).slot_id, bookIds: [book.book_id], sessionId: 7 });
      assert.strictEqual(prisma.rows('cabinet_slot_items')[0].placed_at, placedAt, '重跑沒有副作用');

      const moved = await doors.placeBooks(prisma, {
        cabinetId: ctx.cabinet.cabinet_id, slotId: ctx.door(2).slot_id, bookIds: [book.book_id], source: 'admin'
      });
      assert.deepStrictEqual(moved.moved, [book.book_id]);
      [item] = prisma.rows('cabinet_slot_items');
      assert.strictEqual(prisma.rows('cabinet_slot_items').length, 1);
      assert.deepStrictEqual([item.slot_id, item.placed_by], [ctx.door(2).slot_id, 'admin']);
      assert.strictEqual(ctx.door(1).status, 'empty');
      assert.strictEqual(ctx.door(2).status, 'occupied');

      const map = await doors.bookDoors([book.book_id]);
      assert.deepStrictEqual(map.get(book.book_id), {
        slot_id: ctx.door(2).slot_id, cabinet_id: ctx.cabinet.cabinet_id, channel: 2, label: 'A02', fault_code: null, check_required_at: null
      });
      assert.deepStrictEqual(await doors.booksInSlot(prisma, ctx.door(2).slot_id), [book.book_id]);

      assert.deepStrictEqual(await doors.removeBooks(prisma, [book.book_id]), [ctx.door(2).slot_id]);
      assert.deepStrictEqual(await doors.removeBooks(prisma, [book.book_id]), []);
      assert.strictEqual(ctx.door(2).status, 'empty');
      assert.strictEqual(h.cabinetRow(ctx.cabinet.cabinet_id).available_slots, 4);
    }],

    ['櫃門狀態推導：維修保持、有書為使用中、未結束作業為保留，其餘為空', async () => {
      const ctx = setup();
      const book = h.addBook({ sellerId: ctx.seller.user_id });
      prisma.rows('cabinet_slot_items').push({ book_id: book.book_id, slot_id: ctx.door(1).slot_id, cabinet_id: ctx.cabinet.cabinet_id, placed_at: new Date() });
      ctx.door(2).status = 'maintenance';
      prisma.rows('cabinet_slot_items').push({ book_id: h.addBook({ sellerId: ctx.seller.user_id }).book_id, slot_id: ctx.door(2).slot_id, cabinet_id: ctx.cabinet.cabinet_id, placed_at: new Date() });
      const running = addSession(ctx.cabinet, ctx.device, ctx.buyer.user_id, 'matching');
      prisma.rows('cabinet_session_doors').push({ session_id: running.session_id, slot_id: ctx.door(3).slot_id, lock_channel: 3, state: 'pending' });
      const done = addSession(ctx.cabinet, ctx.device, ctx.buyer.user_id, 'completed');
      prisma.rows('cabinet_session_doors').push({ session_id: done.session_id, slot_id: ctx.door(4).slot_id, lock_channel: 4, state: 'closed' });
      ctx.door(4).status = 'reserved';

      await doors.refresh(prisma, [1, 2, 3, 4].map((c) => ctx.door(c).slot_id));
      assert.deepStrictEqual([1, 2, 3, 4].map((c) => ctx.door(c).status), ['occupied', 'maintenance', 'reserved', 'empty']);
      assert.strictEqual(h.cabinetRow(ctx.cabinet.cabinet_id).available_slots, 1);

      prisma.rows('cabinet_session_doors')[0].state = 'failed';
      await doors.refresh(prisma, [ctx.door(3).slot_id]);
      assert.strictEqual(ctx.door(3).status, 'empty', '開鎖失敗的門不保留');
    }],

    ['待確認櫃門：markCheck 記錄事件並排除分配；三種方式都可解除', async () => {
      const admin = h.addAdmin();
      const token = h.tokenFor(admin);
      const ctx = setup();
      const now = new Date(Date.now() - 60 * 1000);
      const marked = await doors.markCheck(prisma, [ctx.door(1).slot_id, ctx.door(2).slot_id, ctx.door(3).slot_id],
        { reason: 'CANCELLED_AFTER_OPEN', sessionId: 12, now });
      assert.deepStrictEqual(marked.map((m) => m.label), ['A01', 'A02', 'A03']);
      assert.strictEqual(ctx.door(1).check_reason, 'CANCELLED_AFTER_OPEN');
      assert.strictEqual(ctx.door(1).check_session_id, 12);
      assert.strictEqual(h.eventsOf('door_check_required').length, 3);
      assert.strictEqual(h.cabinetRow(ctx.cabinet.cabinet_id).available_slots, 1);

      await doors.markCheck(prisma, [ctx.door(1).slot_id], { reason: 'LATE_OPEN', sessionId: 13 });
      assert.strictEqual(ctx.door(1).check_required_at, now, '已有值時保留原本的時間');
      assert.strictEqual(ctx.door(1).check_reason, 'LATE_OPEN');

      const confirm = await request('POST', `/api/admin/cabinets/${ctx.cabinet.cabinet_id}/doors/${ctx.door(1).slot_id}/check-clear`, {
        token, body: { note: '現場確認無書' }
      });
      assert.strictEqual(confirm.status, 200);
      assert.strictEqual(confirm.body.data.check, null);
      assert.strictEqual(ctx.door(1).check_required_at, null);
      assert.strictEqual(ctx.door(1).check_session_id, null);
      const [cleared] = h.eventsOf('door_check_cleared');
      assert.strictEqual(cleared.source, 'admin');
      assert.strictEqual(cleared.actor_id, admin.user_id);
      assert.deepStrictEqual(JSON.parse(cleared.detail), { mode: 'confirm', reason: 'LATE_OPEN', note: '現場確認無書', label: 'A01' });
      assert.match(JSON.parse(h.logs().at(-1).detail).summary, /A01.*相符（現場確認無書）/);

      const stored = h.addBook({ sellerId: ctx.seller.user_id, cabinet_id: ctx.cabinet.cabinet_id, title: '資料庫系統概論' });
      addDeposit(stored, ctx.cabinet);
      const place = await request('POST', `/api/admin/cabinets/${ctx.cabinet.cabinet_id}/doors/${ctx.door(2).slot_id}/place`, {
        token, body: { book_ids: [stored.book_id] }
      });
      assert.strictEqual(place.status, 200, JSON.stringify(place.body));
      assert.strictEqual(ctx.door(2).check_required_at, null);
      assert.strictEqual(JSON.parse(h.eventsOf('door_check_cleared')[1].detail).mode, 'place');

      assert.strictEqual(await doors.clearCheck(prisma, ctx.door(3).slot_id, { actorId: admin.user_id, mode: 'clear', note: '書籍已取出' }), true);
      assert.strictEqual(await doors.clearCheck(prisma, ctx.door(3).slot_id, { actorId: admin.user_id }), false);
      assert.strictEqual(JSON.parse(h.eventsOf('door_check_cleared')[2].detail).mode, 'clear');
      assert.strictEqual(h.cabinetRow(ctx.cabinet.cabinet_id).available_slots, 3);
    }],

    ['後台登記存放內容：只能登記本書櫃未登記的書，且同一扇門只能有一個保管單位', async () => {
      const admin = h.addAdmin();
      const token = h.tokenFor(admin);
      const ctx = setup();
      const url = (slotId, cabinetId = ctx.cabinet.cabinet_id) => `/api/admin/cabinets/${cabinetId}/doors/${slotId}/place`;
      const { order, ids } = addOrderWith({ ...ctx, count: 2, status: 'deposited' });
      const stored = h.addBook({ sellerId: ctx.seller.user_id, cabinet_id: ctx.cabinet.cabinet_id, title: '存書 A' });
      const stored2 = h.addBook({ sellerId: ctx.seller.user_id, cabinet_id: ctx.cabinet.cabinet_id, title: '存書 B' });
      addDeposit(stored, ctx.cabinet);
      addDeposit(stored2, ctx.cabinet);
      const elsewhere = h.addCabinet();
      const foreign = h.addBook({ sellerId: ctx.seller.user_id, cabinet_id: elsewhere.cabinet_id });
      addDeposit(foreign, elsewhere);

      const before = await request('GET', `/api/admin/cabinets/${ctx.cabinet.cabinet_id}/device`, { token });
      assert.deepStrictEqual(before.body.data.unplaced.map((u) => [u.kind, u.book_id, u.order_no]).sort(), [
        ['deposit', stored.book_id, null], ['deposit', stored2.book_id, null], ['order', ids[0], order.order_no], ['order', ids[1], order.order_no]
      ].sort());

      const both = await request('POST', url(ctx.door(1).slot_id), { token, body: { order_id: order.order_id, book_ids: [stored.book_id] } });
      assert.strictEqual(both.status, 400);
      const neither = await request('POST', url(ctx.door(1).slot_id), { token, body: {} });
      assert.strictEqual(neither.status, 400);

      const res = await request('POST', url(ctx.door(1).slot_id), { token, body: { order_id: order.order_id } });
      assert.strictEqual(res.status, 200, JSON.stringify(res.body));
      assert.deepStrictEqual(res.body.data.items.map((i) => [i.kind, i.book_id, i.order_no, i.seller_nickname]),
        [['order', ids[0], order.order_no, '小明'], ['order', ids[1], order.order_no, '小明']]);
      assert.ok(prisma.rows('cabinet_slot_items').every((i) => i.placed_by === 'admin'));
      const [placed] = h.eventsOf('door_placed');
      assert.deepStrictEqual([placed.source, placed.actor_id, placed.lock_channel, placed.order_id], ['admin', admin.user_id, 1, order.order_id]);

      const invalid = async (slotId, body, cabinetId) => {
        const r = await request('POST', url(slotId, cabinetId), { token, body });
        assert.strictEqual(r.status, 409, JSON.stringify(body));
        assert.strictEqual(r.body.code, 'DOOR_ASSIGN_INVALID');
        assert.strictEqual(r.body.message, '此項目不在本書櫃、已有櫃門紀錄，或與櫃內其他項目不屬於同一筆訂單或同一本書');
      };
      await invalid(ctx.door(1).slot_id, { book_ids: [stored.book_id] });
      await invalid(ctx.door(2).slot_id, { book_ids: [ids[0]] });
      await invalid(ctx.door(2).slot_id, { book_ids: [foreign.book_id] });
      await invalid(ctx.door(2).slot_id, { book_ids: [stored.book_id, stored2.book_id] });
      await invalid(ctx.door(2).slot_id, { order_id: order.order_id });

      const ok = await request('POST', url(ctx.door(2).slot_id), { token, body: { book_ids: [stored.book_id] } });
      assert.strictEqual(ok.status, 200);
      assert.deepStrictEqual(ok.body.data.items.map((i) => i.kind), ['deposit']);
      await invalid(ctx.door(2).slot_id, { book_ids: [stored2.book_id] });

      const missing = await request('POST', url(h.doorOf(elsewhere.cabinet_id, 1)?.slot_id ?? 9999), { token, body: { book_ids: [stored2.book_id] } });
      assert.strictEqual(missing.status, 404);
      assert.strictEqual(missing.body.code, 'DOOR_NOT_FOUND');
    }],

    ['待確認櫃門列出可能存放的書籍，並可直接登記', async () => {
      const admin = h.addAdmin();
      const token = h.tokenFor(admin);
      const ctx = setup();
      const book = h.addBook({ sellerId: ctx.seller.user_id, cabinet_id: ctx.cabinet.cabinet_id, title: '作業系統' });
      const session = addSession(ctx.cabinet, ctx.device, ctx.seller.user_id, 'cancelled');
      prisma.rows('cabinet_session_items').push({
        item_id: prisma.nextId('cabinet_session_items'), session_id: session.session_id, kind: 'pre_deposit', book_id: book.book_id,
        order_id: null, slot_id: ctx.door(2).slot_id, selected: true, result: 'skipped'
      });
      await doors.markCheck(prisma, [ctx.door(2).slot_id], { reason: 'CANCELLED_AFTER_OPEN', sessionId: session.session_id });

      const res = await request('GET', `/api/admin/cabinets/${ctx.cabinet.cabinet_id}/device`, { token });
      const door = res.body.data.doors[1];
      assert.strictEqual(door.check.reason, 'CANCELLED_AFTER_OPEN');
      assert.strictEqual(door.check.session_no, h.publicId.encode('cabinet_session', session.session_id));
      assert.deepStrictEqual(door.check.candidates, [{
        book_id: book.book_id, book_no: h.publicId.encode('book', book.book_id), title: '作業系統', kind: 'pre_deposit', order_id: null
      }]);

      const placed = await request('POST', `/api/admin/cabinets/${ctx.cabinet.cabinet_id}/doors/${ctx.door(2).slot_id}/place`, {
        token, body: { book_ids: [book.book_id] }
      });
      assert.strictEqual(placed.status, 200, JSON.stringify(placed.body));
      assert.strictEqual(placed.body.data.check, null);
      assert.deepStrictEqual(placed.body.data.items.map((i) => [i.kind, i.title]), [['other', '作業系統']]);
    }],

    ['有裝置的書櫃，櫃門狀態僅可設定或結束維修；後台列表附上裝置與櫃門欄位', async () => {
      const admin = h.addAdmin();
      const token = h.tokenFor(admin);
      const ctx = setup();
      const patch = (slotId, status, cabinetId = ctx.cabinet.cabinet_id) =>
        request('PATCH', `/api/admin/cabinets/${cabinetId}/slots/${slotId}`, { token, body: { status } });

      const derived = await patch(ctx.door(1).slot_id, 'occupied');
      assert.strictEqual(derived.status, 409);
      assert.strictEqual(derived.body.code, 'SLOT_STATUS_DERIVED');
      assert.strictEqual(derived.body.message, '此櫃門狀態由系統依存放內容判定，僅可設定或結束維修');

      assert.strictEqual((await patch(ctx.door(1).slot_id, 'maintenance')).status, 200);
      assert.strictEqual(h.cabinetRow(ctx.cabinet.cabinet_id).available_slots, 3);
      h.addPlaced(h.addBook({ sellerId: ctx.seller.user_id }).book_id, ctx.door(1).slot_id);
      const ended = await patch(ctx.door(1).slot_id, 'empty');
      assert.strictEqual(ended.status, 200);
      assert.strictEqual(ended.body.data.status, 'occupied', '結束維修後依存放內容推導');
      assert.strictEqual((await patch(ctx.door(2).slot_id, 'reserved')).status, 409);

      const legacy = h.addCabinet();
      const slot = { slot_id: prisma.nextId('cabinet_slots'), cabinet_id: legacy.cabinet_id, slot_number: 'A01', status: 'empty', lock_channel: null };
      prisma.rows('cabinet_slots').push(slot);
      assert.strictEqual((await patch(slot.slot_id, 'occupied', legacy.cabinet_id)).status, 200, '沒有裝置的書櫃維持原本行為');

      prisma.rows('cabinet_slots').push({ slot_id: prisma.nextId('cabinet_slots'), cabinet_id: ctx.cabinet.cabinet_id, slot_number: 'A09', status: 'occupied', lock_channel: null });
      const list = await request('GET', '/api/admin/cabinets', { token });
      const row = list.body.data.find((c) => c.cabinet_id === ctx.cabinet.cabinet_id);
      assert.deepStrictEqual(row.device, {
        device_no: h.devices.deviceNo(ctx.device), kind: 'esp32', status: 'active', online: true, last_seen_at: row.device.last_seen_at
      });
      assert.deepStrictEqual(row.slot_summary, { empty: 3, occupied: 1, reserved: 0, maintenance: 0 }, '只計算有通道的櫃門');
      assert.ok(row.cabinet_slots.every((s) => 'lock_channel' in s && 'fault_code' in s && 'check_required_at' in s));
      assert.strictEqual(list.body.data.find((c) => c.cabinet_id === legacy.cabinet_id).device, null);
    }],

    ['後台清除櫃門與裝置故障、查詢事件紀錄', async () => {
      const admin = h.addAdmin();
      const token = h.tokenFor(admin);
      const ctx = setup();
      const base = `/api/admin/cabinets/${ctx.cabinet.cabinet_id}`;
      ctx.door(3).fault_code = 'LOCK_NO_RELEASE';
      ctx.device.fault_code = 'POWER';
      ctx.device.fault_since = new Date();

      const door = await request('POST', `${base}/doors/${ctx.door(3).slot_id}/fault-clear`, { token });
      assert.strictEqual(door.status, 200);
      assert.strictEqual(door.body.data.fault_code, null);
      assert.strictEqual(ctx.door(3).fault_code, null);
      const device = await request('POST', `${base}/device/fault-clear`, { token });
      assert.strictEqual(device.status, 200);
      assert.strictEqual(ctx.device.fault_code, null);
      assert.strictEqual(ctx.device.fault_since, null);
      assert.deepStrictEqual(h.eventsOf('fault_cleared').map((e) => [e.source, e.lock_channel, JSON.parse(e.detail).code]),
        [['admin', 3, 'LOCK_NO_RELEASE'], ['admin', null, 'POWER']]);

      const events = await request('GET', `${base}/events?limit=1`, { token });
      assert.strictEqual(events.status, 200);
      assert.deepStrictEqual(events.body.pagination, { total: 2, page: 1, limit: 1, total_pages: 2 });
      const [latest] = events.body.data;
      assert.strictEqual(latest.type, 'fault_cleared');
      assert.deepStrictEqual(latest.actor, { user_no: h.publicId.encode('user', admin.user_id), nickname: admin.nickname });
      assert.strictEqual('event_id' in latest, false);
      assert.strictEqual(latest.device_no, h.devices.deviceNo(ctx.device));
      const filtered = await request('GET', `${base}/events?type=paired`, { token });
      assert.deepStrictEqual(filtered.body.data, []);

      const bare = h.addCabinet();
      const none = await request('POST', `/api/admin/cabinets/${bare.cabinet_id}/device/fault-clear`, { token });
      assert.strictEqual(none.status, 409);
      assert.strictEqual(none.body.code, 'DEVICE_NOT_PAIRED');
      const missing = await request('GET', '/api/admin/cabinets/9999/events', { token });
      assert.strictEqual(missing.status, 404);
    }]
  ]
};
