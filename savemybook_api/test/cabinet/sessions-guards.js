const assert = require('assert');
const h = require('./session-harness');

const { prisma, api } = h;

const addDeposit = (ctx, book, channel = null) => {
  prisma.rows('book_deposits').push({
    book_id: book.book_id, cabinet_id: ctx.cabinet.cabinet_id, deposited_at: new Date(), paused_at: null,
    auto_paused: false, reminded_at: null, escalated_at: null
  });
  if (channel) h.addPlaced(book.book_id, h.doorOf(ctx.cabinet.cabinet_id, channel).slot_id);
};

// 開到櫃門開啟、尚未關門的狀態。
const openSession = async (ctx, token, keys) => {
  const created = await h.createSession(ctx, token);
  assert.strictEqual(created.status, 201, created.text);
  const no = created.body.data.session_no;
  const started = await h.startSession(token, no, keys ?? created.body.data.items.filter((i) => i.selected).map((i) => i.key));
  assert.strictEqual(started.status, 200, started.text);
  await h.selectNumber(ctx, no);
  const { commands } = await h.openDoors(ctx, no);
  return { no, channels: commands.map((c) => c.channel) };
};

const toReview = async (no) => {
  h.expireSession(no);
  await h.sessionsService.sweep(new Date());
  assert.strictEqual(h.sessionOf(no).status, 'needs_review');
};

const adminOpen = (ctx, slot, { force = false } = {}) => h.request('POST', `/api/admin/cabinets/${ctx.cabinet.cabinet_id}/doors/${slot.slot_id}/open`, {
  token: ctx.adminToken, headers: h.adminVerifyHeaders(ctx.adminToken), body: { reason: '測試電磁鎖', force }
});

const resolve = (token, no, action = 'commit') => h.request('POST', `/api/admin/cabinet-sessions/${no}/resolve`, {
  token, body: { action, note: '已與現場人員確認' }
});

module.exports = {
  name: '書櫃作業：並行、異常與職責分離的防護',
  tests: [
    ['作業開門期間雙方都不能提出申訴；取書提交失敗而櫃門曾開啟時，櫃門設為待確認並通知管理員', async () => {
      const ctx = h.scene();
      const book = h.listedBook(ctx);
      const order = h.orderFor(ctx, book.book_id, { status: 'deposited' });
      const door = h.doorOf(ctx.cabinet.cabinet_id, 2);
      h.addPlaced(book.book_id, door.slot_id);
      const { no, channels } = await openSession(ctx, ctx.buyerToken);

      for (const token of [ctx.buyerToken, ctx.sellerToken]) {
        const filed = await h.request('POST', '/api/disputes', { token, body: { order_id: order.order_id, reason: '書櫃中找不到書籍' } });
        assert.strictEqual(filed.status, 409, filed.text);
        assert.strictEqual(filed.body.code, 'ORDER_IN_CABINET_SESSION');
        assert.strictEqual(filed.body.message, '此訂單正於書櫃辦理中，請稍後再試');
      }
      assert.strictEqual(h.orderOf(order.order_id).status, 'deposited');
      assert.strictEqual(prisma.rows('transaction_disputes').length, 0);

      // 申訴在檢查之後、開門之前的空檔成立：取書無法提交，書可能已被取走而紀錄仍在門內。
      h.orderOf(order.order_id).status = 'refunding';
      await h.closeSession(ctx, no, { channels });
      const final = (await h.getSession(ctx.buyerToken, no)).body.data;
      assert.strictEqual(final.status, 'partial');
      assert.strictEqual(final.items[0].error.code, 'ITEM_CHANGED');
      assert.strictEqual(h.orderOf(order.order_id).picked_up_at, null);
      assert.ok(h.slotItemOf(book.book_id));
      assert.ok(door.check_required_at instanceof Date);
      assert.strictEqual(door.check_reason, 'ITEM_FAILED_AFTER_OPEN');
      assert.ok(h.eventsOf('door_check_required').some((e) => JSON.parse(e.detail).reason === 'ITEM_FAILED_AFTER_OPEN'));
      assert.strictEqual(h.adminNotices(ctx, '書櫃作業部分未完成').length, 1);

      await h.closeSession(ctx, no, { channels });
      assert.strictEqual(h.eventsOf('door_check_required').length, 1, '重送關門回報不重複設定待確認');
    }],

    ['取回：列項之後、暫停販售之前被買走時回 CABINET_ITEMS_CHANGED，不開門也不刪除紀錄', async () => {
      const ctx = h.scene();
      const book = h.listedBook(ctx);
      addDeposit(ctx, book, 1);
      const created = await h.createSession(ctx, ctx.sellerToken, { context: { type: 'book', id: book.book_id } });
      assert.strictEqual(created.status, 201, created.text);
      const no = created.body.data.session_no;

      const candidates = api('services/cabinet-candidates');
      const original = candidates.list;
      let raced = false;
      candidates.list = async (...args) => {
        const result = await original(...args);
        if (!raced) {
          raced = true;
          const bought = await h.request('POST', '/api/orders/buy-now', {
            token: ctx.buyerToken, headers: h.verifyHeaders(ctx.buyerToken, 'payment'), body: { book_id: book.book_id }
          });
          assert.strictEqual(bought.status, 201, bought.text);
          assert.strictEqual(bought.body.data.status, 'deposited');
        }
        return result;
      };
      try {
        const started = await h.startSession(ctx.sellerToken, no, [`book:${book.book_id}`]);
        assert.strictEqual(started.status, 409, started.text);
        assert.strictEqual(started.body.code, 'CABINET_ITEMS_CHANGED');
        assert.strictEqual(started.body.session.status, 'selecting');
        assert.ok(!started.body.session.items.some((i) => i.key === `book:${book.book_id}`));
      } finally {
        candidates.list = original;
      }
      assert.strictEqual(h.sessionOf(no).status, 'selecting');
      assert.strictEqual(h.doorsOf(no).length, 0);
      assert.strictEqual(h.bookOf(book.book_id).status, 'reserved');
      assert.ok(h.slotItemOf(book.book_id), '書仍在櫃內，等待買家取書');
    }],

    ['取回：提交時重新檢查，書已成立本書櫃的訂單時不刪除紀錄，櫃門設為待確認', async () => {
      const ctx = h.scene();
      const book = h.listedBook(ctx);
      addDeposit(ctx, book, 3);
      const { no, channels } = await openSession(ctx, ctx.sellerToken, [`book:${book.book_id}`]);

      prisma.store.book_deposits = prisma.rows('book_deposits').filter((r) => r.book_id !== book.book_id);
      h.bookOf(book.book_id).status = 'reserved';
      const order = h.addPaidOrder({
        buyerId: ctx.buyer.user_id, sellerId: ctx.seller.user_id, bookId: book.book_id, cabinetId: ctx.cabinet.cabinet_id,
        status: 'deposited', deposited_at: new Date()
      });

      await h.closeSession(ctx, no, { channels });
      const final = (await h.getSession(ctx.sellerToken, no)).body.data;
      assert.strictEqual(final.status, 'partial');
      assert.strictEqual(final.items[0].error.code, 'ITEM_CHANGED');
      assert.ok(h.slotItemOf(book.book_id), '已售出的書不得在取回時刪除櫃內紀錄');
      assert.strictEqual(h.doorOf(ctx.cabinet.cabinet_id, 3).check_reason, 'ITEM_FAILED_AFTER_OPEN');
      assert.strictEqual(h.orderOf(order.order_id).status, 'deposited');
    }],

    ['取回已售出、訂單在其他書櫃的書：清除預先存書標記，訂單取消後不在原書櫃重建存書登記', async () => {
      const ctx = h.scene();
      const target = h.addCabinet({ name: '公館書櫃' });
      const moved = h.listedBook(ctx, { title: '夜間飛行', status: 'reserved' });
      const other = h.addBook({ sellerId: ctx.seller.user_id, cabinet_id: target.cabinet_id, status: 'reserved' });
      h.addPlaced(moved.book_id, h.doorOf(ctx.cabinet.cabinet_id, 2).slot_id);
      const order = h.addPaidOrder({
        buyerId: ctx.buyer.user_id, sellerId: ctx.seller.user_id, bookId: other.book_id, cabinetId: target.cabinet_id
      });
      prisma.rows('order_items').find((i) => i.book_id === other.book_id).pre_deposited = false;
      prisma.rows('order_items').push({
        item_id: prisma.nextId('order_items'), order_id: order.order_id, book_id: moved.book_id, quantity: 1, unit_price: 100,
        subtotal: 100, pre_deposited: true
      });

      const { created, final } = await h.runSession(ctx, ctx.sellerToken, { context: { type: 'order', id: order.order_id } });
      const unit = created.body.data.items.find((i) => i.kind === 'retrieval');
      assert.strictEqual(unit.note.code, 'MOVE_TO_ORDER_CABINET');
      assert.strictEqual(final.status, 'completed', JSON.stringify(final));
      assert.strictEqual(h.slotItemOf(moved.book_id), null);
      assert.strictEqual(prisma.rows('order_items').find((i) => i.book_id === moved.book_id).pre_deposited, false);

      const cancelled = await h.request('PATCH', `/api/orders/${order.order_id}/cancel`, { token: ctx.buyerToken, body: {} });
      assert.strictEqual(cancelled.status, 200, cancelled.text);
      assert.strictEqual(h.depositOf(moved.book_id), null, '書已在賣家手上，不得在原書櫃重建存書登記');
      const view = await h.request('GET', `/api/books/${moved.book_id}`, { token: ctx.buyerToken });
      assert.strictEqual(view.body.data.in_cabinet, false);
    }],

    ['依訂單存書的書都已在本書櫃但所在櫃門待確認：列為 DOOR_CHECK 並通知管理員，不建立沒有櫃門的作業', async () => {
      const ctx = h.scene();
      const book = h.listedBook(ctx);
      const order = h.orderFor(ctx, book.book_id);
      const door = h.doorOf(ctx.cabinet.cabinet_id, 1);
      h.addPlaced(book.book_id, door.slot_id);
      Object.assign(door, { check_required_at: new Date(), check_reason: 'CANCELLED_AFTER_OPEN' });

      const res = await h.createSession(ctx, ctx.sellerToken);
      assert.strictEqual(res.status, 409, res.text);
      assert.strictEqual(res.body.code, 'CABINET_ITEM_BLOCKED');
      assert.strictEqual(res.body.message, '此項目的櫃門待客服確認，請聯絡客服');
      assert.strictEqual(res.body.items[0].kind, 'order_deposit');
      assert.strictEqual(res.body.items[0].blocked.code, 'DOOR_CHECK');
      assert.strictEqual(h.eventsOf('item_blocked')[0].order_id, order.order_id);
      assert.strictEqual(h.adminNotices(ctx, '書櫃項目無法辦理').length, 1);
      assert.strictEqual(prisma.rows('cabinet_sessions').length, 0);

      Object.assign(door, { check_required_at: null, check_reason: null, fault_code: 'LOCK_NO_RELEASE' });
      const faulty = await h.createSession(ctx, ctx.sellerToken);
      assert.strictEqual(faulty.body.items[0].blocked.code, 'DOOR_FAULT');
    }],

    ['一次勾選超過先行存書額度時回 CABINET_FULL 並維持確認項目；額度在確認期間用完時回 CABINET_ITEMS_CHANGED', async () => {
      const ctx = h.scene();
      const books = [h.listedBook(ctx), h.listedBook(ctx)];
      const keys = books.map((b) => `book:${b.book_id}`);
      const created = await h.createSession(ctx, ctx.sellerToken);
      assert.strictEqual(created.status, 201, created.text);
      assert.ok(created.body.data.items.every((i) => i.kind === 'pre_deposit' && i.blocked === null));
      const no = created.body.data.session_no;

      const tooMany = await h.startSession(ctx.sellerToken, no, keys);
      assert.strictEqual(tooMany.status, 409, tooMany.text);
      assert.strictEqual(tooMany.body.code, 'CABINET_FULL');
      assert.strictEqual(tooMany.body.message, '此書櫃可用的櫃門不足，請減少存書項目或稍後再試');
      assert.strictEqual(tooMany.body.available_doors, 1);
      assert.strictEqual(tooMany.body.required_doors, 2);
      assert.strictEqual(h.sessionOf(no).status, 'selecting');
      assert.ok(h.doorsOf(no).length === 0 && prisma.rows('cabinet_slots').every((s) => s.status === 'empty'));

      prisma.rows('cabinet_manual_reports').push({
        report_id: prisma.nextId('cabinet_manual_reports'), cabinet_id: ctx.cabinet.cabinet_id, user_id: ctx.seller.user_id,
        kind: 'deposit', order_id: null, book_id: h.listedBook(ctx).book_id, target_status: null, reason: 'offline',
        status: 'pending', pending_key: 'deposit:book:x', held_on_sale: false, reviewed_by: null, reviewed_at: null,
        review_note: null, created_at: new Date(), updated_at: new Date()
      });
      const used = await h.startSession(ctx.sellerToken, no, [keys[0]]);
      assert.strictEqual(used.status, 409, used.text);
      assert.strictEqual(used.body.code, 'CABINET_ITEMS_CHANGED');
      assert.strictEqual(used.body.session.items.find((i) => i.key === keys[0]).blocked.code, 'PREDEPOSIT_LIMIT');

      prisma.store.cabinet_manual_reports = [];
      await h.cancelSession(ctx.sellerToken, no);
      const fresh = await h.createSession(ctx, ctx.sellerToken);
      const one = await h.startSession(ctx.sellerToken, fresh.body.data.session_no, [keys[0]]);
      assert.strictEqual(one.status, 200, one.text);
    }],

    ['數字比對只有一次機會：已被認領的比對不再接受，並行送出時只採用一個', async () => {
      const ctx = h.scene();
      const book = h.listedBook(ctx);
      h.orderFor(ctx, book.book_id, { status: 'deposited' });
      h.addPlaced(book.book_id, h.doorOf(ctx.cabinet.cabinet_id, 1).slot_id);
      const created = await h.createSession(ctx, ctx.buyerToken);
      const no = created.body.data.session_no;
      await h.startSession(ctx.buyerToken, no, created.body.data.items.map((i) => i.key));
      const code = h.matchCodeOf(no);
      const wrong = code === 99 ? 98 : code + 1;

      h.sessionOf(no).matched_at = new Date();
      const claimed = await h.selectNumber(ctx, no, code);
      assert.strictEqual(claimed.body.data.results[0].status, 'rejected');
      assert.strictEqual(claimed.body.data.results[0].code, 'STALE');
      assert.strictEqual(h.sessionOf(no).status, 'matching');
      h.sessionOf(no).matched_at = null;

      const responses = await Promise.all([h.selectNumber(ctx, no, wrong), h.selectNumber(ctx, no, code)]);
      const results = responses.map((r) => r.body.data.results[0]);
      assert.strictEqual(results.filter((r) => r.status === 'ok').length, 1, JSON.stringify(results));
      assert.strictEqual(results.filter((r) => r.status === 'rejected' && r.code === 'STALE').length, 1);
      const row = h.sessionOf(no);
      if (results[0].status === 'ok') {
        assert.strictEqual(row.status, 'failed');
        assert.strictEqual(row.result_code, 'MATCH_FAILED');
        assert.strictEqual(row.matched_at, null);
      } else {
        assert.strictEqual(row.status, 'opening');
        assert.ok(row.matched_at instanceof Date);
      }
    }],

    ['不經比對開門只限確定是空的櫃門：待確認或被待確認作業保留的門為 DOOR_NOT_EMPTY', async () => {
      const ctx = h.scene();
      const checked = h.doorOf(ctx.cabinet.cabinet_id, 1);
      Object.assign(checked, { check_required_at: new Date(), check_reason: 'CANCELLED_AFTER_OPEN' });
      const held = h.doorOf(ctx.cabinet.cabinet_id, 2);
      const review = {
        session_id: prisma.nextId('cabinet_sessions'), cabinet_id: ctx.cabinet.cabinet_id, device_id: ctx.device.device_id,
        user_id: ctx.seller.user_id, kind: 'user', status: 'needs_review', version: 3, created_at: new Date()
      };
      prisma.rows('cabinet_sessions').push(review);
      prisma.rows('cabinet_session_doors').push({
        session_id: review.session_id, slot_id: held.slot_id, lock_channel: 2, state: 'open', command_served_at: new Date(),
        opened_at: new Date(), closed_at: null, close_reason: null
      });

      for (const slot of [checked, held]) {
        const res = await adminOpen(ctx, slot, { force: true });
        assert.strictEqual(res.status, 409, res.text);
        assert.strictEqual(res.body.code, 'DOOR_NOT_EMPTY');
        assert.strictEqual(res.body.message, '櫃門內有存放紀錄或待確認，須由現場人員完成數字確認後開啟');
      }
      assert.strictEqual(prisma.rows('cabinet_sessions').filter((s) => s.kind === 'admin').length, 0);
      assert.strictEqual(h.deviceRow(ctx.device.device_id).active_session_id, null);

      const matched = await adminOpen(ctx, checked);
      assert.strictEqual(matched.status, 201, '經現場數字確認時仍可開啟');
    }],

    ['遠端開櫃的櫃門在作業期間為保留；轉為待確認後仍保留，不分配給其他存書', async () => {
      const ctx = h.scene();
      const door = h.doorOf(ctx.cabinet.cabinet_id, 1);
      const res = await adminOpen(ctx, door, { force: true });
      assert.strictEqual(res.status, 201, res.text);
      assert.strictEqual(door.status, 'reserved');
      assert.strictEqual(h.cabinetRow(ctx.cabinet.cabinet_id).available_slots, 3);

      const no = res.body.data.session_no;
      await h.deviceState(ctx.token, ctx.bootId);
      await toReview(no);
      assert.strictEqual(h.sessionOf(no).result_code, 'DEVICE_NO_ACK');
      assert.strictEqual(door.status, 'reserved');

      const book = h.listedBook(ctx);
      const created = await h.createSession(ctx, ctx.sellerToken);
      const started = await h.startSession(ctx.sellerToken, created.body.data.session_no, [`book:${book.book_id}`]);
      assert.strictEqual(started.status, 200, started.text);
      assert.deepStrictEqual(started.body.data.doors.map((d) => d.label), ['A02']);
    }],

    ['管理員不得處理本人發起、或本人為訂單當事人的待確認作業，由其他管理員處理', async () => {
      const ctx = h.scene();
      const sellerAdmin = h.addAdmin();
      const book = h.addBook({ sellerId: sellerAdmin.user_id, cabinet_id: ctx.cabinet.cabinet_id, status: 'reserved' });
      const order = h.addPaidOrder({
        buyerId: ctx.buyer.user_id, sellerId: sellerAdmin.user_id, bookId: book.book_id, cabinetId: ctx.cabinet.cabinet_id,
        status: 'deposited', deposited_at: new Date()
      });
      h.addPlaced(book.book_id, h.doorOf(ctx.cabinet.cabinet_id, 2).slot_id);
      const { no } = await openSession(ctx, ctx.buyerToken);
      await toReview(no);

      const party = await resolve(h.tokenFor(sellerAdmin), no);
      assert.strictEqual(party.status, 403, party.text);
      assert.strictEqual(party.body.code, 'SESSION_SELF_REVIEW');
      assert.strictEqual(party.body.message, '此書櫃作業與您本人相關，須由其他管理員處理');

      ctx.buyer.role = 'admin';
      const initiator = await resolve(h.tokenFor(ctx.buyer), no);
      assert.strictEqual(initiator.body.code, 'SESSION_SELF_REVIEW');
      assert.strictEqual(h.sessionOf(no).status, 'needs_review');
      assert.strictEqual(h.orderOf(order.order_id).picked_up_at, null);

      const staff = await resolve(ctx.adminToken, no);
      assert.strictEqual(staff.status, 200, staff.text);
      assert.ok(h.orderOf(order.order_id).picked_up_at instanceof Date);
    }]
  ]
};
