const assert = require('assert');
const h = require('./harness');

const { prisma, api } = h;
const challenges = api('services/cabinet-challenges');
const access = api('services/cabinet-access');

const WINDOW_MS = 30 * 1000;

const taipeiHour = (date = new Date()) =>
  Number(new Intl.DateTimeFormat('en-GB', { timeZone: 'Asia/Taipei', hour: '2-digit', hourCycle: 'h23' }).format(date));

const hh = (hour) => `${String((hour + 24) % 24).padStart(2, '0')}:00`;

const setup = (options = {}) => {
  const cabinet = h.addCabinet(options);
  return { cabinet, ...h.addDevice({ cabinetId: cabinet.cabinet_id }) };
};

module.exports = {
  name: '書櫃裝置：狀態輪詢與 QR Code',
  tests: [
    ['閒置時回傳 QR Code、剩餘毫秒與櫃門清單', async () => {
      const { device, token, bootId } = setup({ name: '北商大書櫃' });
      const res = await h.deviceState(token, bootId);
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.headers.get('cache-control'), 'no-store');
      const { data } = res.body;
      assert.strictEqual(data.device_no, h.devices.deviceNo(device));
      assert.strictEqual(data.cabinet_name, '北商大書櫃');
      assert.strictEqual(data.screen, 'idle');
      assert.deepStrictEqual(data.message, { code: 'IDLE_SCAN', params: {} });
      assert.strictEqual(data.poll_ms, 2000);
      assert.match(data.qr.payload, /^savemybook:\/\/k\/[0-9a-f]{32}$/);
      assert.strictEqual(data.qr.payload.length, 47);
      assert.ok(data.qr.refresh_in_ms > 0 && data.qr.refresh_in_ms <= WINDOW_MS);
      assert.strictEqual(data.qr.expires_in_ms - data.qr.refresh_in_ms, 15 * 1000);
      assert.strictEqual(data.session, null);
      assert.deepStrictEqual(data.commands, []);
      assert.deepStrictEqual(data.doors, [1, 2, 3, 4].map((channel) => ({
        channel, label: `A0${channel}`, enabled: true, sensor: null
      })));
    }],

    ['同一個 30 秒視窗內 QR Code 相同，換視窗或 qr_seq 遞增後不同', async () => {
      const { device } = setup();
      const start = Math.ceil(Date.now() / WINDOW_MS) * WINDOW_MS;
      const a = await challenges.issue(device, new Date(start + 1000));
      const b = await challenges.issue(device, new Date(start + 25000));
      const c = await challenges.issue(device, new Date(start + WINDOW_MS + 1000));
      assert.strictEqual(a.payload, b.payload);
      assert.strictEqual(a.refresh_in_ms, 29000);
      assert.strictEqual(a.expires_in_ms, 44000);
      assert.notStrictEqual(a.payload, c.payload);
      assert.strictEqual(prisma.rows('cabinet_challenges').length, 2, '同一視窗只建立一列');

      device.qr_seq += 1;
      const d = await challenges.issue(device, new Date(start + WINDOW_MS + 2000));
      assert.notStrictEqual(c.payload, d.payload);
    }],

    ['資料庫只保存挑戰碼的雜湊', async () => {
      const { token, bootId } = setup();
      const payload = await h.scanCode(token, bootId);
      const secret = payload.slice('savemybook://k/'.length);
      const rows = prisma.rows('cabinet_challenges');
      assert.strictEqual(rows.length, 1);
      assert.strictEqual(rows[0].token_hash, challenges.sha256(secret));
      assert.ok(!JSON.stringify(rows).includes(secret));
    }],

    ['非營業時間顯示 closed_hours 且不發出 QR Code', async () => {
      const now = taipeiHour();
      const { token, bootId } = setup({ openTime: hh(now + 2), closeTime: hh(now + 3) });
      const res = await h.deviceState(token, bootId);
      assert.strictEqual(res.body.data.screen, 'closed_hours');
      assert.deepStrictEqual(res.body.data.message, { code: 'CLOSED_HOURS', params: { open: hh(now + 2), close: hh(now + 3) } });
      assert.strictEqual(res.body.data.qr, null);
      assert.strictEqual(prisma.rows('cabinet_challenges').length, 0);
    }],

    ['營業時間判斷：一般、跨夜、未設定、相同，以及後台寫入的 Date 以 UTC 時分計算', () => {
      const at = (hhmm) => new Date(`2026-09-28T${hhmm}:00+08:00`);
      const day = { open_time: '08:00', close_time: '22:00' };
      assert.strictEqual(access.isOpenAt(day, at('07:59')), false);
      assert.strictEqual(access.isOpenAt(day, at('08:00')), true);
      assert.strictEqual(access.isOpenAt(day, at('21:59')), true);
      assert.strictEqual(access.isOpenAt(day, at('22:00')), false);

      const night = { open_time: '22:00', close_time: '02:00' };
      assert.strictEqual(access.isOpenAt(night, at('23:30')), true);
      assert.strictEqual(access.isOpenAt(night, at('01:59')), true);
      assert.strictEqual(access.isOpenAt(night, at('02:00')), false);
      assert.strictEqual(access.isOpenAt(night, at('12:00')), false);

      assert.strictEqual(access.isOpenAt({ open_time: null, close_time: '22:00' }, at('23:00')), true);
      assert.strictEqual(access.isOpenAt({ open_time: '09:00', close_time: '09:00' }, at('03:00')), true);

      const stored = { open_time: new Date('1970-01-01T08:00:00Z'), close_time: new Date('1970-01-01T22:00:00Z') };
      assert.deepStrictEqual(access.hoursOf(stored), { open_time: '08:00', close_time: '22:00' });
      assert.strictEqual(access.isOpenAt(stored, at('07:30')), false);
      assert.strictEqual(access.isOpenAt(stored, at('08:30')), true);
    }],

    ['維修中、裝置故障、所有櫃門不可用時顯示 maintenance；停用時顯示 disabled', async () => {
      const { cabinet, device, token, bootId } = setup();
      cabinet.is_maintenance = 1;
      let res = await h.deviceState(token, bootId);
      assert.strictEqual(res.body.data.screen, 'maintenance');
      assert.deepStrictEqual(res.body.data.message, { code: 'MAINTENANCE', params: {} });
      assert.strictEqual(res.body.data.qr, null);

      cabinet.is_maintenance = 0;
      device.fault_code = 'POWER';
      res = await h.deviceState(token, bootId);
      assert.strictEqual(res.body.data.screen, 'maintenance');

      device.fault_code = null;
      h.doorOf(cabinet.cabinet_id, 1).fault_code = 'LOCK_NO_RELEASE';
      h.doorOf(cabinet.cabinet_id, 2).status = 'maintenance';
      h.doorOf(cabinet.cabinet_id, 3).check_required_at = new Date();
      res = await h.deviceState(token, bootId);
      assert.strictEqual(res.body.data.screen, 'idle', '仍有可用的櫃門');
      assert.deepStrictEqual(res.body.data.doors.map((d) => d.enabled), [false, false, false, true]);

      h.doorOf(cabinet.cabinet_id, 4).fault_code = 'LOCK_NO_RELEASE';
      res = await h.deviceState(token, bootId);
      assert.strictEqual(res.body.data.screen, 'maintenance');

      cabinet.is_active = false;
      res = await h.deviceState(token, bootId);
      assert.strictEqual(res.body.data.screen, 'disabled');
      assert.deepStrictEqual(res.body.data.message, { code: 'DISABLED', params: {} });
    }],

    ['last_seen_at 每 5 秒最多寫入一次', async () => {
      const { device, token, bootId } = setup();
      device.last_ip = h.clientIp();
      const recent = new Date(Date.now() - 2000);
      device.last_seen_at = recent;
      await h.deviceState(token, bootId);
      assert.strictEqual(device.last_seen_at, recent);

      device.last_seen_at = new Date(Date.now() - 6000);
      await h.deviceState(token, bootId);
      assert.ok(Date.now() - device.last_seen_at.getTime() < 1000);
    }],

    ['模擬器關閉時模擬書櫃回 DEVICE_DISABLED', async () => {
      const cabinet = h.addCabinet();
      const { token, bootId } = h.addDevice({ cabinetId: cabinet.cabinet_id, kind: 'simulator' });
      assert.strictEqual((await h.deviceState(token, bootId)).status, 200);
      h.env.cabinetSimulator = false;
      const res = await h.deviceState(token, bootId);
      assert.strictEqual(res.status, 403);
      assert.strictEqual(res.body.code, 'DEVICE_DISABLED');
    }],

    ['作業處理器回傳畫面時採用其內容，且不發出 QR Code', async () => {
      const { device, token, bootId } = setup();
      const calls = [];
      h.setSessionHandler({
        deviceView: async (d, now) => {
          calls.push([d.device_id, now instanceof Date]);
          return {
            screen: 'match',
            message: { code: 'MATCH_PROMPT', params: {} },
            poll_ms: 1000,
            session: { id: 'CS0000000', phase: 'match', choices: [11, 22] },
            commands: []
          };
        },
        handleEvent: async () => ({ status: 'ok' }),
        sweep: async () => {}
      });
      const res = await h.deviceState(token, bootId);
      assert.deepStrictEqual(calls, [[device.device_id, true]]);
      assert.strictEqual(res.body.data.screen, 'match');
      assert.strictEqual(res.body.data.poll_ms, 1000);
      assert.strictEqual(res.body.data.qr, null);
      assert.deepStrictEqual(res.body.data.session.choices, [11, 22]);
      assert.strictEqual(prisma.rows('cabinet_challenges').length, 0);
    }],

    ['有門磁的裝置回報櫃門感測狀態，沒有門磁時一律為 null', async () => {
      const cabinet = h.addCabinet();
      const { token, bootId } = h.addDevice({ cabinetId: cabinet.cabinet_id, hasDoorSensor: true });
      await h.postEvents(token, bootId, [{ type: 'door_forced', channel: 2, data: {} }]);
      const res = await h.deviceState(token, bootId);
      assert.deepStrictEqual(res.body.data.doors.map((d) => d.sensor), [null, 'open', null, null]);

      const other = h.addCabinet();
      const plain = h.addDevice({ cabinetId: other.cabinet_id });
      await h.postEvents(plain.token, plain.bootId, [{ type: 'door_forced', channel: 2, data: { sensor: 'open' } }]);
      assert.strictEqual(h.doorOf(other.cabinet_id, 2).sensor_state, null, '沒有門磁的裝置不記錄感測狀態');
    }]
  ]
};
