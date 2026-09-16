const assert = require('assert');
const h = require('./harness');

const { prisma, request } = h;
const security = h.api('services/security');

const setup = async (options) => {
  const ctx = h.signedIn(options);
  const authenticator = await h.registerPasskey(ctx);
  return { ...ctx, authenticator };
};

const verifyOptions = async (ctx, scope) =>
  request('POST', '/api/security/verify/passkey/options', { token: ctx.token, body: { scope } });

const verifyWith = (ctx, scope, assertion) =>
  request('POST', '/api/security/verify', { token: ctx.token, body: { scope, method: 'passkey', assertion } });

const passkeyToken = async (ctx, scope) => {
  const options = (await verifyOptions(ctx, scope)).body.data.options;
  const res = await verifyWith(ctx, scope, ctx.authenticator.get(options));
  assert.strictEqual(res.status, 200, res.text);
  return res.body.data.verify_token;
};

module.exports = {
  name: '通行密鑰：身分驗證',
  tests: [
    ['安全狀態回報是否已註冊通行密鑰', async () => {
      const ctx = h.signedIn();
      const before = await request('GET', '/api/security', { token: ctx.token });
      assert.strictEqual(before.body.data.passkey_available, true);
      assert.strictEqual(before.body.data.has_passkey, false);

      const none = await verifyOptions(ctx, 'sensitive');
      assert.strictEqual(none.status, 400);
      assert.strictEqual(none.body.code, 'PASSKEY_NOT_REGISTERED');

      ctx.authenticator = await h.registerPasskey(ctx);
      const after = await request('GET', '/api/security', { token: ctx.token });
      assert.strictEqual(after.body.data.has_passkey, true);
    }],

    ['以通行密鑰驗證 sensitive 範圍，權杖記錄方法為 passkey', async () => {
      const ctx = await setup();
      const options = (await verifyOptions(ctx, 'sensitive')).body.data.options;
      assert.deepStrictEqual(options.allowCredentials.map((c) => c.id), [ctx.authenticator.id]);
      assert.strictEqual(options.userVerification, 'required');

      const token = await (async () => {
        const res = await verifyWith(ctx, 'sensitive', ctx.authenticator.get(options));
        assert.strictEqual(res.body.data.scope, 'sensitive');
        return res.body.data.verify_token;
      })();
      const decoded = security.consumeToken(token, { userId: ctx.user.user_id, sid: ctx.session.sid }, 'sensitive');
      assert.strictEqual(decoded.method, 'passkey');
      assert.ok(prisma.rows('user_passkeys')[0].last_used_at);
    }],

    ['通行密鑰簽發的權杖可通過 admin 範圍，後台端點照常放行；交易密碼簽發的仍被拒', async () => {
      const ctx = await setup({ role: 'admin' });
      prisma.rows('admin_permissions').push({ user_id: ctx.user.user_id, can_manage_system: true });
      const user = { userId: ctx.user.user_id, sid: ctx.session.sid };

      const token = await passkeyToken(ctx, 'admin');
      assert.strictEqual(security.consumeToken(token, user, 'admin').method, 'passkey');

      const bare = await request('PUT', '/api/admin/auth/settings', { token: ctx.token, body: {} });
      assert.strictEqual(bare.status, 403);
      assert.deepStrictEqual(bare.body.verification, { scope: 'admin', methods: ['password', 'passkey'] });

      const passed = await request('PUT', '/api/admin/auth/settings', { token: ctx.token, body: {}, headers: { 'x-verify-token': token } });
      assert.strictEqual(passed.status, 400, '通過身分驗證後才會檢查內容');
      assert.strictEqual(passed.body.message, '請提供 settings 設定內容');

      const pin = h.verifyTokenFor({ user: ctx.user, sid: ctx.session.sid, scope: 'admin', method: 'pin' });
      const denied = await request('PUT', '/api/admin/auth/settings', { token: ctx.token, body: {}, headers: { 'x-verify-token': pin } });
      assert.strictEqual(denied.status, 403);
      assert.strictEqual(denied.body.code, 'VERIFICATION_REQUIRED');
    }],

    ['範圍綁定：sensitive 的挑戰值不能換發 admin 權杖，反之亦然', async () => {
      const ctx = await setup();
      const sensitiveOptions = (await verifyOptions(ctx, 'sensitive')).body.data.options;
      const escalate = await verifyWith(ctx, 'admin', ctx.authenticator.get(sensitiveOptions));
      assert.strictEqual(escalate.status, 400);
      assert.strictEqual(escalate.body.code, 'PASSKEY_CHALLENGE_INVALID');

      const adminOptions = (await verifyOptions(ctx, 'admin')).body.data.options;
      const downgrade = await verifyWith(ctx, 'sensitive', ctx.authenticator.get(adminOptions));
      assert.strictEqual(downgrade.body.code, 'PASSKEY_CHALLENGE_INVALID');
    }],

    ['付款範圍不接受通行密鑰', async () => {
      const ctx = await setup();
      const options = await verifyOptions(ctx, 'payment');
      assert.strictEqual(options.status, 400);
      assert.strictEqual(options.body.message, '驗證範圍不正確');

      const res = await request('POST', '/api/security/verify', {
        token: ctx.token, body: { scope: 'payment', method: 'passkey', assertion: {} }
      });
      assert.strictEqual(res.status, 400);
      assert.strictEqual(res.body.message, '不支援此驗證方式');

      const forged = h.verifyTokenFor({ user: ctx.user, sid: ctx.session.sid, scope: 'payment', method: 'passkey' });
      assert.throws(
        () => security.consumeToken(forged, { userId: ctx.user.user_id, sid: ctx.session.sid }, 'payment'),
        (err) => err.code === 'VERIFICATION_REQUIRED'
      );
    }],

    ['只能用自己的通行密鑰驗證，也不能用他人的挑戰值', async () => {
      const owner = await setup();
      const intruder = await setup();

      const options = (await verifyOptions(intruder, 'sensitive')).body.data.options;
      const foreignKey = await verifyWith(intruder, 'sensitive', owner.authenticator.get(options));
      assert.strictEqual(foreignKey.status, 400);
      assert.strictEqual(foreignKey.body.code, 'PASSKEY_NOT_RECOGNIZED');

      const ownerOptions = (await verifyOptions(owner, 'sensitive')).body.data.options;
      const foreignChallenge = await verifyWith(intruder, 'sensitive', intruder.authenticator.get(ownerOptions));
      assert.strictEqual(foreignChallenge.body.code, 'PASSKEY_CHALLENGE_INVALID');
    }],

    ['登入用的挑戰值不能拿來驗證身分', async () => {
      const ctx = await setup();
      const loginOptions = (await request('POST', '/api/auth/passkeys/login/options', { body: {} })).body.data.options;
      const res = await verifyWith(ctx, 'sensitive', ctx.authenticator.get(loginOptions));
      assert.strictEqual(res.body.code, 'PASSKEY_CHALLENGE_INVALID');
    }],

    ['身分驗證同樣檢查來源、使用者驗證與計數倒退', async () => {
      const ctx = await setup();
      const origin = await verifyWith(ctx, 'sensitive', ctx.authenticator.get(
        (await verifyOptions(ctx, 'sensitive')).body.data.options, { origin: 'https://evil.example' }
      ));
      assert.strictEqual(origin.body.code, 'PASSKEY_VERIFICATION_FAILED');

      const uv = await verifyWith(ctx, 'sensitive', ctx.authenticator.get(
        (await verifyOptions(ctx, 'sensitive')).body.data.options, { userVerified: false }
      ));
      assert.strictEqual(uv.body.code, 'PASSKEY_VERIFICATION_FAILED');

      await passkeyToken(ctx, 'sensitive');
      const originalWarn = console.warn;
      console.warn = () => {};
      try {
        const regressed = await verifyWith(ctx, 'sensitive', ctx.authenticator.get(
          (await verifyOptions(ctx, 'sensitive')).body.data.options, { counter: 1 }
        ));
        assert.strictEqual(regressed.body.code, 'PASSKEY_COUNTER_REGRESSED');
      } finally {
        console.warn = originalWarn;
      }
    }],

    ['以通行密鑰驗證身分後即可刪除通行密鑰（全流程不使用密碼）', async () => {
      const ctx = await setup();
      await h.registerPasskey(ctx, { authenticator: new h.Authenticator(), label: 'iPad' });
      const token = await passkeyToken(ctx, 'sensitive');
      const list = await request('GET', '/api/users/me/passkeys', { token: ctx.token });
      const target = list.body.data[1].passkey_id;
      const res = await request('DELETE', `/api/users/me/passkeys/${target}`, { token: ctx.token, headers: { 'x-verify-token': token } });
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.body.data.length, 1);
    }]
  ]
};
