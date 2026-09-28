const assert = require('assert');
const h = require('./harness');

const {
  api, STORAGE_KEYS, TOKEN, QR_PAYLOAD, CHOICES, FakeClock, memoryStorage,
  idleState, sessionState, selectState, matchState, openingState, resultState, makeDevice, openDoors
} = h;

const { DeviceCore, MESSAGES, LAYOUT, TIMING } = api('views/kiosk/device-core');
const QR = api('views/kiosk/qrcode');

const BOOT_RE = /^[a-z0-9]{8}$/;

const started = async (opts) => {
  const device = makeDevice(opts);
  device.core.start();
  await device.clock.advance(0);
  return device;
};

const types = (events) => events.map((e) => e.type);
const eventsAfter = (api, index) => api.requests.slice(index).filter((r) => r.path.endsWith('/events')).flatMap((r) => r.body.events);

const unlockTimeline = (views) => {
  const timeline = [];
  const powered = new Map();
  for (const { at, view } of views) {
    for (const door of view.doors) {
      const was = powered.get(door.channel) || false;
      if (door.unlocking !== was) timeline.push({ at, channel: door.channel, on: door.unlocking });
      powered.set(door.channel, door.unlocking);
    }
  }
  return timeline;
};

const tests = [
  ['開機後第一個請求為含 boot 事件的 POST /events，所有請求都帶 X-Device-Boot 與裝置憑證', async () => {
    const { api: server, clock, core } = await started();
    const [first] = server.requests;
    assert.strictEqual(first.method, 'POST');
    assert.strictEqual(first.path, '/api/device/v1/events');
    const boot = first.body.events[0];
    assert.strictEqual(boot.type, 'boot');
    assert.match(first.headers['x-device-boot'], BOOT_RE);
    assert.deepStrictEqual(boot.data, {
      firmware: 'sim-1.0.0', door_count: 4, has_door_sensor: false, unlock_pulse_ms: 800, reset_reason: 'power_on',
      boot_id: first.headers['x-device-boot']
    });
    assert.strictEqual(boot.id, `${first.headers['x-device-boot']}-000001`);
    assert.strictEqual(typeof boot.age_ms, 'number');

    await clock.advance(4000);
    const later = server.requests.slice(1);
    assert.deepStrictEqual(later.map((r) => `${r.method} ${r.path}`), ['GET /api/device/v1/state', 'GET /api/device/v1/state']);
    for (const r of server.requests) {
      assert.strictEqual(r.headers['x-device-boot'], first.headers['x-device-boot']);
      assert.strictEqual(r.headers.authorization, `Device ${TOKEN}`);
    }
    assert.strictEqual(core.view.screen, 'idle');
    assert.strictEqual(core.view.connection, 'online');
    core.stop();
  }],

  ['閒置時每 2 秒、作業中依 poll_ms 每 1 秒輪詢', async () => {
    const { api: server, clock, core } = await started();
    await clock.advance(6000);
    const idleAt = server.requests.filter((r) => r.method === 'GET').map((r) => r.at);
    assert.deepStrictEqual(idleAt.slice(1).map((t, i) => t - idleAt[i]), [2000, 2000]);

    server.state = selectState();
    const from = server.requests.length;
    await clock.advance(4000);
    const busyAt = server.requests.slice(from).map((r) => r.at);
    assert.deepStrictEqual(busyAt.slice(1).map((t, i) => t - busyAt[i]), [1000, 1000]);
    core.stop();
  }],

  ['閒置畫面顯示 QR 與更換進度，碼逾期後不再顯示', async () => {
    const { api: server, clock, core } = await started();
    assert.strictEqual(core.view.qr.payload, QR_PAYLOAD);
    assert.ok(Math.abs(core.view.qr.refreshRatio - 20000 / 30000) < 0.01);
    assert.deepStrictEqual(core.view.lines, [MESSAGES.IDLE_SCAN]);
    assert.deepStrictEqual(core.view.buttons, []);

    await clock.advance(1000);
    assert.ok(Math.abs(core.view.qr.refreshRatio - 19000 / 30000) < 0.02);

    server.state = idleState({ qr: { payload: QR_PAYLOAD, refresh_in_ms: 1000, expires_in_ms: 1500 } });
    await clock.advance(1000);
    assert.ok(core.view.qr);
    await clock.advance(1600);
    assert.strictEqual(core.view.qr, null);
    core.stop();
  }],

  ['非營業時間、維修中與結果畫面依伺服器訊息顯示', async () => {
    const { api: server, clock, core } = await started();
    server.state = idleState({ screen: 'closed_hours', qr: null, message: { code: 'CLOSED_HOURS', params: { open: '08:00', close: '22:00' } } });
    await clock.advance(2000);
    assert.strictEqual(core.view.screen, 'closed_hours');
    assert.deepStrictEqual(core.view.lines, ['目前非營業時間', '營業時間 08:00–22:00']);
    assert.strictEqual(core.view.qr, null);

    server.state = idleState({ screen: 'maintenance', qr: null, message: { code: 'MAINTENANCE', params: {} } });
    await clock.advance(2000);
    assert.deepStrictEqual(core.view.lines, ['書櫃維修中，暫停服務']);

    server.state = resultState({ code: 'RESULT_REVIEW', outcome: 'needs_review' });
    await clock.advance(2000);
    assert.strictEqual(core.view.screen, 'result');
    assert.strictEqual(core.view.icon, 'alert');
    assert.deepStrictEqual(core.view.lines, ['本次作業待客服確認']);
    core.stop();
  }],

  ['未配對時以書櫃螢幕的 10 鍵鍵盤配對，成功後直接輪詢 state', async () => {
    const { api: server, clock, core, storage } = await started({ paired: false });
    assert.strictEqual(core.view.screen, 'pairing');
    assert.strictEqual(server.requests.length, 0);
    const pairKey = () => core.view.buttons.find((b) => b.id === 'key:pair');
    assert.strictEqual(pairKey().enabled, false);
    assert.deepStrictEqual(pairKey().rect, [162, 266, 72, 44]);

    for (const d of '1234567') assert.strictEqual(core.tap(`key:${d}`), true);
    assert.strictEqual(pairKey().enabled, false);
    core.tap('key:9');
    core.tap('key:del');
    core.tap('key:8');
    assert.strictEqual(core.view.pairing.digits, '12345678');
    assert.strictEqual(core.tap('key:0'), false, '滿 8 碼後不再接受輸入');
    assert.strictEqual(pairKey().enabled, true);

    core.tap('key:pair');
    await clock.advance(0);
    const pair = server.requests[0];
    assert.strictEqual(pair.path, '/api/device/v1/pair');
    assert.strictEqual(pair.headers.authorization, undefined);
    assert.match(pair.headers['x-device-boot'], BOOT_RE);
    assert.deepStrictEqual(pair.body, {
      code: '1234-5678', kind: 'simulator', door_count: 4, has_door_sensor: false, unlock_pulse_ms: 800, firmware: 'sim-1.0.0'
    });
    assert.strictEqual(storage.get(STORAGE_KEYS.token), TOKEN);
    assert.strictEqual(storage.get(STORAGE_KEYS.no), 'DVKIOSK01');
    assert.strictEqual(storage.get(STORAGE_KEYS.cabinet), '測試書櫃');

    const next = server.requests[1];
    assert.strictEqual(`${next.method} ${next.path}`, 'GET /api/device/v1/state');
    assert.strictEqual(next.headers['x-device-boot'], pair.headers['x-device-boot']);
    assert.strictEqual(next.headers.authorization, `Device ${TOKEN}`);
    assert.strictEqual(core.view.screen, 'idle');
    assert.strictEqual(core.view.deviceNo, 'DVKIOSK01');
    assert.strictEqual(core.view.cabinetName, '測試書櫃');
    core.stop();
  }],

  ['配對碼錯誤時顯示配對失敗並清除輸入；pair() 接受含連字號的碼，格式不符時不送出請求', async () => {
    const { api: server, clock, core } = await started({ paired: false });
    for (const d of '87654321') core.tap(`key:${d}`);
    core.tap('key:pair');
    await clock.advance(0);
    assert.strictEqual(server.requests.length, 1);
    assert.strictEqual(core.view.screen, 'pairing');
    assert.strictEqual(core.view.pairing.error, 'PAIRING_FAILED');
    assert.strictEqual(core.view.pairing.digits, '');

    const invalid = await core.pair('1234-56');
    assert.deepStrictEqual(invalid, { ok: false, status: 0, code: 'PAIRING_CODE_INVALID' });
    assert.strictEqual(server.requests.length, 1);

    const ok = await core.pair(' 1234-5678 ');
    assert.strictEqual(ok.ok, true);
    assert.strictEqual(ok.deviceNo, 'DVKIOSK01');
    assert.strictEqual(server.requests[1].body.code, '1234-5678');
    core.stop();
  }],

  ['比對畫面：9 個數字排成 3×3，點選後送出 match_selected 並顯示處理中直到伺服器回應', async () => {
    const { api: server, clock, core } = await started();
    server.state = matchState();
    await clock.advance(2000);
    assert.strictEqual(core.view.screen, 'match');
    assert.deepStrictEqual(core.view.lines, [MESSAGES.MATCH_PROMPT]);
    const numbers = core.view.buttons.filter((b) => b.id.startsWith('match:'));
    assert.deepStrictEqual(numbers.map((b) => b.label), CHOICES.map(String));
    assert.deepStrictEqual(numbers.map((b) => b.rect), LAYOUT.MATCH.KEYS);
    assert.deepStrictEqual(core.view.buttons.at(-1), { id: 'abort', label: '取消', primary: false, enabled: true, rect: LAYOUT.MATCH.ABORT });
    assert.strictEqual(core.view.countdown.totalMs, 60000);

    core.setLatency(500);
    const from = server.requests.length;
    assert.strictEqual(core.tap('match:37'), true);
    assert.strictEqual(core.view.screen, 'processing');
    assert.strictEqual(core.tap('match:12'), false, '只能點選一次');
    server.onEvents = () => { server.state = resultState({ code: 'RESULT_MATCH_FAILED', outcome: 'failed' }); };
    await clock.advance(0);
    assert.strictEqual(core.view.screen, 'processing');
    const [selected] = eventsAfter(server, from);
    assert.strictEqual(selected.type, 'match_selected');
    assert.strictEqual(selected.session_id, 'CSKIOSK01');
    assert.deepStrictEqual(selected.data, { value: 37 });

    await clock.advance(500);
    assert.strictEqual(core.view.screen, 'result');
    assert.deepStrictEqual(core.view.lines, ['數字不符，本次作業已取消']);
    assert.strictEqual(server.eventsOf('match_selected').length, 1);
    core.stop();
  }],

  ['確認項目與比對畫面的「取消」送出 session_cancel', async () => {
    const { api: server, clock, core } = await started();
    server.state = selectState('CSSELECT1', { poll_ms: 5000 });
    await clock.advance(2000);
    assert.strictEqual(core.view.screen, 'select');
    assert.deepStrictEqual(core.view.lines, ['書櫃使用中', '請於手機確認項目', '剩餘 60 秒']);
    assert.deepStrictEqual(core.view.buttons.map((b) => [b.id, b.rect]), [['abort', LAYOUT.SELECT.ABORT]]);
    await clock.advance(900);
    assert.strictEqual(core.view.lines[2], '剩餘 60 秒');
    await clock.advance(100);
    assert.strictEqual(core.view.lines[2], '剩餘 59 秒');

    core.tap('abort');
    await clock.advance(0);
    const [cancel] = server.eventsOf('session_cancel');
    assert.strictEqual(cancel.session_id, 'CSSELECT1');

    server.state = matchState('CSMATCH01');
    await clock.advance(5000);
    assert.strictEqual(core.view.screen, 'match');
    core.tap('abort');
    await clock.advance(0);
    assert.deepStrictEqual(server.eventsOf('session_cancel').map((e) => e.session_id), ['CSSELECT1', 'CSMATCH01']);
    core.stop();
  }],

  ['開鎖：通電前寫入開門中紀錄，多扇門依「斷電後 300 毫秒」逐扇開啟並各回報 door_opened', async () => {
    const device = await started();
    const { api: server, clock, core, storage, views } = device;
    const recordAtFirstPower = [];
    const origin = core.onView;
    core.onView = (view) => {
      if (view.doors.some((d) => d.unlocking) && !recordAtFirstPower.length) recordAtFirstPower.push(storage.json(STORAGE_KEYS.openSession));
      origin(view);
    };

    server.state = matchState();
    await clock.advance(2000);
    server.onEvents = (events) => {
      if (events.some((e) => e.type === 'match_selected')) server.state = openingState({ channels: [2, 3], openMs: 45000 });
    };
    core.tap('match:37');
    const tapAt = clock.now();
    await clock.advance(3000);

    assert.deepStrictEqual(recordAtFirstPower[0], {
      session_id: 'CSKIOSK01', command_ids: ['CSKIOSK01:2:1', 'CSKIOSK01:3:1'], action: 'pickup', open_ms: 45000
    });
    const timeline = unlockTimeline(views).map(({ at, channel, on }) => [at - tapAt, channel, on]);
    assert.deepStrictEqual(timeline, [[0, 2, true], [800, 2, false], [1100, 3, true], [1900, 3, false]]);

    const opened = server.eventsOf('door_opened');
    assert.deepStrictEqual(opened.map((e) => [e.session_id, e.channel, e.data.command_id]), [
      ['CSKIOSK01', 2, 'CSKIOSK01:2:1'], ['CSKIOSK01', 3, 'CSKIOSK01:3:1']
    ]);
    assert.strictEqual(core.view.screen, 'open');
    assert.deepStrictEqual(core.view.lines, ['A02　A03', '請取出 A02、A03 內的書籍後關上櫃門']);
    assert.strictEqual(core.view.countdown.totalMs, 45000);
    assert.deepStrictEqual(core.view.buttons.map((b) => [b.id, b.label, b.enabled, b.rect]), [
      ['done', '完成並關門', true, LAYOUT.OPEN.DONE],
      ['cancel_close', '取消並關門', true, LAYOUT.OPEN.CANCEL]
    ]);
    assert.deepStrictEqual(core.view.doors.filter((d) => d.open).map((d) => d.channel), [2, 3]);
    core.stop();
  }],

  ['開鎖期間收到新的指令時排在目前的櫃門之後，任何時刻只有一個電磁鎖通電', async () => {
    const device = await started();
    const { api: server, clock, core, views } = device;
    server.state = openingState({ channels: [2], releaseMs: 2500 });
    await clock.advance(2000);
    const firstOn = unlockTimeline(views).find((t) => t.on && t.channel === 2).at;
    server.state = openingState({ channels: [2, 3], releaseMs: 2500 });
    await clock.advance(1000);
    assert.strictEqual(core.view.doors[1].unlocking, true, '新指令於 A02 通電期間送達');
    await clock.advance(8000);
    const timeline = unlockTimeline(views).map(({ at, channel, on }) => [at - firstOn, channel, on]);
    assert.deepStrictEqual(timeline, [[0, 2, true], [2500, 2, false], [2800, 3, true], [5300, 3, false]]);
    for (const { view } of views) assert.ok(view.doors.filter((d) => d.unlocking).length <= 1);
    assert.deepStrictEqual(server.eventsOf('door_opened').map((e) => e.channel), [2, 3]);
    core.stop();
  }],

  ['同一個開鎖指令只執行一次', async () => {
    const device = await started();
    const { api: server, clock, core } = device;
    await openDoors(device, { channels: [2] });
    server.state = openingState({ channels: [2] });
    await clock.advance(5000);
    assert.strictEqual(server.eventsOf('door_opened').length, 1);
    assert.strictEqual(unlockTimeline(device.views).filter((t) => t.on).length, 1);
    core.stop();
  }],

  ['往返超過 3 秒或 expires_in_ms 不大於 0 時不執行開鎖，也不寫入開門中紀錄', async () => {
    const { api: server, clock, core, storage, views } = await started();
    assert.strictEqual(TIMING.ROUNDTRIP_MAX_MS, 3000);
    core.setLatency(3500);
    server.state = openingState();
    await clock.advance(10000);
    assert.strictEqual(server.eventsOf('door_opened').length, 0);
    assert.strictEqual(storage.get(STORAGE_KEYS.openSession), null);
    assert.ok(views.every(({ view }) => view.doors.every((d) => !d.unlocking)));
    assert.strictEqual(core.view.screen, 'opening');

    core.setLatency(0);
    server.state = openingState({ id: 'CSEXPIRED', expiresInMs: 0 });
    await clock.advance(3000);
    assert.strictEqual(server.eventsOf('door_opened').length, 0);

    core.setLatency(2900);
    server.state = openingState({ id: 'CSINTIME1' });
    await clock.advance(6000);
    assert.deepStrictEqual(server.eventsOf('door_opened').map((e) => e.session_id), ['CSINTIME1']);
    core.stop();
  }],

  ['倒數歸零時自動關門並回報完成，結果畫面後回到閒置', async () => {
    const device = await started();
    const { api: server, clock, core, storage } = device;
    await openDoors(device, { channels: [2, 3] });
    const from = server.requests.length;
    await clock.advance(28000);
    assert.strictEqual(core.view.screen, 'open');
    assert.ok(core.view.countdown.remainingMs <= 1000, '倒數自第一扇門開啟時起算');
    assert.deepStrictEqual(eventsAfter(server, from), []);

    server.onEvents = (events) => {
      if (events.some((e) => e.type === 'session_closed')) server.state = resultState();
    };
    await clock.advance(1000);
    const sent = eventsAfter(server, from);
    assert.deepStrictEqual(sent.map((e) => [e.type, e.channel ?? null, e.data]), [
      ['door_closed', 2, { reason: 'timeout' }],
      ['door_closed', 3, { reason: 'timeout' }],
      ['session_closed', null, { outcome: 'completed', reason: 'timeout' }]
    ]);
    assert.ok(sent.every((e) => e.session_id === 'CSKIOSK01'));
    assert.strictEqual(storage.get(STORAGE_KEYS.openSession), null);
    assert.strictEqual(core.view.screen, 'result');
    assert.strictEqual(core.view.icon, 'check');
    assert.deepStrictEqual(core.view.lines, ['作業完成']);
    assert.ok(core.view.doors.every((d) => d.locked && !d.open));

    server.state = idleState();
    await clock.advance(4000);
    assert.strictEqual(core.view.screen, 'idle');
    core.stop();
  }],

  ['關門回報後未收到結果時顯示處理中，4 秒後改依伺服器畫面', async () => {
    const device = await started();
    const { api: server, clock, core } = device;
    await openDoors(device);
    server.state = idleState();
    core.tap('done');
    assert.strictEqual(core.view.screen, 'processing');
    await clock.advance(3900);
    assert.strictEqual(core.view.screen, 'processing');
    await clock.advance(200);
    assert.strictEqual(core.view.screen, 'idle');
    core.stop();
  }],

  ['關閉自動關門時倒數結束不回報，按「完成並關門」送出 button', async () => {
    const device = await started({ options: { autoCloseOnTimeout: false } });
    const { api: server, clock, core } = device;
    await openDoors(device, { channels: [2] });
    const from = server.requests.length;
    await clock.advance(31000);
    assert.deepStrictEqual(eventsAfter(server, from), []);
    assert.strictEqual(core.view.screen, 'open');
    assert.strictEqual(core.view.countdown.remainingMs, 0);
    assert.ok(core.view.buttons.every((b) => b.enabled));

    core.tap('done');
    await clock.advance(0);
    assert.deepStrictEqual(eventsAfter(server, from).map((e) => [e.type, e.data]), [
      ['door_closed', { reason: 'button' }],
      ['session_closed', { outcome: 'completed', reason: 'button' }]
    ]);
    core.stop();
  }],

  ['「取消並關門」只送出 session_closed(cancelled)', async () => {
    const device = await started();
    const { api: server, clock, core } = device;
    await openDoors(device, { channels: [1, 4] });
    const from = server.requests.length;
    core.tap('cancel_close');
    await clock.advance(0);
    assert.deepStrictEqual(eventsAfter(server, from).map((e) => [e.type, e.session_id, e.data]), [
      ['session_closed', 'CSKIOSK01', { outcome: 'cancelled', reason: 'cancel_button' }]
    ]);
    core.stop();
  }],

  ['管理員作業顯示「管理人員作業中」且只有「完成並關門」', async () => {
    const device = await started();
    const { core } = device;
    await openDoors(device, { channels: [3], action: 'admin', openMs: 120000 });
    assert.strictEqual(core.view.screen, 'admin');
    assert.deepStrictEqual(core.view.lines, ['A03', '管理人員作業中']);
    assert.deepStrictEqual(core.view.buttons.map((b) => b.id), ['done']);
    assert.strictEqual(core.view.countdown.totalMs, 120000);
    core.stop();
  }],

  ['本機開門模式只依本機狀態繪製，不採用伺服器畫面', async () => {
    const device = await started();
    const { api: server, clock, core } = device;
    await openDoors(device);
    server.state = resultState({ code: 'RESULT_REVIEW', outcome: 'needs_review' });
    await clock.advance(3000);
    assert.strictEqual(core.view.screen, 'open');
    server.state = idleState();
    await clock.advance(3000);
    assert.strictEqual(core.view.screen, 'open');
    assert.ok(core.view.countdown.remainingMs <= 24000);
    assert.strictEqual(core.tap('done'), true);
    core.stop();
  }],

  ['門磁模式：倒數結束時門仍開著送出 DOOR_LEFT_OPEN，關上後送出 fault_cleared', async () => {
    const device = await started({ options: { hasDoorSensor: true } });
    const { api: server, clock, core } = device;
    assert.strictEqual(server.eventsOf('boot')[0].data.has_door_sensor, true);
    await openDoors(device, { channels: [2] });
    const from = server.requests.length;
    await clock.advance(30000);
    assert.deepStrictEqual(eventsAfter(server, from).map((e) => [e.type, e.channel ?? null, e.session_id ?? null, e.data]), [
      ['fault', 2, null, { code: 'DOOR_LEFT_OPEN' }],
      ['session_closed', null, 'CSKIOSK01', { outcome: 'completed', reason: 'timeout' }]
    ]);
    assert.strictEqual(core.view.doors[1].fault, 'DOOR_LEFT_OPEN');
    assert.strictEqual(core.view.doors[1].open, true);

    const mid = server.requests.length;
    assert.strictEqual(core.setDoorPhysical(2, 'closed'), true);
    await clock.advance(0);
    assert.deepStrictEqual(eventsAfter(server, mid).map((e) => [e.type, e.channel, e.data]), [['fault_cleared', 2, { code: 'DOOR_LEFT_OPEN' }]]);
    assert.strictEqual(core.view.doors[1].fault, null);
    core.stop();
  }],

  ['門磁模式：門未關時按完成顯示「請先關上櫃門」，全部關上即回報完成', async () => {
    const device = await started({ options: { hasDoorSensor: true } });
    const { api: server, clock, core } = device;
    await openDoors(device, { channels: [2, 3] });
    const from = server.requests.length;
    core.tap('done');
    assert.strictEqual(core.view.notice, '請先關上櫃門');
    await clock.advance(0);
    assert.deepStrictEqual(eventsAfter(server, from), []);

    core.setDoorPhysical(2, 'closed');
    await clock.advance(0);
    assert.strictEqual(core.view.screen, 'open');
    core.setDoorPhysical(3, 'closed');
    await clock.advance(0);
    assert.deepStrictEqual(eventsAfter(server, from).map((e) => [e.type, e.channel ?? null, e.data]), [
      ['door_closed', 2, { reason: 'sensor' }],
      ['door_closed', 3, { reason: 'sensor' }],
      ['session_closed', null, { outcome: 'completed', reason: 'sensor' }]
    ]);
    await clock.advance(3000);
    assert.strictEqual(core.view.notice, null);
    core.stop();
  }],

  ['門磁模式：未收到指令時門被開啟送出 door_forced；切換門磁設定時送出 boot 事件', async () => {
    const { api: server, clock, core } = await started();
    assert.strictEqual(core.setDoorPhysical(1, 'open'), false, '沒有門磁時不接受實體門操作');
    const bootHeader = server.requests[0].headers['x-device-boot'];
    core.setOptions({ hasDoorSensor: true });
    await clock.advance(0);
    const configBoot = server.eventsOf('boot').at(-1);
    assert.strictEqual(configBoot.data.has_door_sensor, true);
    assert.strictEqual(configBoot.data.reset_reason, 'config');
    assert.strictEqual(configBoot.data.boot_id, bootHeader);

    core.setDoorPhysical(1, 'open');
    await clock.advance(0);
    assert.deepStrictEqual(server.eventsOf('door_forced').map((e) => e.channel), [1]);

    core.setDoorPhysical(1, 'closed');
    await clock.advance(0);
    const [closed] = server.eventsOf('door_closed');
    assert.deepStrictEqual([closed.channel, closed.session_id, closed.data], [1, undefined, { reason: 'sensor' }],
      '不屬於開門中作業的門關上時，仍回報門磁狀態');
    core.stop();
  }],

  ['櫃門故障：送出 LOCK_NO_RELEASE，開鎖時回報故障而不送 door_opened，解除時送出 fault_cleared', async () => {
    const device = await started();
    const { api: server, clock, core } = device;
    core.injectFault(2, 'LOCK_NO_RELEASE');
    await clock.advance(0);
    const [fault] = server.eventsOf('fault');
    assert.deepStrictEqual([fault.channel, fault.session_id, fault.data], [2, undefined, { code: 'LOCK_NO_RELEASE' }]);
    assert.strictEqual(core.view.doors[1].fault, 'LOCK_NO_RELEASE');

    await openDoors(device, { channels: [2, 3] });
    const sessionFault = server.eventsOf('fault').find((e) => e.session_id === 'CSKIOSK01');
    assert.deepStrictEqual([sessionFault.channel, sessionFault.data], [2, { code: 'LOCK_NO_RELEASE' }]);
    assert.deepStrictEqual(server.eventsOf('door_opened').map((e) => e.channel), [3]);
    assert.deepStrictEqual(core.view.lines[0], 'A03');

    core.tap('done');
    core.clearFault(2, 'LOCK_NO_RELEASE');
    await clock.advance(0);
    const cleared = server.eventsOf('fault_cleared');
    assert.deepStrictEqual(cleared.map((e) => [e.channel, e.data]), [[2, { code: 'LOCK_NO_RELEASE' }]]);
    assert.deepStrictEqual(server.eventsOf('door_closed').map((e) => e.channel), [3]);
    core.stop();
  }],

  ['所有櫃門都未能開啟時結束開門流程並清除開門中紀錄', async () => {
    const device = await started();
    const { api: server, clock, core, storage } = device;
    core.injectFault(1);
    await clock.advance(0);
    await openDoors(device, { channels: [1] });
    assert.strictEqual(server.eventsOf('door_opened').length, 0);
    assert.strictEqual(storage.get(STORAGE_KEYS.openSession), null);
    await clock.advance(1000);
    assert.notStrictEqual(core.view.screen, 'open');
    core.stop();
  }],

  ['連續 3 次網路失敗後顯示離線畫面，並以 2、4、8、15 秒退避重試', async () => {
    const { api: server, clock, core } = await started();
    const from = server.requests.length;
    server.failures = 5;
    await clock.advance(2000);
    assert.strictEqual(core.view.screen, 'idle');
    await clock.advance(2000);
    assert.strictEqual(core.view.screen, 'idle');
    await clock.advance(4000);
    assert.strictEqual(core.view.screen, 'offline');
    assert.deepStrictEqual(core.view.lines, ['連線中斷，重新連線中']);
    assert.strictEqual(core.view.connection, 'offline');
    await clock.advance(8000 + 15000 + 15000);
    const times = server.requests.slice(from).map((r) => r.at);
    assert.deepStrictEqual(times.slice(1).map((t, i) => t - times[i]), [2000, 4000, 8000, 15000, 15000]);
    assert.strictEqual(core.view.screen, 'idle');
    assert.strictEqual(core.view.connection, 'online');
    core.stop();
  }],

  ['離線時事件存入佇列，恢復連線後以原 id 補送；門開啟中不切換為離線畫面', async () => {
    const device = await started();
    const { api: server, clock, core, storage } = device;
    await openDoors(device, { channels: [2] });
    core.setOffline(true);
    await clock.advance(20000);
    assert.strictEqual(core.view.screen, 'open');
    core.tap('done');
    await clock.advance(20000);
    const queued = storage.json(STORAGE_KEYS.queue);
    assert.deepStrictEqual(queued.map((e) => e.type), ['door_closed', 'session_closed']);
    assert.strictEqual(core.view.screen, 'offline');

    const from = server.requests.length;
    core.setOffline(false);
    await clock.advance(0);
    const [sent] = server.requests.slice(from);
    assert.deepStrictEqual(sent.body.events.map((e) => e.id), queued.map((e) => e.id));
    assert.ok(sent.body.events.every((e) => e.age_ms >= 20000), '以本機時鐘計算事件經過時間');
    assert.deepStrictEqual(storage.json(STORAGE_KEYS.queue), []);
    core.stop();
  }],

  ['伺服器回 retry 時保留事件，下次以原 id 重送', async () => {
    const { api: server, clock, core, storage } = await started();
    let attempts = 0;
    server.resultFor = (event) => {
      if (event.type !== 'fault') return { status: 'ok' };
      attempts += 1;
      return attempts === 1 ? { status: 'retry' } : { status: 'duplicate' };
    };
    core.injectFault(4);
    await clock.advance(0);
    assert.strictEqual(storage.json(STORAGE_KEYS.queue).length, 1);
    await clock.advance(2000);
    const faults = server.eventsOf('fault');
    assert.strictEqual(faults.length, 2);
    assert.strictEqual(faults[0].id, faults[1].id);
    assert.deepStrictEqual(storage.json(STORAGE_KEYS.queue), []);
    core.stop();
  }],

  ['事件序號跨重新開機持續遞增，前一次開機留下的事件送 age_ms: null', async () => {
    const storage = memoryStorage();
    const clock = new FakeClock();
    const device = makeDevice({ storage, clock });
    const { api: server, core } = device;
    core.start();
    await clock.advance(0);
    const boot1 = server.requests[0].headers['x-device-boot'];
    core.setOffline(true);
    core.injectFault(3);
    await clock.advance(100);

    core.reboot();
    const from = server.requests.length;
    core.setOffline(false);
    await clock.advance(0);
    const [first] = server.requests.slice(from);
    const boot2 = first.headers['x-device-boot'];
    assert.notStrictEqual(boot2, boot1);
    assert.deepStrictEqual(first.body.events.map((e) => [e.type, e.id]), [
      ['boot', `${boot2}-000003`],
      ['fault', `${boot1}-000002`]
    ]);
    assert.strictEqual(first.body.events[0].data.reset_reason, 'software');
    assert.strictEqual(first.body.events[1].age_ms, null);
    core.stop();

    const reloaded = makeDevice({ storage, clock, options: { seed: 99 } });
    reloaded.core.start();
    await clock.advance(0);
    const header = reloaded.api.requests[0].headers['x-device-boot'];
    assert.strictEqual(reloaded.api.requests[0].body.events[0].id, `${header}-000004`);
    reloaded.core.stop();
  }],

  ['門開啟中重新開機或重新整理頁面時，開機事件後回報 interrupted', async () => {
    const device = await started();
    const { api: server, clock, core, storage } = device;
    await openDoors(device, { channels: [2] });
    assert.ok(storage.json(STORAGE_KEYS.openSession));

    core.reboot();
    const from = server.requests.length;
    await clock.advance(0);
    assert.deepStrictEqual(server.requests[from].body.events.map((e) => [e.type, e.session_id ?? null, e.data.outcome ?? null]), [
      ['boot', null, null],
      ['session_closed', 'CSKIOSK01', 'interrupted']
    ]);
    assert.strictEqual(server.requests[from].body.events[1].data.reason, 'reboot');
    assert.strictEqual(storage.get(STORAGE_KEYS.openSession), null);
    assert.ok(core.view.doors.every((d) => d.locked && !d.open));
    core.stop();

    const reload = makeDevice({ clock, storage: memoryStorage({ [STORAGE_KEYS.openSession]: JSON.stringify({ session_id: 'CSRELOAD1', command_ids: ['CSRELOAD1:1:1'] }) }) });
    reload.core.start();
    await clock.advance(0);
    assert.deepStrictEqual(reload.api.requests[0].body.events.map((e) => [e.type, e.session_id ?? null]), [
      ['boot', null], ['session_closed', 'CSRELOAD1']
    ]);
    reload.core.stop();
  }],

  ['任何請求回 401 時清除本機資料並回到配對畫面', async () => {
    const { api: server, clock, core, storage } = await started();
    storage.set(STORAGE_KEYS.openSession, JSON.stringify({ session_id: 'CSOLD0001', command_ids: [] }));
    server.revoked = true;
    await clock.advance(2000);
    assert.strictEqual(core.view.screen, 'pairing');
    for (const key of Object.values(STORAGE_KEYS)) assert.strictEqual(storage.get(key), null, key);
    const count = server.requests.length;
    await clock.advance(10000);
    assert.strictEqual(server.requests.length, count);
    core.stop();
  }],

  ['解除配對呼叫 /unpair 並清除本機資料', async () => {
    const { api: server, core, storage } = await started();
    const result = await core.unpair();
    assert.deepStrictEqual(result, { ok: true, status: 200 });
    assert.strictEqual(server.requests.at(-1).path, '/api/device/v1/unpair');
    assert.strictEqual(server.requests.at(-1).headers.authorization, `Device ${TOKEN}`);
    assert.strictEqual(storage.get(STORAGE_KEYS.token), null);
    assert.strictEqual(core.view.screen, 'pairing');
    core.stop();
  }],

  ['系統維護、模擬器停用與 409 DEVICE_STALE_BOOT 的處理', async () => {
    const { api: server, clock, core, storage } = await started();
    server.respondOnce((r) => r.method === 'GET', () => h.json(503, { success: false, code: 'MAINTENANCE', message: '系統維護中，請稍後再試' }));
    await clock.advance(2000);
    assert.strictEqual(core.view.screen, 'system_maintenance');
    assert.deepStrictEqual(core.view.lines, ['系統維護中，請稍後再試']);
    await clock.advance(5000);
    assert.strictEqual(core.view.screen, 'idle');

    server.respondOnce((r) => r.method === 'GET', () => h.json(403, { success: false, code: 'DEVICE_DISABLED', message: '模擬書櫃目前未開放' }));
    await clock.advance(2000);
    assert.strictEqual(core.view.screen, 'device_disabled');
    assert.ok(storage.get(STORAGE_KEYS.token), '停用時保留憑證');

    await clock.advance(15000);
    server.respondOnce((r) => r.path.endsWith('/events'), () => h.json(409, { success: false, code: 'DEVICE_STALE_BOOT', message: '此請求來自裝置重新啟動前，已略過' }));
    core.injectFault(1);
    await clock.advance(0);
    assert.strictEqual(storage.json(STORAGE_KEYS.queue).length, 1, '被略過的請求不移除事件');
    await clock.advance(2000);
    assert.deepStrictEqual(storage.json(STORAGE_KEYS.queue), []);
    core.stop();
  }],

  ['LAYOUT：鍵盤與按鈕矩形落在 240×320 內且互不重疊', () => {
    const inside = ([x, y, w, h]) => x >= 0 && y >= LAYOUT.HEADER_HEIGHT && x + w <= LAYOUT.WIDTH && y + h <= LAYOUT.HEIGHT;
    const overlap = (a, b) => a[0] < b[0] + b[2] && b[0] < a[0] + a[2] && a[1] < b[1] + b[3] && b[1] < a[1] + a[3];
    const groups = {
      pairing: LAYOUT.PAIRING.KEYS.map((k) => k.rect).concat(LAYOUT.PAIRING.SLOTS),
      match: LAYOUT.MATCH.KEYS.concat([LAYOUT.MATCH.ABORT]),
      open: [LAYOUT.OPEN.DONE, LAYOUT.OPEN.CANCEL]
    };
    for (const [name, rects] of Object.entries(groups)) {
      for (const r of rects) assert.ok(inside(r), `${name} ${r}`);
      rects.forEach((a, i) => rects.slice(i + 1).forEach((b) => assert.ok(!overlap(a, b), `${name} ${a} / ${b}`)));
    }
    assert.deepStrictEqual(LAYOUT.MATCH.KEYS.map(([x, y]) => [x, y]), [
      [6, 70], [84, 70], [162, 70], [6, 134], [84, 134], [162, 134], [6, 198], [84, 198], [162, 198]
    ]);
    assert.deepStrictEqual(LAYOUT.PAIRING.KEYS.map((k) => k.id), [
      'key:1', 'key:2', 'key:3', 'key:4', 'key:5', 'key:6', 'key:7', 'key:8', 'key:9', 'key:del', 'key:0', 'key:pair'
    ]);
    const s = LAYOUT.PAIRING.SLOTS;
    assert.strictEqual(s[4][0] - (s[3][0] + s[3][2]), 12, '第 4、5 格之間留 12px');
    assert.deepStrictEqual(TIMING, { ROUNDTRIP_MAX_MS: 3000, LOCK_GAP_MS: 300 });
  }],

  ['字串表涵蓋伺服器訊息代碼與裝置本機字串', () => {
    const required = [
      'IDLE_SCAN', 'CLOSED_HOURS', 'MAINTENANCE', 'DISABLED', 'SELECT_ON_PHONE', 'MATCH_PROMPT', 'OPENING', 'OPEN_PICKUP',
      'OPEN_DEPOSIT', 'OPEN_RETRIEVE', 'OPEN_MIXED', 'OPEN_ADMIN', 'RESULT_DONE', 'RESULT_PARTIAL', 'RESULT_CANCELLED',
      'RESULT_MATCH_FAILED', 'RESULT_TIMEOUT', 'RESULT_DEVICE_ERROR', 'RESULT_REVIEW', 'TITLE', 'PAIRING_PROMPT',
      'PAIRING_FAILED', 'BTN_DELETE', 'BTN_PAIR', 'OFFLINE', 'SYSTEM_MAINTENANCE', 'DEVICE_DISABLED', 'BOOTING', 'PROCESSING',
      'CLOSE_DOOR_FIRST', 'BTN_DONE', 'BTN_CANCEL_CLOSE', 'BTN_ABORT'
    ];
    for (const code of required) assert.ok(MESSAGES[code], code);
    assert.strictEqual(MESSAGES.TITLE, '智慧書櫃');
    assert.strictEqual(MESSAGES.OPEN_DEPOSIT, '請將書籍放入 {doors} 後關上櫃門');
  }],

  ['內嵌 QR 產生器：書櫃 QR 為版本 4（33 格）、錯誤修正等級 M，含三個定位圖形', () => {
    const { version, size, modules } = QR.encode(QR_PAYLOAD);
    assert.strictEqual(version, 4);
    assert.strictEqual(size, 33);
    const finderAt = (r0, c0) => {
      for (let r = 0; r < 7; r++) {
        for (let c = 0; c < 7; c++) {
          const ring = r === 0 || r === 6 || c === 0 || c === 6;
          const core = r >= 2 && r <= 4 && c >= 2 && c <= 4;
          assert.strictEqual(modules[r0 + r][c0 + c], ring || core, `finder ${r0},${c0} @ ${r},${c}`);
        }
      }
    };
    finderAt(0, 0);
    finderAt(0, size - 7);
    finderAt(size - 7, 0);
    for (let i = 8; i < size - 8; i++) assert.strictEqual(modules[6][i], i % 2 === 0, 'timing pattern');

    // 格式資訊（左上角直向 15 位元）解除遮罩後，前兩位為錯誤修正等級：M = 00
    let bits = 0;
    for (let v = 0; v < 15; v++) {
      const row = v < 6 ? v : v < 8 ? v + 1 : size - 15 + v;
      if (modules[row][8]) bits |= 1 << v;
    }
    const unmasked = bits ^ 0b101010000010010;
    assert.strictEqual(unmasked >> 13, 0b00);
    assert.deepStrictEqual(QR.encode(QR_PAYLOAD).modules, modules, '相同內容產生相同圖形');
    assert.notDeepStrictEqual(QR.encode(`savemybook://k/${'0'.repeat(32)}`).modules, modules);
  }],

  ['瀏覽器與 Node 共用同一份程式：UMD 匯出與介面方法', () => {
    const src = require('fs').readFileSync(require('path').join(h.API_ROOT, 'views/kiosk/device-core.js'), 'utf8');
    assert.match(src, /root\.SmbDeviceCore = factory\(\)/);
    const core = new DeviceCore({ fetch: async () => { throw new Error('unused'); }, storage: memoryStorage(), clock: new FakeClock() });
    for (const method of ['start', 'stop', 'pair', 'tap', 'setOffline', 'setLatency', 'reboot', 'setDoorPhysical', 'injectFault', 'clearFault', 'setOptions', 'unpair']) {
      assert.strictEqual(typeof core[method], 'function', method);
    }
    const view = core.view;
    for (const key of ['screen', 'header', 'lines', 'qr', 'pairing', 'countdown', 'buttons', 'doors', 'connection', 'deviceNo', 'cabinetName']) {
      assert.ok(key in view, key);
    }
    assert.deepStrictEqual(Object.keys(view.doors[0]).filter((k) => ['channel', 'label', 'locked', 'open', 'fault'].includes(k)).sort(),
      ['channel', 'fault', 'label', 'locked', 'open']);
  }]
];

module.exports = { name: 'device-core（假時鐘與假 fetch）', tests };
