const assert = require('assert');
const h = require('./harness');

const { prisma, request } = h;

const pendingLineCode = () => {
  const code = 'b'.repeat(32);
  prisma.rows('oauth_results').push({
    code,
    payload: JSON.stringify({
      kind: 'signup',
      provider: 'line',
      info: { subject: 'line-pk-1', email: 'line@example.com', emailVerified: true, phoneNumber: null, displayName: 'LINE' }
    }),
    created_at: new Date()
  });
  prisma.store.auth_settings = [{
    id: 1, config: JSON.stringify({ social_enabled: true, providers: { line: { enabled: true, signup: true } } }), updated_at: new Date()
  }];
  return code;
};

module.exports = {
  name: '通行密鑰：登入既有帳號並綁定',
  tests: [
    ['以通行密鑰登入並綁定 LINE，不需另外驗證身分', async () => {
      const ctx = h.signedIn({ passwordSet: 0 });
      const authenticator = await h.registerPasskey(ctx);
      const code = pendingLineCode();

      const options = (await request('POST', '/api/auth/passkeys/login/options', { body: {} })).body.data.options;
      const res = await request('POST', '/api/auth/social/link-login', {
        body: { code, assertion: authenticator.get(options), device_id: 'device-2', platform: 'android' }
      });
      assert.strictEqual(res.status, 200, res.text);
      assert.deepStrictEqual(Object.keys(res.body.data), ['token']);
      assert.strictEqual(h.authToken.verify(res.body.data.token).userId, ctx.user.user_id);

      const [identity] = prisma.rows('user_identities');
      assert.strictEqual(identity.provider, 'line');
      assert.strictEqual(Number(identity.user_id), ctx.user.user_id);
      assert.strictEqual(prisma.rows('login_logs').at(-1).login_method, 'passkey');
      assert.strictEqual(prisma.rows('oauth_results').length, 0);
    }],

    ['通行密鑰驗證失敗時不綁定，一次性碼保留可再試', async () => {
      const ctx = h.signedIn();
      const authenticator = await h.registerPasskey(ctx);
      const code = pendingLineCode();

      const options = (await request('POST', '/api/auth/passkeys/login/options', { body: {} })).body.data.options;
      const res = await request('POST', '/api/auth/social/link-login', {
        body: { code, assertion: authenticator.get(options, { signWith: new h.Authenticator().privateKey }) }
      });
      assert.strictEqual(res.body.code, 'PASSKEY_VERIFICATION_FAILED');
      assert.strictEqual(prisma.rows('user_identities').length, 0);
      assert.strictEqual(prisma.rows('oauth_results').length, 1);
    }]
  ]
};
