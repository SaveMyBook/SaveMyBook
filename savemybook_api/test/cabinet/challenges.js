const assert = require('assert');
const h = require('./harness');

const { prisma, api } = h;
const challenges = api('services/cabinet-challenges');

const WINDOW_MS = 30 * 1000;

const setup = (options = {}) => {
  const cabinet = h.addCabinet();
  return { cabinet, ...h.addDevice({ cabinetId: cabinet.cabinet_id, ...options }) };
};

const rejects = async (promise, status, code) => {
  await assert.rejects(promise, (err) => {
    assert.strictEqual(err.status, status);
    assert.strictEqual(err.code, code);
    return true;
  });
};

const windowStart = () => Math.ceil(Date.now() / WINDOW_MS) * WINDOW_MS;

module.exports = {
  name: '書櫃挑戰碼',
  tests: [
    ['格式不符為 CABINET_CODE_INVALID；大小寫與結尾斜線皆可辨識', async () => {
      const { device } = setup();
      const now = new Date();
      for (const raw of ['', 'https://savemybook.today/k/abc', 'savemybook://k/123', `savemybook://x/${'a'.repeat(32)}`, null]) {
        await rejects(challenges.lookup(raw, now, { userId: 1 }), 400, 'CABINET_CODE_INVALID');
      }
      const { payload } = await challenges.issue(device, now);
      const upper = `SAVEMYBOOK://K/${payload.slice(15).toUpperCase()}/`;
      const found = await challenges.lookup(upper, now, { userId: 1 });
      assert.strictEqual(found.used, false);
      assert.strictEqual(found.device.device_id, device.device_id);
      assert.strictEqual(found.cabinet.cabinet_id, device.cabinet_id);
    }],

    ['查無、過期、裝置已撤銷或模擬器關閉時一律為 CABINET_CODE_EXPIRED', async () => {
      const { device } = setup({ kind: 'simulator' });
      const start = windowStart();
      const { payload } = await challenges.issue(device, new Date(start + 1000));
      await rejects(challenges.lookup(`savemybook://k/${'0'.repeat(32)}`, new Date(start + 2000)), 410, 'CABINET_CODE_EXPIRED');
      await rejects(challenges.lookup(payload, new Date(start + 45 * 1000)), 410, 'CABINET_CODE_EXPIRED');

      assert.strictEqual((await challenges.lookup(payload, new Date(start + 44 * 1000))).used, false, '每組碼有效 45 秒');
      h.env.cabinetSimulator = false;
      await rejects(challenges.lookup(payload, new Date(start + 2000)), 410, 'CABINET_CODE_EXPIRED');
      h.env.cabinetSimulator = true;
      device.status = 'revoked';
      await rejects(challenges.lookup(payload, new Date(start + 2000)), 410, 'CABINET_CODE_EXPIRED');
    }],

    ['兌換後舊碼全部作廢：前一個視窗仍在效期內的碼也回 410', async () => {
      const { device } = setup();
      const start = windowStart();
      const older = await challenges.issue(device, new Date(start + 20 * 1000));
      const newer = await challenges.issue(device, new Date(start + WINDOW_MS + 1000));
      const at = new Date(start + WINDOW_MS + 2000);

      assert.strictEqual((await challenges.lookup(older.payload, at)).used, false, '兌換前舊視窗的碼仍有效');
      const found = await challenges.lookup(newer.payload, at, { userId: 7 });
      await challenges.claim(prisma, { ...found, sessionId: 501, userId: 7, now: at });
      assert.strictEqual(device.qr_seq, 1);
      assert.strictEqual(device.active_session_id, 501);

      await rejects(challenges.lookup(older.payload, at, { userId: 8 }), 410, 'CABINET_CODE_EXPIRED');
      device.active_session_id = null;
      await rejects(challenges.lookup(older.payload, at, { userId: 8 }), 410, 'CABINET_CODE_EXPIRED');
    }],

    ['本人重送已兌換的碼時 lookup 回 used: true，其他人為 410', async () => {
      const { device } = setup();
      const now = new Date();
      const { payload } = await challenges.issue(device, now);
      const found = await challenges.lookup(payload, now, { userId: 7 });
      await challenges.claim(prisma, { ...found, sessionId: 88, userId: 7, now });

      const again = await challenges.lookup(payload, now, { userId: 7 });
      assert.strictEqual(again.used, true);
      assert.strictEqual(again.challenge.challenge_id, found.challenge.challenge_id);
      await rejects(challenges.lookup(payload, now, { userId: 9 }), 410, 'CABINET_CODE_EXPIRED');
      await rejects(challenges.lookup(payload, new Date(now.getTime() + 60 * 1000), { userId: 7 }), 410, 'CABINET_CODE_EXPIRED');
    }],

    ['同一組碼不能兌換兩次；裝置已有作業時為 CABINET_BUSY', async () => {
      const { device } = setup();
      const now = new Date();
      const { payload } = await challenges.issue(device, now);
      const found = await challenges.lookup(payload, now, { userId: 1 });
      await challenges.claim(prisma, { ...found, sessionId: 1, userId: 1, now });
      await rejects(challenges.claim(prisma, { ...found, sessionId: 2, userId: 2, now }), 410, 'CABINET_CODE_EXPIRED');

      const second = setup();
      const code = await challenges.issue(second.device, now);
      const target = await challenges.lookup(code.payload, now, { userId: 3 });
      second.device.active_session_id = 99;
      await rejects(challenges.claim(prisma, { ...target, sessionId: 3, userId: 3, now }), 409, 'CABINET_BUSY');
    }],

    ['清除過期超過 1 小時的挑戰碼', async () => {
      const { device } = setup();
      const start = windowStart();
      await challenges.issue(device, new Date(start - 3 * 60 * 60 * 1000));
      await challenges.issue(device, new Date(start + 1000));
      const { count } = await challenges.purge(new Date(start + 2000));
      assert.strictEqual(count, 1);
      assert.strictEqual(prisma.rows('cabinet_challenges').length, 1);
    }]
  ]
};
