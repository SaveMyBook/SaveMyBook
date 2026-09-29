const assert = require('assert');
const h = require('./harness');

const { request } = h;

const bootEvent = (bootId, extra = {}) => ({
  type: 'boot',
  data: { firmware: 'esp-1.0.1', door_count: 4, has_door_sensor: false, unlock_pulse_ms: 800, reset_reason: 'power_on', boot_id: bootId, ...extra }
});

const setup = () => {
  const admin = h.addAdmin();
  const cabinet = h.addCabinet({ name: '台北車站書櫃' });
  return { admin, cabinet, ...h.addDevice({ cabinetId: cabinet.cabinet_id }) };
};

module.exports = {
  name: '書櫃裝置：開機代碼與複製偵測',
  tests: [
    ['缺少或格式錯誤的 X-Device-Boot 為 400', async () => {
      const { token } = setup();
      const missing = await request('GET', '/api/device/v1/state', { headers: { authorization: `Device ${token}` } });
      assert.strictEqual(missing.status, 400);
      assert.strictEqual(missing.body.code, 'DEVICE_PAYLOAD_INVALID');
      for (const bad of ['abc', 'ABCDEFGH', 'k3v9-aa01', 'a'.repeat(17)]) {
        const res = await h.deviceState(token, bad);
        assert.strictEqual(res.status, 400, bad);
        assert.strictEqual(res.body.code, 'DEVICE_PAYLOAD_INVALID');
      }
    }],

    ['重新開機後第一個請求為 boot 事件時切換開機代碼', async () => {
      const { device, token, bootId } = setup();
      const next = 'reboot002';
      const res = await h.postEvents(token, next, [bootEvent(next)]);
      assert.strictEqual(res.status, 200, JSON.stringify(res.body));
      assert.deepStrictEqual(res.body.data.results.map((r) => r.status), ['ok']);
      assert.strictEqual(device.current_boot_id, next);
      assert.strictEqual(device.previous_boot_id, bootId);
      assert.ok(device.boot_switched_at instanceof Date);
      assert.strictEqual(device.firmware, 'esp-1.0.1');
      assert.strictEqual(res.body.data.state.screen, 'idle', '回應附上最新狀態');

      const state = await h.deviceState(token, next);
      assert.strictEqual(state.status, 200);
      assert.strictEqual(h.eventsOf('device_cloned').length, 0);
    }],

    ['前一個開機代碼在 30 秒內的請求回 DEVICE_STALE_BOOT，不做任何處理', async () => {
      const { device, token, bootId } = setup();
      await h.postEvents(token, 'reboot003', [bootEvent('reboot003')]);

      const stale = await h.deviceState(token, bootId);
      assert.strictEqual(stale.status, 409);
      assert.strictEqual(stale.body.code, 'DEVICE_STALE_BOOT');
      const staleEvents = await h.postEvents(token, bootId, [{ type: 'connection_restored', data: { offline_ms: 1000, queued: 0 } }]);
      assert.strictEqual(staleEvents.status, 409);
      assert.strictEqual(h.eventsOf('connection_restored').length, 0);
      assert.strictEqual(device.status, 'active');
    }],

    ['超過 30 秒仍以前一個開機代碼連線時視為憑證複製：撤銷、記錄並通知管理員', async () => {
      const { admin, device, token, bootId } = setup();
      await h.postEvents(token, 'reboot004', [bootEvent('reboot004')]);
      device.boot_switched_at = new Date(Date.now() - 31 * 1000);

      const res = await h.deviceState(token, bootId);
      assert.strictEqual(res.status, 401);
      assert.strictEqual(res.body.code, 'DEVICE_REVOKED');
      assert.strictEqual(device.status, 'revoked');
      assert.strictEqual(device.revoke_reason, 'cloned');
      const [cloned] = h.eventsOf('device_cloned');
      assert.deepStrictEqual(JSON.parse(cloned.detail), { expected: 'reboot004', got: bootId, ip: h.clientIp() });
      const [notice] = h.notificationsOf(admin.user_id).filter((n) => n.title === '書櫃裝置憑證疑遭複製');
      assert.strictEqual(notice.content, '「台北車站書櫃」的裝置憑證同時由兩個來源使用，系統已撤銷此裝置，請確認書櫃後重新配對。');
    }],

    ['兩個開機代碼交錯使用同一憑證時撤銷裝置', async () => {
      const { admin, device, token, bootId } = setup();
      assert.strictEqual((await h.deviceState(token, bootId)).status, 200);

      const other = await h.deviceState(token, 'intruder1');
      assert.strictEqual(other.status, 401);
      assert.strictEqual(other.body.code, 'DEVICE_REVOKED');
      assert.strictEqual(device.status, 'revoked');
      assert.strictEqual(device.token_hash, null);
      assert.strictEqual(h.eventsOf('device_cloned').length, 1);
      assert.strictEqual(h.notificationsOf(admin.user_id).filter((n) => n.title === '書櫃裝置憑證疑遭複製').length, 1);

      const original = await h.deviceState(token, bootId);
      assert.strictEqual(original.status, 401, '撤銷後原本的裝置也須重新配對');
    }],

    ['開機後的第一批事件不是以 boot 開頭時不切換開機代碼', async () => {
      const { device, token } = setup();
      const res = await h.postEvents(token, 'reboot005', [
        { type: 'connection_restored', data: { offline_ms: 10, queued: 1 } },
        bootEvent('reboot005')
      ]);
      assert.strictEqual(res.status, 401);
      assert.strictEqual(device.status, 'revoked');
    }],

    ['來源 IP 變更時記錄 ip_changed；離線後恢復連線時記錄 connection_restored', async () => {
      const { device, token, bootId } = setup();
      device.last_ip = '203.0.113.7';
      device.offline_since = new Date(Date.now() - 90 * 1000);
      device.offline_notified = true;

      const res = await h.deviceState(token, bootId);
      assert.strictEqual(res.status, 200);
      const [changed] = h.eventsOf('ip_changed');
      assert.deepStrictEqual(JSON.parse(changed.detail), { from: '203.0.113.7', to: h.clientIp() });
      assert.strictEqual(device.last_ip, h.clientIp());
      const [restored] = h.eventsOf('connection_restored');
      assert.strictEqual(restored.source, 'server');
      assert.ok(JSON.parse(restored.detail).offline_ms >= 90 * 1000);
      assert.strictEqual(device.offline_since, null);
      assert.strictEqual(device.offline_notified, false);

      await h.deviceState(token, bootId);
      assert.strictEqual(h.eventsOf('ip_changed').length, 1, '同一個 IP 不重複記錄');
    }]
  ]
};
