const assert = require('assert');
const h = require('./harness');

const { prisma, api } = h;
const access = api('services/cabinet-access');

const setup = (options = {}) => {
  const admin = h.addAdmin();
  const cabinet = h.addCabinet({ name: '中正書櫃' });
  return { admin, cabinet, ...h.addDevice({ cabinetId: cabinet.cabinet_id, ...options }) };
};

const addSession = (device, overrides = {}) => {
  const user = h.addUser();
  const row = {
    session_id: prisma.nextId('cabinet_sessions'),
    cabinet_id: device.cabinet_id,
    device_id: device.device_id,
    user_id: user.user_id,
    kind: 'user',
    status: 'opening',
    version: 1,
    created_at: new Date(),
    ...overrides
  };
  prisma.rows('cabinet_sessions').push(row);
  return { row, no: h.publicId.encode('cabinet_session', row.session_id) };
};

const stubHandler = (reply = async () => ({ status: 'ok' })) => {
  const calls = [];
  h.setSessionHandler({
    deviceView: async () => null,
    handleEvent: async (device, event, now) => {
      calls.push({ device, event, now });
      return reply(event, calls.length);
    },
    sweep: async () => {}
  });
  return calls;
};

const post = (ctx, events) => h.postEvents(ctx.token, ctx.bootId, events);

module.exports = {
  name: '書櫃裝置：事件回報',
  tests: [
    ['同一個事件重送時回 duplicate，只處理一次', async () => {
      const ctx = setup();
      const event = { id: `${ctx.bootId}-000100`, type: 'connection_restored', data: { offline_ms: 3000, queued: 2 } };
      const first = await post(ctx, [event]);
      assert.deepStrictEqual(first.body.data.results, [{ id: event.id, status: 'ok' }]);
      const second = await post(ctx, [event]);
      assert.deepStrictEqual(second.body.data.results, [{ id: event.id, status: 'duplicate', result: 'ok' }]);
      const rows = h.eventsOf('connection_restored');
      assert.strictEqual(rows.length, 1);
      assert.strictEqual(rows[0].source, 'device');
      assert.strictEqual(rows[0].event_key, event.id);
      assert.ok(rows[0].processed_at instanceof Date);
    }],

    ['處理中的事件重送回 retry，超過 30 秒後重新認領處理', async () => {
      const ctx = setup();
      const id = `${ctx.bootId}-000200`;
      const row = {
        event_id: prisma.nextId('cabinet_events'), cabinet_id: ctx.cabinet.cabinet_id, device_id: ctx.device.device_id,
        session_id: null, event_key: id, source: 'device', type: 'fault', lock_channel: 1, detail: '{"code":"POWER"}',
        occurred_at: new Date(), received_at: new Date(), claimed_at: new Date(), processed_at: null, result: null
      };
      prisma.rows('cabinet_events').push(row);

      const busy = await post(ctx, [{ id, type: 'fault', channel: 1, data: { code: 'POWER' } }]);
      assert.deepStrictEqual(busy.body.data.results, [{ id, status: 'retry' }]);
      assert.strictEqual(h.doorOf(ctx.cabinet.cabinet_id, 1).fault_code, null);

      row.claimed_at = new Date(Date.now() - 31 * 1000);
      const again = await post(ctx, [{ id, type: 'fault', channel: 1, data: { code: 'POWER' } }]);
      assert.deepStrictEqual(again.body.data.results, [{ id, status: 'ok' }]);
      assert.strictEqual(h.doorOf(ctx.cabinet.cabinet_id, 1).fault_code, 'POWER');
      assert.ok(row.processed_at instanceof Date);
      assert.strictEqual(h.eventsOf('fault').length, 1);
    }],

    ['同一個 id 但內容不同時回 EVENT_ID_REUSED', async () => {
      const ctx = setup();
      const id = `${ctx.bootId}-000300`;
      await post(ctx, [{ id, type: 'fault', channel: 2, data: { code: 'POWER' } }]);
      const other = await post(ctx, [{ id, type: 'fault', channel: 3, data: { code: 'POWER' } }]);
      assert.deepStrictEqual(other.body.data.results, [{ id, status: 'rejected', code: 'EVENT_ID_REUSED' }]);
      const type = await post(ctx, [{ id, type: 'door_forced', channel: 2 }]);
      assert.strictEqual(type.body.data.results[0].code, 'EVENT_ID_REUSED');
    }],

    ['未知種類、櫃門通道超出範圍、id 格式錯誤或批次過大時拒絕', async () => {
      const ctx = setup({ doorCount: 2 });
      const res = await post(ctx, [
        { type: 'door_melted', data: {} },
        { type: 'door_forced', channel: 3 },
        { type: 'door_forced' },
        { id: 'short', type: 'connection_restored' },
        { type: 'fault', data: { code: 'bad code' } },
        { type: 'connection_restored', age_ms: 'soon' }
      ]);
      assert.deepStrictEqual(res.body.data.results.map((r) => [r.status, r.code]), [
        ['rejected', 'EVENT_INVALID'], ['rejected', 'EVENT_INVALID'], ['rejected', 'EVENT_INVALID'],
        ['rejected', 'EVENT_INVALID'], ['rejected', 'EVENT_INVALID'], ['rejected', 'EVENT_INVALID']
      ]);
      assert.strictEqual(h.eventsOf().length, 0);

      const empty = await h.request('POST', '/api/device/v1/events', { headers: h.deviceHeaders(ctx.token, ctx.bootId), body: { events: [] } });
      assert.strictEqual(empty.status, 400);
      assert.strictEqual(empty.body.code, 'DEVICE_PAYLOAD_INVALID');
      const tooMany = await post(ctx, Array.from({ length: 21 }, () => ({ type: 'connection_restored' })));
      assert.strictEqual(tooMany.status, 400);
    }],

    ['boot 事件更新韌體、門磁與開鎖時間，門數不同時只記錄', async () => {
      const ctx = setup();
      const res = await post(ctx, [{
        type: 'boot',
        data: { firmware: 'esp-2.0.0', door_count: 6, has_door_sensor: true, unlock_pulse_ms: 1200, reset_reason: 'sw', boot_id: ctx.bootId }
      }]);
      assert.strictEqual(res.body.data.results[0].status, 'ok');
      assert.strictEqual(ctx.device.firmware, 'esp-2.0.0');
      assert.strictEqual(ctx.device.unlock_pulse_ms, 1200);
      assert.strictEqual(ctx.device.has_door_sensor, true);
      assert.strictEqual(ctx.device.door_count, 4);
      assert.strictEqual(JSON.parse(h.eventsOf('boot')[0].detail).door_count_mismatch, true);

      await post(ctx, [{ type: 'boot', data: { unlock_pulse_ms: 50, firmware: '中文', boot_id: ctx.bootId } }]);
      assert.strictEqual(ctx.device.unlock_pulse_ms, 1200, '超出範圍的開鎖時間不採用');
      assert.strictEqual(ctx.device.firmware, 'esp-2.0.0');
    }],

    ['櫃門故障：記錄故障、減少可用櫃門並通知管理員；fault_cleared 只清除相同代碼，不影響待確認', async () => {
      const ctx = setup();
      const door = h.doorOf(ctx.cabinet.cabinet_id, 2);
      door.check_required_at = new Date();
      door.check_reason = 'CANCELLED_AFTER_OPEN';

      const res = await post(ctx, [{ type: 'fault', channel: 2, data: { code: 'LOCK_NO_RELEASE' } }]);
      assert.strictEqual(res.body.data.results[0].status, 'ok');
      assert.strictEqual(door.fault_code, 'LOCK_NO_RELEASE');
      assert.strictEqual(h.cabinetRow(ctx.cabinet.cabinet_id).available_slots, 3);
      assert.strictEqual(res.body.data.state.doors[1].enabled, false);
      const notices = h.notificationsOf(ctx.admin.user_id).filter((n) => n.title === '書櫃櫃門故障');
      assert.deepStrictEqual(notices.map((n) => n.content), ['「中正書櫃」櫃門 A02 回報故障：電磁鎖未釋放。']);

      await post(ctx, [{ type: 'fault', channel: 2, data: { code: 'LOCK_NO_RELEASE' } }]);
      assert.strictEqual(h.notificationsOf(ctx.admin.user_id).filter((n) => n.title === '書櫃櫃門故障').length, 1, '相同故障不重複通知');

      await post(ctx, [{ type: 'fault_cleared', channel: 2, data: { code: 'DOOR_LEFT_OPEN' } }]);
      assert.strictEqual(door.fault_code, 'LOCK_NO_RELEASE');
      await post(ctx, [{ type: 'fault_cleared', channel: 2, data: { code: 'LOCK_NO_RELEASE' } }]);
      assert.strictEqual(door.fault_code, null);
      assert.ok(door.check_required_at instanceof Date, 'fault_cleared 不會解除待確認');
      assert.strictEqual(h.cabinetRow(ctx.cabinet.cabinet_id).available_slots, 3, '待確認的櫃門仍不可分配');
    }],

    ['裝置故障持續 120 秒後才轉為手動模式，清除後恢復掃碼', async () => {
      const ctx = setup();
      await post(ctx, [{ type: 'fault', data: { code: 'SCREEN', detail: 'no display' } }]);
      assert.strictEqual(ctx.device.fault_code, 'SCREEN');
      assert.ok(ctx.device.fault_since instanceof Date);
      assert.strictEqual(h.notificationsOf(ctx.admin.user_id).filter((n) => n.title === '書櫃裝置故障')[0].content,
        '「中正書櫃」的書櫃裝置回報故障：螢幕異常。');

      const soon = (await access.accessFor([ctx.cabinet.cabinet_id])).get(ctx.cabinet.cabinet_id);
      assert.deepStrictEqual([soon.mode, soon.reason], ['scan', null]);
      const later = (await access.accessFor([ctx.cabinet.cabinet_id], new Date(Date.now() + 121 * 1000))).get(ctx.cabinet.cabinet_id);
      ctx.device.last_seen_at = new Date(Date.now() + 121 * 1000);
      const faulty = (await access.accessFor([ctx.cabinet.cabinet_id], new Date(Date.now() + 121 * 1000))).get(ctx.cabinet.cabinet_id);
      assert.deepStrictEqual([later.mode, later.reason], ['manual', 'offline']);
      assert.deepStrictEqual([faulty.mode, faulty.reason], ['manual', 'fault']);

      ctx.device.last_seen_at = new Date(Date.now() - 10 * 1000);
      await post(ctx, [{ type: 'fault_cleared', data: { code: 'SCREEN' } }]);
      assert.strictEqual(ctx.device.fault_code, null);
      assert.strictEqual(ctx.device.fault_since, null);
    }],

    ['occurred_at 依 age_ms 計算，前一次開機留下的事件記為 age_unknown', async () => {
      const ctx = setup();
      const before = Date.now();
      await post(ctx, [
        { type: 'connection_restored', age_ms: 5000, data: { offline_ms: 1, queued: 0 } },
        { type: 'connection_restored', age_ms: null, data: { offline_ms: 1, queued: 0 } },
        { type: 'connection_restored', age_ms: 30 * 24 * 3600 * 1000, data: {} }
      ]);
      const [aged, unknown, capped] = h.eventsOf('connection_restored');
      assert.ok(Math.abs(aged.occurred_at.getTime() - (before - 5000)) < 1000);
      assert.strictEqual(unknown.occurred_at.getTime(), unknown.received_at.getTime());
      assert.strictEqual(JSON.parse(unknown.detail).age_unknown, true);
      assert.strictEqual(JSON.parse(aged.detail).age_unknown, undefined);
      assert.ok(Math.abs(capped.occurred_at.getTime() - (before - 7 * 24 * 3600 * 1000)) < 1000, '最多回推 7 天');
    }],

    ['沒有作業處理器時作業事件回 SESSION_UNAVAILABLE；不屬於本裝置的作業回 SESSION_MISMATCH', async () => {
      const ctx = setup();
      h.setSessionHandler(null);
      const { no } = addSession(ctx.device);
      const res = await post(ctx, [{ type: 'close_refused', session_id: no, data: { command_id: `${no}:close:1`, code: 'DOOR_OPEN' } }]);
      assert.deepStrictEqual(res.body.data.results.map((r) => [r.status, r.code]), [['rejected', 'SESSION_UNAVAILABLE']]);

      const other = setup();
      const foreign = addSession(other.device);
      const mismatch = await post(ctx, [
        { type: 'door_opened', session_id: foreign.no, channel: 1, data: {} },
        { type: 'door_opened', session_id: 'CS9999999', channel: 1, data: {} },
        { type: 'close_refused', data: { code: 'DOOR_OPEN' } },
        { type: 'match_selected', session_id: no, data: { value: 37 } },
        { type: 'session_cancel', session_id: no }
      ]);
      assert.deepStrictEqual(mismatch.body.data.results.map((r) => r.code),
        ['SESSION_MISMATCH', 'SESSION_MISMATCH', 'EVENT_INVALID', 'EVENT_INVALID', 'EVENT_INVALID']);
    }],

    ['作業事件轉交作業處理器，session_id 以數字編號提供', async () => {
      const ctx = setup();
      const calls = stubHandler();
      const { row, no } = addSession(ctx.device);
      const res = await post(ctx, [
        { type: 'close_refused', session_id: no, data: { command_id: `${no}:close:1`, code: 'DOOR_OPEN' } },
        { type: 'door_opened', session_id: no.toLowerCase(), channel: 2, data: { command_id: `${no}:2:1` }, age_ms: 40 }
      ]);
      assert.deepStrictEqual(res.body.data.results.map((r) => r.status), ['ok', 'ok']);
      assert.strictEqual(calls.length, 2);
      assert.strictEqual(calls[0].device.device_id, ctx.device.device_id);
      assert.deepStrictEqual(
        { type: calls[1].event.type, session_id: calls[1].event.session_id, session_no: calls[1].event.session_no, channel: calls[1].event.channel },
        { type: 'door_opened', session_id: row.session_id, session_no: no, channel: 2 }
      );
      assert.deepStrictEqual(calls[1].event.data, { command_id: `${no}:2:1` });
      assert.ok(calls[1].event.occurred_at instanceof Date);
      assert.strictEqual(h.eventsOf('door_opened')[0].session_id, row.session_id);
    }],

    ['作業處理器回 retry 時保留事件，同批次後續同一作業的事件也回 retry', async () => {
      const ctx = setup();
      const calls = stubHandler(async (event, n) => (n === 1 ? { status: 'retry' } : { status: 'ok' }));
      const { no } = addSession(ctx.device);
      const other = addSession(ctx.device, { status: 'completed' });
      const res = await post(ctx, [
        { type: 'door_opened', session_id: no, channel: 1, data: {} },
        { type: 'door_closed', session_id: no, channel: 1, data: { reason: 'user_done' } },
        { type: 'session_closed', session_id: other.no, data: { outcome: 'completed', reason: 'user_done' } }
      ]);
      assert.deepStrictEqual(res.body.data.results.map((r) => r.status), ['retry', 'retry', 'ok']);
      assert.strictEqual(calls.length, 2);
      const opened = h.eventsOf('door_opened')[0];
      assert.strictEqual(opened.claimed_at, null);
      assert.strictEqual(opened.processed_at, null);
      assert.strictEqual(h.eventsOf('door_closed').length, 0);

      const resend = await h.request('POST', '/api/device/v1/events', {
        headers: h.deviceHeaders(ctx.token, ctx.bootId),
        body: { events: [{ id: opened.event_key, type: 'door_opened', session_id: no, channel: 1, data: {}, age_ms: 0 }] }
      });
      assert.deepStrictEqual(resend.body.data.results, [{ id: opened.event_key, status: 'ok' }]);
    }],

    ['處理時發生非預期錯誤：回 500、釋放認領，重送後可重新處理', async () => {
      const ctx = setup();
      let fail = true;
      stubHandler(async () => {
        if (fail) {
          fail = false;
          throw new Error('資料庫暫時無法連線');
        }
        return { status: 'rejected', code: 'STALE' };
      });
      const { no } = addSession(ctx.device);
      const event = { id: `${ctx.bootId}-000900`, type: 'session_closed', session_id: no, data: { outcome: 'completed', reason: 'timeout' } };
      const originalError = console.error;
      console.error = () => {};
      let crashed;
      try {
        crashed = await post(ctx, [event]);
      } finally {
        console.error = originalError;
      }
      assert.strictEqual(crashed.status, 500);
      const [row] = h.eventsOf('session_closed');
      assert.strictEqual(row.claimed_at, null);

      const retried = await post(ctx, [event]);
      assert.deepStrictEqual(retried.body.data.results, [{ id: event.id, status: 'rejected', code: 'STALE' }]);
      assert.strictEqual(row.result, 'STALE');
      const dup = await post(ctx, [event]);
      assert.deepStrictEqual(dup.body.data.results, [{ id: event.id, status: 'duplicate', result: 'STALE' }]);
    }],

    ['帶作業的櫃門故障：先記錄故障，該門仍為 pending 時轉交作業處理器', async () => {
      const ctx = setup();
      const calls = stubHandler();
      const { row, no } = addSession(ctx.device);
      const door = h.doorOf(ctx.cabinet.cabinet_id, 3);
      prisma.rows('cabinet_session_doors').push({ session_id: row.session_id, slot_id: door.slot_id, lock_channel: 3, state: 'pending' });

      await post(ctx, [{ type: 'fault', channel: 3, session_id: no, data: { code: 'LOCK_NO_RELEASE' } }]);
      assert.strictEqual(door.fault_code, 'LOCK_NO_RELEASE');
      assert.strictEqual(calls.length, 1);
      assert.strictEqual(calls[0].event.type, 'fault');

      prisma.rows('cabinet_session_doors')[0].state = 'open';
      await post(ctx, [{ type: 'fault', channel: 3, session_id: no, data: { code: 'SENSOR_ERROR' } }]);
      assert.strictEqual(calls.length, 1, '已開啟的門不再轉交');
    }],

    ['未收到指令卻被開啟：記錄並通知管理員', async () => {
      const ctx = setup();
      const res = await post(ctx, [{ type: 'door_forced', channel: 4 }]);
      assert.strictEqual(res.body.data.results[0].status, 'ok');
      assert.strictEqual(h.eventsOf('door_forced')[0].lock_channel, 4);
      const [notice] = h.notificationsOf(ctx.admin.user_id).filter((n) => n.title === '書櫃櫃門異常開啟');
      assert.strictEqual(notice.content, '「中正書櫃」櫃門 A04 在未收到開門指令時被開啟。');
    }],

    ['門磁狀態由事件推導：開門、強制開啟與未關閉為 open，關門與未關閉排除為 closed；較早的事件不覆蓋較新的狀態', async () => {
      const ctx = setup({ hasDoorSensor: true });
      const calls = stubHandler();
      const { no } = addSession(ctx.device);
      const sensor = (channel) => h.doorOf(ctx.cabinet.cabinet_id, channel).sensor_state;

      await post(ctx, [{ type: 'door_forced', channel: 1 }]);
      assert.strictEqual(sensor(1), 'open');
      const closed = await post(ctx, [{ type: 'door_closed', channel: 1, data: { reason: 'sensor' } }]);
      assert.strictEqual(closed.body.data.results[0].status, 'ok', '沒有作業時關門仍可回報門磁狀態');
      assert.strictEqual(sensor(1), 'closed');
      assert.strictEqual(calls.length, 0, '不帶作業的關門回報不轉交作業處理器');

      await post(ctx, [{ type: 'door_opened', channel: 2, session_id: no, data: { command_id: `${no}:2:1` } }]);
      assert.strictEqual(sensor(2), 'open');
      await post(ctx, [{ type: 'fault', channel: 2, data: { code: 'DOOR_LEFT_OPEN' } }]);
      assert.strictEqual(sensor(2), 'open');
      await post(ctx, [{ type: 'fault_cleared', channel: 2, data: { code: 'DOOR_LEFT_OPEN' } }]);
      assert.strictEqual(sensor(2), 'closed');
      await post(ctx, [{ type: 'door_opened', channel: 2, session_id: no, age_ms: 60000, data: {} }]);
      assert.strictEqual(sensor(2), 'closed', '離線期間累積的較早事件不覆蓋目前狀態');
      await post(ctx, [{ type: 'door_closed', channel: 3, session_id: no, data: { reason: 'user_done', sensor: 'open' } }]);
      assert.strictEqual(sensor(3), 'open', '明確回報的 data.sensor 優先');

      const state = await h.deviceState(ctx.token, ctx.bootId);
      assert.deepStrictEqual(state.body.data.doors.map((d) => d.sensor), ['closed', 'closed', 'open', null]);
    }],

    ['沒有門磁的裝置不記錄門磁狀態，也不接受不帶作業的關門回報', async () => {
      const ctx = setup();
      const res = await post(ctx, [{ type: 'door_closed', channel: 1, data: { reason: 'sensor' } }]);
      assert.deepStrictEqual(res.body.data.results.map((r) => [r.status, r.code]), [['rejected', 'EVENT_INVALID']]);
      await post(ctx, [{ type: 'door_forced', channel: 1 }]);
      assert.strictEqual(h.doorOf(ctx.cabinet.cabinet_id, 1).sensor_state, null);
    }]
  ]
};
