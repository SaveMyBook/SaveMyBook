const assert = require('assert');
const h = require('./session-harness');

const { prisma } = h;

const pickupScene = () => {
  const ctx = h.scene();
  const book = h.listedBook(ctx);
  const order = h.orderFor(ctx, book.book_id, { status: 'deposited' });
  h.addPlaced(book.book_id, h.doorOf(ctx.cabinet.cabinet_id, 2).slot_id);
  return { ...ctx, book, order };
};

const matching = async (ctx) => {
  const created = await h.createSession(ctx, ctx.buyerToken);
  assert.strictEqual(created.status, 201, created.text);
  const no = created.body.data.session_no;
  const started = await h.startSession(ctx.buyerToken, no, created.body.data.items.filter((i) => i.selected).map((i) => i.key));
  assert.strictEqual(started.status, 200, started.text);
  return no;
};

const opened = async (ctx) => {
  const no = await matching(ctx);
  const matched = await h.enterCode(no);
  assert.strictEqual(matched.status, 200, matched.text);
  const { commands } = await h.openDoors(ctx, no);
  return { no, channels: commands.map((c) => c.channel) };
};

const adminOpen = (ctx, channel, token = ctx.adminToken) => h.request(
  'POST', `/api/admin/cabinets/${ctx.cabinet.cabinet_id}/doors/${h.doorOf(ctx.cabinet.cabinet_id, channel).slot_id}/open`,
  { token, headers: h.adminVerifyHeaders(token), body: { reason: '檢查櫃門' } }
);

const closeCommandsOf = async (ctx) => (await h.deviceState(ctx.token, ctx.bootId)).body.data.commands.filter((c) => c.type === 'close');

module.exports = {
  name: '書櫃作業：手機輸入比對碼與結束作業',
  tests: [
    ['比對碼格式不符回 400 MATCH_CODE_INVALID，不消耗比對機會', async () => {
      const ctx = pickupScene();
      const no = await matching(ctx);
      const token = ctx.buyerToken;
      for (const code of ['7', '100', '09', '３７', ' 37', '3a', '']) {
        const res = await h.request('POST', `/api/cabinet-sessions/${no}/match`, { token, body: { code } });
        assert.strictEqual(res.status, 400, `${code}：${res.text}`);
        assert.strictEqual(res.body.code, 'MATCH_CODE_INVALID');
        assert.strictEqual(res.body.message, '請輸入兩位數字');
      }
      for (const body of [{ code: h.matchCodeOf(no) }, {}, { code: null }]) {
        const res = await h.request('POST', `/api/cabinet-sessions/${no}/match`, { token, body });
        assert.strictEqual(res.body.code, 'MATCH_CODE_INVALID', JSON.stringify(body));
      }
      const row = h.sessionOf(no);
      assert.strictEqual(row.status, 'matching');
      assert.strictEqual(row.matched_at, null);
      assert.strictEqual(h.eventsOf('match_entered').length, 0);

      const ok = await h.enterCode(no);
      assert.strictEqual(ok.status, 200, ok.text);
      assert.strictEqual(ok.body.data.status, 'opening');
    }],

    ['比對時限已過而排程尚未處理時送出：作業改為 expired／MATCH_TIMEOUT，回 409 附作業', async () => {
      const ctx = pickupScene();
      const no = await matching(ctx);
      h.expireSession(no);
      const res = await h.enterCode(no);
      assert.strictEqual(res.status, 409, res.text);
      assert.strictEqual(res.body.code, 'CABINET_SESSION_STATE');
      assert.strictEqual(res.body.session.status, 'expired');
      assert.strictEqual(res.body.session.result.code, 'MATCH_TIMEOUT');
      assert.strictEqual(h.sessionOf(no).matched_at, null);
      assert.strictEqual(h.eventsOf('match_entered').length, 0);
    }],

    ['只有發起人可以輸入：他人與管理員的使用者端點皆為 404，後台端點也不接受使用者作業', async () => {
      const ctx = pickupScene();
      const no = await matching(ctx);
      for (const token of [h.tokenFor(h.addUser()), ctx.sellerToken, ctx.adminToken]) {
        const res = await h.enterCode(no, h.matchCodeOf(no), { token });
        assert.strictEqual(res.status, 404, res.text);
        assert.strictEqual(res.body.code, 'CABINET_SESSION_NOT_FOUND');
      }
      const viaAdmin = await h.request('POST', `/api/admin/cabinet-sessions/${no}/match`, {
        token: ctx.adminToken, body: { code: String(h.matchCodeOf(no)) }
      });
      assert.strictEqual(viaAdmin.status, 404, viaAdmin.text);
      assert.strictEqual(viaAdmin.body.code, 'CABINET_SESSION_NOT_FOUND');
      assert.strictEqual(h.sessionOf(no).status, 'matching');
      assert.strictEqual(h.sessionOf(no).matched_at, null);
    }],

    ['管理員遠端開櫃：只有發起的管理員可以輸入比對碼與結束作業，其他管理員為 404', async () => {
      const ctx = pickupScene();
      const res = await adminOpen(ctx, 3);
      assert.strictEqual(res.status, 201, res.text);
      const no = res.body.data.session_no;
      const otherAdmin = h.tokenFor(h.addAdmin());

      const foreign = await h.enterCode(no, h.matchCodeOf(no), { token: otherAdmin });
      assert.strictEqual(foreign.status, 404, foreign.text);
      assert.strictEqual(foreign.body.code, 'CABINET_SESSION_NOT_FOUND');
      const asUser = await h.request('POST', `/api/cabinet-sessions/${no}/match`, {
        token: ctx.adminToken, body: { code: String(h.matchCodeOf(no)) }
      });
      assert.strictEqual(asUser.status, 404);
      assert.strictEqual(h.sessionOf(no).matched_at, null);

      const matched = await h.enterCode(no);
      assert.strictEqual(matched.status, 200, matched.text);
      assert.strictEqual(matched.body.data.status, 'opening');
      await h.openDoors(ctx, no);

      const refused = await h.requestClose(no, 'completed', { token: otherAdmin });
      assert.strictEqual(refused.status, 404);
      const closing = await h.request('POST', `/api/admin/cabinet-sessions/${no}/close`, { token: ctx.adminToken });
      assert.strictEqual(closing.status, 200, closing.text);
      assert.strictEqual(closing.body.message, '已要求書櫃結束作業');
      assert.strictEqual(closing.body.data.status, 'open');
      const [command] = await closeCommandsOf(ctx);
      assert.strictEqual(command.outcome, 'completed');
      assert.strictEqual(command.id, `${no}:close:${h.sessionOf(no).close_requested_at.getTime()}`);

      await h.closeSession(ctx, no, { channels: [3] });
      const requestedAt = h.sessionOf(no).close_requested_at;
      const repeat = await h.request('POST', `/api/admin/cabinet-sessions/${no}/close`, { token: ctx.adminToken });
      assert.strictEqual(repeat.status, 200, repeat.text);
      assert.strictEqual(repeat.body.message, '此作業已結束', '作業已結束時不送出要求');
      assert.strictEqual(repeat.body.data.status, 'completed');
      assert.strictEqual(h.sessionOf(no).close_requested_at, requestedAt);
    }],

    ['手機按完成：裝置收到 close 指令後關門並提交，每次輪詢都帶同一個指令直到作業關閉', async () => {
      const ctx = pickupScene();
      const { no, channels } = await opened(ctx);
      assert.deepStrictEqual(await closeCommandsOf(ctx), []);
      const calls = h.captureEmits();

      const res = await h.requestClose(no, 'completed');
      assert.strictEqual(res.status, 200, res.text);
      assert.strictEqual(res.body.data.status, 'open');
      assert.strictEqual(res.body.data.notice, null);
      const row = h.sessionOf(no);
      assert.strictEqual(row.close_request, 'completed');
      assert.ok(row.close_requested_at instanceof Date);
      assert.strictEqual(calls.filter((c) => c.event === 'cabinet:session').at(-1).payload.session.version, row.version);

      const first = await closeCommandsOf(ctx);
      const again = await closeCommandsOf(ctx);
      assert.deepStrictEqual(first, [{ type: 'close', id: `${no}:close:${row.close_requested_at.getTime()}`, outcome: 'completed' }]);
      assert.deepStrictEqual(again, first);

      const closed = await h.closeSession(ctx, no, { channels });
      assert.ok(closed.body.data.results.every((r) => r.status === 'ok'), closed.text);
      const final = (await h.getSession(ctx.buyerToken, no)).body.data;
      assert.strictEqual(final.status, 'completed');
      assert.strictEqual(h.sessionOf(no).close_reason, 'user_done');
      assert.ok(h.orderOf(ctx.order.order_id).picked_up_at instanceof Date);
      assert.deepStrictEqual(closed.body.data.state.commands, []);

      const repeat = await h.requestClose(no, 'cancelled');
      assert.strictEqual(repeat.status, 200, repeat.text);
      assert.strictEqual(repeat.body.data.status, 'completed');
      assert.strictEqual(repeat.body.data.result.code, 'COMPLETED');
    }],

    ['手機按取消：裝置以 user_cancel 關閉，結果為 CANCELLED_AFTER_OPEN，狀態未變更', async () => {
      const ctx = pickupScene();
      const { no } = await opened(ctx);
      const res = await h.requestClose(no, 'cancelled');
      assert.strictEqual(res.status, 200, res.text);
      const [command] = await closeCommandsOf(ctx);
      assert.strictEqual(command.outcome, 'cancelled');

      await h.closeSession(ctx, no, { outcome: 'cancelled' });
      const final = (await h.getSession(ctx.buyerToken, no)).body.data;
      assert.strictEqual(final.status, 'cancelled');
      assert.deepStrictEqual(final.result, { outcome: 'cancelled', code: 'CANCELLED_AFTER_OPEN', message: '本次作業已取消，狀態未變更' });
      assert.strictEqual(h.sessionOf(no).close_reason, 'user_cancel');
      assert.strictEqual(h.orderOf(ctx.order.order_id).picked_up_at, null);
    }],

    ['裝置因櫃門未關拒絕：notice 為 CLOSE_DOOR_FIRST、指令撤回；重新要求後 notice 清除並產生新指令', async () => {
      const ctx = pickupScene();
      const { no } = await opened(ctx);
      await h.requestClose(no, 'completed');
      const [command] = await closeCommandsOf(ctx);

      const stale = await h.events(ctx, [{ type: 'close_refused', session_id: no, data: { command_id: `${no}:close:1`, code: 'DOOR_OPEN' } }]);
      assert.strictEqual(stale.body.data.results[0].status, 'ok');
      assert.strictEqual(h.sessionOf(no).close_request, 'completed', '不是目前的指令時不處理');

      const calls = h.captureEmits();
      const refused = await h.events(ctx, [{ type: 'close_refused', session_id: no, data: { command_id: command.id, code: 'DOOR_OPEN' } }]);
      assert.strictEqual(refused.body.data.results[0].status, 'ok');
      assert.deepStrictEqual(refused.body.data.state.commands, []);
      const row = h.sessionOf(no);
      assert.strictEqual(row.close_request, null);
      assert.ok(row.close_refused_at instanceof Date);
      const pushed = calls.filter((c) => c.event === 'cabinet:session').at(-1).payload.session;
      assert.strictEqual(pushed.notice, 'CLOSE_DOOR_FIRST');
      assert.strictEqual((await h.getSession(ctx.buyerToken, no)).body.data.notice, 'CLOSE_DOOR_FIRST');

      const retry = await h.requestClose(no, 'completed');
      assert.strictEqual(retry.body.data.notice, null);
      assert.strictEqual(h.sessionOf(no).close_refused_at, null);
      const [next] = await closeCommandsOf(ctx);
      assert.notStrictEqual(next.id, command.id);
    }],

    ['開門前或提交中不能要求關門；outcome 不正確為 400；他人作業為 404', async () => {
      const ctx = pickupScene();
      const no = await matching(ctx);
      const early = await h.requestClose(no, 'completed');
      assert.strictEqual(early.status, 409, early.text);
      assert.strictEqual(early.body.code, 'CABINET_SESSION_STATE');
      assert.strictEqual(early.body.message, '目前無法執行此操作');

      await h.enterCode(no);
      const opening = await h.requestClose(no, 'completed');
      assert.strictEqual(opening.status, 409);
      assert.strictEqual(opening.body.session.status, 'opening');

      await h.openDoors(ctx, no);
      const bad = await h.requestClose(no, 'done');
      assert.strictEqual(bad.status, 400);
      const stranger = await h.requestClose(no, 'completed', { token: h.tokenFor(h.addUser()) });
      assert.strictEqual(stranger.status, 404);
      assert.strictEqual(stranger.body.code, 'CABINET_SESSION_NOT_FOUND');

      const open = await h.requestClose(no, 'completed', { token: ctx.buyerToken });
      assert.strictEqual(open.status, 200, open.text);
      await h.events(ctx, [{ type: 'close_refused', session_id: no, data: { command_id: (await closeCommandsOf(ctx))[0].id, code: 'DOOR_OPEN' } }]);
      assert.strictEqual((await h.getSession(ctx.buyerToken, no)).body.data.notice, 'CLOSE_DOOR_FIRST');
      const started = await h.startSession(ctx.buyerToken, no, ['x']);
      assert.strictEqual(started.status, 409);
      assert.strictEqual(started.body.message, '櫃門已開啟，無法執行此操作');

      h.sessionOf(no).closed_at = new Date();
      const committing = await h.requestClose(no, 'completed');
      assert.strictEqual(committing.status, 409);
      assert.strictEqual(committing.body.code, 'CABINET_SESSION_STATE');
      assert.strictEqual(committing.body.message, '本次作業處理中，請稍候', '書櫃已回報關門，不可再稱櫃門已開啟');
      assert.strictEqual(committing.body.session.notice, null, '書櫃已回報關門後不再提示先關門');
      assert.strictEqual(h.sessionOf(no).close_request, null);
      assert.strictEqual(prisma.rows('cabinet_sessions').length, 1);
    }]
  ]
};
