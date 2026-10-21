const assert = require('assert');
const h = require('./session-harness');

const { api } = h;
const demo = api('services/cabinet-demo');
require('../lib/server').onReset(() => demo.reset());

const FAR = { lat: 25.0377, lng: 121.51, accuracy_m: 20, age_ms: 500 };

const pickupScene = () => {
  const ctx = h.scene();
  const book = h.listedBook(ctx);
  const order = h.orderFor(ctx, book.book_id, { status: 'deposited' });
  h.addPlaced(book.book_id, h.doorOf(ctx.cabinet.cabinet_id, 1).slot_id);
  return { ...ctx, book, order };
};

const setDemo = (ctx, body, { verify = true } = {}) => h.request('PUT', '/api/admin/cabinet-demo-mode', {
  token: ctx.adminToken, headers: verify ? h.adminVerifyHeaders(ctx.adminToken) : {}, body
});

const summaryOf = (log) => JSON.parse(log.detail).summary;

module.exports = {
  name: '書櫃展示模式',
  tests: [
    ['開啟須書櫃管理權限與身分驗證並限定時數，關閉不需驗證；開關都寫入操作紀錄', async () => {
      const ctx = h.scene();
      const initial = await h.request('GET', '/api/admin/cabinet-demo-mode', { token: ctx.adminToken });
      assert.strictEqual(initial.status, 200, initial.text);
      assert.deepStrictEqual(initial.body.data, { enabled: false, until: null });
      assert.strictEqual((await h.request('GET', '/api/admin/cabinet-demo-mode', { token: ctx.buyerToken })).status, 403);

      const noVerify = await setDemo(ctx, { enabled: true, hours: 4 }, { verify: false });
      assert.strictEqual(noVerify.status, 403);
      assert.strictEqual(noVerify.body.code, 'VERIFICATION_REQUIRED');
      const stringFlag = await setDemo(ctx, { enabled: 'true', hours: 4 }, { verify: false });
      assert.strictEqual(stringFlag.body.code, 'VERIFICATION_REQUIRED');
      const badHours = await setDemo(ctx, { enabled: true, hours: 5 });
      assert.strictEqual(badHours.status, 400);
      assert.strictEqual(demo.isOn(), false);

      const before = Date.now();
      const on = await setDemo(ctx, { enabled: true, hours: 4 });
      assert.strictEqual(on.status, 200, on.text);
      assert.strictEqual(on.body.message, '已開啟展示模式');
      assert.strictEqual(on.body.data.enabled, true);
      const until = Date.parse(on.body.data.until);
      assert.ok(until >= before + 4 * 3600000 && until <= Date.now() + 4 * 3600000);

      const seen = await h.request('GET', '/api/cabinet-sessions/demo-mode', { token: ctx.buyerToken });
      assert.strictEqual(seen.status, 200, seen.text);
      assert.deepStrictEqual(seen.body.data, on.body.data);

      const off = await setDemo(ctx, { enabled: false }, { verify: false });
      assert.strictEqual(off.status, 200, off.text);
      assert.deepStrictEqual(off.body.data, { enabled: false, until: null });
      const actions = h.logs().map((l) => l.action);
      assert.deepStrictEqual(actions.filter((a) => a.includes('展示模式')), ['開啟書櫃展示模式', '關閉書櫃展示模式']);
      assert.ok(summaryOf(h.logs().find((l) => l.action === '開啟書櫃展示模式')).includes('4 小時'));
    }],

    ['展示模式下距離過遠或未提供定位仍可建立作業，並在作業事件註明；到期後恢復距離檢查', async () => {
      const ctx = pickupScene();
      assert.strictEqual((await setDemo(ctx, { enabled: true, hours: 1 })).status, 200);

      const far = await h.createSession(ctx, ctx.buyerToken, { location_status: 'granted', location: FAR });
      assert.strictEqual(far.status, 201, far.text);
      assert.ok(far.body.data.distance_m > 800);
      const [created] = h.eventsOf('session_created');
      assert.strictEqual(JSON.parse(created.detail).demo_mode, true);
      assert.strictEqual((await h.cancelSession(ctx.buyerToken, far.body.data.session_no)).status, 200);

      const other = h.addUser({ nickname: '另一位買家', balance: 1000 });
      const book = h.listedBook(ctx);
      h.orderFor(ctx, book.book_id, { status: 'deposited', buyer: other });
      h.addPlaced(book.book_id, h.doorOf(ctx.cabinet.cabinet_id, 2).slot_id);
      const denied = await h.createSession(ctx, h.tokenFor(other), { location_status: 'denied', location: null });
      assert.strictEqual(denied.status, 201, denied.text);
      assert.strictEqual(h.sessionOf(denied.body.data.session_no).location_status, 'denied');
      assert.strictEqual((await h.cancelSession(h.tokenFor(other), denied.body.data.session_no)).status, 200);

      await demo.set({ enabled: true, hours: 1 }, { adminId: ctx.admin.user_id }, new Date(Date.now() - 2 * 3600000));
      assert.deepStrictEqual(demo.status(), { enabled: false, until: null });
      const third = h.addUser({ nickname: '第三位買家', balance: 1000 });
      const late = await h.createSession(ctx, h.tokenFor(third), { location_status: 'granted', location: FAR });
      assert.strictEqual(late.status, 403, late.text);
      assert.strictEqual(late.body.code, 'CABINET_TOO_FAR');
    }],

    ['展示模式下遠端開櫃免身分驗證與數字比對，有存放紀錄的櫃門也直接送出開門指令', async () => {
      const ctx = pickupScene();
      assert.strictEqual((await setDemo(ctx, { enabled: true, hours: 1 })).status, 200);
      const slot = h.doorOf(ctx.cabinet.cabinet_id, 1);
      const res = await h.request('POST', `/api/admin/cabinets/${ctx.cabinet.cabinet_id}/doors/${slot.slot_id}/open`, {
        token: ctx.adminToken, body: { reason: '複評展示' }
      });
      assert.strictEqual(res.status, 201, res.text);
      assert.strictEqual(res.body.message, '已送出開門指令');
      assert.strictEqual(res.body.data.status, 'opening');
      const row = h.sessionOf(res.body.data.session_no);
      assert.strictEqual(row.admin_force, true);
      assert.strictEqual(row.match_code ?? null, null);
      const [opened] = h.eventsOf('admin_open');
      assert.strictEqual(JSON.parse(opened.detail).demo_mode, true);
      const log = h.logs().find((l) => l.action === '遠端開啟書櫃櫃門');
      assert.ok(summaryOf(log).includes('（展示模式，未經數字確認）'));

      const state = (await h.deviceState(ctx.token, ctx.bootId)).body.data;
      assert.strictEqual(state.screen, 'admin');
      assert.strictEqual(state.commands[0].channel, 1);

      const summary = await h.request('GET', `/api/admin/cabinets/${ctx.cabinet.cabinet_id}/device`, { token: ctx.adminToken });
      assert.strictEqual(summary.body.data.demo_mode.enabled, true);
    }],

    ['展示模式關閉時遠端開櫃仍須身分驗證', async () => {
      const ctx = pickupScene();
      const slot = h.doorOf(ctx.cabinet.cabinet_id, 2);
      const res = await h.request('POST', `/api/admin/cabinets/${ctx.cabinet.cabinet_id}/doors/${slot.slot_id}/open`, {
        token: ctx.adminToken, body: { reason: '測試' }
      });
      assert.strictEqual(res.status, 403);
      assert.strictEqual(res.body.code, 'VERIFICATION_REQUIRED');
    }]
  ]
};
