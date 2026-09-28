const assert = require('assert');
const h = require('./harness');

const { prisma, api } = h;
const scheduler = api('jobs/scheduler');

const SECOND = 1000;

module.exports = {
  name: '書櫃排程：連線檢查、作業逾時與資料清理',
  tests: [
    ['超過 60 秒未連線記錄連線中斷，超過 5 分鐘通知管理員一次', async () => {
      const admin = h.addAdmin();
      const cabinet = h.addCabinet({ name: '公館書櫃' });
      const lastSeen = new Date(Date.now() - 70 * SECOND);
      const { device } = h.addDevice({ cabinetId: cabinet.cabinet_id, lastSeenAt: lastSeen });
      const fresh = h.addDevice({ cabinetId: h.addCabinet().cabinet_id });

      await h.devices.sweep(new Date());
      assert.strictEqual(device.offline_since, lastSeen);
      assert.strictEqual(fresh.device.offline_since, null);
      const [lost] = h.eventsOf('connection_lost');
      assert.strictEqual(lost.device_id, device.device_id);
      assert.strictEqual(JSON.parse(lost.detail).last_seen_at, lastSeen.toISOString());
      assert.strictEqual(h.notificationsOf(admin.user_id).length, 0);
      fresh.device.last_seen_at = new Date(Date.now() + 20 * 60 * SECOND);

      await h.devices.sweep(new Date(Date.now() + 4 * 60 * SECOND));
      await h.devices.sweep(new Date(Date.now() + 5 * 60 * SECOND));
      assert.strictEqual(h.eventsOf('connection_lost').length, 1, '同一次斷線只記錄一次');
      const notices = h.notificationsOf(admin.user_id).filter((n) => n.title === '書櫃裝置離線');
      assert.deepStrictEqual(notices.map((n) => n.content), ['「公館書櫃」的書櫃裝置已離線超過 5 分鐘。']);
      assert.strictEqual(device.offline_notified, true);

      await h.devices.sweep(new Date(Date.now() + 10 * 60 * SECOND));
      assert.strictEqual(h.notificationsOf(admin.user_id).length, 1);
    }],

    ['作業逾時排程轉呼叫已註冊處理器的 sweep；未註冊時不做任何事', async () => {
      const calls = [];
      h.setSessionHandler({ deviceView: async () => null, handleEvent: async () => ({ status: 'ok' }), sweep: async (now) => calls.push(now) });
      await scheduler.runCabinetSessionSweep();
      assert.strictEqual(calls.length, 1);
      assert.ok(calls[0] instanceof Date);

      h.setSessionHandler(null);
      await scheduler.runCabinetSessionSweep();
      assert.strictEqual(calls.length, 1);
    }],

    ['開門回報時限依門數與開鎖時間計算', () => {
      assert.strictEqual(h.devices.openingAckMs(4, 800), 20400);
      assert.strictEqual(h.devices.openingAckMs(1, 800), 17100);
    }],

    ['開鎖指令：比對成功後 8 秒內列出仍待開啟的門，並記錄送出時間', async () => {
      const matchedAt = new Date(Date.now() - 1800);
      const sessionDoors = [
        { slot_id: 13, lock_channel: 3, state: 'pending' },
        { slot_id: 12, lock_channel: 2, state: 'pending' },
        { slot_id: 11, lock_channel: 1, state: 'open' }
      ];
      const now = new Date(matchedAt.getTime() + 1800);
      const commands = h.devices.unlockCommands({ sessionNo: 'CS8MZQ41K', matchedAt, doors: sessionDoors, pulseMs: 800 }, now);
      assert.deepStrictEqual(commands, [
        { id: 'CS8MZQ41K:2:1', type: 'unlock', channel: 2, release_ms: 800, expires_in_ms: 6200 },
        { id: 'CS8MZQ41K:3:1', type: 'unlock', channel: 3, release_ms: 800, expires_in_ms: 6200 }
      ]);
      assert.deepStrictEqual(h.devices.unlockCommands({ sessionNo: 'CS8MZQ41K', matchedAt, doors: sessionDoors, pulseMs: 800 },
        new Date(matchedAt.getTime() + 8000)), []);

      prisma.rows('cabinet_session_doors').push(
        { session_id: 5, slot_id: 12, lock_channel: 2, state: 'pending', command_served_at: null },
        { session_id: 5, slot_id: 13, lock_channel: 3, state: 'pending', command_served_at: matchedAt }
      );
      await h.devices.markCommandsServed(prisma, 5, [12, 13], now);
      assert.deepStrictEqual(prisma.rows('cabinet_session_doors').map((d) => d.command_served_at), [now, matchedAt], '只記錄第一次送出的時間');
    }],

    ['每 10 分鐘清除過期挑戰碼，每天清除一年前的事件與逾期的配對碼', async () => {
      const cabinet = h.addCabinet();
      const { device } = h.addDevice({ cabinetId: cabinet.cabinet_id });
      const now = new Date();
      prisma.rows('cabinet_challenges').push(
        { challenge_id: 1, device_id: device.device_id, token_hash: 'a'.repeat(64), qr_seq: 0, epoch: 1, expires_at: new Date(now - 2 * 3600 * SECOND) },
        { challenge_id: 2, device_id: device.device_id, token_hash: 'b'.repeat(64), qr_seq: 0, epoch: 2, expires_at: new Date(now - 10 * SECOND) }
      );
      await h.devices.recordEvent(prisma, { cabinetId: cabinet.cabinet_id, type: 'paired', occurredAt: new Date(now - 400 * 24 * 3600 * SECOND) });
      await h.devices.recordEvent(prisma, { cabinetId: cabinet.cabinet_id, type: 'paired', occurredAt: now });
      prisma.rows('cabinet_devices').push(
        { device_id: 50, cabinet_id: cabinet.cabinet_id, status: 'pending', pairing_expires_at: new Date(now - 2 * 24 * 3600 * SECOND) },
        { device_id: 51, cabinet_id: cabinet.cabinet_id, status: 'pending', pairing_expires_at: new Date(now - 3600 * SECOND) }
      );

      assert.deepStrictEqual(await h.devices.purge(now), { challenges: 1, events: 0, pending: 0 });
      assert.deepStrictEqual(await h.devices.purge(now, { daily: true }), { challenges: 0, events: 1, pending: 1 });
      assert.deepStrictEqual(prisma.rows('cabinet_devices').map((d) => d.device_id).sort(), [device.device_id, 51].sort());
    }],

    ['維護模式期間排程全部跳過', async () => {
      const maintenance = api('lib/maintenance');
      const calls = [];
      h.setSessionHandler({ deviceView: async () => null, handleEvent: async () => ({ status: 'ok' }), sweep: async (now) => calls.push(now) });
      maintenance.enter('資料庫還原中');
      try {
        await scheduler.runCabinetSessionSweep();
        await scheduler.runCabinetDeviceSweep();
        await scheduler.runCabinetPurge({ daily: true });
      } finally {
        maintenance.leave();
      }
      assert.strictEqual(calls.length, 0);
    }],

    ['模擬器關閉後排程撤銷模擬書櫃裝置並通知管理員；重新開啟時舊憑證不會恢復', async () => {
      const admin = h.addAdmin();
      const cabinet = h.addCabinet({ name: '公館書櫃' });
      const sim = h.addDevice({ cabinetId: cabinet.cabinet_id, kind: 'simulator' });
      const real = h.addDevice({ cabinetId: h.addCabinet().cabinet_id });

      await h.devices.sweep(new Date());
      assert.strictEqual(sim.device.status, 'active', '模擬器開啟時不撤銷');

      h.env.cabinetSimulator = false;
      const result = await h.devices.sweep(new Date());
      assert.strictEqual(result.revoked, 1);
      assert.strictEqual(sim.device.status, 'revoked');
      assert.strictEqual(sim.device.revoke_reason, 'simulator_off');
      assert.strictEqual(sim.device.active_cabinet_id, null);
      assert.strictEqual(sim.device.token_hash, null);
      assert.strictEqual(real.device.status, 'active');
      const [event] = h.eventsOf('revoked');
      assert.strictEqual(JSON.parse(event.detail).reason, 'simulator_off');
      const [notice] = h.notificationsOf(admin.user_id).filter((n) => n.title === '模擬書櫃裝置已撤銷');
      assert.strictEqual(notice.content, '「公館書櫃」的模擬書櫃裝置已因模擬書櫃功能關閉而撤銷；如需再次使用，請於開啟後重新配對。');
      assert.strictEqual((await h.devices.sweep(new Date())).revoked, 0);

      h.env.cabinetSimulator = true;
      const state = await h.deviceState(sim.token, sim.bootId);
      assert.strictEqual(state.status, 401);
      assert.strictEqual(state.body.code, 'DEVICE_REVOKED');
      const access = (await h.api('services/cabinet-access').accessFor([cabinet.cabinet_id])).get(cabinet.cabinet_id);
      assert.deepStrictEqual([access.mode, access.reason], ['manual', 'no_device']);
    }]
  ]
};
