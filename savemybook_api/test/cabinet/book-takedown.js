const assert = require('assert');
const h = require('./session-harness');

const { api } = h;
const orders = () => api('services/orders');

const HOLD_TITLE = '下架書籍訂單待人工處理';

const depositedOrder = (ctx, channel) => {
  const book = h.listedBook(ctx, { title: '小王子' });
  const order = h.orderFor(ctx, book.book_id, { status: 'deposited' });
  h.addPlaced(book.book_id, h.doorOf(ctx.cabinet.cabinet_id, channel).slot_id);
  return { book, order };
};

const delist = (ctx, book) => h.request('PATCH', `/api/admin/books/${book.book_id}`, {
  token: ctx.adminToken, body: { status: 'removed', reason: '內容不實' }
});

const startPickup = async (ctx, order) => {
  const created = await h.createSession(ctx, ctx.buyerToken);
  assert.strictEqual(created.status, 201, created.text);
  const no = created.body.data.session_no;
  const started = await h.startSession(ctx.buyerToken, no, [`order:${order.order_id}`]);
  assert.strictEqual(started.status, 200, started.text);
  return no;
};

module.exports = {
  name: '書櫃：書籍下架時的訂單取消保護',
  tests: [
    ['買家取書開門中下架：不取消也不退款，關門後照常完成取書；訂單完成時書轉為已完成並維持不公開', async () => {
      const ctx = h.scene();
      const { book, order } = depositedOrder(ctx, 2);
      const balance = h.balanceOf(ctx.buyer.user_id);
      const no = await startPickup(ctx, order);
      await h.enterCode(no);
      await h.openDoors(ctx, no);

      const res = await delist(ctx, book);
      assert.strictEqual(res.status, 200, res.text);
      assert.strictEqual(h.orderOf(order.order_id).status, 'deposited');
      assert.strictEqual(h.balanceOf(ctx.buyer.user_id), balance);
      assert.strictEqual(h.bookOf(book.book_id).status, 'removed');
      assert.strictEqual(h.adminNotices(ctx, HOLD_TITLE).length, 0);

      await h.closeSession(ctx, no, { channels: [2] });
      assert.ok(h.orderOf(order.order_id).picked_up_at);
      await orders().runAutomation();
      assert.strictEqual(h.orderOf(order.order_id).status, 'deposited');
      assert.strictEqual(h.balanceOf(ctx.buyer.user_id), balance);
      assert.strictEqual(h.bookOf(book.book_id).status, 'removed');

      h.orderOf(order.order_id).picked_up_at = new Date(Date.now() - 25 * 60 * 60 * 1000);
      await orders().runAutomation();
      assert.strictEqual(h.orderOf(order.order_id).status, 'completed');
      assert.deepStrictEqual([h.bookOf(book.book_id).status, h.bookOf(book.book_id).is_approved], ['sold', false]);
    }],

    ['作業進行中下架而作業未開門即取消：由排程取消訂單並退款，書恢復存書登記待賣家取回', async () => {
      const ctx = h.scene();
      const { book, order } = depositedOrder(ctx, 1);
      const balance = h.balanceOf(ctx.buyer.user_id);
      const no = await startPickup(ctx, order);

      await delist(ctx, book);
      assert.strictEqual(h.orderOf(order.order_id).status, 'deposited');
      await h.cancelSession(ctx.buyerToken, no);

      assert.strictEqual((await orders().runAutomation()).delisted, 1);
      assert.strictEqual(h.orderOf(order.order_id).status, 'cancelled');
      assert.strictEqual(h.balanceOf(ctx.buyer.user_id), balance + 100);
      assert.strictEqual(h.bookOf(book.book_id).status, 'removed');
      assert.ok(h.depositOf(book.book_id));
      assert.strictEqual(h.depositOf(book.book_id).auto_paused, false);
    }],

    ['書櫃紀錄待確認時交由管理員：只通知一次，排除後由排程取消', async () => {
      const ctx = h.scene();
      const { book, order } = depositedOrder(ctx, 3);
      h.doorOf(ctx.cabinet.cabinet_id, 3).fault_code = 'LOCK_NO_RELEASE';

      await delist(ctx, book);
      await orders().runAutomation();
      assert.strictEqual(h.orderOf(order.order_id).status, 'deposited');
      const notices = h.adminNotices(ctx, HOLD_TITLE);
      assert.strictEqual(notices.length, 1);
      assert.strictEqual(notices[0].content,
        `訂單 ${order.order_no} 的書籍已經審核下架，但書櫃紀錄顯示櫃門故障或待確認，系統未自動取消，請確認後處理。`);
      assert.strictEqual(h.eventsOf('delist_review').length, 1);
      assert.strictEqual(h.eventsOf('overdue_review').length, 0);

      h.doorOf(ctx.cabinet.cabinet_id, 3).fault_code = null;
      assert.strictEqual((await orders().runAutomation()).delisted, 1);
      assert.strictEqual(h.orderOf(order.order_id).status, 'cancelled');
    }]
  ]
};
