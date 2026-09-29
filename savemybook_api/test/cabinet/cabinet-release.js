const assert = require('assert');
const h = require('./session-harness');

const { prisma, api } = h;
const orders = () => api('services/orders');

const WEEK = 8 * 24 * 60 * 60 * 1000;

const overdueOrder = (ctx, { channel = 1, status = 'deposited' } = {}) => {
  const book = h.listedBook(ctx);
  const order = h.orderFor(ctx, book.book_id, {
    status, deposited_at: status === 'deposited' ? h.ago(WEEK) : null, created_at: h.ago(WEEK)
  });
  if (status === 'deposited') order.deposited_at = h.ago(WEEK);
  if (channel) h.addPlaced(book.book_id, h.doorOf(ctx.cabinet.cabinet_id, channel).slot_id);
  return { book, order };
};

const addSessionItem = (ctx, order, book, { status = 'selecting', selected = true, openedAt = null, result = 'pending', doorState = null } = {}) => {
  const slot = prisma.rows('cabinet_slot_items').find((r) => r.book_id === book.book_id);
  const session = {
    session_id: prisma.nextId('cabinet_sessions'), cabinet_id: ctx.cabinet.cabinet_id, device_id: ctx.device.device_id,
    user_id: order.buyer_id, kind: 'user', status, version: 1, created_at: new Date(), opened_at: openedAt,
    finished_at: ['completed', 'partial', 'cancelled', 'failed', 'expired'].includes(status) ? new Date() : null
  };
  prisma.rows('cabinet_sessions').push(session);
  prisma.rows('cabinet_session_items').push({
    item_id: prisma.nextId('cabinet_session_items'), session_id: session.session_id, kind: 'pickup', order_id: order.order_id,
    book_id: book.book_id, slot_id: slot?.slot_id ?? null, selected, held_on_sale: false, blocked_code: null, note_code: null, result, error_code: null
  });
  if (doorState && slot) {
    prisma.rows('cabinet_session_doors').push({
      session_id: session.session_id, slot_id: slot.slot_id, lock_channel: 1, state: doorState, command_served_at: new Date(),
      opened_at: doorState === 'failed' ? null : new Date(), closed_at: null, close_reason: null
    });
  }
  return session;
};

const reviewNotices = (ctx) => h.adminNotices(ctx, '逾期訂單待人工處理');

module.exports = {
  name: '書櫃：訂單取消、逾期保留與同門書籍',
  tests: [
    ['訂單取消後同一扇門有多本書：全部暫停販售並通知賣家取回；一扇門一本書時不受影響', async () => {
      const ctx = h.scene();
      const a = h.listedBook(ctx, { title: '甲' });
      const b = h.listedBook(ctx, { title: '乙' });
      const shared = h.orderFor(ctx, [a.book_id, b.book_id], { status: 'deposited' });
      h.addPlaced(a.book_id, h.doorOf(ctx.cabinet.cabinet_id, 1).slot_id);
      h.addPlaced(b.book_id, h.doorOf(ctx.cabinet.cabinet_id, 1).slot_id);
      const single = h.listedBook(ctx, { title: '丙' });
      const alone = h.orderFor(ctx, single.book_id, { status: 'deposited' });
      h.addPlaced(single.book_id, h.doorOf(ctx.cabinet.cabinet_id, 2).slot_id);

      const admin = { userId: ctx.admin.user_id, role: 'admin' };
      await orders().cancel(shared.order_id, admin, '客服取消');
      await orders().cancel(alone.order_id, admin, '客服取消');

      for (const book of [a, b]) {
        const row = h.depositOf(book.book_id);
        assert.ok(row.paused_at, '同門書籍的存書登記已暫停');
        assert.strictEqual(row.auto_paused, true);
        assert.strictEqual(h.bookOf(book.book_id).status, 'removed');
      }
      const notice = h.notificationsOf(ctx.seller.user_id).find((n) => n.title === '請取回書櫃中的書籍');
      assert.strictEqual(notice.content,
        `訂單 ${shared.order_no} 已取消，《甲》、《乙》存放於「北商大書櫃」的同一櫃門，須取回後才能重新存書或販售，請至書櫃以 App 掃描 QR Code 取回。`);
      assert.strictEqual(h.notificationsOf(ctx.seller.user_id).filter((n) => n.title === '請取回書櫃中的書籍').length, 1);

      assert.strictEqual(h.depositOf(single.book_id).paused_at, null);
      assert.strictEqual(h.bookOf(single.book_id).status, 'on_sale');
      const cancelNotice = h.notificationsOf(ctx.seller.user_id).find((n) => n.title === '訂單已取消' && n.content.includes(shared.order_no));
      assert.ok(!cancelNotice.content.includes('將繼續販售'), cancelNotice.content);

      const created = await h.createSession(ctx, ctx.sellerToken, { context: { type: 'book', id: a.book_id } });
      assert.strictEqual(created.status, 201, created.text);
      const selected = created.body.data.items.filter((i) => i.selected).map((i) => i.key).sort();
      assert.deepStrictEqual(selected, [`book:${a.book_id}`, `book:${b.book_id}`].sort());
    }],

    ['作業在確認項目階段時當事人仍可取消訂單；比對後則回 ORDER_IN_CABINET_SESSION', async () => {
      const ctx = h.scene();
      const book = h.listedBook(ctx);
      const order = h.orderFor(ctx, book.book_id);
      const created = await h.createSession(ctx, ctx.sellerToken);
      const no = created.body.data.session_no;
      await h.startSession(ctx.sellerToken, no, [`order:${order.order_id}`]);
      const busy = await h.request('PATCH', `/api/orders/${order.order_id}/cancel`, { token: ctx.buyerToken, body: {} });
      assert.strictEqual(busy.status, 409);
      assert.strictEqual(busy.body.code, 'ORDER_IN_CABINET_SESSION');
      assert.strictEqual(busy.body.message, '此訂單正於書櫃辦理中，請稍後再試');

      await h.cancelSession(ctx.sellerToken, no);
      const ok = await h.request('PATCH', `/api/orders/${order.order_id}/cancel`, { token: ctx.buyerToken, body: {} });
      assert.strictEqual(ok.status, 200, ok.text);
    }],

    ['逾期自動取消：作業進行中（含開門中）略過，下次排程再判斷', async () => {
      const ctx = h.scene();
      const { book, order } = overdueOrder(ctx);
      addSessionItem(ctx, order, book, { status: 'open', openedAt: new Date(), doorState: 'open' });
      const result = await orders().cancelUncollected(new Date());
      assert.strictEqual(result, 0);
      assert.strictEqual(h.orderOf(order.order_id).status, 'deposited');
      assert.strictEqual(reviewNotices(ctx).length, 0);
    }],

    ['逾期自動取消：開門後未完成取書時不取消、不退款，只通知管理員一次', async () => {
      const ctx = h.scene();
      const { book, order } = overdueOrder(ctx);
      addSessionItem(ctx, order, book, { status: 'partial', openedAt: h.ago(60000), result: 'failed', doorState: 'closed' });
      const before = h.balanceOf(ctx.buyer.user_id);
      await orders().cancelUncollected(new Date());
      await orders().cancelUncollected(new Date());
      assert.strictEqual(h.orderOf(order.order_id).status, 'deposited');
      assert.strictEqual(h.balanceOf(ctx.buyer.user_id), before);
      const notices = reviewNotices(ctx);
      assert.strictEqual(notices.length, 1);
      assert.strictEqual(notices[0].content, `訂單 ${order.order_no} 已逾期，但書櫃紀錄顯示開門後未完成取書，系統未自動取消，請確認後處理。`);
      assert.strictEqual(h.eventsOf('overdue_review').length, 1);
    }],

    ['逾期自動取消：曾有無法辦理的紀錄、櫃門故障或待確認、有待確認的手動回報時交由管理員', async () => {
      const ctx = h.scene();
      const blocked = overdueOrder(ctx, { channel: null });
      prisma.rows('cabinet_events').push({
        event_id: prisma.nextId('cabinet_events'), cabinet_id: ctx.cabinet.cabinet_id, device_id: null, session_id: null,
        order_id: blocked.order.order_id, book_id: null, event_key: null, source: 'server', type: 'item_blocked', lock_channel: null,
        actor_id: null, detail: '{"code":"DOOR_UNKNOWN"}', result: null, occurred_at: new Date(), received_at: new Date(), claimed_at: null, processed_at: null
      });
      const faulty = overdueOrder(ctx, { channel: 2 });
      h.doorOf(ctx.cabinet.cabinet_id, 2).fault_code = 'LOCK_NO_RELEASE';
      const reported = overdueOrder(ctx, { channel: 3 });
      prisma.rows('cabinet_manual_reports').push({
        report_id: 1, cabinet_id: ctx.cabinet.cabinet_id, user_id: ctx.buyer.user_id, kind: 'pickup', order_id: reported.order.order_id,
        book_id: null, target_status: 'picked_up', reason: 'offline', status: 'pending', pending_key: `pickup:order:${reported.order.order_id}`,
        reviewed_by: null, reviewed_at: null, review_note: null, created_at: new Date(), updated_at: new Date()
      });
      const plain = overdueOrder(ctx, { channel: 4 });

      await orders().cancelUncollected(new Date());
      for (const { order } of [blocked, faulty, reported]) assert.strictEqual(h.orderOf(order.order_id).status, 'deposited');
      assert.strictEqual(h.orderOf(plain.order.order_id).status, 'cancelled');
      const contents = reviewNotices(ctx).map((n) => n.content);
      assert.ok(contents.some((c) => c.includes(blocked.order.order_no) && c.includes('曾有無法辦理的紀錄')));
      assert.ok(contents.some((c) => c.includes(faulty.order.order_no) && c.includes('櫃門故障或待確認')));
      assert.ok(contents.some((c) => c.includes(reported.order.order_no) && c.includes('有待確認的手動回報')));
    }],

    ['逾期未存書：作業進行中略過；未勾選的取書項目不影響逾期取消', async () => {
      const ctx = h.scene();
      const pending = overdueOrder(ctx, { channel: null, status: 'pending_deposit' });
      const session = addSessionItem(ctx, pending.order, pending.book, { status: 'matching' });
      prisma.rows('cabinet_session_items').find((i) => i.session_id === session.session_id).kind = 'order_deposit';
      await orders().cancelUndeposited(new Date());
      assert.strictEqual(h.orderOf(pending.order.order_id).status, 'pending_deposit');

      const unselected = overdueOrder(ctx, { channel: 2 });
      addSessionItem(ctx, unselected.order, unselected.book, { status: 'partial', selected: false, openedAt: new Date(), doorState: 'closed' });
      await orders().cancelUncollected(new Date());
      assert.strictEqual(h.orderOf(unselected.order.order_id).status, 'cancelled');
    }],

    ['取書作業在開門期間逾期排程到期時不會取消訂單，關門後照常提交取書', async () => {
      const ctx = h.scene();
      const { book, order } = overdueOrder(ctx, { channel: 2 });
      const created = await h.createSession(ctx, ctx.buyerToken);
      const no = created.body.data.session_no;
      await h.startSession(ctx.buyerToken, no, [`order:${order.order_id}`]);
      await h.enterCode(no);
      await h.openDoors(ctx, no);

      await orders().cancelUncollected(new Date());
      assert.strictEqual(h.orderOf(order.order_id).status, 'deposited');
      await h.closeSession(ctx, no, { channels: [2] });
      assert.ok(h.orderOf(order.order_id).picked_up_at);
      assert.strictEqual(h.slotItemOf(book.book_id), null);
    }],

    ['逾期保留的訂單超過一批時，較新的逾期訂單仍會被處理', async () => {
      const ctx = h.scene();
      const held = [];
      for (let i = 0; i < 101; i += 1) {
        const { order } = overdueOrder(ctx, { channel: null });
        prisma.rows('cabinet_events').push({
          event_id: prisma.nextId('cabinet_events'), cabinet_id: ctx.cabinet.cabinet_id, order_id: order.order_id, type: 'item_blocked',
          source: 'server', detail: null, occurred_at: new Date(), received_at: new Date()
        });
        held.push(order);
      }
      const { order: due } = overdueOrder(ctx, { channel: null });

      assert.strictEqual(await orders().cancelUncollected(new Date()), 1);
      assert.strictEqual(h.orderOf(due.order_id).status, 'cancelled');
      assert.ok(held.every((o) => h.orderOf(o.order_id).status === 'deposited'));
      assert.strictEqual(h.eventsOf('overdue_review').length, 101);
    }]
  ]
};
