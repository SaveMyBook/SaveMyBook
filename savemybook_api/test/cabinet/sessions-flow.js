const assert = require('assert');
const h = require('./session-harness');

const { prisma, api } = h;
const orders = () => api('services/orders');

const doorLabels = (session) => session.doors.map((d) => d.label);

module.exports = {
  name: '書櫃作業：比對、開門與提交',
  tests: [
    ['開始後進入數字比對：書櫃畫面顯示兩位數比對碼，App 與作業內容都不含比對碼', async () => {
      const ctx = h.scene();
      const book = h.listedBook(ctx);
      const order = h.orderFor(ctx, book.book_id, { status: 'deposited' });
      h.addPlaced(book.book_id, h.doorOf(ctx.cabinet.cabinet_id, 2).slot_id);

      const created = await h.createSession(ctx, ctx.buyerToken);
      assert.strictEqual(created.status, 201, created.text);
      const session = created.body.data;
      assert.strictEqual(session.status, 'selecting');
      assert.strictEqual(session.items[0].key, `order:${order.order_id}`);
      assert.deepStrictEqual(session.items[0].books.map((b) => b.door), ['A02']);
      assert.ok(!('match' in session));
      assert.strictEqual(session.notice, null);

      const started = await h.startSession(ctx.buyerToken, session.session_no, [`order:${order.order_id}`]);
      assert.strictEqual(started.status, 200, started.text);
      const code = h.matchCodeOf(session.session_no);
      assert.ok(code >= 10 && code <= 99);
      assert.ok(!('match' in started.body.data));
      assert.ok(!JSON.stringify(started.body.data).includes(`:${code},`));
      assert.strictEqual(started.body.data.status, 'matching');
      assert.deepStrictEqual(doorLabels(started.body.data), ['A02']);
      assert.strictEqual(started.body.data.open_ms, 30000);

      const state = await h.deviceState(ctx.token, ctx.bootId);
      const view = state.body.data;
      assert.strictEqual(view.screen, 'match');
      assert.strictEqual(view.qr, null);
      assert.deepStrictEqual(view.message, { code: 'MATCH_PROMPT', params: {} });
      assert.strictEqual(view.session.code, code);
      assert.ok(!('choices' in view.session));
      assert.strictEqual(view.session.action, 'pickup');
    }],

    ['輸入錯誤數字：回 200，作業為 failed／MATCH_FAILED 並釋放書櫃；事件不記錄輸入值', async () => {
      const ctx = h.scene();
      const book = h.listedBook(ctx);
      h.orderFor(ctx, book.book_id, { status: 'deposited' });
      h.addPlaced(book.book_id, h.doorOf(ctx.cabinet.cabinet_id, 1).slot_id);
      const created = await h.createSession(ctx, ctx.buyerToken);
      const no = created.body.data.session_no;
      await h.startSession(ctx.buyerToken, no, created.body.data.items.map((i) => i.key));
      const code = h.matchCodeOf(no);
      const wrong = h.wrongCodeOf(no);

      const res = await h.enterCode(no, wrong);
      assert.strictEqual(res.status, 200, res.text);
      assert.strictEqual(res.body.data.status, 'failed');
      assert.deepStrictEqual(res.body.data.result, { outcome: 'failed', code: 'MATCH_FAILED', message: '數字不符，本次作業已取消' });
      const state = await h.deviceState(ctx.token, ctx.bootId);
      assert.strictEqual(state.body.data.screen, 'result');
      assert.strictEqual(state.body.data.message.code, 'RESULT_MATCH_FAILED');
      const [entered] = h.eventsOf('match_entered');
      assert.strictEqual(entered.source, 'user');
      assert.deepStrictEqual(JSON.parse(entered.detail), { matched: false });
      const digits = new RegExp(`"?(${code}|${wrong})"?[,}]`);
      assert.ok(prisma.rows('cabinet_events').every((e) => !digits.test(e.detail ?? '')), '事件不記錄比對碼或輸入值');
      const row = h.sessionOf(no);
      assert.strictEqual(row.status, 'failed');
      assert.strictEqual(row.result_code, 'MATCH_FAILED');
      assert.strictEqual(h.deviceRow(ctx.device.device_id).active_session_id, null);
      assert.strictEqual(h.orderOf(prisma.rows('orders')[0].order_id).picked_up_at, null);
    }],

    ['輸入正確數字後產生開鎖指令並記錄送出時間；第一扇門開啟即進入倒數，opened_at 為該門的時間', async () => {
      const ctx = h.scene();
      const book = h.listedBook(ctx);
      h.orderFor(ctx, book.book_id, { status: 'deposited' });
      h.addPlaced(book.book_id, h.doorOf(ctx.cabinet.cabinet_id, 3).slot_id);
      const created = await h.createSession(ctx, ctx.buyerToken);
      const no = created.body.data.session_no;
      await h.startSession(ctx.buyerToken, no, created.body.data.items.map((i) => i.key));

      const matched = await h.enterCode(no);
      assert.strictEqual(matched.status, 200, matched.text);
      assert.strictEqual(matched.body.data.status, 'opening');
      assert.deepStrictEqual(JSON.parse(h.eventsOf('match_entered')[0].detail), { matched: true });
      const state = (await h.deviceState(ctx.token, ctx.bootId)).body.data;
      assert.strictEqual(state.screen, 'opening');
      assert.strictEqual(state.commands.length, 1);
      assert.strictEqual(state.commands[0].channel, 3);
      assert.strictEqual(state.commands[0].id, `${no}:3:1`);
      assert.strictEqual(state.commands[0].release_ms, 800);
      assert.ok(state.commands[0].expires_in_ms > 0 && state.commands[0].expires_in_ms <= 8000);
      assert.ok(h.doorsOf(no)[0].command_served_at instanceof Date);
      assert.strictEqual(h.sessionOf(no).status, 'opening');

      const opened = await h.events(ctx, [{ type: 'door_opened', session_id: no, channel: 3, age_ms: 1500, data: { command_id: `${no}:3:1` } }]);
      assert.strictEqual(opened.body.data.results[0].status, 'ok');
      const row = h.sessionOf(no);
      assert.strictEqual(row.status, 'open');
      const door = h.doorsOf(no)[0];
      assert.strictEqual(door.state, 'open');
      assert.strictEqual(row.opened_at.getTime(), door.opened_at.getTime());
      assert.ok(Date.now() - row.opened_at.getTime() >= 1400);
      assert.strictEqual(opened.body.data.state.screen, 'open');
      assert.strictEqual(opened.body.data.state.message.code, 'OPEN_PICKUP');
      assert.strictEqual(opened.body.data.state.message.params.doors, 'A03');
      const app = await h.getSession(ctx.buyerToken, no);
      assert.strictEqual(app.body.data.status, 'open');
      assert.ok(app.body.data.remaining_ms <= 30000 - 1400);
    }],

    ['關門後提交取書：記錄取書時間、通知賣家、刪除櫃內紀錄並釋放櫃門', async () => {
      const ctx = h.scene();
      const book = h.listedBook(ctx, { title: '資料庫系統概論' });
      const order = h.orderFor(ctx, book.book_id, { status: 'deposited' });
      const slot = h.doorOf(ctx.cabinet.cabinet_id, 2);
      h.addPlaced(book.book_id, slot.slot_id);

      const { final, no } = await h.runSession(ctx, ctx.buyerToken);
      assert.strictEqual(final.status, 'completed');
      assert.strictEqual(final.result.code, 'COMPLETED');
      assert.strictEqual(final.items[0].result, 'done');
      assert.ok(h.orderOf(order.order_id).picked_up_at instanceof Date);
      assert.strictEqual(h.orderOf(order.order_id).status, 'deposited');
      assert.ok(h.notificationsOf(ctx.seller.user_id).some((n) => n.title === '買家已取書'));
      assert.strictEqual(h.slotItemOf(book.book_id), null);
      assert.strictEqual(h.doorOf(ctx.cabinet.cabinet_id, 2).status, 'empty');
      assert.strictEqual(h.cabinetRow(ctx.cabinet.cabinet_id).available_slots, 4);
      assert.strictEqual(h.deviceRow(ctx.device.device_id).active_session_id, null);
      assert.strictEqual(h.doorsOf(no)[0].state, 'closed');
      assert.strictEqual(h.doorsOf(no)[0].close_reason, 'user_done');
      assert.strictEqual(h.sessionOf(no).close_reason, 'user_done');
      assert.strictEqual(h.eventsOf('session_finished').length, 1);
    }],

    ['依訂單存書：4 本書分到兩扇門，關門後改為已存書並通知買家，slot_id 為主要櫃門', async () => {
      const ctx = h.scene();
      const books = [1, 2, 3, 4].map((i) => h.listedBook(ctx, { title: `書籍${i}` }));
      const order = h.orderFor(ctx, books.map((b) => b.book_id));

      const created = await h.createSession(ctx, ctx.sellerToken);
      assert.strictEqual(created.status, 201, created.text);
      assert.strictEqual(created.body.data.items[0].kind, 'order_deposit');
      assert.ok(created.body.data.items[0].books.every((b) => b.door === null));
      const no = created.body.data.session_no;
      const started = await h.startSession(ctx.sellerToken, no, [`order:${order.order_id}`]);
      assert.strictEqual(started.status, 200, started.text);
      assert.deepStrictEqual(doorLabels(started.body.data), ['A01', 'A02']);
      assert.strictEqual(started.body.data.open_ms, 45000);
      assert.deepStrictEqual(started.body.data.items[0].books.map((b) => b.door), ['A01', 'A01', 'A02', 'A02']);
      assert.strictEqual(h.doorOf(ctx.cabinet.cabinet_id, 1).status, 'reserved');

      await h.enterCode(no);
      const { commands } = await h.openDoors(ctx, no);
      assert.deepStrictEqual(commands.map((c) => c.channel), [1, 2]);
      await h.closeSession(ctx, no, { channels: [1, 2] });

      const final = (await h.getSession(ctx.sellerToken, no)).body.data;
      assert.strictEqual(final.status, 'completed');
      const current = h.orderOf(order.order_id);
      assert.strictEqual(current.status, 'deposited');
      assert.strictEqual(current.slot_id, h.doorOf(ctx.cabinet.cabinet_id, 1).slot_id);
      assert.ok(h.notificationsOf(ctx.buyer.user_id).some((n) => n.title === '書籍已存入書櫃'
        && n.content.includes('請於營業時間內至書櫃以 App 掃描 QR Code 取書')));
      assert.deepStrictEqual(books.map((b) => h.slotItemOf(b.book_id).slot_id), [
        h.doorOf(ctx.cabinet.cabinet_id, 1).slot_id, h.doorOf(ctx.cabinet.cabinet_id, 1).slot_id,
        h.doorOf(ctx.cabinet.cabinet_id, 2).slot_id, h.doorOf(ctx.cabinet.cabinet_id, 2).slot_id
      ]);
      assert.strictEqual(h.doorOf(ctx.cabinet.cabinet_id, 1).status, 'occupied');
      assert.strictEqual(h.cabinetRow(ctx.cabinet.cabinet_id).available_slots, 2);
    }],

    ['依訂單存書：書已先存在此書櫃時補進原櫃門，不另開新門', async () => {
      const ctx = h.scene();
      const first = h.listedBook(ctx, { title: '先存的書' });
      const second = h.listedBook(ctx, { title: '後存的書' });
      h.addPlaced(first.book_id, h.doorOf(ctx.cabinet.cabinet_id, 3).slot_id);
      const order = h.orderFor(ctx, [first.book_id, second.book_id]);

      const { final } = await h.runSession(ctx, ctx.sellerToken, { keys: [`order:${order.order_id}`] });
      assert.strictEqual(final.status, 'completed', JSON.stringify(final));
      assert.deepStrictEqual(doorLabels(final), ['A03']);
      assert.strictEqual(h.slotItemOf(second.book_id).slot_id, h.doorOf(ctx.cabinet.cabinet_id, 3).slot_id);
      assert.strictEqual(h.orderOf(order.order_id).status, 'deposited');
    }],

    ['先行存書：關門後建立存書登記與櫃內紀錄', async () => {
      const ctx = h.scene();
      const book = h.listedBook(ctx);
      const { created, final } = await h.runSession(ctx, ctx.sellerToken, { context: { type: 'book', id: book.book_id } });
      const item = created.body.data.items.find((i) => i.key === `book:${book.book_id}`);
      assert.strictEqual(item.kind, 'pre_deposit');
      assert.strictEqual(item.selected, true);
      assert.strictEqual(final.status, 'completed');
      assert.deepStrictEqual(final.items[0].books.map((b) => b.door), ['A01']);
      assert.strictEqual(h.depositOf(book.book_id).cabinet_id, ctx.cabinet.cabinet_id);
      assert.ok(h.slotItemOf(book.book_id));
      assert.strictEqual(h.bookOf(book.book_id).status, 'on_sale');
    }],

    ['取回暫停販售的書：刪除存書登記與櫃內紀錄，書籍恢復上架', async () => {
      const ctx = h.scene();
      const book = h.listedBook(ctx, { status: 'removed' });
      prisma.rows('book_deposits').push({
        book_id: book.book_id, cabinet_id: ctx.cabinet.cabinet_id, deposited_at: h.ago(8 * 86400000), paused_at: h.ago(86400000),
        auto_paused: true, reminded_at: null, escalated_at: null
      });
      h.addPlaced(book.book_id, h.doorOf(ctx.cabinet.cabinet_id, 4).slot_id);

      const { created, final } = await h.runSession(ctx, ctx.sellerToken, { keys: [`book:${book.book_id}`] });
      const unit = created.body.data.items.find((i) => i.kind === 'retrieval');
      assert.strictEqual(unit.paused, true);
      assert.strictEqual(unit.selected, false);
      assert.deepStrictEqual(unit.doors, ['A04']);
      assert.strictEqual(final.status, 'completed');
      assert.strictEqual(h.depositOf(book.book_id), null);
      assert.strictEqual(h.slotItemOf(book.book_id), null);
      assert.strictEqual(h.bookOf(book.book_id).status, 'on_sale');
    }],

    ['取回開始後書改為下架，此時結帳失敗；作業取消後恢復上架', async () => {
      const ctx = h.scene();
      const book = h.listedBook(ctx);
      prisma.rows('book_deposits').push({
        book_id: book.book_id, cabinet_id: ctx.cabinet.cabinet_id, deposited_at: new Date(), paused_at: null,
        auto_paused: false, reminded_at: null, escalated_at: null
      });
      h.addPlaced(book.book_id, h.doorOf(ctx.cabinet.cabinet_id, 1).slot_id);
      const created = await h.createSession(ctx, ctx.sellerToken, { context: { type: 'book', id: book.book_id } });
      const no = created.body.data.session_no;
      const started = await h.startSession(ctx.sellerToken, no, [`book:${book.book_id}`]);
      assert.strictEqual(started.status, 200, started.text);
      assert.strictEqual(h.bookOf(book.book_id).status, 'removed');
      assert.strictEqual(h.itemsOf(no)[0].held_on_sale, true);

      const buy = await h.request('POST', '/api/orders/buy-now', {
        token: ctx.buyerToken, body: { book_id: book.book_id }, headers: h.verifyHeaders(ctx.buyerToken, 'payment')
      });
      assert.notStrictEqual(buy.status, 201);

      const cancelled = await h.cancelSession(ctx.sellerToken, no);
      assert.strictEqual(cancelled.body.data.status, 'cancelled');
      assert.strictEqual(cancelled.body.data.result.code, 'CANCELLED_BY_USER');
      assert.strictEqual(h.bookOf(book.book_id).status, 'on_sale');
      assert.strictEqual(h.itemsOf(no)[0].held_on_sale, false);
      assert.ok(h.depositOf(book.book_id));
    }],

    ['取回上架中的書並完成後仍維持上架', async () => {
      const ctx = h.scene();
      const book = h.listedBook(ctx);
      prisma.rows('book_deposits').push({
        book_id: book.book_id, cabinet_id: ctx.cabinet.cabinet_id, deposited_at: new Date(), paused_at: null,
        auto_paused: false, reminded_at: null, escalated_at: null
      });
      h.addPlaced(book.book_id, h.doorOf(ctx.cabinet.cabinet_id, 1).slot_id);
      const { final } = await h.runSession(ctx, ctx.sellerToken, { context: { type: 'book', id: book.book_id }, keys: [`book:${book.book_id}`] });
      assert.strictEqual(final.status, 'completed');
      assert.strictEqual(h.bookOf(book.book_id).status, 'on_sale');
      assert.strictEqual(h.depositOf(book.book_id), null);
    }],

    ['開門後取消不變更狀態（CANCELLED_AFTER_OPEN）；存書櫃門開啟後取消時通知管理員並設為待確認', async () => {
      const ctx = h.scene();
      const book = h.listedBook(ctx);
      const order = h.orderFor(ctx, book.book_id);
      const { final, no } = await h.runSession(ctx, ctx.sellerToken, { keys: [`order:${order.order_id}`], outcome: 'cancelled' });
      assert.strictEqual(final.status, 'cancelled');
      assert.deepStrictEqual(final.result, { outcome: 'cancelled', code: 'CANCELLED_AFTER_OPEN', message: '本次作業已取消，狀態未變更' });
      assert.strictEqual(h.sessionOf(no).close_reason, 'user_cancel');
      assert.strictEqual(final.items[0].result, 'skipped');
      assert.strictEqual(h.orderOf(order.order_id).status, 'pending_deposit');
      assert.strictEqual(h.slotItemOf(book.book_id), null);
      const door = h.doorOf(ctx.cabinet.cabinet_id, 1);
      assert.ok(door.check_required_at instanceof Date);
      assert.strictEqual(door.check_reason, 'CANCELLED_AFTER_OPEN');
      assert.strictEqual(door.check_session_id, h.sessionOf(no).session_id);
      assert.strictEqual(door.status, 'empty');
      assert.strictEqual(h.cabinetRow(ctx.cabinet.cabinet_id).available_slots, 3);
      const notice = h.adminNotices(ctx, '書櫃作業開門後取消')[0];
      assert.ok(notice.content.includes(no) && notice.content.includes('A01'));
    }],

    ['重送 session_closed 不會重複提交', async () => {
      const ctx = h.scene();
      const book = h.listedBook(ctx);
      const order = h.orderFor(ctx, book.book_id);
      const created = await h.createSession(ctx, ctx.sellerToken);
      const no = created.body.data.session_no;
      await h.startSession(ctx.sellerToken, no, [`order:${order.order_id}`]);
      await h.enterCode(no);
      await h.openDoors(ctx, no);
      const event = { id: `${ctx.bootId}-900001`, type: 'session_closed', session_id: no, age_ms: 0, data: { outcome: 'completed', reason: 'user_done' } };
      const first = await h.request('POST', '/api/device/v1/events', { headers: h.deviceHeaders(ctx.token, ctx.bootId), body: { events: [event] } });
      assert.strictEqual(first.body.data.results[0].status, 'ok');
      const again = await h.request('POST', '/api/device/v1/events', { headers: h.deviceHeaders(ctx.token, ctx.bootId), body: { events: [event] } });
      assert.strictEqual(again.body.data.results[0].status, 'duplicate');
      const other = await h.events(ctx, [{ type: 'session_closed', session_id: no, data: { outcome: 'completed', reason: 'timeout' } }]);
      assert.strictEqual(other.body.data.results[0].status, 'ok');
      assert.strictEqual(h.notificationsOf(ctx.buyer.user_id).filter((n) => n.title === '書籍已存入書櫃').length, 1);
      assert.strictEqual(h.eventsOf('session_finished').length, 1);
    }],

    ['存書期間訂單被取消：項目為 ITEM_CHANGED，但櫃內紀錄保留為待取回', async () => {
      const ctx = h.scene();
      const book = h.listedBook(ctx);
      const order = h.orderFor(ctx, book.book_id);
      const created = await h.createSession(ctx, ctx.sellerToken);
      const no = created.body.data.session_no;
      await h.startSession(ctx.sellerToken, no, [`order:${order.order_id}`]);
      await h.enterCode(no);
      await h.openDoors(ctx, no);

      const party = await h.request('PATCH', `/api/orders/${order.order_id}/cancel`, { token: ctx.buyerToken, body: {} });
      assert.strictEqual(party.status, 409);
      assert.strictEqual(party.body.code, 'ORDER_IN_CABINET_SESSION');
      await orders().cancel(order.order_id, { userId: ctx.admin.user_id, role: 'admin' }, '測試');

      await h.closeSession(ctx, no, { channels: [1] });
      const final = (await h.getSession(ctx.sellerToken, no)).body.data;
      assert.strictEqual(final.status, 'partial');
      assert.strictEqual(final.result.code, 'ITEMS_FAILED');
      assert.strictEqual(final.items[0].error.code, 'ITEM_CHANGED');
      assert.ok(h.slotItemOf(book.book_id));
      assert.strictEqual(h.doorOf(ctx.cabinet.cabinet_id, 1).status, 'occupied');
      assert.ok(h.adminNotices(ctx, '書櫃作業部分未完成')[0].content.includes('A01'));
      assert.ok(h.notificationsOf(ctx.seller.user_id).some((n) => n.title === '書櫃作業未全部完成'));

      const retrieval = await h.createSession(ctx, ctx.sellerToken);
      assert.strictEqual(retrieval.status, 201, retrieval.text);
      assert.strictEqual(retrieval.body.data.items[0].kind, 'retrieval');
    }],

    ['門內已有其他保管單位的書：仍記錄實體位置，項目為 DOOR_CONFLICT 並設為待確認', async () => {
      const ctx = h.scene({ doorCount: 2 });
      const book = h.listedBook(ctx);
      const order = h.orderFor(ctx, book.book_id);
      const created = await h.createSession(ctx, ctx.sellerToken);
      const no = created.body.data.session_no;
      await h.startSession(ctx.sellerToken, no, [`order:${order.order_id}`]);
      const slot = h.doorOf(ctx.cabinet.cabinet_id, 1);
      const stranger = h.addUser();
      const other = h.addBook({ sellerId: stranger.user_id, cabinet_id: ctx.cabinet.cabinet_id });
      prisma.rows('cabinet_slot_items').push({
        book_id: other.book_id, slot_id: slot.slot_id, cabinet_id: ctx.cabinet.cabinet_id, session_id: null, placed_by: 'admin', placed_at: new Date()
      });
      await h.enterCode(no);
      await h.openDoors(ctx, no);
      await h.closeSession(ctx, no, { channels: [1] });

      const final = (await h.getSession(ctx.sellerToken, no)).body.data;
      assert.strictEqual(final.items[0].error.code, 'DOOR_CONFLICT');
      assert.strictEqual(h.slotItemOf(book.book_id).slot_id, slot.slot_id);
      assert.strictEqual(h.doorOf(ctx.cabinet.cabinet_id, 1).check_reason, 'DOOR_CONFLICT');
      assert.strictEqual(h.orderOf(order.order_id).status, 'pending_deposit');
    }],

    ['各階段逾時：確認項目與數字比對逾時為 expired', async () => {
      const ctx = h.scene();
      const book = h.listedBook(ctx);
      h.orderFor(ctx, book.book_id, { status: 'deposited' });
      h.addPlaced(book.book_id, h.doorOf(ctx.cabinet.cabinet_id, 1).slot_id);

      const first = await h.createSession(ctx, ctx.buyerToken);
      h.expireSession(first.body.data.session_no);
      const expired = await h.getSession(ctx.buyerToken, first.body.data.session_no);
      assert.strictEqual(expired.body.data.status, 'expired');
      assert.strictEqual(expired.body.data.result.code, 'SELECT_TIMEOUT');
      assert.strictEqual(h.deviceRow(ctx.device.device_id).active_session_id, null);

      const second = await h.createSession(ctx, ctx.buyerToken);
      const no = second.body.data.session_no;
      await h.startSession(ctx.buyerToken, no, second.body.data.items.map((i) => i.key));
      h.expireSession(no);
      await h.sessionsService.sweep(new Date());
      assert.strictEqual(h.sessionOf(no).status, 'expired');
      assert.strictEqual(h.sessionOf(no).result_code, 'MATCH_TIMEOUT');
      const late = await h.enterCode(no);
      assert.strictEqual(late.status, 409, late.text);
      assert.strictEqual(late.body.code, 'CABINET_SESSION_STATE');
      assert.strictEqual(late.body.session.result.code, 'MATCH_TIMEOUT');
    }],

    ['開門中逾時：指令未送出為 DEVICE_NO_RESPONSE；已送出為 DEVICE_NO_ACK，保留櫃門並通知', async () => {
      const ctx = h.scene();
      const book = h.listedBook(ctx);
      const order = h.orderFor(ctx, book.book_id);

      const first = await h.createSession(ctx, ctx.sellerToken);
      const one = first.body.data.session_no;
      await h.startSession(ctx.sellerToken, one, [`order:${order.order_id}`]);
      await h.enterCode(one);
      assert.strictEqual(h.sessionOf(one).status, 'opening');
      h.expireSession(one);
      await h.sessionsService.sweep(new Date());
      assert.strictEqual(h.sessionOf(one).status, 'failed');
      assert.strictEqual(h.sessionOf(one).result_code, 'DEVICE_NO_RESPONSE');
      assert.strictEqual(h.doorOf(ctx.cabinet.cabinet_id, 1).status, 'empty');

      const second = await h.createSession(ctx, ctx.sellerToken);
      const two = second.body.data.session_no;
      await h.startSession(ctx.sellerToken, two, [`order:${order.order_id}`]);
      await h.enterCode(two);
      await h.deviceState(ctx.token, ctx.bootId);
      assert.ok(h.doorsOf(two)[0].command_served_at);
      h.expireSession(two);
      const state = await h.deviceState(ctx.token, ctx.bootId);
      assert.strictEqual(state.body.data.screen, 'result');
      assert.strictEqual(state.body.data.message.code, 'RESULT_REVIEW');
      const row = h.sessionOf(two);
      assert.strictEqual(row.status, 'needs_review');
      assert.strictEqual(row.result_code, 'DEVICE_NO_ACK');
      assert.strictEqual(h.deviceRow(ctx.device.device_id).active_session_id, null);
      const slot = h.doorOf(ctx.cabinet.cabinet_id, h.doorsOf(two)[0].lock_channel);
      assert.strictEqual(slot.status, 'reserved');
      assert.ok(h.adminNotices(ctx, '書櫃作業待確認')[0].content.includes('已送出開門指令'));
      assert.ok(h.notificationsOf(ctx.seller.user_id).some((n) => n.title === '書櫃作業待確認'));
    }],

    ['開門後逾時為 DEVICE_LOST；之後遲到的關門回報仍會提交並通知發起人', async () => {
      const ctx = h.scene();
      const book = h.listedBook(ctx);
      const order = h.orderFor(ctx, book.book_id);
      const created = await h.createSession(ctx, ctx.sellerToken);
      const no = created.body.data.session_no;
      await h.startSession(ctx.sellerToken, no, [`order:${order.order_id}`]);
      await h.enterCode(no);
      await h.openDoors(ctx, no);
      h.expireSession(no);
      await h.sessionsService.sweep(new Date());
      assert.strictEqual(h.sessionOf(no).status, 'needs_review');
      assert.strictEqual(h.sessionOf(no).result_code, 'DEVICE_LOST');
      assert.ok(h.adminNotices(ctx, '書櫃作業待確認')[0].content.includes('未收到關門回報'));

      await h.closeSession(ctx, no, { reason: 'timeout', channels: [1] });
      const final = (await h.getSession(ctx.sellerToken, no)).body.data;
      assert.strictEqual(final.status, 'completed');
      assert.strictEqual(h.orderOf(order.order_id).status, 'deposited');
      assert.ok(h.notificationsOf(ctx.seller.user_id).some((n) => n.title === '書櫃作業已確認' && n.content.includes('已完成')));
      assert.strictEqual(h.doorOf(ctx.cabinet.cabinet_id, 1).status, 'occupied');
    }],

    ['DEVICE_NO_ACK 之後遲到的開門與關門回報仍會提交', async () => {
      const ctx = h.scene();
      const book = h.listedBook(ctx);
      const order = h.orderFor(ctx, book.book_id);
      const created = await h.createSession(ctx, ctx.sellerToken);
      const no = created.body.data.session_no;
      await h.startSession(ctx.sellerToken, no, [`order:${order.order_id}`]);
      await h.enterCode(no);
      await h.deviceState(ctx.token, ctx.bootId);
      h.expireSession(no);
      await h.sessionsService.sweep(new Date());
      assert.strictEqual(h.sessionOf(no).status, 'needs_review');

      const opened = await h.events(ctx, [{ type: 'door_opened', session_id: no, channel: 1, data: { command_id: `${no}:1:1` } }]);
      assert.strictEqual(opened.body.data.results[0].status, 'ok');
      assert.strictEqual(h.sessionOf(no).status, 'needs_review');
      assert.ok(h.sessionOf(no).opened_at);
      await h.closeSession(ctx, no, { channels: [1] });
      assert.strictEqual(h.sessionOf(no).status, 'completed');
      assert.strictEqual(h.orderOf(order.order_id).status, 'deposited');
    }],

    ['已結束的作業收到開門回報：不恢復作業，只設為待確認並通知管理員', async () => {
      const ctx = h.scene();
      const book = h.listedBook(ctx);
      const order = h.orderFor(ctx, book.book_id);
      const created = await h.createSession(ctx, ctx.sellerToken);
      const no = created.body.data.session_no;
      await h.startSession(ctx.sellerToken, no, [`order:${order.order_id}`]);
      await h.enterCode(no);
      h.expireSession(no);
      await h.sessionsService.sweep(new Date());
      assert.strictEqual(h.sessionOf(no).status, 'failed');

      const late = await h.events(ctx, [{ type: 'door_opened', session_id: no, channel: 1, data: { command_id: `${no}:1:1` } }]);
      assert.strictEqual(late.body.data.results[0].status, 'ok');
      assert.strictEqual(h.sessionOf(no).status, 'failed');
      assert.strictEqual(h.doorOf(ctx.cabinet.cabinet_id, 1).check_reason, 'LATE_OPEN');
      assert.ok(h.adminNotices(ctx, '書櫃櫃門異常開啟')[0].content.includes(no));
      assert.strictEqual(h.eventsOf('late_door_opened').length, 1);
    }],

    ['書櫃重新開機回報 interrupted：作業為 needs_review／DEVICE_INTERRUPTED', async () => {
      const ctx = h.scene();
      const book = h.listedBook(ctx);
      const order = h.orderFor(ctx, book.book_id);
      const created = await h.createSession(ctx, ctx.sellerToken);
      const no = created.body.data.session_no;
      await h.startSession(ctx.sellerToken, no, [`order:${order.order_id}`]);
      await h.enterCode(no);
      await h.openDoors(ctx, no);
      const res = await h.events(ctx, [{ type: 'session_closed', session_id: no, data: { outcome: 'interrupted', reason: 'reboot' } }]);
      assert.strictEqual(res.body.data.results[0].status, 'ok');
      assert.strictEqual(h.sessionOf(no).status, 'needs_review');
      assert.strictEqual(h.sessionOf(no).result_code, 'DEVICE_INTERRUPTED');
      assert.strictEqual(h.sessionOf(no).closed_at, null);
      assert.strictEqual(h.deviceRow(ctx.device.device_id).active_session_id, null);
    }],

    ['管理員處理待確認作業：commit 提交；discard 不變更狀態並把開過的存書櫃門設為待確認', async () => {
      const ctx = h.scene();
      const [a, b] = [h.listedBook(ctx), h.listedBook(ctx)];
      const first = h.orderFor(ctx, a.book_id);
      const second = h.orderFor(ctx, b.book_id);
      const verify = h.adminVerifyHeaders(ctx.adminToken);

      const toReview = async (orderId) => {
        const created = await h.createSession(ctx, ctx.sellerToken);
        const no = created.body.data.session_no;
        await h.startSession(ctx.sellerToken, no, [`order:${orderId}`]);
        await h.enterCode(no);
        await h.openDoors(ctx, no);
        await h.events(ctx, [{ type: 'session_closed', session_id: no, data: { outcome: 'interrupted', reason: 'reboot' } }]);
        return no;
      };

      const one = await toReview(first.order_id);
      const committed = await h.request('POST', `/api/admin/cabinet-sessions/${one}/resolve`, {
        token: ctx.adminToken, headers: verify, body: { action: 'commit', note: '現場確認已放入' }
      });
      assert.strictEqual(committed.status, 200, committed.text);
      assert.strictEqual(committed.body.data.status, 'completed');
      assert.strictEqual(committed.body.data.result.code, 'ADMIN_RESOLVED_COMMIT');
      assert.strictEqual(committed.body.data.review.note, '現場確認已放入');
      assert.strictEqual(h.orderOf(first.order_id).status, 'deposited');
      assert.strictEqual(h.eventsOf('review_resolved').length, 1);

      const two = await toReview(second.order_id);
      const discarded = await h.request('POST', `/api/admin/cabinet-sessions/${two}/resolve`, {
        token: ctx.adminToken, body: { action: 'discard', note: '書籍未放入' }
      });
      assert.strictEqual(discarded.status, 200, discarded.text);
      assert.strictEqual(discarded.body.data.result.code, 'ADMIN_RESOLVED_DISCARD');
      assert.strictEqual(h.orderOf(second.order_id).status, 'pending_deposit');
      const slot = h.doorOf(ctx.cabinet.cabinet_id, h.doorsOf(two)[0].lock_channel);
      assert.strictEqual(slot.check_reason, 'DISCARDED_AFTER_OPEN');
      assert.ok(h.notificationsOf(ctx.seller.user_id).some((n) => n.content.includes('確認未完成，狀態未變更')));

      const again = await h.request('POST', `/api/admin/cabinet-sessions/${two}/resolve`, {
        token: ctx.adminToken, body: { action: 'commit', note: '重複處理' }
      });
      assert.strictEqual(again.status, 409);
      assert.strictEqual(again.body.code, 'SESSION_NOT_REVIEWABLE');
    }],

    ['提交途中拋錯：重送 session_closed 完成收尾，且沒有重複提交、書櫃已釋放', async () => {
      const ctx = h.scene();
      const book = h.listedBook(ctx);
      const order = h.orderFor(ctx, book.book_id);
      const created = await h.createSession(ctx, ctx.sellerToken);
      const no = created.body.data.session_no;
      await h.startSession(ctx.sellerToken, no, [`order:${order.order_id}`]);
      await h.enterCode(no);
      await h.openDoors(ctx, no);

      h.failNext('services/orders#markDepositedInTx');
      const event = { id: `${ctx.bootId}-900100`, type: 'session_closed', session_id: no, age_ms: 0, data: { outcome: 'completed', reason: 'user_done' } };
      const failed = await h.request('POST', '/api/device/v1/events', { headers: h.deviceHeaders(ctx.token, ctx.bootId), body: { events: [event] } });
      assert.strictEqual(failed.status, 500);
      const row = h.sessionOf(no);
      assert.strictEqual(row.status, 'open');
      assert.ok(row.closed_at);
      assert.strictEqual(h.itemsOf(no)[0].result, 'pending');
      assert.ok(h.slotItemOf(book.book_id));
      assert.strictEqual(h.orderOf(order.order_id).status, 'pending_deposit');

      const retried = await h.request('POST', '/api/device/v1/events', { headers: h.deviceHeaders(ctx.token, ctx.bootId), body: { events: [event] } });
      assert.strictEqual(retried.body.data.results[0].status, 'ok', retried.text);
      assert.strictEqual(h.sessionOf(no).status, 'completed');
      assert.strictEqual(h.orderOf(order.order_id).status, 'deposited');
      assert.strictEqual(h.notificationsOf(ctx.buyer.user_id).filter((n) => n.title === '書籍已存入書櫃').length, 1);
      assert.strictEqual(h.deviceRow(ctx.device.device_id).active_session_id, null);
    }],

    ['提交途中拋錯：超過 60 秒由排程續做完成', async () => {
      const ctx = h.scene();
      const book = h.listedBook(ctx);
      prisma.rows('book_deposits').push({
        book_id: book.book_id, cabinet_id: ctx.cabinet.cabinet_id, deposited_at: new Date(), paused_at: null,
        auto_paused: false, reminded_at: null, escalated_at: null
      });
      h.addPlaced(book.book_id, h.doorOf(ctx.cabinet.cabinet_id, 2).slot_id);
      const created = await h.createSession(ctx, ctx.sellerToken);
      const no = created.body.data.session_no;
      await h.startSession(ctx.sellerToken, no, [`book:${book.book_id}`]);
      await h.enterCode(no);
      await h.openDoors(ctx, no);

      h.failNext('services/cabinet-commit#commitUnit');
      const failed = await h.closeSession(ctx, no, { channels: [2] });
      assert.strictEqual(failed.status, 500);
      assert.strictEqual(h.sessionOf(no).status, 'open');
      assert.ok(h.depositOf(book.book_id));

      await h.sessionsService.sweep(new Date());
      assert.strictEqual(h.sessionOf(no).status, 'open');
      h.sessionOf(no).closed_at = h.ago(61000);
      await h.sessionsService.sweep(new Date());
      assert.strictEqual(h.sessionOf(no).status, 'completed');
      assert.strictEqual(h.depositOf(book.book_id), null);
      assert.strictEqual(h.slotItemOf(book.book_id), null);
      assert.strictEqual(h.bookOf(book.book_id).status, 'on_sale');
      assert.strictEqual(h.deviceRow(ctx.device.device_id).active_session_id, null);
    }],

    ['櫃門回報故障且全部未開啟時，作業立即結束為 DEVICE_NO_RESPONSE', async () => {
      const ctx = h.scene();
      const book = h.listedBook(ctx);
      const order = h.orderFor(ctx, book.book_id);
      const created = await h.createSession(ctx, ctx.sellerToken);
      const no = created.body.data.session_no;
      await h.startSession(ctx.sellerToken, no, [`order:${order.order_id}`]);
      await h.enterCode(no);
      const res = await h.events(ctx, [{ type: 'fault', session_id: no, channel: 1, data: { code: 'LOCK_NO_RELEASE' } }]);
      assert.strictEqual(res.body.data.results[0].status, 'ok');
      assert.strictEqual(h.sessionOf(no).status, 'failed');
      assert.strictEqual(h.sessionOf(no).result_code, 'DEVICE_NO_RESPONSE');
      assert.strictEqual(h.doorOf(ctx.cabinet.cabinet_id, 1).fault_code, 'LOCK_NO_RELEASE');
      assert.strictEqual(res.body.data.state.message.code, 'RESULT_DEVICE_ERROR');
    }],

    ['書櫃不再接受 match_selected 與 session_cancel：回 EVENT_INVALID，作業維持比對中', async () => {
      const ctx = h.scene();
      const book = h.listedBook(ctx);
      const order = h.orderFor(ctx, book.book_id);
      const created = await h.createSession(ctx, ctx.sellerToken);
      const no = created.body.data.session_no;
      await h.startSession(ctx.sellerToken, no, [`order:${order.order_id}`]);
      const res = await h.events(ctx, [
        { type: 'match_selected', session_id: no, data: { value: h.matchCodeOf(no) } },
        { type: 'session_cancel', session_id: no }
      ]);
      assert.deepStrictEqual(res.body.data.results.map((r) => [r.status, r.code]), [['rejected', 'EVENT_INVALID'], ['rejected', 'EVENT_INVALID']]);
      assert.strictEqual(h.sessionOf(no).status, 'matching');
      assert.strictEqual(h.sessionOf(no).matched_at, null);
      assert.strictEqual(h.eventsOf('match_selected').length, 0);
    }],

    ['開始前項目已變更：回 CABINET_ITEMS_CHANGED 並附最新作業，作業維持確認項目；重複開始回 CABINET_SESSION_STATE', async () => {
      const ctx = h.scene();
      const [a, b] = [h.listedBook(ctx), h.listedBook(ctx)];
      const first = h.orderFor(ctx, a.book_id, { status: 'deposited' });
      const second = h.orderFor(ctx, b.book_id, { status: 'deposited' });
      h.addPlaced(a.book_id, h.doorOf(ctx.cabinet.cabinet_id, 1).slot_id);
      h.addPlaced(b.book_id, h.doorOf(ctx.cabinet.cabinet_id, 2).slot_id);
      const created = await h.createSession(ctx, ctx.buyerToken);
      const no = created.body.data.session_no;
      const deadline = h.sessionOf(no).phase_deadline.getTime();
      h.orderOf(first.order_id).picked_up_at = new Date();

      const res = await h.startSession(ctx.buyerToken, no, [`order:${first.order_id}`, `order:${second.order_id}`]);
      assert.strictEqual(res.status, 409);
      assert.strictEqual(res.body.code, 'CABINET_ITEMS_CHANGED');
      assert.strictEqual(res.body.message, '部分項目狀態已變更，請重新確認');
      assert.strictEqual(res.body.session.status, 'selecting');
      assert.deepStrictEqual(res.body.session.items.map((i) => i.key), [`order:${second.order_id}`]);
      assert.strictEqual(res.body.session.items[0].selected, true);
      assert.strictEqual(h.sessionOf(no).phase_deadline.getTime(), deadline);

      const bad = await h.startSession(ctx.buyerToken, no, ['order:999999']);
      assert.strictEqual(bad.status, 400);
      const empty = await h.startSession(ctx.buyerToken, no, []);
      assert.strictEqual(empty.body.code, 'CABINET_NO_SELECTION');

      const ok = await h.startSession(ctx.buyerToken, no, [`order:${second.order_id}`]);
      assert.strictEqual(ok.status, 200, ok.text);
      const twice = await h.startSession(ctx.buyerToken, no, [`order:${second.order_id}`]);
      assert.strictEqual(twice.status, 409);
      assert.strictEqual(twice.body.code, 'CABINET_SESSION_STATE');
      assert.strictEqual(twice.body.message, '目前無法執行此操作');

      const stranger = h.addUser();
      const hidden = await h.getSession(h.tokenFor(stranger), no);
      assert.strictEqual(hidden.status, 404);
      assert.strictEqual(hidden.body.code, 'CABINET_SESSION_NOT_FOUND');
      const admin = await h.getSession(ctx.adminToken, no);
      assert.strictEqual(admin.status, 404);
    }],

    ['開始時櫃門不足：回 CABINET_FULL 並通知管理員，作業維持確認項目、櫃門未被占用', async () => {
      const ctx = h.scene({ doorCount: 2 });
      const stranger = h.addUser();
      const other = h.addBook({ sellerId: stranger.user_id, cabinet_id: ctx.cabinet.cabinet_id });
      h.addPlaced(other.book_id, h.doorOf(ctx.cabinet.cabinet_id, 1).slot_id);
      const [a, b] = [h.listedBook(ctx), h.listedBook(ctx)];
      const first = h.orderFor(ctx, a.book_id);
      const second = h.orderFor(ctx, b.book_id);
      const created = await h.createSession(ctx, ctx.sellerToken);
      assert.ok(created.body.data.items.every((i) => i.blocked === null));
      const no = created.body.data.session_no;
      const res = await h.startSession(ctx.sellerToken, no, [`order:${first.order_id}`, `order:${second.order_id}`]);
      assert.strictEqual(res.status, 409, res.text);
      assert.strictEqual(res.body.code, 'CABINET_FULL');
      assert.strictEqual(res.body.available_doors, 1);
      assert.strictEqual(res.body.required_doors, 2);
      assert.strictEqual(h.sessionOf(no).status, 'selecting');
      assert.strictEqual(h.doorOf(ctx.cabinet.cabinet_id, 2).status, 'empty');
      assert.strictEqual(h.doorsOf(no).length, 0);
      assert.strictEqual(h.eventsOf('item_blocked').length, 2);
      assert.ok(h.adminNotices(ctx, '書櫃項目無法辦理')[0].content.includes('可用櫃門不足'));

      const ok = await h.startSession(ctx.sellerToken, no, [`order:${first.order_id}`]);
      assert.strictEqual(ok.status, 200, ok.text);
    }],

    ['客服確認完成（DEVICE_NO_ACK）：已送出指令而未回報的櫃門視為已開啟並提交', async () => {
      const ctx = h.scene();
      const book = h.listedBook(ctx);
      const order = h.orderFor(ctx, book.book_id);
      const created = await h.createSession(ctx, ctx.sellerToken);
      const no = created.body.data.session_no;
      await h.startSession(ctx.sellerToken, no, [`order:${order.order_id}`]);
      await h.enterCode(no);
      await h.deviceState(ctx.token, ctx.bootId);
      h.expireSession(no);
      await h.sessionsService.sweep(new Date());
      assert.strictEqual(h.sessionOf(no).result_code, 'DEVICE_NO_ACK');
      const res = await h.request('POST', `/api/admin/cabinet-sessions/${no}/resolve`, {
        token: ctx.adminToken, body: { action: 'commit', note: '現場確認書籍已放入' }
      });
      assert.strictEqual(res.status, 200, res.text);
      assert.strictEqual(res.body.data.status, 'completed');
      assert.strictEqual(h.orderOf(order.order_id).status, 'deposited');
      assert.ok(h.slotItemOf(book.book_id));
      assert.strictEqual(h.doorOf(ctx.cabinet.cabinet_id, 1).check_required_at, null);
    }],

    ['App 取消：櫃門開啟後回 CABINET_SESSION_STATE', async () => {
      const ctx = h.scene();
      const book = h.listedBook(ctx);
      const order = h.orderFor(ctx, book.book_id);
      const created = await h.createSession(ctx, ctx.sellerToken);
      const no = created.body.data.session_no;
      await h.startSession(ctx.sellerToken, no, [`order:${order.order_id}`]);
      await h.enterCode(no);
      await h.openDoors(ctx, no);
      const res = await h.cancelSession(ctx.sellerToken, no);
      assert.strictEqual(res.status, 409);
      assert.strictEqual(res.body.code, 'CABINET_SESSION_STATE');
      assert.strictEqual(res.body.message, '櫃門已開啟，無法執行此操作');
      assert.strictEqual(res.body.session.status, 'open');
    }]
  ]
};
