const assert = require('assert');
const h = require('./harness');

const { prisma, request } = h;

const loginOptions = async (body = {}) => request('POST', '/api/auth/passkeys/login/options', { body });

const login = (assertion, extra = {}) => request('POST', '/api/auth/passkeys/login', {
  body: { assertion, device_id: 'device-1', device_name: 'iPhone 17', platform: 'ios', app_version: '1.0.3', ...extra }
});

const setup = async () => {
  const ctx = h.signedIn();
  const authenticator = await h.registerPasskey(ctx);
  prisma.store.notifications = [];
  return { ...ctx, authenticator };
};

module.exports = {
  name: '通行密鑰：登入',
  tests: [
    ['伺服器已啟用時 status 回報 enabled', async () => {
      const res = await request('GET', '/api/auth/passkeys/status');
      assert.deepStrictEqual(res.body, { success: true, data: { enabled: true } });
    }],

    ['探索式登入：回應結構與密碼登入相同，登入紀錄記為 passkey', async () => {
      const { user, authenticator } = await setup();
      const options = (await loginOptions()).body.data.options;
      assert.deepStrictEqual(options.allowCredentials, []);
      assert.strictEqual(options.userVerification, 'required');
      assert.strictEqual(options.rpId, 'savemybook.today');

      const res = await login(authenticator.get(options));
      assert.strictEqual(res.status, 200);
      assert.deepStrictEqual(Object.keys(res.body).sort(), ['data', 'message', 'success']);
      assert.strictEqual(res.body.message, '登入成功');
      assert.deepStrictEqual(Object.keys(res.body.data), ['token']);

      const decoded = h.authToken.verify(res.body.data.token);
      assert.strictEqual(decoded.userId, user.user_id);
      assert.ok(decoded.sid, '登入須建立裝置工作階段');

      const [log] = prisma.rows('login_logs');
      assert.strictEqual(log.login_method, 'passkey');
      assert.strictEqual(Number(log.user_id), user.user_id);

      const [row] = prisma.rows('user_passkeys');
      assert.strictEqual(Number(row.sign_count), 1);
      assert.ok(row.last_used_at);

      const me = await request('GET', '/api/auth/me', { token: res.body.data.token });
      assert.strictEqual(me.body.data.email, user.email);
    }],

    ['帶 Email 時只回傳該帳號的憑證', async () => {
      const { user, authenticator } = await setup();
      const options = (await loginOptions({ email: user.email })).body.data.options;
      assert.deepStrictEqual(options.allowCredentials.map((c) => c.id), [authenticator.id]);
      assert.strictEqual((await login(authenticator.get(options))).status, 200);
    }],

    ['帳號列舉防護：查無帳號與沒有通行密鑰的帳號都回傳固定的假憑證', async () => {
      const plain = h.addUser({ email: 'plain@example.com' });
      const unknown = (await loginOptions({ email: 'nobody@example.com' })).body.data.options;
      const again = (await loginOptions({ email: 'nobody@example.com' })).body.data.options;
      const noPasskey = (await loginOptions({ email: plain.email })).body.data.options;

      assert.strictEqual(unknown.allowCredentials.length, 1);
      assert.strictEqual(noPasskey.allowCredentials.length, 1);
      assert.deepStrictEqual(Object.keys(unknown).sort(), Object.keys(noPasskey).sort());
      assert.deepStrictEqual(unknown.allowCredentials, again.allowCredentials, '同一個 Email 每次都回傳同一組假憑證');
      assert.notDeepStrictEqual(unknown.allowCredentials, noPasskey.allowCredentials);
      assert.strictEqual(unknown.allowCredentials[0].id.length, 43);
      assert.strictEqual(prisma.rows('webauthn_challenges').length, 3, '假回應同樣會建立挑戰值');

      const bad = await loginOptions({ email: 'not-an-email' });
      assert.strictEqual(bad.status, 400);
    }],

    ['挑戰值只能使用一次', async () => {
      const { authenticator } = await setup();
      const options = (await loginOptions()).body.data.options;
      assert.strictEqual((await login(authenticator.get(options))).status, 200);
      const replay = await login(authenticator.get(options));
      assert.strictEqual(replay.status, 400);
      assert.strictEqual(replay.body.code, 'PASSKEY_CHALLENGE_INVALID');
    }],

    ['系統視窗開到逾時前一刻才完成，挑戰值仍然有效', async () => {
      const { authenticator } = await setup();
      const options = (await loginOptions()).body.data.options;
      assert.strictEqual(options.timeout, 5 * 60 * 1000);
      prisma.rows('webauthn_challenges')[0].created_at = new Date(Date.now() - options.timeout - 30 * 1000);
      await h.api('services/passkeys').cleanupExpired();
      const res = await login(authenticator.get(options));
      assert.strictEqual(res.status, 200, res.text);
    }],

    ['挑戰值超過 10 分鐘即失效，且逾時的挑戰值同樣被刪除', async () => {
      const { authenticator } = await setup();
      const options = (await loginOptions()).body.data.options;
      prisma.rows('webauthn_challenges')[0].created_at = new Date(Date.now() - 10 * 60 * 1000 - 1000);
      const res = await login(authenticator.get(options));
      assert.strictEqual(res.status, 400);
      assert.strictEqual(res.body.code, 'PASSKEY_CHALLENGE_EXPIRED');
      assert.strictEqual(prisma.rows('webauthn_challenges').length, 0);
    }],

    ['排程清理會刪除逾時的挑戰值', async () => {
      await loginOptions();
      await loginOptions();
      prisma.rows('webauthn_challenges')[0].created_at = new Date(Date.now() - 11 * 60 * 1000);
      await h.api('services/passkeys').cleanupExpired();
      assert.strictEqual(prisma.rows('webauthn_challenges').length, 1);
    }],

    ['用途不符：註冊或身分驗證取得的挑戰值不能用來登入', async () => {
      const ctx = await setup();
      const registerOptions = (await request('POST', '/api/users/me/passkeys/options', { token: ctx.token })).body.data.options;
      const asRegister = await login(ctx.authenticator.get(registerOptions));
      assert.strictEqual(asRegister.status, 400);
      assert.strictEqual(asRegister.body.code, 'PASSKEY_CHALLENGE_INVALID');

      const verifyOptions = (await request('POST', '/api/security/verify/passkey/options', {
        token: ctx.token, body: { scope: 'sensitive' }
      })).body.data.options;
      const asVerify = await login(ctx.authenticator.get(verifyOptions));
      assert.strictEqual(asVerify.body.code, 'PASSKEY_CHALLENGE_INVALID');
    }],

    ['自行捏造的挑戰值（未由伺服器簽發）不被接受', async () => {
      const { authenticator } = await setup();
      const forged = 'A'.repeat(64);
      prisma.rows('webauthn_challenges').push({ challenge: forged, user_id: null, purpose: 'login', created_at: new Date() });
      const res = await login(authenticator.get({ challenge: forged }));
      assert.strictEqual(res.body.code, 'PASSKEY_CHALLENGE_INVALID');
    }],

    ['來源、RP ID、使用者驗證或簽章不符時拒絕', async () => {
      const { authenticator } = await setup();
      const other = new h.Authenticator();
      const cases = [
        { origin: 'https://savemybook.today.evil.example' },
        { origin: 'https://api.savemybook.today.evil.example' },
        { rpId: 'evil.example' },
        { userVerified: false },
        { signWith: other.privateKey }
      ];
      for (const override of cases) {
        const options = (await loginOptions()).body.data.options;
        const res = await login(authenticator.get(options, { ...override, counter: 100 }));
        assert.strictEqual(res.status, 400, Object.keys(override)[0]);
        assert.strictEqual(res.body.code, 'PASSKEY_VERIFICATION_FAILED', Object.keys(override)[0]);
      }
      assert.strictEqual(Number(prisma.rows('user_passkeys')[0].sign_count), 0, '失敗的驗證不更新計數');
      assert.strictEqual(prisma.rows('login_logs').length, 0);
    }],

    ['簽章計數倒退時拒絕、記錄並通知本人；計數維持 0 的驗證器照常可用', async () => {
      const { user, authenticator } = await setup();
      assert.strictEqual((await login(authenticator.get((await loginOptions()).body.data.options, { counter: 5 }))).status, 200);

      const warnings = [];
      const originalWarn = console.warn;
      console.warn = (message) => warnings.push(message);
      let res;
      try {
        res = await login(authenticator.get((await loginOptions()).body.data.options, { counter: 5 }));
      } finally {
        console.warn = originalWarn;
      }
      assert.strictEqual(res.status, 400);
      assert.strictEqual(res.body.code, 'PASSKEY_COUNTER_REGRESSED');
      assert.ok(warnings.some((w) => w.includes('簽章計數倒退')));
      const notice = prisma.rows('notifications').find((n) => n.title === '通行密鑰驗證異常');
      assert.strictEqual(Number(notice.user_id), user.user_id);
      assert.strictEqual(Number(prisma.rows('user_passkeys')[0].sign_count), 5);

      // iCloud 鑰匙圈等同步型通行密鑰的計數固定為 0。
      const synced = h.signedIn();
      const zero = await h.registerPasskey(synced);
      for (let i = 0; i < 2; i += 1) {
        const ok = await login(zero.get((await loginOptions()).body.data.options, { counter: 0 }));
        assert.strictEqual(ok.status, 200);
      }
    }],

    ['偽造簽章不會觸發計數異常通知', async () => {
      const { authenticator } = await setup();
      const res = await login(authenticator.get((await loginOptions()).body.data.options, {
        counter: 0, signWith: new h.Authenticator().privateKey
      }));
      assert.strictEqual(res.body.code, 'PASSKEY_VERIFICATION_FAILED');
      assert.strictEqual(prisma.rows('notifications').length, 0);
    }],

    ['已刪除的憑證、userHandle 不符都回 PASSKEY_NOT_RECOGNIZED', async () => {
      const { authenticator } = await setup();
      const stranger = new h.Authenticator();
      stranger.userHandle = authenticator.userHandle;
      const unknown = await login(stranger.get((await loginOptions()).body.data.options));
      assert.strictEqual(unknown.body.code, 'PASSKEY_NOT_RECOGNIZED');

      const otherUser = h.signedIn();
      const mismatch = await login(authenticator.get((await loginOptions()).body.data.options, {
        userHandle: h.api('lib/webauthn').userHandleText(otherUser.user.user_id)
      }));
      assert.strictEqual(mismatch.body.code, 'PASSKEY_NOT_RECOGNIZED');
    }],

    ['停權帳號無法以通行密鑰登入', async () => {
      const { user, authenticator } = await setup();
      user.is_active = false;
      const res = await login(authenticator.get((await loginOptions()).body.data.options));
      assert.strictEqual(res.status, 403);
      assert.strictEqual(res.body.code, 'ACCOUNT_INACTIVE');
    }],

    ['申請刪除中的帳號登入後帶回 pending_deletion', async () => {
      const { user, authenticator } = await setup();
      user.deletion_requested_at = new Date();
      const res = await login(authenticator.get((await loginOptions()).body.data.options));
      assert.strictEqual(res.status, 200);
      assert.ok(res.body.data.pending_deletion.purge_at);
    }],

    ['未設定 RP ID 時所有通行密鑰端點回 503 PASSKEY_UNAVAILABLE，status 回報停用', async () => {
      const { env } = h.api('config/env');
      const rpId = env.passkeyRpId;
      env.passkeyRpId = '';
      try {
        const ctx = h.signedIn();
        const status = await request('GET', '/api/auth/passkeys/status');
        assert.strictEqual(status.body.data.enabled, false);

        const calls = [
          request('POST', '/api/auth/passkeys/login/options', { body: {} }),
          request('POST', '/api/auth/passkeys/login', { body: { assertion: {} } }),
          request('GET', '/api/users/me/passkeys', { token: ctx.token }),
          request('POST', '/api/users/me/passkeys/options', { token: ctx.token }),
          request('POST', '/api/users/me/passkeys', { token: ctx.token, headers: h.sensitive(ctx), body: { attestation: {} } }),
          request('DELETE', '/api/users/me/passkeys/PK0000000', { token: ctx.token, headers: h.sensitive(ctx) }),
          request('POST', '/api/security/verify/passkey/options', { token: ctx.token, body: { scope: 'sensitive' } }),
          request('POST', '/api/security/verify', { token: ctx.token, body: { scope: 'sensitive', method: 'passkey', assertion: {} } })
        ];
        for (const res of await Promise.all(calls)) {
          assert.strictEqual(res.status, 503, res.text);
          assert.strictEqual(res.body.code, 'PASSKEY_UNAVAILABLE');
        }
        assert.strictEqual(prisma.sqlLog.some((sql) => /user_passkeys|webauthn_challenges/.test(sql)), false);

        const security = await request('GET', '/api/security', { token: ctx.token });
        assert.strictEqual(security.body.data.passkey_available, false);
        assert.strictEqual(security.body.data.has_passkey, false);
      } finally {
        env.passkeyRpId = rpId;
      }
    }]
  ]
};
