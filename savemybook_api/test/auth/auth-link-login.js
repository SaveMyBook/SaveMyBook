const assert = require('assert');
const h = require('./harness');

const PASSWORD = 'Passw0rd123';

const enableAll = () => h.setAuthSettings({
  social_enabled: true,
  providers: Object.fromEntries(['google', 'apple', 'phone', 'line', 'discord'].map((id) => [id, { enabled: true, signup: true }]))
});

const linkLogin = (body) => h.request('POST', '/api/auth/social/link-login', {
  body: { device_id: 'device-9', device_name: 'iPhone 17', platform: 'ios', ...body }
});

const googleToken = (sub = 'g-link-1', email = 'google-link@example.com') => h.firebaseToken({ sub, email, name: '小華' });

const authToken = h.api('lib/auth-token');

let codeSeq = 0;
const lineCode = async ({ email = 'line-link@example.com' } = {}) => {
  codeSeq += 1;
  const code = codeSeq.toString(16).padStart(32, '0');
  h.prisma.rows('oauth_results').push({
    code,
    payload: JSON.stringify({
      kind: 'signup',
      provider: 'line',
      info: { subject: 'line-link-1', email, emailVerified: true, phoneNumber: null, displayName: 'LINE 使用者' }
    }),
    created_at: new Date()
  });
  return code;
};

const tests = [
  ['NO_ACCOUNT_FOR_PROVIDER 附帶第三方電子郵件供預填', async () => {
    const res = await h.request('POST', '/api/auth/social', { body: { provider: 'google', id_token: googleToken() } });
    assert.strictEqual(res.status, 404);
    assert.strictEqual(res.body.code, 'NO_ACCOUNT_FOR_PROVIDER');
    assert.strictEqual(res.body.provider_email, 'google-link@example.com');
  }],

  ['以密碼登入並綁定 Google：回應與密碼登入相同，寫入綁定、登入紀錄與通知', async () => {
    const user = h.addUser({ email: 'member@example.com', password: PASSWORD });
    const res = await linkLogin({ provider: 'google', id_token: googleToken(), email: 'member@example.com', password: PASSWORD });
    assert.strictEqual(res.status, 200, res.text);
    assert.strictEqual(res.body.message, '登入成功');
    assert.deepStrictEqual(Object.keys(res.body.data), ['token']);
    assert.strictEqual(authToken.verify(res.body.data.token).userId, user.user_id);

    const [identity] = h.prisma.rows('user_identities');
    assert.strictEqual(Number(identity.user_id), user.user_id);
    assert.strictEqual(identity.provider, 'google');
    assert.strictEqual(identity.subject, 'g-link-1');
    const [log] = h.prisma.rows('login_logs');
    assert.strictEqual(Number(log.user_id), user.user_id);
    assert.strictEqual(log.login_method, 'password');
    assert.ok(h.prisma.rows('notifications').some((n) => n.title === '已綁定登入方式' && n.content.includes('Google')));

    const again = await h.request('POST', '/api/auth/social', { body: { provider: 'google', id_token: googleToken() } });
    assert.strictEqual(again.status, 200, '綁定後可直接以 Google 登入');
  }],

  ['密碼錯誤回 401 INVALID_PASSWORD 且不寫入任何資料；Email 不存在回 ACCOUNT_NOT_FOUND', async () => {
    h.addUser({ email: 'member@example.com', password: PASSWORD });
    const wrong = await linkLogin({ provider: 'google', id_token: googleToken(), email: 'member@example.com', password: 'nope1234' });
    assert.strictEqual(wrong.status, 401);
    assert.strictEqual(wrong.body.code, 'INVALID_PASSWORD');
    const missing = await linkLogin({ provider: 'google', id_token: googleToken(), email: 'ghost@example.com', password: PASSWORD });
    assert.strictEqual(missing.status, 404);
    assert.strictEqual(missing.body.code, 'ACCOUNT_NOT_FOUND');
    assert.strictEqual(h.prisma.rows('user_identities').length, 0);
    assert.strictEqual(h.prisma.rows('login_logs').length, 0);
    assert.strictEqual(h.prisma.rows('notifications').length, 0);
  }],

  ['缺少帳號憑證或第三方憑證回 400', async () => {
    const noPassword = await linkLogin({ provider: 'google', id_token: googleToken(), email: 'member@example.com' });
    assert.strictEqual(noPassword.status, 400);
    const noToken = await linkLogin({ provider: 'google', email: 'member@example.com', password: PASSWORD });
    assert.strictEqual(noToken.status, 400);
    const badProvider = await linkLogin({ provider: 'line', id_token: googleToken(), email: 'member@example.com', password: PASSWORD });
    assert.strictEqual(badProvider.status, 400);
  }],

  ['與登入共用 IP＋Email 的嘗試次數上限', async () => {
    h.addUser({ email: 'member@example.com', password: PASSWORD });
    const statuses = [];
    for (let i = 0; i < 11; i += 1) {
      const res = await linkLogin({ provider: 'google', id_token: googleToken(), email: 'member@example.com', password: `wrong${i}pass` });
      statuses.push(res.status);
    }
    assert.deepStrictEqual(statuses.slice(0, 10), Array(10).fill(401));
    assert.strictEqual(statuses[10], 429);
    const res = await h.request('POST', '/api/auth/login', { body: { email: 'member@example.com', password: PASSWORD } });
    assert.strictEqual(res.status, 429, '改走一般登入也不能繞過上限');
  }],

  ['第三方身分已綁定其他帳號回 409 IDENTITY_TAKEN', async () => {
    const other = h.addUser({ email: 'other@example.com' });
    h.addIdentity({ userId: other.user_id, provider: 'google', subject: 'g-link-1' });
    h.addUser({ email: 'member@example.com', password: PASSWORD });
    const res = await linkLogin({ provider: 'google', id_token: googleToken(), email: 'member@example.com', password: PASSWORD });
    assert.strictEqual(res.status, 409);
    assert.strictEqual(res.body.code, 'IDENTITY_TAKEN');
    assert.strictEqual(h.prisma.rows('login_logs').length, 0);
  }],

  ['帳號已綁定另一個 Google 身分回 409 ALREADY_LINKED；同一組身分已綁定本帳號時直接登入', async () => {
    const user = h.addUser({ email: 'member@example.com', password: PASSWORD });
    h.addIdentity({ userId: user.user_id, provider: 'google', subject: 'g-other' });
    const res = await linkLogin({ provider: 'google', id_token: googleToken(), email: 'member@example.com', password: PASSWORD });
    assert.strictEqual(res.status, 409);
    assert.strictEqual(res.body.code, 'ALREADY_LINKED');

    const same = await linkLogin({ provider: 'google', id_token: googleToken('g-other'), email: 'member@example.com', password: PASSWORD });
    assert.strictEqual(same.status, 200);
    assert.strictEqual(h.prisma.rows('user_identities').length, 1);
  }],

  ['渠道停用時回 403，停權帳號回 403 ACCOUNT_INACTIVE', async () => {
    h.setAuthSettings({ social_enabled: true, providers: { google: { enabled: false, signup: true } } });
    h.addUser({ email: 'member@example.com', password: PASSWORD });
    const disabled = await linkLogin({ provider: 'google', id_token: googleToken(), email: 'member@example.com', password: PASSWORD });
    assert.strictEqual(disabled.body.code, 'SIGN_IN_METHOD_DISABLED');

    enableAll();
    h.addUser({ email: 'inactive@example.com', password: PASSWORD, isActive: false });
    const inactive = await linkLogin({ provider: 'google', id_token: googleToken(), email: 'inactive@example.com', password: PASSWORD });
    assert.strictEqual(inactive.status, 403);
    assert.strictEqual(inactive.body.code, 'ACCOUNT_INACTIVE');
    assert.strictEqual(h.prisma.rows('user_identities').length, 0);
  }],

  ['LINE：同一組一次性碼在密碼錯誤後仍可使用，成功後作廢', async () => {
    enableAll();
    const user = h.addUser({ email: 'member@example.com', password: PASSWORD });
    const code = await lineCode();

    const asked = await h.request('POST', '/api/auth/oauth/exchange', { body: { code } });
    assert.strictEqual(asked.body.code, 'NO_ACCOUNT_FOR_PROVIDER');
    assert.strictEqual(asked.body.provider_email, 'line-link@example.com');

    const wrong = await linkLogin({ code, email: 'member@example.com', password: 'wrong-pass1' });
    assert.strictEqual(wrong.body.code, 'INVALID_PASSWORD');
    assert.strictEqual(h.prisma.rows('oauth_results').length, 1);

    const ok = await linkLogin({ code, email: 'member@example.com', password: PASSWORD });
    assert.strictEqual(ok.status, 200, ok.text);
    assert.strictEqual(h.prisma.rows('user_identities')[0].provider, 'line');
    assert.strictEqual(Number(h.prisma.rows('user_identities')[0].user_id), user.user_id);
    assert.strictEqual(h.prisma.rows('oauth_results').length, 0);

    const replay = await linkLogin({ code, email: 'member@example.com', password: PASSWORD });
    assert.strictEqual(replay.body.code, 'OAUTH_CODE_INVALID');
  }],

  ['LINE：建立帳號時電子郵件已註冊（409）後，以同一組碼登入並綁定', async () => {
    enableAll();
    h.addUser({ email: 'member@example.com', password: PASSWORD });
    const code = await lineCode({ email: 'member@example.com' });
    const conflict = await h.request('POST', '/api/auth/oauth/exchange', { body: { code, create: true } });
    assert.strictEqual(conflict.body.code, 'ACCOUNT_EXISTS_LINK_REQUIRED');

    const ok = await linkLogin({ code, email: 'member@example.com', password: PASSWORD });
    assert.strictEqual(ok.status, 200, ok.text);
    assert.strictEqual(h.prisma.rows('users').length, 1, '不得建立新帳號');
  }],

  ['一次性碼的 provider 與請求不符回 PROVIDER_MISMATCH；綁定用的碼不能拿來登入並綁定', async () => {
    enableAll();
    h.addUser({ email: 'member@example.com', password: PASSWORD });
    const code = await lineCode();
    const mismatch = await linkLogin({ provider: 'discord', code, email: 'member@example.com', password: PASSWORD });
    assert.strictEqual(mismatch.body.code, 'PROVIDER_MISMATCH');

    h.prisma.rows('oauth_results').push({
      code: 'a'.repeat(32), payload: JSON.stringify({ kind: 'login', provider: 'line', user_id: 1 }), created_at: new Date()
    });
    const wrongKind = await linkLogin({ code: 'a'.repeat(32), email: 'member@example.com', password: PASSWORD });
    assert.strictEqual(wrongKind.body.code, 'OAUTH_CODE_INVALID');
  }],

  ['未執行 014 時回 503', async () => {
    h.reset({ schema: h.withoutSessions(h.withoutAuthMigration()) });
    const res = await linkLogin({ provider: 'google', id_token: googleToken(), email: 'member@example.com', password: PASSWORD });
    assert.strictEqual(res.status, 503);
    assert.strictEqual(res.body.code, 'AUTH_SOCIAL_UNAVAILABLE');
  }]
];

module.exports = { name: '登入既有帳號並綁定', tests };
