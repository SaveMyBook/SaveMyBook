const assert = require('assert');
const { io: connect } = require('socket.io-client');
const server = require('../lib/server');
const h = require('./session-harness');

const { api } = h;

const pickupScene = () => {
  const ctx = h.scene();
  const book = h.listedBook(ctx);
  const order = h.orderFor(ctx, book.book_id, { status: 'deposited' });
  h.addPlaced(book.book_id, h.doorOf(ctx.cabinet.cabinet_id, 1).slot_id);
  return { ...ctx, book, order };
};

const cabinetEvents = (calls) => calls.filter((c) => c.event === 'cabinet:session');

let handle = null;

module.exports = {
  name: '書櫃作業：即時推播與發起人通知',
  tests: [
    ['每次狀態變更都推播給發起人，version 遞增', async () => {
      const ctx = pickupScene();
      const calls = h.captureEmits();
      const { no } = await h.runSession(ctx, ctx.buyerToken);
      const pushes = cabinetEvents(calls);
      assert.ok(pushes.every((c) => c.userId === ctx.buyer.user_id));
      assert.ok(pushes.every((c) => c.payload.session.session_no === no));
      const versions = pushes.map((c) => c.payload.session.version);
      assert.deepStrictEqual(versions, [...versions].sort((a, b) => a - b));
      assert.strictEqual(new Set(versions).size, versions.length, `version 應嚴格遞增：${versions.join(',')}`);
      const statuses = [...new Set(pushes.map((c) => c.payload.session.status))];
      assert.deepStrictEqual(statuses, ['selecting', 'matching', 'opening', 'open', 'completed']);
      assert.strictEqual(pushes.at(-1).payload.session.version, h.sessionOf(no).version);
    }],

    ['取消與逾時也會推播；遠端開櫃作業推播給該管理員', async () => {
      const ctx = pickupScene();
      const calls = h.captureEmits();
      const created = await h.createSession(ctx, ctx.buyerToken);
      await h.cancelSession(ctx.buyerToken, created.body.data.session_no);
      const last = cabinetEvents(calls).at(-1).payload.session;
      assert.strictEqual(last.status, 'cancelled');
      assert.strictEqual(last.result.code, 'CANCELLED_BY_USER');

      const again = await h.createSession(ctx, ctx.buyerToken);
      h.expireSession(again.body.data.session_no);
      await h.sessionsService.sweep(new Date());
      assert.strictEqual(cabinetEvents(calls).at(-1).payload.session.result.code, 'SELECT_TIMEOUT');

      await h.sessionsService.adminOpen(ctx.cabinet.cabinet_id, h.doorOf(ctx.cabinet.cabinet_id, 2).slot_id,
        { reason: '測試', force: false }, { adminId: ctx.admin.user_id, req: null });
      const adminPush = cabinetEvents(calls).at(-1);
      assert.strictEqual(adminPush.userId, ctx.admin.user_id);
      assert.strictEqual(adminPush.payload.session.status, 'matching');
      assert.ok(adminPush.payload.session.match.code >= 10);
    }],

    ['部分完成時通知發起人；待確認時通知發起人，確認後再通知一次', async () => {
      const ctx = h.scene();
      const [a, b] = [h.listedBook(ctx), h.listedBook(ctx)];
      const first = h.orderFor(ctx, a.book_id);
      const second = h.orderFor(ctx, b.book_id);
      const created = await h.createSession(ctx, ctx.sellerToken);
      const no = created.body.data.session_no;
      await h.startSession(ctx.sellerToken, no, [`order:${first.order_id}`, `order:${second.order_id}`]);
      await h.selectNumber(ctx, no);
      await h.openDoors(ctx, no);
      h.orderOf(second.order_id).status = 'cancelled';
      await h.closeSession(ctx, no, { channels: [1, 2] });
      const final = (await h.getSession(ctx.sellerToken, no)).body.data;
      assert.strictEqual(final.status, 'partial');
      assert.strictEqual(final.result.code, 'PARTIAL');
      const partial = h.notificationsOf(ctx.seller.user_id).filter((n) => n.title === '書櫃作業未全部完成');
      assert.strictEqual(partial.length, 1);
      assert.strictEqual(partial[0].content,
        `您於「北商大書櫃」的書櫃作業 ${no} 有項目未能完成，請查看訂單或書籍狀態；如有疑問，請聯絡客服。`);
      assert.strictEqual(partial[0].type, 'order');
      assert.strictEqual(partial[0].related_type, null);

      const ctx2 = pickupScene();
      const second2 = await h.createSession(ctx2, ctx2.buyerToken);
      const two = second2.body.data.session_no;
      await h.startSession(ctx2.buyerToken, two, second2.body.data.items.map((i) => i.key));
      await h.selectNumber(ctx2, two);
      await h.openDoors(ctx2, two);
      h.expireSession(two);
      await h.sessionsService.sweep(new Date());
      const review = h.notificationsOf(ctx2.buyer.user_id).filter((n) => n.title === '書櫃作業待確認');
      assert.strictEqual(review.length, 1);
      assert.strictEqual(review[0].content, `您於「北商大書櫃」的書櫃作業 ${two} 待客服確認，確認後將另行通知。`);
      await h.request('POST', `/api/admin/cabinet-sessions/${two}/resolve`, {
        token: ctx2.adminToken, body: { action: 'commit', note: '已確認取書' }
      });
      const resolved = h.notificationsOf(ctx2.buyer.user_id).filter((n) => n.title === '書櫃作業已確認');
      assert.strictEqual(resolved.length, 1);
      assert.strictEqual(resolved[0].content, `您於「北商大書櫃」的書櫃作業 ${two} 已完成。`);
      assert.strictEqual(h.notificationsOf(ctx2.buyer.user_id).filter((n) => n.title === '書櫃作業未全部完成').length, 0);
    }],

    ['完成、取消、失敗與逾時時，發起人不另外收到書櫃作業通知', async () => {
      const ctx = pickupScene();
      await h.runSession(ctx, ctx.buyerToken);
      const titles = h.notificationsOf(ctx.buyer.user_id).map((n) => n.title);
      assert.ok(!titles.some((t) => t.startsWith('書櫃作業')), titles.join('、'));
    }],

    ['App 以 Socket.IO 收到 cabinet:session', async () => {
      const ctx = pickupScene();
      handle ??= api('services/realtime').attach(server.httpServer);
      const client = await new Promise((resolve, reject) => {
        const socket = connect(server.baseUrl(), { auth: { token: ctx.buyerToken }, transports: ['websocket'], reconnection: false, forceNew: true });
        socket.on('connect', () => resolve(socket));
        socket.on('connect_error', reject);
      });
      try {
        const received = new Promise((resolve, reject) => {
          const timer = setTimeout(() => reject(new Error('未收到 cabinet:session')), 2000);
          client.once('cabinet:session', (payload) => {
            clearTimeout(timer);
            resolve(payload);
          });
        });
        const created = await h.createSession(ctx, ctx.buyerToken);
        const payload = await received;
        assert.strictEqual(payload.session.session_no, created.body.data.session_no);
        assert.strictEqual(payload.session.status, 'selecting');
      } finally {
        client.disconnect();
        handle.close();
        handle = null;
      }
    }]
  ]
};
