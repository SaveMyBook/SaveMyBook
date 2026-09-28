const assert = require('assert');
const h = require('./harness');

const { prisma, request, api } = h;
const access = api('services/cabinet-access');

const BOOT = 'k3v9aa01';

const requestCode = (token, cabinetId, body = { kind: 'esp32', door_count: 4 }, { verified = true } = {}) =>
  request('POST', `/api/admin/cabinets/${cabinetId}/device/pairing-code`, {
    token, body, headers: verified ? h.adminVerifyHeaders(token) : {}
  });

const pair = (code, overrides = {}, { boot = BOOT } = {}) => request('POST', '/api/device/v1/pair', {
  headers: boot ? { 'x-device-boot': boot } : {},
  body: { code, kind: 'esp32', door_count: 4, has_door_sensor: false, unlock_pulse_ms: 800, firmware: 'esp-1.0.0', ...overrides }
});

const setup = async ({ kind = 'esp32', doorCount = 4 } = {}) => {
  const admin = h.addAdmin();
  const token = h.tokenFor(admin);
  const cabinet = h.addCabinet({ name: '北商大書櫃' });
  const res = await requestCode(token, cabinet.cabinet_id, { kind, door_count: doorCount });
  assert.strictEqual(res.status, 201, JSON.stringify(res.body));
  return { admin, token, cabinet, code: res.body.data.code };
};

const devicesOf = (cabinetId) => prisma.rows('cabinet_devices').filter((d) => d.cabinet_id === cabinetId);

module.exports = {
  name: '書櫃裝置：配對與撤銷',
  tests: [
    ['產生配對碼須身分驗證，種類與門數由管理員指定，配對碼為 8 位數字且不寫入操作紀錄', async () => {
      const admin = h.addAdmin();
      const token = h.tokenFor(admin);
      const cabinet = h.addCabinet();

      const unverified = await requestCode(token, cabinet.cabinet_id, { kind: 'esp32', door_count: 4 }, { verified: false });
      assert.strictEqual(unverified.status, 403);
      assert.strictEqual(unverified.body.code, 'VERIFICATION_REQUIRED');

      const invalid = await requestCode(token, cabinet.cabinet_id, { kind: 'raspberry', door_count: 4 });
      assert.strictEqual(invalid.status, 400);
      const tooMany = await requestCode(token, cabinet.cabinet_id, { kind: 'esp32', door_count: 9 });
      assert.strictEqual(tooMany.status, 400);

      const res = await requestCode(token, cabinet.cabinet_id, { kind: 'esp32', door_count: 2 });
      assert.strictEqual(res.status, 201);
      assert.match(res.body.data.code, /^\d{4}-\d{4}$/);
      assert.strictEqual(res.body.data.kind, 'esp32');
      assert.strictEqual(res.body.data.door_count, 2);

      const [row] = devicesOf(cabinet.cabinet_id);
      assert.strictEqual(row.status, 'pending');
      assert.strictEqual(row.door_count, 2);
      assert.strictEqual(row.pairing_code_hash, h.devices.sha256(res.body.data.code.replace('-', '')));
      assert.ok(!JSON.stringify(row).includes(res.body.data.code.replace('-', '')));

      const again = await requestCode(token, cabinet.cabinet_id, { kind: 'simulator' });
      assert.strictEqual(again.status, 201);
      assert.strictEqual(again.body.data.door_count, 4, '省略門數時為 4');
      assert.strictEqual(devicesOf(cabinet.cabinet_id).length, 1, '舊的 pending 列一併作廢');

      const logs = h.logs().filter((l) => l.action === '產生書櫃裝置配對碼');
      assert.strictEqual(logs.length, 2);
      for (const log of logs) {
        assert.ok(!log.detail.includes(res.body.data.code.replace('-', '')) && !log.detail.includes(again.body.data.code.replace('-', '')));
      }
      assert.match(JSON.parse(logs[1].detail).summary, /模擬書櫃（4 扇櫃門）/);
    }],

    ['配對成功只回傳一次憑證，同一組碼不能再用，並記錄事件與通知管理員（含來源 IP）', async () => {
      const { admin, cabinet, code } = await setup();
      const res = await pair(code.replace('-', ' '));
      assert.strictEqual(res.status, 201, JSON.stringify(res.body));
      const { data } = res.body;
      assert.match(data.token, /^smbd_[A-Za-z0-9_-]{43}$/);
      assert.strictEqual(data.token.length, 48);
      assert.match(data.device_no, /^DV[0-9A-Z]{7}$/);
      assert.deepStrictEqual(data.cabinet, { cabinet_name: '北商大書櫃' });
      assert.deepStrictEqual(data.doors.map((d) => d.label), ['A01', 'A02', 'A03', 'A04']);
      assert.strictEqual(data.poll_ms, 2000);

      const [device] = devicesOf(cabinet.cabinet_id);
      assert.strictEqual(device.status, 'active');
      assert.strictEqual(device.active_cabinet_id, cabinet.cabinet_id);
      assert.strictEqual(device.token_hash, h.devices.sha256(data.token));
      assert.strictEqual(device.pairing_code_hash, null);
      assert.strictEqual(device.current_boot_id, BOOT);
      assert.strictEqual(device.firmware, 'esp-1.0.0');
      assert.ok(!JSON.stringify(device).includes(data.token), '資料庫只存憑證的雜湊');

      const [paired] = h.eventsOf('paired');
      assert.deepStrictEqual(JSON.parse(paired.detail), { kind: 'esp32', ip: h.clientIp(), replaced: false });
      const [notice] = h.notificationsOf(admin.user_id).filter((n) => n.title === '書櫃裝置已配對');
      assert.strictEqual(notice.related_type, 'cabinet');
      assert.strictEqual(notice.related_id, cabinet.cabinet_id);
      assert.ok(notice.content.includes(`來源 IP：${h.clientIp()}`));
      assert.ok(notice.content.includes('實體書櫃'));

      const reused = await pair(code);
      assert.strictEqual(reused.status, 400);
      assert.strictEqual(reused.body.code, 'PAIRING_CODE_INVALID');

      const state = await h.deviceState(data.token, BOOT);
      assert.strictEqual(state.status, 200);
    }],

    ['請求的種類或門數與配對碼不同時拒絕，且不會用掉配對碼', async () => {
      const { code } = await setup({ kind: 'esp32', doorCount: 4 });
      const wrongKind = await pair(code, { kind: 'simulator' });
      assert.strictEqual(wrongKind.status, 400);
      assert.strictEqual(wrongKind.body.code, 'PAIRING_CODE_INVALID');
      const wrongDoors = await pair(code, { door_count: 3 });
      assert.strictEqual(wrongDoors.body.code, 'PAIRING_CODE_INVALID');
      const malformed = await pair('1234-567');
      assert.strictEqual(malformed.body.code, 'PAIRING_CODE_INVALID');

      const ok = await pair(code);
      assert.strictEqual(ok.status, 201);
    }],

    ['逾時的配對碼無效', async () => {
      const { cabinet, code } = await setup();
      devicesOf(cabinet.cabinet_id)[0].pairing_expires_at = new Date(Date.now() - 1000);
      const res = await pair(code);
      assert.strictEqual(res.status, 400);
      assert.strictEqual(res.body.code, 'PAIRING_CODE_INVALID');
      assert.strictEqual(res.body.message, '配對碼無效或已逾時');
    }],

    ['欄位格式不符或缺少 X-Device-Boot 時回 DEVICE_PAYLOAD_INVALID', async () => {
      const { code } = await setup();
      const cases = [
        [{ unlock_pulse_ms: 50 }],
        [{ unlock_pulse_ms: 800.5 }],
        [{ firmware: '' }],
        [{ firmware: '韌體' }],
        [{ door_count: 0 }],
        [{ kind: 'arduino' }],
        [{}, { boot: null }],
        [{}, { boot: 'UPPER1' }]
      ];
      for (const [overrides, options] of cases) {
        const res = await pair(code, overrides, options);
        assert.strictEqual(res.status, 400, JSON.stringify(overrides));
        assert.strictEqual(res.body.code, 'DEVICE_PAYLOAD_INVALID');
      }
    }],

    ['模擬器關閉時無法產生或使用 simulator 配對碼', async () => {
      const admin = h.addAdmin();
      const token = h.tokenFor(admin);
      const cabinet = h.addCabinet();
      const created = await requestCode(token, cabinet.cabinet_id, { kind: 'simulator', door_count: 4 });
      assert.strictEqual(created.status, 201);

      h.env.cabinetSimulator = false;
      const denied = await requestCode(token, cabinet.cabinet_id, { kind: 'simulator', door_count: 4 });
      assert.strictEqual(denied.status, 403);
      assert.strictEqual(denied.body.code, 'DEVICE_DISABLED');

      const res = await pair(created.body.data.code, { kind: 'simulator', firmware: 'sim-1.0.0' });
      assert.strictEqual(res.status, 403);
      assert.strictEqual(res.body.code, 'DEVICE_DISABLED');
      assert.strictEqual(res.body.message, '模擬書櫃目前未開放');

      const esp = await requestCode(token, cabinet.cabinet_id, { kind: 'esp32', door_count: 4 });
      assert.strictEqual(esp.status, 201, '實體書櫃不受模擬器開關影響');
    }],

    ['新配對會撤銷原有裝置並通知管理員，舊憑證隨即失效', async () => {
      const { admin, token, cabinet, code } = await setup();
      const first = await pair(code);
      const second = await requestCode(token, cabinet.cabinet_id);
      const res = await pair(second.body.data.code, {}, { boot: 'k3v9bb02' });
      assert.strictEqual(res.status, 201);

      const rows = devicesOf(cabinet.cabinet_id);
      assert.deepStrictEqual(rows.map((d) => d.status), ['revoked', 'active']);
      assert.strictEqual(rows[0].revoke_reason, 'replaced');
      assert.strictEqual(rows[0].token_hash, null);
      assert.strictEqual(rows[0].active_cabinet_id, null);
      assert.ok(h.eventsOf('revoked').some((e) => JSON.parse(e.detail).reason === 'replaced'));
      assert.strictEqual(JSON.parse(h.eventsOf('paired')[1].detail).replaced, true);

      const notices = h.notificationsOf(admin.user_id).filter((n) => n.title === '書櫃裝置已配對');
      assert.ok(notices[1].content.endsWith('原有的有效裝置已撤銷。'));

      const old = await h.deviceState(first.body.data.token, BOOT);
      assert.strictEqual(old.status, 401);
      assert.strictEqual(old.body.code, 'DEVICE_REVOKED');
    }],

    ['A01 至 A04 對應電磁鎖通道，其餘格位不再分配，total_slots 改為門數', async () => {
      const { token, cabinet } = await setup({ doorCount: 4 });
      for (let i = 1; i <= 6; i += 1) {
        prisma.rows('cabinet_slots').push({
          slot_id: prisma.nextId('cabinet_slots'), cabinet_id: cabinet.cabinet_id, slot_number: `A${String(i).padStart(2, '0')}`,
          status: i === 5 ? 'occupied' : 'empty', lock_channel: null, fault_code: null, check_required_at: null
        });
      }
      const code = (await requestCode(token, cabinet.cabinet_id, { kind: 'esp32', door_count: 4 })).body.data.code;
      assert.strictEqual((await pair(code)).status, 201);

      const slots = prisma.rows('cabinet_slots').filter((s) => s.cabinet_id === cabinet.cabinet_id);
      assert.strictEqual(slots.length, 6, '不重複建立既有格位');
      assert.deepStrictEqual(slots.map((s) => [s.slot_number, s.lock_channel]),
        [['A01', 1], ['A02', 2], ['A03', 3], ['A04', 4], ['A05', null], ['A06', null]]);
      assert.strictEqual(h.cabinetRow(cabinet.cabinet_id).total_slots, 4);
      assert.strictEqual(h.cabinetRow(cabinet.cabinet_id).available_slots, 4);

      const two = (await requestCode(token, cabinet.cabinet_id, { kind: 'esp32', door_count: 2 })).body.data.code;
      assert.strictEqual((await pair(two, { door_count: 2 }, { boot: 'k3v9cc03' })).status, 201);
      assert.deepStrictEqual(prisma.rows('cabinet_slots').filter((s) => s.cabinet_id === cabinet.cabinet_id && s.lock_channel)
        .map((s) => s.slot_number), ['A01', 'A02']);
      assert.strictEqual(h.cabinetRow(cabinet.cabinet_id).total_slots, 2);
    }],

    ['只接受 Device 驗證：未帶標頭或帶 Bearer 為 DEVICE_AUTH_REQUIRED，查無憑證為 DEVICE_REVOKED', async () => {
      const cabinet = h.addCabinet();
      const { token, bootId } = h.addDevice({ cabinetId: cabinet.cabinet_id });
      const none = await request('GET', '/api/device/v1/state', { headers: { 'x-device-boot': bootId } });
      assert.strictEqual(none.status, 401);
      assert.strictEqual(none.body.code, 'DEVICE_AUTH_REQUIRED');

      const bearer = await request('GET', '/api/device/v1/state', { headers: { authorization: `Bearer ${token}`, 'x-device-boot': bootId } });
      assert.strictEqual(bearer.status, 401);
      assert.strictEqual(bearer.body.code, 'DEVICE_AUTH_REQUIRED');

      const userToken = h.tokenFor(h.addUser());
      const asUser = await request('GET', '/api/device/v1/state', { token: userToken, headers: { 'x-device-boot': bootId } });
      assert.strictEqual(asUser.body.code, 'DEVICE_AUTH_REQUIRED');

      const deviceAsUser = await request('GET', '/api/orders', { headers: h.deviceHeaders(token, bootId) });
      assert.strictEqual(deviceAsUser.status, 401, '裝置憑證不能呼叫使用者 API');

      const unknown = await h.deviceState(`smbd_${'x'.repeat(43)}`, bootId);
      assert.strictEqual(unknown.status, 401);
      assert.strictEqual(unknown.body.code, 'DEVICE_REVOKED');
    }],

    ['管理員撤銷後裝置回 DEVICE_REVOKED；沒有任何裝置時回 DEVICE_NOT_PAIRED', async () => {
      const admin = h.addAdmin();
      const token = h.tokenFor(admin);
      const cabinet = h.addCabinet();
      const none = await request('DELETE', `/api/admin/cabinets/${cabinet.cabinet_id}/device`, { token });
      assert.strictEqual(none.status, 409);
      assert.strictEqual(none.body.code, 'DEVICE_NOT_PAIRED');

      const { device, token: deviceToken, bootId } = h.addDevice({ cabinetId: cabinet.cabinet_id });
      const res = await request('DELETE', `/api/admin/cabinets/${cabinet.cabinet_id}/device`, { token, body: { reason: '更換主機板' } });
      assert.strictEqual(res.status, 200);
      assert.deepStrictEqual(res.body.data.revoked, [h.devices.deviceNo(device)]);
      assert.strictEqual(device.status, 'revoked');
      assert.strictEqual(device.revoke_reason, 'admin');
      assert.strictEqual(device.revoked_by, admin.user_id);
      const [event] = h.eventsOf('revoked');
      assert.strictEqual(event.source, 'admin');
      assert.strictEqual(event.actor_id, admin.user_id);
      assert.deepStrictEqual(JSON.parse(event.detail), { reason: 'admin', note: '更換主機板' });
      assert.match(JSON.parse(h.logs().at(-1).detail).summary, /撤銷.*更換主機板/);

      const after = await h.deviceState(deviceToken, bootId);
      assert.strictEqual(after.status, 401);
      assert.strictEqual(after.body.code, 'DEVICE_REVOKED');

      const access0 = (await access.accessFor([cabinet.cabinet_id])).get(cabinet.cabinet_id);
      assert.deepStrictEqual([access0.mode, access0.reason], ['manual', 'no_device'], '管理員撤銷後立即回到手動模式');
    }],

    ['裝置自行解除配對：通知管理員，120 秒內仍維持掃碼模式', async () => {
      const admin = h.addAdmin();
      const cabinet = h.addCabinet({ name: '公館書櫃' });
      const { device, token, bootId } = h.addDevice({ cabinetId: cabinet.cabinet_id });

      const res = await request('POST', '/api/device/v1/unpair', { headers: h.deviceHeaders(token, bootId) });
      assert.strictEqual(res.status, 200);
      assert.deepStrictEqual(res.body, { success: true });
      assert.strictEqual(device.status, 'revoked');
      assert.strictEqual(device.revoke_reason, 'device');
      assert.strictEqual(JSON.parse(h.eventsOf('revoked')[0].detail).reason, 'device');

      const [notice] = h.notificationsOf(admin.user_id).filter((n) => n.title === '書櫃裝置已解除配對');
      assert.strictEqual(notice.content, '「公館書櫃」的書櫃裝置已自行解除配對，書櫃將於 2 分鐘後開放手動回報。');

      const soon = (await access.accessFor([cabinet.cabinet_id], new Date(Date.now() + 60 * 1000))).get(cabinet.cabinet_id);
      assert.deepStrictEqual([soon.mode, soon.reason], ['scan', 'no_device']);
      const later = (await access.accessFor([cabinet.cabinet_id], new Date(Date.now() + 121 * 1000))).get(cabinet.cabinet_id);
      assert.deepStrictEqual([later.mode, later.reason], ['manual', 'no_device']);

      const again = await h.deviceState(token, bootId);
      assert.strictEqual(again.body.code, 'DEVICE_REVOKED');
    }],

    ['後台裝置摘要：裝置、配對碼與存取模式', async () => {
      const admin = h.addAdmin();
      const token = h.tokenFor(admin);
      const cabinet = h.addCabinet({ name: '北商大書櫃', openTime: '08:00', closeTime: '22:00' });
      const { device } = h.addDevice({ cabinetId: cabinet.cabinet_id, kind: 'simulator' });
      await requestCode(token, cabinet.cabinet_id, { kind: 'esp32', door_count: 4 });

      const res = await request('GET', `/api/admin/cabinets/${cabinet.cabinet_id}/device`, { token });
      assert.strictEqual(res.status, 200);
      const { data } = res.body;
      assert.deepStrictEqual(data.cabinet, {
        cabinet_id: cabinet.cabinet_id, cabinet_name: '北商大書櫃', is_active: true, is_maintenance: false,
        open_time: '08:00', close_time: '22:00'
      });
      assert.strictEqual(data.access.mode, 'scan');
      assert.strictEqual(data.access.online, true);
      assert.strictEqual(data.simulator_enabled, true);
      assert.strictEqual(data.kiosk_url, 'https://example.test/kiosk');
      assert.strictEqual(data.device.device_no, h.devices.deviceNo(device));
      assert.strictEqual(data.device.kind, 'simulator');
      assert.strictEqual(data.device.unlock_pulse_ms, 800);
      assert.deepStrictEqual({ ...data.pairing, expires_at: undefined }, { kind: 'esp32', door_count: 4, expires_at: undefined });
      assert.strictEqual(data.active_session_no, null);
      assert.deepStrictEqual(data.doors.map((d) => d.label), ['A01', 'A02', 'A03', 'A04']);
      assert.match(data.doors[0].slot_no, /^SL/);
      assert.deepStrictEqual(data.unplaced, []);
      assert.ok(!JSON.stringify(data).includes('"device_id"'), '不露出裝置流水號');

      h.env.cabinetSimulator = false;
      const off = await request('GET', `/api/admin/cabinets/${cabinet.cabinet_id}/device`, { token });
      assert.strictEqual(off.body.data.kiosk_url, null);
      assert.strictEqual(off.body.data.device, null, '模擬器關閉時模擬書櫃不算有效裝置');

      const limited = h.addAdmin({ can_manage_cabinets: false });
      const denied = await request('GET', `/api/admin/cabinets/${cabinet.cabinet_id}/device`, { token: h.tokenFor(limited) });
      assert.strictEqual(denied.status, 403);
    }]
  ]
};
