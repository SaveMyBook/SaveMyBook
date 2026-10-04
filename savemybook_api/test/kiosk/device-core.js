const assert = require('assert');
const h = require('./harness');

const {
  api, STORAGE_KEYS, TOKEN, POLL_TOKEN, QR_PAYLOAD, FakeClock, memoryStorage,
  idleState, selectState, matchState, openingState, openState, closeCommand, resultState, makeDevice, openDoors
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

  ['未配對時申請配對碼並顯示於螢幕，管理員綁定後以輪詢取得憑證並直接輪詢 state', async () => {
    const { api: server, clock, core, storage, logs } = await started({ paired: false });
    const [request] = server.requests;
    assert.strictEqual(`${request.method} ${request.path}`, 'POST /api/device/v1/pair/request');
    assert.strictEqual(request.headers.authorization, undefined);
    assert.match(request.headers['x-device-boot'], BOOT_RE);
    assert.deepStrictEqual(request.body, { kind: 'simulator', door_count: 4, has_door_sensor: false, unlock_pulse_ms: 800, firmware: 'sim-1.0.0' });
    assert.strictEqual(core.view.screen, 'pairing');
    assert.deepStrictEqual(core.view.lines, ['配對碼', '1234-5678', '請於管理後台輸入此配對碼', '剩餘時間 10:00']);
    assert.strictEqual(core.view.pairing.code, '1234-5678');
    assert.strictEqual(core.view.connection, 'online');

    await clock.advance(3000);
    const poll = server.requests[1];
    assert.strictEqual(`${poll.method} ${poll.path}`, 'POST /api/device/v1/pair/poll');
    assert.deepStrictEqual(poll.body, { poll_token: `${POLL_TOKEN}1` });
    assert.strictEqual(poll.headers.authorization, undefined);
    assert.strictEqual(poll.headers['x-device-boot'], request.headers['x-device-boot']);
    assert.strictEqual(core.view.lines[3], '剩餘時間 9:57');
    assert.strictEqual(storage.get(STORAGE_KEYS.token), null);

    server.bindPairing();
    await clock.advance(3000);
    assert.deepStrictEqual(server.pairPaths(), ['pair/request', 'pair/poll', 'pair/poll']);
    assert.strictEqual(storage.get(STORAGE_KEYS.token), TOKEN);
    assert.strictEqual(storage.get(STORAGE_KEYS.no), 'DVKIOSK01');
    assert.strictEqual(storage.get(STORAGE_KEYS.cabinet), '測試書櫃');
    const next = server.requests[3];
    assert.strictEqual(`${next.method} ${next.path}`, 'GET /api/device/v1/state');
    assert.strictEqual(next.headers['x-device-boot'], request.headers['x-device-boot'], '沿用申請配對碼時的開機代碼');
    assert.strictEqual(next.headers.authorization, `Device ${TOKEN}`);
    assert.strictEqual(core.view.screen, 'idle');
    assert.strictEqual(core.view.deviceNo, 'DVKIOSK01');
    assert.strictEqual(core.view.cabinetName, '測試書櫃');

    await clock.advance(10000);
    assert.strictEqual(server.pairPaths().length, 3, '取得憑證後不再輪詢配對');
    const summaries = logs.map((l) => String(l.summary)).join('\n');
    for (const secret of ['1234', POLL_TOKEN, TOKEN]) assert.ok(!summaries.includes(secret), `紀錄不得含 ${secret}`);
    core.stop();
  }],

  ['配對碼到期時以原輪詢權杖再查詢一次，回 410 才重新申請；輪詢回 410 時也重新申請', async () => {
    const { api: server, clock, core } = makeDevice({ paired: false });
    server.pairTtlMs = 7000;
    core.start();
    await clock.advance(0);
    assert.strictEqual(core.view.lines[3], '剩餘時間 0:07');
    await clock.advance(6000);
    assert.deepStrictEqual(server.pairPaths(), ['pair/request', 'pair/poll', 'pair/poll']);
    assert.strictEqual(core.view.pairing.code, '1234-5678');

    await clock.advance(1000);
    assert.deepStrictEqual(server.pairPaths().slice(3), ['pair/poll', 'pair/request'], '到期當下先查詢舊碼，回 410 才重新申請');
    assert.strictEqual(core.view.pairing.code, '1234-5679');
    assert.strictEqual(server.requests.at(-1).at - server.requests[0].at, 7000);

    server.expirePairing();
    await clock.advance(3000);
    assert.deepStrictEqual(server.pairPaths().slice(5), ['pair/poll', 'pair/request']);
    assert.strictEqual(core.view.pairing.code, '1234-5680');
    assert.strictEqual(core.view.screen, 'pairing');
    core.stop();
  }],

  ['管理員於配對碼到期前最後一刻綁定：到期後的查詢仍取得憑證，不重新申請', async () => {
    const { api: server, clock, core, storage } = makeDevice({ paired: false });
    server.pairTtlMs = 7000;
    core.start();
    await clock.advance(6500);
    assert.deepStrictEqual(server.pairPaths(), ['pair/request', 'pair/poll', 'pair/poll']);
    server.bindPairing();
    await clock.advance(500);
    assert.deepStrictEqual(server.pairPaths(), ['pair/request', 'pair/poll', 'pair/poll', 'pair/poll']);
    assert.strictEqual(storage.get(STORAGE_KEYS.token), TOKEN);
    assert.strictEqual(core.view.screen, 'idle');
    await clock.advance(10000);
    assert.strictEqual(server.pairPaths().length, 4);
    core.stop();
  }],

  ['配對碼到期後查詢遇到網路失敗時依退避重試舊碼，不連續送出請求', async () => {
    const { api: server, clock, core } = makeDevice({ paired: false });
    server.pairTtlMs = 7000;
    core.start();
    await clock.advance(6000);
    server.failures = 2;
    await clock.advance(1000);
    assert.deepStrictEqual(server.pairPaths().slice(3), ['pair/poll']);
    await clock.advance(2000);
    assert.deepStrictEqual(server.pairPaths().slice(3), ['pair/poll', 'pair/poll']);
    await clock.advance(4000);
    assert.deepStrictEqual(server.pairPaths().slice(3), ['pair/poll', 'pair/poll', 'pair/poll', 'pair/request']);
    assert.strictEqual(core.view.pairing.code, '1234-5679');
    core.stop();
  }],

  ['申請或輪詢配對失敗時依原因顯示並重試：模擬器停用、系統維護、連線中斷', async () => {
    const { api: server, clock, core } = makeDevice({ paired: false });
    server.respondOnce((r) => r.path.endsWith('/pair/request'), () => h.json(403, { success: false, code: 'DEVICE_DISABLED', message: '模擬書櫃目前未開放' }));
    core.start();
    await clock.advance(0);
    assert.deepStrictEqual(core.view.lines, ['配對碼', '模擬書櫃目前未開放']);
    assert.strictEqual(core.view.pairing.code, null);
    await clock.advance(59000);
    assert.strictEqual(server.pairPaths().length, 1);
    await clock.advance(1000);
    assert.strictEqual(server.pairPaths().length, 2);
    assert.strictEqual(core.view.pairing.code, '1234-5678');

    server.respondOnce((r) => r.path.endsWith('/pair/poll'), () => h.json(503, { success: false, code: 'MAINTENANCE', message: '系統維護中，請稍後再試' }));
    await clock.advance(3000);
    assert.deepStrictEqual(core.view.lines, ['配對碼', '系統維護中，請稍後再試']);
    await clock.advance(5000);
    assert.strictEqual(core.view.pairing.code, '1234-5678', '恢復後沿用未逾時的配對碼');

    server.failures = 3;
    await clock.advance(3000 + 2000);
    assert.strictEqual(core.view.pairing.code, '1234-5678', '連續失敗未達 3 次時仍顯示配對碼');
    await clock.advance(4000);
    assert.deepStrictEqual(core.view.lines, ['配對碼', '連線中斷，重新連線中']);
    assert.strictEqual(core.view.connection, 'offline');
    await clock.advance(8000);
    assert.strictEqual(core.view.pairing.code, '1234-5678');
    assert.strictEqual(core.view.connection, 'online');
    core.stop();
  }],

  ['申請配對碼遇到限流時依 Retry-After 重試；配對前切換門磁設定時以新設定重新申請', async () => {
    const { api: server, clock, core } = makeDevice({ paired: false });
    server.respondOnce((r) => r.path.endsWith('/pair/request'),
      () => h.json(429, { success: false, code: 'RATE_LIMITED', message: '操作過於頻繁，請稍後再試' }, { 'retry-after': '20' }));
    core.start();
    await clock.advance(0);
    assert.deepStrictEqual(core.view.lines, ['配對碼', '暫時無法取得配對碼，稍後自動重試']);
    await clock.advance(19000);
    assert.strictEqual(server.pairPaths().length, 1);
    await clock.advance(1000);
    assert.strictEqual(core.view.pairing.code, '1234-5678');

    core.setOptions({ hasDoorSensor: true });
    await clock.advance(0);
    const last = server.requests.at(-1);
    assert.strictEqual(last.path, '/api/device/v1/pair/request');
    assert.strictEqual(last.body.has_door_sensor, true);
    assert.strictEqual(core.view.pairing.code, '1234-5679');
    core.stop();
  }],

  ['比對畫面置中顯示伺服器給的兩位數比對碼與倒數，裝置不送出任何比對事件，紀錄不含比對碼', async () => {
    const { api: server, clock, core, logs } = await started();
    server.state = matchState();
    await clock.advance(2000);
    assert.strictEqual(core.view.screen, 'match');
    assert.strictEqual(core.view.code, '37');
    assert.deepStrictEqual(core.view.lines, ['請於手機輸入下列數字', '37', '剩餘 60 秒']);
    assert.strictEqual(core.view.countdown.totalMs, 60000);

    server.state = matchState('CSKIOSK01', 7);
    await clock.advance(1000);
    assert.strictEqual(core.view.code, null, '不是兩位數時不顯示');
    assert.deepStrictEqual(core.view.lines, ['請於手機輸入下列數字', '剩餘 60 秒']);

    assert.deepStrictEqual(server.events().map((e) => e.type), ['boot']);
    assert.ok(logs.every((l) => !String(l.summary).includes('37')));
    core.stop();
  }],

  ['確認項目畫面顯示「書櫃使用中｜請於手機確認項目」與倒數', async () => {
    const { api: server, clock, core } = await started();
    server.state = selectState('CSSELECT1', { poll_ms: 5000 });
    await clock.advance(2000);
    assert.strictEqual(core.view.screen, 'select');
    assert.deepStrictEqual(core.view.lines, ['書櫃使用中', '請於手機確認項目', '剩餘 60 秒']);
    await clock.advance(900);
    assert.strictEqual(core.view.lines[2], '剩餘 60 秒');
    await clock.advance(100);
    assert.strictEqual(core.view.lines[2], '剩餘 59 秒');
    assert.deepStrictEqual(server.events().map((e) => e.type), ['boot']);
    core.stop();
  }],

  ['書櫃螢幕只負責顯示：配對至結果的每個畫面都沒有按鈕，裝置不送出比對或取消事件', async () => {
    const device = makeDevice({ paired: false });
    const { api: server, clock, core, views } = device;
    core.start();
    await clock.advance(0);
    server.bindPairing();
    await clock.advance(3000);
    server.state = selectState();
    await clock.advance(2000);
    server.state = matchState();
    await clock.advance(1000);
    await openDoors(device, { channels: [1] });
    server.onEvents = (events) => {
      if (events.some((e) => e.type === 'session_closed')) server.state = resultState();
    };
    server.state = openState({ commands: [closeCommand('completed')] });
    await clock.advance(1000);

    const screens = new Set(views.map(({ view }) => view.screen));
    for (const screen of ['pairing', 'idle', 'select', 'match', 'opening', 'open', 'result']) assert.ok(screens.has(screen), screen);
    assert.ok(views.every(({ view }) => !('buttons' in view)));
    for (const removed of ['tap', 'tapKey', 'pair']) assert.strictEqual(core[removed], undefined, removed);
    assert.deepStrictEqual(server.events().filter((e) => e.type === 'match_selected' || e.type === 'session_cancel'), []);
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

    server.state = openingState({ channels: [2, 3], openMs: 45000 });
    await clock.advance(2000);
    const commandAt = server.requests.at(-1).at;
    await clock.advance(3000);

    assert.deepStrictEqual(recordAtFirstPower[0], {
      session_id: 'CSKIOSK01', command_ids: ['CSKIOSK01:2:1', 'CSKIOSK01:3:1'], action: 'pickup', open_ms: 45000
    });
    const timeline = unlockTimeline(views).map(({ at, channel, on }) => [at - commandAt, channel, on]);
    assert.deepStrictEqual(timeline, [[0, 2, true], [800, 2, false], [1100, 3, true], [1900, 3, false]]);

    const opened = server.eventsOf('door_opened');
    assert.deepStrictEqual(opened.map((e) => [e.session_id, e.channel, e.data.command_id]), [
      ['CSKIOSK01', 2, 'CSKIOSK01:2:1'], ['CSKIOSK01', 3, 'CSKIOSK01:3:1']
    ]);
    assert.strictEqual(core.view.screen, 'open');
    assert.deepStrictEqual(core.view.lines, ['A02　A03', '請取出 A02、A03 內的書籍後關上櫃門']);
    assert.strictEqual(core.view.countdown.totalMs, 45000);
    assert.strictEqual(core.view.notice, null);
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
    server.state = openState({ commands: [closeCommand('completed')] });
    await clock.advance(1000);
    const closedAt = server.requests.find((r) => r.path.endsWith('/events') && r.body.events.some((e) => e.type === 'session_closed')).at;
    assert.strictEqual(core.view.screen, 'processing');
    server.state = idleState();
    await clock.advance(closedAt + 3900 - clock.now());
    assert.strictEqual(core.view.screen, 'processing');
    await clock.advance(400);
    assert.strictEqual(core.view.screen, 'idle');
    core.stop();
  }],

  ['手機按完成：收到 close(completed) 指令時送出各門 door_closed 與 session_closed，原因為 user_done', async () => {
    const device = await started({ options: { autoCloseOnTimeout: false } });
    const { api: server, clock, core } = device;
    await openDoors(device, { channels: [2, 3] });
    const from = server.requests.length;
    await clock.advance(31000);
    assert.deepStrictEqual(eventsAfter(server, from), [], '關閉自動關門時倒數結束不回報');
    assert.strictEqual(core.view.screen, 'open');
    assert.strictEqual(core.view.countdown.remainingMs, 0);

    server.state = openState({ commands: [closeCommand('completed')] });
    await clock.advance(3000);
    assert.deepStrictEqual(eventsAfter(server, from).map((e) => [e.type, e.channel ?? null, e.session_id, e.data]), [
      ['door_closed', 2, 'CSKIOSK01', { reason: 'user_done' }],
      ['door_closed', 3, 'CSKIOSK01', { reason: 'user_done' }],
      ['session_closed', null, 'CSKIOSK01', { outcome: 'completed', reason: 'user_done' }]
    ], '指令於每次輪詢重送，只執行一次');
    assert.ok(core.view.doors.every((d) => d.locked && !d.open));
    core.stop();
  }],

  ['手機按取消：收到 close(cancelled) 指令只送出 session_closed(cancelled, user_cancel)', async () => {
    const device = await started();
    const { api: server, clock } = device;
    await openDoors(device, { channels: [1, 4] });
    const from = server.requests.length;
    server.state = openState({ commands: [closeCommand('cancelled')] });
    await clock.advance(1000);
    assert.deepStrictEqual(eventsAfter(server, from).map((e) => [e.type, e.session_id, e.data]), [
      ['session_closed', 'CSKIOSK01', { outcome: 'cancelled', reason: 'user_cancel' }]
    ]);
    device.core.stop();
  }],

  ['close 指令不屬於本機開門中的作業、或本機沒有開門中的作業時忽略', async () => {
    const device = await started();
    const { api: server, clock, core } = device;
    server.state = openState({ commands: [closeCommand('completed')] });
    await clock.advance(2000);
    assert.deepStrictEqual(server.events().map((e) => e.type), ['boot']);

    await openDoors(device, { channels: [2] });
    server.state = openState({ commands: [closeCommand('completed', { id: 'CSOTHER01' }), { type: 'close', id: 'CSKIOSK01:close:1', outcome: 'done' }] });
    await clock.advance(2000);
    assert.strictEqual(core.view.screen, 'open');
    assert.deepStrictEqual(server.eventsOf('session_closed'), []);
    core.stop();
  }],

  ['開鎖尚未全部完成時收到 close 指令，待全部櫃門處理完才關閉', async () => {
    const { api: server, clock, core } = await started();
    server.state = openingState({ channels: [2, 3], releaseMs: 2500 });
    await clock.advance(5000);
    assert.strictEqual(core.view.doors[1].open, true);
    server.state = openState({ commands: [closeCommand('completed')] });
    await clock.advance(1000);
    assert.strictEqual(core.view.doors[2].unlocking, true);
    assert.deepStrictEqual(server.eventsOf('session_closed'), []);
    assert.strictEqual(core.view.screen, 'open');

    await clock.advance(2000);
    assert.deepStrictEqual(server.eventsOf('door_opened').map((e) => e.channel), [2, 3]);
    assert.deepStrictEqual(server.eventsOf('door_closed').map((e) => [e.channel, e.data.reason]), [[2, 'user_done'], [3, 'user_done']]);
    assert.deepStrictEqual(server.eventsOf('session_closed').map((e) => e.data), [{ outcome: 'completed', reason: 'user_done' }]);
    core.stop();
  }],

  ['管理員作業顯示「管理人員作業中」，由後台完成時以 user_done 關閉', async () => {
    const device = await started();
    const { api: server, clock, core } = device;
    await openDoors(device, { channels: [3], action: 'admin', openMs: 120000 });
    assert.strictEqual(core.view.screen, 'admin');
    assert.deepStrictEqual(core.view.lines, ['A03', '管理人員作業中']);
    assert.strictEqual(core.view.countdown.totalMs, 120000);
    const from = server.requests.length;
    server.state = openState({ action: 'admin', openMs: 120000, commands: [closeCommand('completed')] });
    await clock.advance(1000);
    assert.deepStrictEqual(eventsAfter(server, from).map((e) => [e.type, e.channel ?? null, e.data]), [
      ['door_closed', 3, { reason: 'user_done' }],
      ['session_closed', null, { outcome: 'completed', reason: 'user_done' }]
    ]);
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

  ['門磁模式：門未關時收到 close 指令顯示「請先關上櫃門」並對每個指令只送一次 close_refused，全部關上後依最後被拒絕的要求結束', async () => {
    const device = await started({ options: { hasDoorSensor: true } });
    const { api: server, clock, core } = device;
    await openDoors(device, { channels: [2, 3] });
    const from = server.requests.length;
    server.state = openState({ commands: [closeCommand('completed', { at: 1 })] });
    await clock.advance(1000);
    assert.strictEqual(core.view.screen, 'open');
    assert.strictEqual(core.view.notice, '請先關上櫃門');
    await clock.advance(3000);
    assert.strictEqual(core.view.notice, '請先關上櫃門', '門未關上前持續顯示');
    assert.deepStrictEqual(server.eventsOf('close_refused').map((e) => [e.session_id, e.data]), [
      ['CSKIOSK01', { command_id: 'CSKIOSK01:close:1', code: 'DOOR_OPEN' }]
    ]);

    server.state = openState();
    core.setDoorPhysical(2, 'closed');
    await clock.advance(0);
    assert.strictEqual(core.view.notice, '請先關上櫃門');
    server.state = openState({ commands: [closeCommand('cancelled', { at: 2 })] });
    await clock.advance(1000);
    server.state = openState();
    core.setDoorPhysical(3, 'closed');
    await clock.advance(0);
    assert.deepStrictEqual(eventsAfter(server, from).map((e) => [e.type, e.channel ?? null, e.data]), [
      ['close_refused', null, { command_id: 'CSKIOSK01:close:1', code: 'DOOR_OPEN' }],
      ['door_closed', 2, { reason: 'sensor' }],
      ['close_refused', null, { command_id: 'CSKIOSK01:close:2', code: 'DOOR_OPEN' }],
      ['door_closed', 3, { reason: 'sensor' }],
      ['session_closed', null, { outcome: 'cancelled', reason: 'user_cancel' }]
    ]);
    assert.strictEqual(core.view.notice, null);
    core.stop();
  }],

  ['門磁模式：完成被拒絕後關上櫃門以 sensor 完成；取消被拒絕後又要求完成時，以最後的要求為準', async () => {
    const device = await started({ options: { hasDoorSensor: true } });
    const { api: server, clock, core } = device;
    await openDoors(device, { channels: [2] });
    server.state = openState({ commands: [closeCommand('cancelled', { at: 1 })] });
    await clock.advance(1000);
    server.state = openState({ commands: [closeCommand('completed', { at: 2 })] });
    await clock.advance(1000);
    assert.deepStrictEqual(server.eventsOf('close_refused').map((e) => e.data.command_id), ['CSKIOSK01:close:1', 'CSKIOSK01:close:2']);
    server.state = openState();
    core.setDoorPhysical(2, 'closed');
    await clock.advance(0);
    assert.deepStrictEqual(server.eventsOf('session_closed').map((e) => e.data), [{ outcome: 'completed', reason: 'sensor' }]);
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

    server.state = openState({ commands: [closeCommand('completed')] });
    await clock.advance(1000);
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
    await clock.advance(30000);
    const queued = storage.json(STORAGE_KEYS.queue);
    assert.deepStrictEqual(queued.map((e) => [e.type, e.data.reason]), [['door_closed', 'timeout'], ['session_closed', 'timeout']]);
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
    assert.strictEqual(core.view.pairing.code, '1234-5678', '回到配對畫面後自動申請新的配對碼');
    const count = server.requests.length;
    await clock.advance(10000);
    const later = server.requests.slice(count);
    assert.ok(later.length > 0);
    assert.ok(later.every((r) => r.path === '/api/device/v1/pair/poll'), '憑證失效後不再輪詢 state');
    core.stop();
  }],

  ['解除配對呼叫 /unpair、清除本機資料並申請新的配對碼', async () => {
    const { api: server, clock, core, storage } = await started();
    const result = await core.unpair();
    assert.deepStrictEqual(result, { ok: true, status: 200 });
    assert.strictEqual(server.requests.at(-1).path, '/api/device/v1/unpair');
    assert.strictEqual(server.requests.at(-1).headers.authorization, `Device ${TOKEN}`);
    assert.strictEqual(storage.get(STORAGE_KEYS.token), null);
    assert.strictEqual(core.view.screen, 'pairing');
    await clock.advance(0);
    assert.strictEqual(server.requests.at(-1).path, '/api/device/v1/pair/request');
    assert.strictEqual(core.view.pairing.code, '1234-5678');
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

  ['LAYOUT：橫向 320×240 螢幕，畫面元素落在螢幕內且互不重疊，沒有任何按鍵或按鈕配置', () => {
    assert.deepStrictEqual([LAYOUT.WIDTH, LAYOUT.HEIGHT], [320, 240]);
    const inside = ([x, y, w, h]) => x >= 0 && y >= LAYOUT.HEADER_HEIGHT && x + w <= LAYOUT.WIDTH && y + h <= LAYOUT.HEIGHT;

    // 書櫃 QR Code（版本 4）須以每格 4 像素繪製，倒數條在其下方，右側留有說明文字的空間。
    const I = LAYOUT.IDLE;
    const side = (QR.encode(QR_PAYLOAD).size + I.QUIET_ZONE * 2) * I.SCALE;
    assert.ok(side <= LAYOUT.HEIGHT - I.QR_Y - I.MARGIN, String(side));
    const qrBar = [I.QR_X, I.QR_Y + side + I.BAR_GAP, side, 4];
    assert.ok(LAYOUT.WIDTH - I.MARGIN - (I.QR_X + side + I.TEXT_GAP) >= 100);

    for (const r of [LAYOUT.PAIRING.BAR, [I.QR_X, I.QR_Y, side, side], qrBar, LAYOUT.SELECT.BAR, LAYOUT.MATCH.BAR]) {
      assert.ok(inside(r), String(r));
    }

    const O = LAYOUT.OPEN;
    const outer = O.RING.R + O.RING.WIDTH / 2;
    assert.ok(inside([O.RING.X - outer, O.RING.Y - outer, outer * 2, outer * 2]));
    assert.ok(O.LABEL_X + O.LABEL_WIDTH < O.RING.X - outer, '櫃門編號不與倒數環重疊');
    assert.ok(O.MESSAGE_X + O.MESSAGE_WIDTH < O.RING.X - outer, '說明文字不與倒數環重疊');

    const keys = [];
    const collect = (node) => {
      if (!node || typeof node !== 'object' || Array.isArray(node)) return;
      for (const [key, value] of Object.entries(node)) {
        keys.push(key);
        collect(value);
      }
    };
    collect(LAYOUT);
    assert.deepStrictEqual(keys.filter((k) => /KEY|SLOT|ABORT|DONE|CANCEL|BUTTON/.test(k)), []);
    const P = LAYOUT.PAIRING;
    assert.ok(P.TITLE_Y < P.CODE_Y && P.CODE_Y < P.PROMPT_Y && P.PROMPT_Y < P.REMAINING_Y && P.REMAINING_Y < P.BAR[1]);
    assert.ok(P.STATUS_TITLE_Y < P.STATUS_Y);
    const S = LAYOUT.SELECT;
    assert.ok(S.TITLE_Y < S.TEXT_Y && S.TEXT_Y < S.REMAINING_Y && S.REMAINING_Y < S.BAR[1]);
    const M = LAYOUT.MATCH;
    assert.ok(M.TITLE_Y < M.CODE_Y && M.CODE_Y < M.REMAINING_Y && M.REMAINING_Y < M.BAR[1]);
    // 與韌體 tools/make_fonts.py 的點陣字級相同
    assert.deepStrictEqual(LAYOUT.FONTS, { SMALL: 13, BODY: 15, TITLE: 16, CODE: 38, LABEL: 44, LABEL_SM: 28, RING: 34, HUGE: 96 });
    assert.deepStrictEqual(TIMING, { ROUNDTRIP_MAX_MS: 3000, LOCK_GAP_MS: 300 });
  }],

  ['字串表涵蓋伺服器訊息代碼與裝置本機字串', () => {
    const required = [
      'IDLE_SCAN', 'CLOSED_HOURS', 'MAINTENANCE', 'DISABLED', 'SELECT_ON_PHONE', 'MATCH_PROMPT', 'OPENING', 'OPEN_PICKUP',
      'OPEN_DEPOSIT', 'OPEN_RETRIEVE', 'OPEN_MIXED', 'OPEN_ADMIN', 'RESULT_DONE', 'RESULT_PARTIAL', 'RESULT_CANCELLED',
      'RESULT_MATCH_FAILED', 'RESULT_TIMEOUT', 'RESULT_DEVICE_ERROR', 'RESULT_REVIEW', 'TITLE', 'PAIRING_TITLE', 'PAIRING_PROMPT',
      'PAIRING_REMAINING', 'PAIRING_REQUESTING', 'PAIRING_RETRY', 'OFFLINE', 'SYSTEM_MAINTENANCE', 'DEVICE_DISABLED', 'BOOTING',
      'PROCESSING', 'CLOSE_DOOR_FIRST', 'REMAINING_SECONDS'
    ];
    for (const code of required) assert.ok(MESSAGES[code], code);
    assert.deepStrictEqual(Object.keys(MESSAGES).filter((k) => k.startsWith('BTN_')), []);
    assert.strictEqual(MESSAGES.TITLE, '智慧書櫃');
    assert.strictEqual(MESSAGES.MATCH_PROMPT, '請於手機輸入下列數字');
    assert.strictEqual(MESSAGES.PAIRING_PROMPT, '請於管理後台輸入此配對碼');
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
    for (const method of ['start', 'stop', 'setOffline', 'setLatency', 'reboot', 'setDoorPhysical', 'injectFault', 'clearFault', 'setOptions', 'unpair']) {
      assert.strictEqual(typeof core[method], 'function', method);
    }
    const view = core.view;
    for (const key of ['screen', 'header', 'lines', 'qr', 'pairing', 'code', 'countdown', 'notice', 'doors', 'connection', 'deviceNo', 'cabinetName']) {
      assert.ok(key in view, key);
    }
    assert.ok(!('buttons' in view));
    assert.deepStrictEqual(Object.keys(view.doors[0]).filter((k) => ['channel', 'label', 'locked', 'open', 'fault'].includes(k)).sort(),
      ['channel', 'fault', 'label', 'locked', 'open']);
  }]
];

module.exports = { name: 'device-core（假時鐘與假 fetch）', tests };
