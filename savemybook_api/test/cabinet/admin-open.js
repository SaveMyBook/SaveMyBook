const assert = require('assert');
const h = require('./session-harness');

const { prisma } = h;

const openDoor = (ctx, channel, body, { verify = true } = {}) => h.request(
  'POST', `/api/admin/cabinets/${ctx.cabinet.cabinet_id}/doors/${h.doorOf(ctx.cabinet.cabinet_id, channel).slot_id}/open`,
  { token: ctx.adminToken, headers: verify ? h.adminVerifyHeaders(ctx.adminToken) : {}, body }
);

const clearDoor = (ctx, channel, body) => h.request(
  'POST', `/api/admin/cabinets/${ctx.cabinet.cabinet_id}/doors/${h.doorOf(ctx.cabinet.cabinet_id, channel).slot_id}/clear`,
  { token: ctx.adminToken, body }
);

const deposit = (ctx, book, channel) => {
  prisma.rows('book_deposits').push({
    book_id: book.book_id, cabinet_id: ctx.cabinet.cabinet_id, deposited_at: new Date(), paused_at: null,
    auto_paused: false, reminded_at: null, escalated_at: null
  });
  h.addPlaced(book.book_id, h.doorOf(ctx.cabinet.cabinet_id, channel).slot_id);
};

module.exports = {
  name: '書櫃後台：遠端開櫃、清空紀錄與作業處理',
  tests: [
    ['遠端開櫃須身分驗證與原因；預設進入數字比對，比對碼只顯示於書櫃螢幕', async () => {
      const ctx = h.scene();
      const noVerify = await openDoor(ctx, 2, { reason: '測試電磁鎖' }, { verify: false });
      assert.strictEqual(noVerify.status, 403);
      assert.strictEqual(noVerify.body.code, 'VERIFICATION_REQUIRED');
      const noReason = await openDoor(ctx, 2, {});
      assert.strictEqual(noReason.status, 400);

      const res = await openDoor(ctx, 2, { reason: '協助賣家取回書籍' });
      assert.strictEqual(res.status, 201, res.text);
      assert.strictEqual(res.body.message, '請輸入書櫃螢幕上顯示的數字');
      assert.deepStrictEqual(Object.keys(res.body.data).sort(), ['remaining_ms', 'session_no', 'status']);
      assert.ok(res.body.data.session_no.startsWith('CS'));
      assert.strictEqual(res.body.data.status, 'matching');
      assert.ok(res.body.data.remaining_ms > 55000);
      const code = h.matchCodeOf(res.body.data.session_no);
      assert.ok(code >= 10 && code <= 99);

      const state = await h.deviceState(ctx.token, ctx.bootId);
      assert.strictEqual(state.body.data.screen, 'match');
      assert.strictEqual(state.body.data.session.code, code);
      assert.strictEqual(state.body.data.session.action, 'admin');

      const row = h.sessionOf(res.body.data.session_no);
      assert.strictEqual(row.kind, 'admin');
      assert.strictEqual(row.admin_reason, '協助賣家取回書籍');
      assert.strictEqual(row.open_ms, 120000);
      assert.strictEqual(h.eventsOf('admin_open').length, 1);
      assert.ok(h.logs().some((l) => l.action === '遠端開啟書櫃櫃門'));

      const detail = await h.request('GET', `/api/admin/cabinet-sessions/${res.body.data.session_no}`, { token: ctx.adminToken });
      assert.strictEqual(detail.status, 200);
      assert.ok(!('match' in detail.body.data));
      assert.strictEqual(detail.body.data.kind, 'admin');
    }],

    ['管理員輸入書櫃螢幕的數字後開門，關門後開過的櫃門設為待確認（ADMIN_OPEN）', async () => {
      const ctx = h.scene();
      const res = await openDoor(ctx, 3, { reason: '檢查櫃門' });
      const no = res.body.data.session_no;
      const matched = await h.enterCode(no);
      assert.strictEqual(matched.status, 200, matched.text);
      assert.strictEqual(matched.body.data.status, 'opening');
      assert.strictEqual(matched.body.data.kind, 'admin');
      const [entered] = h.eventsOf('match_entered');
      assert.strictEqual(entered.source, 'admin');
      assert.strictEqual(entered.actor_id, ctx.admin.user_id);
      const opening = (await h.deviceState(ctx.token, ctx.bootId)).body.data;
      assert.strictEqual(opening.screen, 'admin');
      assert.strictEqual(opening.message.code, 'OPEN_ADMIN');
      assert.strictEqual(opening.commands[0].channel, 3);
      await h.events(ctx, [{ type: 'door_opened', session_id: no, channel: 3, data: { command_id: `${no}:3:1` } }]);
      const open = await h.deviceState(ctx.token, ctx.bootId);
      assert.strictEqual(open.body.data.screen, 'admin');
      assert.strictEqual(open.body.data.session.phase, 'open');
      await h.closeSession(ctx, no, { channels: [3] });

      const row = h.sessionOf(no);
      assert.strictEqual(row.status, 'completed');
      const door = h.doorOf(ctx.cabinet.cabinet_id, 3);
      assert.strictEqual(door.check_reason, 'ADMIN_OPEN');
      assert.strictEqual(door.check_session_id, row.session_id);
      assert.strictEqual(h.deviceRow(ctx.device.device_id).active_session_id, null);
    }],

    ['force 只允許空門：門內有存放紀錄時為 DOOR_NOT_EMPTY；空門直接送出開門指令', async () => {
      const ctx = h.scene();
      const book = h.listedBook(ctx);
      deposit(ctx, book, 1);
      const refused = await openDoor(ctx, 1, { reason: '測試', force: true });
      assert.strictEqual(refused.status, 409);
      assert.strictEqual(refused.body.code, 'DOOR_NOT_EMPTY');

      const forced = await openDoor(ctx, 2, { reason: '測試電磁鎖', force: true });
      assert.strictEqual(forced.status, 201, forced.text);
      assert.strictEqual(forced.body.data.status, 'opening');
      const state = await h.deviceState(ctx.token, ctx.bootId);
      assert.strictEqual(state.body.data.screen, 'admin');
      assert.strictEqual(state.body.data.commands[0].channel, 2);
      assert.strictEqual(h.sessionOf(forced.body.data.session_no).admin_force, true);
    }],

    ['同一位管理員 10 分鐘內 2 次數字確認未完成（逾時或不符）時，暫停發起需比對的遠端開櫃；空門強制開啟與其他管理員不受影響', async () => {
      const ctx = h.scene();
      const timedOut = (await openDoor(ctx, 1, { reason: '檢查櫃門' })).body.data.session_no;
      h.expireSession(timedOut);
      await h.sessionsService.sweep(new Date());
      assert.strictEqual(h.sessionOf(timedOut).result_code, 'MATCH_TIMEOUT');

      const guessed = (await openDoor(ctx, 1, { reason: '檢查櫃門' })).body.data.session_no;
      const wrong = await h.enterCode(guessed, h.wrongCodeOf(guessed));
      assert.strictEqual(wrong.body.data.result.code, 'MATCH_FAILED');

      const blocked = await openDoor(ctx, 1, { reason: '檢查櫃門' });
      assert.strictEqual(blocked.status, 429, blocked.text);
      assert.strictEqual(blocked.body.code, 'CABINET_COOLDOWN');
      assert.strictEqual(blocked.body.message, '數字確認多次未完成，請於 10 分鐘後再試');
      assert.ok(blocked.body.retry_after_s > 590 && blocked.body.retry_after_s <= 600, String(blocked.body.retry_after_s));
      assert.strictEqual(prisma.rows('cabinet_sessions').length, 2);

      const forced = await openDoor(ctx, 2, { reason: '測試電磁鎖', force: true });
      assert.strictEqual(forced.status, 201, forced.text);
      const discarded = await h.request('POST', `/api/admin/cabinet-sessions/${forced.body.data.session_no}/resolve`, {
        token: ctx.adminToken, body: { action: 'discard', note: '測試結束' }
      });
      assert.strictEqual(discarded.body.data.result.code, 'ADMIN_CANCELLED');
      const still = await openDoor(ctx, 1, { reason: '檢查櫃門' });
      assert.strictEqual(still.status, 429, '穿插其他結果的作業不會重新累計');

      const other = h.addAdmin();
      const byOther = await h.request('POST', `/api/admin/cabinets/${ctx.cabinet.cabinet_id}/doors/${h.doorOf(ctx.cabinet.cabinet_id, 1).slot_id}/open`, {
        token: h.tokenFor(other), headers: h.adminVerifyHeaders(h.tokenFor(other)), body: { reason: '檢查櫃門' }
      });
      assert.strictEqual(byOther.status, 201, byOther.text);
      await h.request('POST', `/api/admin/cabinet-sessions/${byOther.body.data.session_no}/resolve`, {
        token: ctx.adminToken, body: { action: 'discard', note: '測試結束' }
      });

      h.sessionOf(timedOut).finished_at = h.ago(10 * 60000 + 1000);
      const again = await openDoor(ctx, 1, { reason: '檢查櫃門' });
      assert.strictEqual(again.status, 201, again.text);
      assert.strictEqual(again.body.data.status, 'matching');
    }],

    ['遠端開櫃每位管理員 10 分鐘最多 10 次請求', async () => {
      const ctx = h.scene();
      for (let i = 0; i < 10; i++) assert.strictEqual((await openDoor(ctx, 1, {})).status, 400);
      const limited = await openDoor(ctx, 1, { reason: '檢查櫃門' });
      assert.strictEqual(limited.status, 429);
      assert.strictEqual(limited.body.code, 'RATE_LIMITED');
      assert.strictEqual(prisma.rows('cabinet_sessions').length, 0);
    }],

    ['書櫃使用中、裝置離線、未配對與櫃門不存在時拒絕', async () => {
      const ctx = h.scene();
      const first = await openDoor(ctx, 1, { reason: '測試' });
      assert.strictEqual(first.status, 201);
      const busy = await openDoor(ctx, 2, { reason: '測試' });
      assert.strictEqual(busy.status, 409);
      assert.strictEqual(busy.body.code, 'CABINET_BUSY');
      assert.strictEqual(prisma.rows('cabinet_sessions').length, 1);

      const other = h.scene();
      h.deviceRow(other.device.device_id).last_seen_at = h.ago(60000);
      const offline = await openDoor(other, 1, { reason: '測試' });
      assert.strictEqual(offline.body.code, 'DEVICE_OFFLINE');

      const bare = h.addCabinet({ name: '未配對書櫃' });
      const unpaired = await h.request('POST', `/api/admin/cabinets/${bare.cabinet_id}/doors/1/open`, {
        token: ctx.adminToken, headers: h.adminVerifyHeaders(ctx.adminToken), body: { reason: '測試' }
      });
      assert.strictEqual(unpaired.body.code, 'DEVICE_NOT_PAIRED');

      const missing = await h.request('POST', `/api/admin/cabinets/${ctx.cabinet.cabinet_id}/doors/99999/open`, {
        token: ctx.adminToken, headers: h.adminVerifyHeaders(ctx.adminToken), body: { reason: '測試' }
      });
      assert.strictEqual(missing.status, 404);
      assert.strictEqual(missing.body.code, 'DOOR_NOT_FOUND');
    }],

    ['管理員作業逾時未回報開門：待確認，處理結束後已送出指令的櫃門設為待確認', async () => {
      const ctx = h.scene();
      const res = await openDoor(ctx, 1, { reason: '測試' });
      const no = res.body.data.session_no;
      await h.enterCode(no);
      await h.deviceState(ctx.token, ctx.bootId);
      h.expireSession(no);
      await h.sessionsService.sweep(new Date());
      assert.strictEqual(h.sessionOf(no).status, 'needs_review');
      const resolved = await h.request('POST', `/api/admin/cabinet-sessions/${no}/resolve`, {
        token: ctx.adminToken, body: { action: 'discard', note: '櫃門未開啟' }
      });
      assert.strictEqual(resolved.status, 200, resolved.text);
      assert.strictEqual(resolved.body.data.status, 'cancelled');
      assert.strictEqual(h.doorOf(ctx.cabinet.cabinet_id, 1).check_reason, 'ADMIN_OPEN');
    }],

    ['進行中的作業可由管理員強制結束（ADMIN_CANCELLED）；開門中的作業不可處理', async () => {
      const ctx = h.scene();
      const book = h.listedBook(ctx);
      const order = h.orderFor(ctx, book.book_id);
      const created = await h.createSession(ctx, ctx.sellerToken);
      const no = created.body.data.session_no;
      await h.startSession(ctx.sellerToken, no, [`order:${order.order_id}`]);
      await h.enterCode(no);
      await h.deviceState(ctx.token, ctx.bootId);
      const resolved = await h.request('POST', `/api/admin/cabinet-sessions/${no}/resolve`, {
        token: ctx.adminToken, body: { action: 'discard', note: '使用者離開' }
      });
      assert.strictEqual(resolved.status, 200, resolved.text);
      assert.strictEqual(resolved.body.data.result.code, 'ADMIN_CANCELLED');
      assert.strictEqual(h.doorOf(ctx.cabinet.cabinet_id, 1).check_reason, 'DOOR_UNCONFIRMED');
      assert.strictEqual(h.deviceRow(ctx.device.device_id).active_session_id, null);
      const notice = h.notificationsOf(ctx.seller.user_id).find((n) => n.title === '書櫃作業已由客服結束');
      assert.ok(notice && notice.content.includes(no), '強制結束時通知作業發起人');

      const second = await h.createSession(ctx, ctx.sellerToken);
      const two = second.body.data.session_no;
      prisma.rows('cabinet_slots').forEach((s) => { s.check_required_at = null; });
      await h.doors.recountAvailable(null, ctx.cabinet.cabinet_id);
      await h.startSession(ctx.sellerToken, two, [`order:${order.order_id}`]);
      await h.enterCode(two);
      await h.openDoors(ctx, two);
      const refused = await h.request('POST', `/api/admin/cabinet-sessions/${two}/resolve`, {
        token: ctx.adminToken, body: { action: 'discard', note: '測試' }
      });
      assert.strictEqual(refused.status, 409);
      assert.strictEqual(refused.body.code, 'SESSION_NOT_REVIEWABLE');
    }],

    ['清空存放紀錄（書籍已取出）：刪除存書登記、改為下架並通知賣家；門內有進行中訂單時為 DOOR_HAS_ORDER', async () => {
      const ctx = h.scene();
      const book = h.listedBook(ctx, { title: '小王子' });
      deposit(ctx, book, 1);
      h.doorOf(ctx.cabinet.cabinet_id, 1).check_required_at = new Date();
      h.doorOf(ctx.cabinet.cabinet_id, 1).check_reason = 'CANCELLED_AFTER_OPEN';

      const missingReason = await clearDoor(ctx, 1, { mode: 'removed' });
      assert.strictEqual(missingReason.status, 400);
      const res = await clearDoor(ctx, 1, { mode: 'removed', reason: '人員已取出' });
      assert.strictEqual(res.status, 200, res.text);
      assert.strictEqual(res.body.data.items.length, 0);
      assert.strictEqual(res.body.data.check, null);
      assert.strictEqual(h.depositOf(book.book_id), null);
      assert.strictEqual(h.slotItemOf(book.book_id), null);
      assert.strictEqual(h.bookOf(book.book_id).status, 'removed');
      assert.ok(h.notificationsOf(ctx.seller.user_id).some((n) => n.title === '書櫃中的書籍已由客服取出' && n.content.includes('小王子')));
      assert.strictEqual(JSON.parse(h.eventsOf('door_cleared')[0].detail).mode, 'removed');
      assert.ok(h.logs().some((l) => l.action === '清空書櫃櫃門存放紀錄'));

      const sold = h.listedBook(ctx);
      h.orderFor(ctx, sold.book_id, { status: 'deposited' });
      h.addPlaced(sold.book_id, h.doorOf(ctx.cabinet.cabinet_id, 2).slot_id);
      const blocked = await clearDoor(ctx, 2, { mode: 'removed', reason: '測試' });
      assert.strictEqual(blocked.status, 409);
      assert.strictEqual(blocked.body.code, 'DOOR_HAS_ORDER');
    }],

    ['清空存放紀錄（僅更正紀錄）：只刪除櫃內紀錄，不變更訂單或存書', async () => {
      const ctx = h.scene();
      const book = h.listedBook(ctx);
      const order = h.orderFor(ctx, book.book_id, { status: 'deposited' });
      h.addPlaced(book.book_id, h.doorOf(ctx.cabinet.cabinet_id, 2).slot_id);
      const res = await clearDoor(ctx, 2, { mode: 'correct', reason: '書不在門內' });
      assert.strictEqual(res.status, 200, res.text);
      assert.strictEqual(h.slotItemOf(book.book_id), null);
      assert.strictEqual(h.orderOf(order.order_id).status, 'deposited');
      assert.strictEqual(h.bookOf(book.book_id).status, 'reserved');
      assert.strictEqual(h.doorOf(ctx.cabinet.cabinet_id, 2).status, 'empty');
    }],

    ['後台訂單詳情與存書列表附櫃門；管理員把未取書的訂單改為完成時，櫃門設為待確認；訂單詳情不含取件碼', async () => {
      const ctx = h.scene();
      const book = h.listedBook(ctx);
      const order = h.orderFor(ctx, book.book_id, { status: 'deposited' });
      h.addPlaced(book.book_id, h.doorOf(ctx.cabinet.cabinet_id, 3).slot_id);
      const stored = h.listedBook(ctx);
      deposit(ctx, stored, 2);

      const detail = await h.request('GET', `/api/admin/orders/${order.order_id}`, { token: ctx.adminToken });
      assert.strictEqual(detail.status, 200, detail.text);
      assert.deepStrictEqual(detail.body.data.doors, ['A03']);

      const list = await h.request('GET', `/api/admin/cabinets/deposits?cabinet_id=${ctx.cabinet.cabinet_id}`, { token: ctx.adminToken });
      assert.deepStrictEqual(list.body.data[0].door, { slot_id: h.doorOf(ctx.cabinet.cabinet_id, 2).slot_id, label: 'A02' });

      const own = await h.request('GET', `/api/orders/${order.order_id}`, { token: ctx.buyerToken });
      assert.ok(!('pickup_code' in own.body.data));
      assert.deepStrictEqual(own.body.data.doors, ['A03']);
      assert.strictEqual(own.body.data.manual_report, null);

      const changed = await h.request('PATCH', `/api/admin/orders/${order.order_id}`, { token: ctx.adminToken, body: { status: 'completed' } });
      assert.strictEqual(changed.status, 200, changed.text);
      assert.strictEqual(h.doorOf(ctx.cabinet.cabinet_id, 3).check_reason, 'ADMIN_COMPLETED');
      assert.ok(h.slotItemOf(book.book_id), '櫃內紀錄保留，由管理員確認後處理');
    }],

    ['作業列表與詳情：待確認篩選、項目、櫃門時間軸；不提供比對碼', async () => {
      const ctx = h.scene();
      const book = h.listedBook(ctx, { title: '作業系統' });
      const order = h.orderFor(ctx, book.book_id);
      const created = await h.createSession(ctx, ctx.sellerToken);
      const no = created.body.data.session_no;
      await h.startSession(ctx.sellerToken, no, [`order:${order.order_id}`]);

      const detail = await h.request('GET', `/api/admin/cabinet-sessions/${no}`, { token: ctx.adminToken });
      assert.strictEqual(detail.status, 200, detail.text);
      assert.strictEqual(detail.body.data.status, 'matching');
      assert.ok(!('match' in detail.body.data));
      assert.strictEqual(detail.body.data.items[0].seller_nickname, '賣家');
      assert.strictEqual(detail.body.data.items[0].buyer_nickname, '買家');
      assert.strictEqual(detail.body.data.user.nickname, '賣家');

      await h.enterCode(no);
      await h.openDoors(ctx, no);
      await h.events(ctx, [{ type: 'session_closed', session_id: no, data: { outcome: 'interrupted', reason: 'reboot' } }]);

      const review = await h.request('GET', `/api/admin/cabinets/${ctx.cabinet.cabinet_id}/sessions?status=review`, { token: ctx.adminToken });
      assert.strictEqual(review.status, 200);
      assert.strictEqual(review.body.pagination.total, 1);
      const row = review.body.data[0];
      assert.strictEqual(row.session_no, no);
      assert.strictEqual(row.result_code, 'DEVICE_INTERRUPTED');
      assert.deepStrictEqual(row.item_kinds, ['order_deposit']);
      assert.deepStrictEqual(row.doors, ['A01']);
      assert.strictEqual(row.user.user_no, h.publicId.encode('user', ctx.seller.user_id));

      const full = await h.request('GET', `/api/admin/cabinet-sessions/${no}`, { token: ctx.adminToken });
      const timeline = full.body.data.doors_timeline[0];
      assert.strictEqual(timeline.label, 'A01');
      assert.ok(timeline.command_served_at && timeline.opened_at);
      assert.ok(full.body.data.events.some((e) => e.type === 'door_opened'));
      assert.ok(!JSON.stringify(full.body.data).includes('"user_id"'));

      const stranger = h.addUser();
      const denied = await h.request('GET', `/api/admin/cabinet-sessions/${no}`, { token: h.tokenFor(stranger) });
      assert.strictEqual(denied.status, 403);
    }]
  ]
};
