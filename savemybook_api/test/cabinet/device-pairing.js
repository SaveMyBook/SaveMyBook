const assert = require('assert');
const h = require('./harness');

const { prisma, request, api } = h;
const access = api('services/cabinet-access');

const BOOT = 'k3v9aa01';

const adminOf = (permissions) => {
  const admin = h.addAdmin(permissions);
  return { admin, token: h.tokenFor(admin) };
};

// 只測綁定與領取時直接呼叫服務申請配對碼：申請端點有全站每分鐘 30 次的限流，整個測試行程共用。
const issue = (overrides = {}) => h.devices.requestPairing({
  kind: 'esp32', doorCount: 4, hasDoorSensor: false, unlockPulseMs: 800, firmware: 'esp-1.0.0', bootId: BOOT, ...overrides
});

const pairThrough = async ({ token, cabinet, boot = BOOT, body = {} }) => {
  const requested = await h.requestPairing(body, { boot });
  assert.strictEqual(requested.status, 201, requested.text);
  const claimed = await h.claimPairing(token, cabinet.cabinet_id, requested.body.data.code);
  assert.strictEqual(claimed.status, 201, claimed.text);
  const polled = await h.pollPairing(requested.body.data.poll_token);
  assert.strictEqual(polled.status, 200, polled.text);
  return polled.body.data;
};

const devicesOf = (cabinetId) => prisma.rows('cabinet_devices').filter((d) => d.cabinet_id === cabinetId);
const digitsOf = (code) => code.replace('-', '');

module.exports = {
  name: '書櫃裝置：配對與撤銷',
  tests: [
    ['裝置申請配對碼：回傳 8 位數配對碼與輪詢權杖，伺服器只保存雜湊，綁定前輪詢為 pending', async () => {
      const res = await h.requestPairing({ has_door_sensor: true, door_count: 2 });
      assert.strictEqual(res.status, 201, res.text);
      assert.strictEqual(res.headers.get('cache-control'), 'no-store');
      const { data } = res.body;
      assert.match(data.code, /^\d{4}-\d{4}$/);
      assert.match(data.poll_token, /^[A-Za-z0-9_-]{43}$/);
      assert.strictEqual(data.expires_in_ms, 600000);
      assert.strictEqual(data.poll_ms, 3000);

      const [row] = prisma.rows('cabinet_pair_requests');
      assert.strictEqual(row.code_hash, h.devices.sha256(digitsOf(data.code)));
      assert.strictEqual(row.poll_token_hash, h.devices.sha256(data.poll_token));
      assert.deepStrictEqual(
        [row.kind, row.door_count, row.has_door_sensor, row.unlock_pulse_ms, row.firmware, row.boot_id, row.ip],
        ['esp32', 2, true, 800, 'esp-1.0.0', BOOT, h.clientIp()]
      );
      assert.deepStrictEqual([row.cabinet_id, row.device_id, row.claimed_at, row.delivered_at], [null, null, null, null]);
      const stored = JSON.stringify(row);
      assert.ok(!stored.includes(digitsOf(data.code)) && !stored.includes(data.poll_token), '資料庫不保存配對碼與輪詢權杖');
      assert.strictEqual(prisma.rows('cabinet_devices').length, 0, '申請時不建立裝置');

      const polled = await h.pollPairing(data.poll_token);
      assert.strictEqual(polled.status, 200);
      assert.strictEqual(polled.headers.get('cache-control'), 'no-store');
      assert.strictEqual(polled.body.data.status, 'pending');
      assert.strictEqual(polled.body.data.poll_ms, 3000);
      assert.ok(polled.body.data.expires_in_ms > 590000 && polled.body.data.expires_in_ms <= 600000);
      assert.strictEqual(polled.body.data.token, undefined);
    }],

    ['欄位格式不符或缺少 X-Device-Boot 時回 DEVICE_PAYLOAD_INVALID；輪詢權杖格式不符亦同', async () => {
      const cases = [
        [{ unlock_pulse_ms: 50 }],
        [{ firmware: '韌體' }],
        [{ door_count: 0 }],
        [{ kind: 'arduino' }],
        [{}, { boot: null }],
        [{}, { boot: 'UPPER1' }]
      ];
      for (const [overrides, options] of cases) {
        const res = await h.requestPairing(overrides, options);
        assert.strictEqual(res.status, 400, JSON.stringify(overrides));
        assert.strictEqual(res.body.code, 'DEVICE_PAYLOAD_INVALID');
      }
      assert.strictEqual(prisma.rows('cabinet_pair_requests').length, 0);

      for (const token of [undefined, 'short', 12345, `${'a'.repeat(42)}!`]) {
        const res = await h.pollPairing(token);
        assert.strictEqual(res.status, 400, String(token));
        assert.strictEqual(res.body.code, 'DEVICE_PAYLOAD_INVALID');
      }
    }],

    ['管理員輸入配對碼後裝置輪詢取得憑證：憑證只交付一次，並記錄事件、稽核與通知管理員', async () => {
      const { admin, token } = adminOf();
      const cabinet = h.addCabinet({ name: '北商大書櫃' });
      const requested = await h.requestPairing({ has_door_sensor: true });
      const { code, poll_token: pollToken } = requested.body.data;

      const claimed = await h.claimPairing(token, cabinet.cabinet_id, ` ${code.replace('-', ' ')} `);
      assert.strictEqual(claimed.status, 201, claimed.text);
      assert.strictEqual(claimed.body.message, '已送出配對，裝置連線後即完成');
      const { data } = claimed.body;
      assert.deepStrictEqual([data.kind, data.door_count, data.has_door_sensor, data.firmware], ['esp32', 4, true, 'esp-1.0.0']);
      assert.strictEqual(data.summary.cabinet.cabinet_name, '北商大書櫃');
      assert.strictEqual(data.summary.device, null);
      assert.deepStrictEqual({ ...data.summary.pairing, expires_at: undefined }, {
        kind: 'esp32', door_count: 4, has_door_sensor: true, firmware: 'esp-1.0.0', expires_at: undefined
      });
      assert.ok(!claimed.text.includes(digitsOf(code)), '回應不含配對碼');

      const [pending] = devicesOf(cabinet.cabinet_id);
      assert.deepStrictEqual([pending.status, pending.kind, pending.door_count, pending.has_door_sensor, pending.created_by],
        ['pending', 'esp32', 4, true, admin.user_id]);
      const [row] = prisma.rows('cabinet_pair_requests');
      assert.deepStrictEqual([row.cabinet_id, row.device_id, row.claimed_by], [cabinet.cabinet_id, pending.device_id, admin.user_id]);
      assert.ok(row.claimed_at instanceof Date);

      const logs = h.logs().filter((l) => l.action === '配對書櫃裝置');
      assert.strictEqual(logs.length, 1);
      assert.strictEqual(logs[0].target_type, 'cabinet');
      assert.strictEqual(logs[0].target_id, cabinet.cabinet_id);
      assert.strictEqual(JSON.parse(logs[0].detail).summary, '為「北商大書櫃」配對實體書櫃（4 扇櫃門，韌體 esp-1.0.0）');
      assert.ok(!logs[0].detail.includes(digitsOf(code)), '操作紀錄不記錄配對碼');

      const polled = await h.pollPairing(pollToken);
      assert.strictEqual(polled.status, 200, polled.text);
      const paired = polled.body.data;
      assert.strictEqual(paired.status, 'paired');
      assert.match(paired.token, /^smbd_[A-Za-z0-9_-]{43}$/);
      assert.match(paired.device_no, /^DV[0-9A-Z]{7}$/);
      assert.strictEqual(paired.device_no, h.devices.deviceNo(pending));
      assert.deepStrictEqual(paired.cabinet, { cabinet_name: '北商大書櫃' });
      assert.deepStrictEqual(paired.doors.map((d) => d.label), ['A01', 'A02', 'A03', 'A04']);
      assert.strictEqual(paired.poll_ms, 2000);

      const device = h.deviceRow(pending.device_id);
      assert.strictEqual(device.status, 'active');
      assert.strictEqual(device.active_cabinet_id, cabinet.cabinet_id);
      assert.strictEqual(device.token_hash, h.devices.sha256(paired.token));
      assert.strictEqual(device.current_boot_id, BOOT, '開機代碼沿用申請配對碼時的 X-Device-Boot');
      assert.strictEqual(device.has_door_sensor, true);
      assert.strictEqual(device.last_ip, h.clientIp());
      assert.ok(!JSON.stringify(device).includes(paired.token), '資料庫只存憑證的雜湊');
      assert.ok(prisma.rows('cabinet_pair_requests')[0].delivered_at instanceof Date);

      const [event] = h.eventsOf('paired');
      assert.deepStrictEqual(JSON.parse(event.detail), { kind: 'esp32', ip: h.clientIp(), replaced: false });
      assert.strictEqual(event.actor_id, admin.user_id);
      const [notice] = h.notificationsOf(admin.user_id).filter((n) => n.title === '書櫃裝置已配對');
      assert.strictEqual(notice.related_type, 'cabinet');
      assert.strictEqual(notice.related_id, cabinet.cabinet_id);
      assert.ok(notice.content.includes(`來源 IP：${h.clientIp()}`));
      assert.ok(notice.content.includes('實體書櫃'));

      const again = await h.pollPairing(pollToken);
      assert.strictEqual(again.status, 410);
      assert.strictEqual(again.body.code, 'PAIRING_EXPIRED');
      assert.strictEqual(again.body.message, '配對碼已逾時，請重新取得');
      assert.strictEqual(again.body.data, undefined);

      const reused = await h.claimPairing(token, cabinet.cabinet_id, code);
      assert.strictEqual(reused.status, 400);
      assert.strictEqual(reused.body.code, 'PAIRING_CODE_INVALID');

      const state = await h.deviceState(paired.token, BOOT);
      assert.strictEqual(state.status, 200);
    }],

    ['並行輪詢只有一次取得憑證', async () => {
      const { token } = adminOf();
      const cabinet = h.addCabinet();
      const { code, poll_token: pollToken } = await issue();
      assert.strictEqual((await h.claimPairing(token, cabinet.cabinet_id, code)).status, 201);

      const results = await Promise.all([h.pollPairing(pollToken), h.pollPairing(pollToken), h.pollPairing(pollToken)]);
      assert.deepStrictEqual(results.map((r) => r.status).sort(), [200, 410, 410]);
      assert.strictEqual(results.filter((r) => r.body.data?.token).length, 1);
      assert.strictEqual(h.eventsOf('paired').length, 1);
      assert.deepStrictEqual(devicesOf(cabinet.cabinet_id).map((d) => d.status), ['active']);
    }],

    ['配對碼接受連字號、空白或純數字；格式不符、查無或已綁定皆回 PAIRING_CODE_INVALID，且不會用掉配對碼', async () => {
      const { token } = adminOf();
      const cabinet = h.addCabinet();
      const { code } = await issue();
      const wrong = String((Number(digitsOf(code)) + 1) % 100000000).padStart(8, '0');

      const unverified = await h.claimPairing(token, cabinet.cabinet_id, code, { verified: false });
      assert.strictEqual(unverified.status, 403);
      assert.strictEqual(unverified.body.code, 'VERIFICATION_REQUIRED');
      for (const value of ['1234-567', 'abcd-efgh', wrong, '', undefined, 12]) {
        const res = await h.claimPairing(token, cabinet.cabinet_id, value);
        assert.strictEqual(res.status, 400, String(value));
        assert.strictEqual(res.body.code, 'PAIRING_CODE_INVALID');
        assert.strictEqual(res.body.message, '配對碼無效或已逾時');
      }
      const missing = await h.claimPairing(token, 999999, code);
      assert.strictEqual(missing.status, 404);
      const limited = adminOf({ can_manage_cabinets: false });
      const denied = await h.claimPairing(limited.token, cabinet.cabinet_id, code);
      assert.strictEqual(denied.status, 403);
      assert.strictEqual(prisma.rows('cabinet_pair_requests')[0].claimed_at, null);

      const other = adminOf();
      const [first, second] = await Promise.all([
        h.claimPairing(token, cabinet.cabinet_id, digitsOf(code)),
        h.claimPairing(other.token, cabinet.cabinet_id, code)
      ]);
      assert.deepStrictEqual([first.status, second.status].sort(), [201, 400], '同一組配對碼只能綁定一次');
      assert.strictEqual(devicesOf(cabinet.cabinet_id).length, 1);
      assert.strictEqual(h.logs().filter((l) => l.action === '配對書櫃裝置').length, 1);
    }],

    ['管理員輸入配對碼每 10 分鐘最多 10 次', async () => {
      const { token } = adminOf();
      const cabinet = h.addCabinet();
      for (let i = 0; i < 10; i += 1) {
        const res = await h.claimPairing(token, cabinet.cabinet_id, '0000-0000');
        assert.strictEqual(res.status, 400);
      }
      const blocked = await h.claimPairing(token, cabinet.cabinet_id, '0000-0000');
      assert.strictEqual(blocked.status, 429);
      assert.strictEqual(blocked.body.code, 'RATE_LIMITED');
      const other = adminOf();
      assert.strictEqual((await h.claimPairing(other.token, cabinet.cabinet_id, '0000-0000')).status, 400, '依管理員分別計算');
    }],

    ['逾時的配對碼無法綁定，裝置輪詢回 410；效期將屆時綁定仍保留 30 秒供裝置領取', async () => {
      const { token } = adminOf();
      const cabinet = h.addCabinet();
      const expired = await issue();
      h.pairRequestOf(expired.code).expires_at = new Date(Date.now() - 1000);
      const late = await h.claimPairing(token, cabinet.cabinet_id, expired.code);
      assert.strictEqual(late.status, 400);
      assert.strictEqual(late.body.code, 'PAIRING_CODE_INVALID');
      const gone = await h.pollPairing(expired.poll_token);
      assert.strictEqual(gone.status, 410);
      assert.strictEqual(gone.body.code, 'PAIRING_EXPIRED');
      assert.strictEqual(devicesOf(cabinet.cabinet_id).length, 0);

      const unknown = await h.pollPairing('a'.repeat(43));
      assert.strictEqual(unknown.status, 410);

      const closing = await issue();
      h.pairRequestOf(closing.code).expires_at = new Date(Date.now() + 1000);
      assert.strictEqual((await h.claimPairing(token, cabinet.cabinet_id, closing.code)).status, 201);
      const extended = h.pairRequestOf(closing.code).expires_at.getTime() - Date.now();
      assert.ok(extended > 25000 && extended <= 30000, String(extended));

      h.pairRequestOf(closing.code).expires_at = new Date(Date.now() - 1000);
      const missed = await h.pollPairing(closing.poll_token);
      assert.strictEqual(missed.status, 410);
      assert.deepStrictEqual(devicesOf(cabinet.cabinet_id).map((d) => d.status), ['pending'], '逾時未領取的裝置列不會啟用');
    }],

    ['模擬器關閉時無法申請、綁定或領取模擬書櫃的配對', async () => {
      const { token } = adminOf();
      const cabinet = h.addCabinet();
      const sim = { kind: 'simulator', firmware: 'sim-1.0.0' };
      const first = await h.requestPairing(sim);
      assert.strictEqual(first.status, 201);
      const second = await issue({ kind: 'simulator', firmware: 'sim-1.0.0' });

      h.env.cabinetSimulator = false;
      const denied = await h.requestPairing(sim);
      assert.strictEqual(denied.status, 403);
      assert.strictEqual(denied.body.code, 'DEVICE_DISABLED');
      assert.strictEqual(denied.body.message, '模擬書櫃目前未開放');
      const claim = await h.claimPairing(token, cabinet.cabinet_id, first.body.data.code);
      assert.strictEqual(claim.status, 403);
      assert.strictEqual(claim.body.code, 'DEVICE_DISABLED');
      const esp = await h.requestPairing();
      assert.strictEqual(esp.status, 201, '實體書櫃不受模擬器開關影響');

      h.env.cabinetSimulator = true;
      assert.strictEqual((await h.claimPairing(token, cabinet.cabinet_id, second.code)).status, 201);
      h.env.cabinetSimulator = false;
      const poll = await h.pollPairing(second.poll_token);
      assert.strictEqual(poll.status, 403);
      assert.strictEqual(poll.body.code, 'DEVICE_DISABLED');
      assert.deepStrictEqual(devicesOf(cabinet.cabinet_id).map((d) => d.status), ['pending']);
    }],

    ['新配對會撤銷原有裝置並通知管理員，舊憑證隨即失效', async () => {
      const { admin, token } = adminOf();
      const cabinet = h.addCabinet({ name: '北商大書櫃' });
      const first = await pairThrough({ token, cabinet });
      const second = await pairThrough({ token, cabinet, boot: 'k3v9bb02' });

      const rows = devicesOf(cabinet.cabinet_id);
      assert.deepStrictEqual(rows.map((d) => d.status), ['revoked', 'active']);
      assert.strictEqual(rows[0].revoke_reason, 'replaced');
      assert.strictEqual(rows[0].token_hash, null);
      assert.strictEqual(rows[0].active_cabinet_id, null);
      assert.strictEqual(rows[1].current_boot_id, 'k3v9bb02');
      assert.ok(h.eventsOf('revoked').some((e) => JSON.parse(e.detail).reason === 'replaced'));
      assert.strictEqual(JSON.parse(h.eventsOf('paired')[1].detail).replaced, true);

      const notices = h.notificationsOf(admin.user_id).filter((n) => n.title === '書櫃裝置已配對');
      assert.ok(notices[1].content.endsWith('原有的有效裝置已撤銷。'));

      const old = await h.deviceState(first.token, BOOT);
      assert.strictEqual(old.status, 401);
      assert.strictEqual(old.body.code, 'DEVICE_REVOKED');
      assert.strictEqual((await h.deviceState(second.token, 'k3v9bb02')).status, 200);
    }],

    ['A01 至 A04 對應電磁鎖通道，其餘格位不再分配，total_slots 改為裝置回報的門數', async () => {
      const { token } = adminOf();
      const cabinet = h.addCabinet();
      for (let i = 1; i <= 6; i += 1) {
        prisma.rows('cabinet_slots').push({
          slot_id: prisma.nextId('cabinet_slots'), cabinet_id: cabinet.cabinet_id, slot_number: `A${String(i).padStart(2, '0')}`,
          status: i === 5 ? 'occupied' : 'empty', lock_channel: null, fault_code: null, check_required_at: null
        });
      }
      const pairWith = async (doorCount, boot) => {
        const { code, poll_token: pollToken } = await issue({ doorCount, bootId: boot });
        assert.strictEqual((await h.claimPairing(token, cabinet.cabinet_id, code)).status, 201);
        assert.strictEqual((await h.pollPairing(pollToken)).status, 200);
      };

      await pairWith(4, BOOT);
      const slots = prisma.rows('cabinet_slots').filter((s) => s.cabinet_id === cabinet.cabinet_id);
      assert.strictEqual(slots.length, 6, '不重複建立既有格位');
      assert.deepStrictEqual(slots.map((s) => [s.slot_number, s.lock_channel]),
        [['A01', 1], ['A02', 2], ['A03', 3], ['A04', 4], ['A05', null], ['A06', null]]);
      assert.strictEqual(h.cabinetRow(cabinet.cabinet_id).total_slots, 4);
      assert.strictEqual(h.cabinetRow(cabinet.cabinet_id).available_slots, 4);

      await pairWith(2, 'k3v9cc03');
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

    ['管理員撤銷後裝置回 DEVICE_REVOKED，尚未領取的配對一併作廢；沒有任何裝置時回 DEVICE_NOT_PAIRED', async () => {
      const { admin, token } = adminOf();
      const cabinet = h.addCabinet();
      const none = await request('DELETE', `/api/admin/cabinets/${cabinet.cabinet_id}/device`, { token });
      assert.strictEqual(none.status, 409);
      assert.strictEqual(none.body.code, 'DEVICE_NOT_PAIRED');

      const { device, token: deviceToken, bootId } = h.addDevice({ cabinetId: cabinet.cabinet_id });
      const waiting = await issue();
      assert.strictEqual((await h.claimPairing(token, cabinet.cabinet_id, waiting.code)).status, 201);
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

      assert.deepStrictEqual(devicesOf(cabinet.cabinet_id).map((d) => d.status), ['revoked'], '待配對的裝置列一併刪除');
      const late = await h.pollPairing(waiting.poll_token);
      assert.strictEqual(late.status, 410);
      assert.strictEqual(late.body.code, 'PAIRING_EXPIRED');

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

    ['後台裝置摘要：裝置、待完成的配對與存取模式', async () => {
      const { token } = adminOf();
      const cabinet = h.addCabinet({ name: '北商大書櫃', openTime: '08:00', closeTime: '22:00' });
      const { device } = h.addDevice({ cabinetId: cabinet.cabinet_id, kind: 'simulator' });
      const empty = await request('GET', `/api/admin/cabinets/${cabinet.cabinet_id}/device`, { token });
      assert.strictEqual(empty.body.data.pairing, null);
      const unclaimed = await issue({ hasDoorSensor: true, firmware: 'esp-2.0.0' });
      assert.strictEqual((await request('GET', `/api/admin/cabinets/${cabinet.cabinet_id}/device`, { token })).body.data.pairing, null,
        '尚未綁定的配對碼不屬於任何書櫃');
      await h.claimPairing(token, cabinet.cabinet_id, unclaimed.code);

      const res = await request('GET', `/api/admin/cabinets/${cabinet.cabinet_id}/device`, { token });
      assert.strictEqual(res.status, 200);
      const { data } = res.body;
      assert.deepStrictEqual(data.cabinet, {
        cabinet_id: cabinet.cabinet_id, cabinet_name: '北商大書櫃', is_active: true, is_maintenance: false,
        open_time: '08:00', close_time: '22:00', screen_brightness: 100
      });
      assert.strictEqual(data.access.mode, 'scan');
      assert.strictEqual(data.access.online, true);
      assert.strictEqual(data.simulator_enabled, true);
      assert.strictEqual(data.kiosk_url, 'https://example.test/kiosk');
      assert.strictEqual(data.device.device_no, h.devices.deviceNo(device));
      assert.strictEqual(data.device.kind, 'simulator');
      assert.strictEqual(data.device.unlock_pulse_ms, 800);
      assert.deepStrictEqual({ ...data.pairing, expires_at: undefined }, {
        kind: 'esp32', door_count: 4, has_door_sensor: true, firmware: 'esp-2.0.0', expires_at: undefined
      });
      assert.ok(new Date(data.pairing.expires_at) > new Date());
      assert.strictEqual(data.active_session_no, null);
      assert.deepStrictEqual(data.doors.map((d) => d.label), ['A01', 'A02', 'A03', 'A04']);
      assert.match(data.doors[0].slot_no, /^SL/);
      assert.deepStrictEqual(data.unplaced, []);
      assert.ok(!JSON.stringify(data).includes('"device_id"'), '不露出裝置流水號');

      h.pairRequestOf(unclaimed.code).expires_at = new Date(Date.now() - 1000);
      const expired = await request('GET', `/api/admin/cabinets/${cabinet.cabinet_id}/device`, { token });
      assert.strictEqual(expired.body.data.pairing, null, '逾時未領取的配對不再顯示');

      h.env.cabinetSimulator = false;
      const off = await request('GET', `/api/admin/cabinets/${cabinet.cabinet_id}/device`, { token });
      assert.strictEqual(off.body.data.kiosk_url, null);
      assert.strictEqual(off.body.data.device, null, '模擬器關閉時模擬書櫃不算有效裝置');

      const limited = adminOf({ can_manage_cabinets: false });
      const denied = await request('GET', `/api/admin/cabinets/${cabinet.cabinet_id}/device`, { token: limited.token });
      assert.strictEqual(denied.status, 403);
    }],

    ['舊的配對端點已移除', async () => {
      const { token } = adminOf();
      const cabinet = h.addCabinet();
      const old = await request('POST', '/api/device/v1/pair', {
        headers: { 'x-device-boot': BOOT }, body: { code: '1234-5678', kind: 'esp32', door_count: 4, unlock_pulse_ms: 800, firmware: 'x' }
      });
      assert.strictEqual(old.status, 404);
      const legacy = await request('POST', `/api/admin/cabinets/${cabinet.cabinet_id}/device/pairing-code`, {
        token, headers: h.adminVerifyHeaders(token), body: { kind: 'esp32' }
      });
      assert.strictEqual(legacy.status, 404);
    }]
  ]
};
