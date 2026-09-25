const assert = require('assert');
const h = require('./harness');

const LINE_PROFILE = { userId: 'line-user-1', displayName: 'LINE 使用者', pictureUrl: 'https://example.test/p.png' };
const DISCORD_ME = { id: 'discord-user-1', username: 'tester', global_name: 'Discord 使用者', email: 'discord@example.com', verified: true };

const lineIdToken = ({ email = 'line@example.com', sub = LINE_PROFILE.userId } = {}) => h.jwt.sign(
  { sub, email, name: LINE_PROFILE.displayName },
  process.env.LINE_CHANNEL_SECRET,
  { algorithm: 'HS256', audience: process.env.LINE_CHANNEL_ID, issuer: 'https://access.line.me', expiresIn: 600 }
);

let lineTokenBody = null;
let discordTokenBody = null;

h.onFetch('https://api.line.me/oauth2/v2.1/token', () => h.jsonResponse(lineTokenBody));
h.onFetch('https://api.line.me/v2/profile', () => h.jsonResponse(LINE_PROFILE));
h.onFetch('https://discord.com/api/oauth2/token', () => h.jsonResponse(discordTokenBody));
h.onFetch('https://discord.com/api/users/@me', () => h.jsonResponse(DISCORD_ME));

const enableAll = () => h.setAuthSettings({
  social_enabled: true,
  providers: {
    google: { enabled: true, signup: true },
    apple: { enabled: true, signup: true },
    phone: { enabled: true, signup: true },
    line: { enabled: true, signup: true },
    discord: { enabled: true, signup: true }
  }
});

const prepare = () => {
  enableAll();
  lineTokenBody = { access_token: 'line-access-token', id_token: lineIdToken() };
  discordTokenBody = { access_token: 'discord-access-token' };
};

const startLogin = (provider = 'line') => h.request('POST', `/api/auth/oauth/${provider}/start`, { body: { mode: 'login' } });

const callback = (provider, code, state) =>
  h.request('GET', `/api/auth/oauth/${provider}/callback?code=${encodeURIComponent(code)}&state=${encodeURIComponent(state)}`);

const exchange = (code, extra = {}) => h.request('POST', '/api/auth/oauth/exchange', { body: { code, ...extra } });

const deepLinkParams = (res) => {
  const location = res.headers.get('location');
  assert.ok(location?.startsWith('savemybook://auth/oauth?'), `導向網址不正確：${location}`);
  return new URLSearchParams(location.split('?')[1]);
};

const tests = [
  ['LINE 停用時無法開始授權', async () => {
    const res = await startLogin('line');
    assert.strictEqual(res.status, 403);
    assert.strictEqual(res.body.code, 'SIGN_IN_METHOD_DISABLED');
  }],

  ['start 產生授權網址與 state，並寫入 oauth_states', async () => {
    prepare();
    const res = await startLogin('line');
    assert.strictEqual(res.status, 200);
    assert.match(res.body.data.state, /^[0-9a-f]{32}$/);

    const url = new URL(res.body.data.url);
    assert.strictEqual(url.origin + url.pathname, 'https://access.line.me/oauth2/v2.1/authorize');
    assert.strictEqual(url.searchParams.get('client_id'), process.env.LINE_CHANNEL_ID);
    assert.strictEqual(url.searchParams.get('scope'), 'profile openid email');
    assert.strictEqual(url.searchParams.get('redirect_uri'), 'https://api.example.test/api/auth/oauth/line/callback');
    assert.ok(!res.body.data.url.includes(process.env.LINE_CHANNEL_SECRET), '授權網址不得含密鑰');
    assert.strictEqual(h.prisma.rows('oauth_states').length, 1);
    assert.strictEqual(h.prisma.rows('oauth_states')[0].mode, 'login');
  }],

  ['Discord 的授權網址採用自身的端點與 scope', async () => {
    prepare();
    const res = await startLogin('discord');
    const url = new URL(res.body.data.url);
    assert.strictEqual(url.origin + url.pathname, 'https://discord.com/oauth2/authorize');
    assert.strictEqual(url.searchParams.get('scope'), 'identify email');
  }],

  ['未知的 provider 回 400', async () => {
    prepare();
    const res = await h.request('POST', '/api/auth/oauth/github/start', { body: { mode: 'login' } });
    assert.strictEqual(res.status, 400);
  }],

  ['mode=link 需要登入', async () => {
    prepare();
    const res = await h.request('POST', '/api/auth/oauth/line/start', { body: { mode: 'link' } });
    assert.strictEqual(res.status, 401);
  }],

  ['完整登入流程：start → callback → exchange', async () => {
    prepare();
    const started = await startLogin('line');
    const state = started.body.data.state;

    const cb = await callback('line', 'auth-code-1', state);
    assert.strictEqual(cb.status, 302);
    const params = deepLinkParams(cb);
    const code = params.get('code');
    assert.match(code, /^[0-9a-f]{32}$/);
    assert.ok(!cb.text.includes(code), '回呼頁面內容不得含一次性碼');
    assert.strictEqual(params.get('error'), null);
    assert.strictEqual(h.prisma.rows('oauth_states').length, 0, 'state 應一次性消耗');

    // 尚未綁定任何帳號：先問使用者，不建立帳號，且一次性碼要留著給下一步
    const asked = await exchange(code);
    assert.strictEqual(asked.status, 404);
    assert.strictEqual(asked.body.code, 'NO_ACCOUNT_FOR_PROVIDER');
    assert.ok(asked.body.message.includes('LINE'));
    assert.strictEqual(h.prisma.rows('users').length, 0, '不得自動建立帳號');
    assert.strictEqual(h.prisma.rows('oauth_results').length, 1, '一次性碼要保留供使用者決定後再用');

    // 交換階段才建立工作階段並簽發 Token
    const exchanged = await exchange(code, { create: true, device_id: 'device-1', platform: 'ios' });
    assert.strictEqual(exchanged.status, 200);
    assert.strictEqual(exchanged.body.message, '登入成功');
    assert.ok(exchanged.body.data.token);

    const user = h.prisma.rows('users')[0];
    assert.strictEqual(user.email, 'line@example.com');
    assert.strictEqual(user.password_set, 0);
    assert.strictEqual(h.prisma.rows('user_identities')[0].provider, 'line');
    assert.strictEqual(h.prisma.rows('login_logs')[0].login_method, 'line');
  }],

  ['一次性碼用過即失效', async () => {
    prepare();
    const started = await startLogin('line');
    const cb = await callback('line', 'auth-code-2', started.body.data.state);
    const code = deepLinkParams(cb).get('code');

    const first = await exchange(code, { create: true });
    assert.strictEqual(first.status, 200);

    const second = await exchange(code, { create: true });
    assert.strictEqual(second.status, 400);
    assert.strictEqual(second.body.code, 'OAUTH_CODE_INVALID');
  }],

  ['一次性碼超過 5 分鐘即失效', async () => {
    prepare();
    const started = await startLogin('line');
    const cb = await callback('line', 'auth-code-3', started.body.data.state);
    const code = deepLinkParams(cb).get('code');

    h.prisma.rows('oauth_results')[0].created_at = new Date(Date.now() - 6 * 60 * 1000);
    const res = await exchange(code, { create: true });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.code, 'OAUTH_CODE_INVALID');
  }],

  ['state 超過 10 分鐘即失效', async () => {
    prepare();
    const started = await startLogin('line');
    h.prisma.rows('oauth_states')[0].created_at = new Date(Date.now() - 11 * 60 * 1000);

    const cb = await callback('line', 'auth-code-4', started.body.data.state);
    assert.strictEqual(deepLinkParams(cb).get('error'), 'OAUTH_STATE_INVALID');
  }],

  ['偽造或重複使用的 state 一律拒絕', async () => {
    prepare();
    const started = await startLogin('line');
    const state = started.body.data.state;

    const forged = await callback('line', 'auth-code-5', 'f'.repeat(32));
    assert.strictEqual(deepLinkParams(forged).get('error'), 'OAUTH_STATE_INVALID');

    await callback('line', 'auth-code-5', state);
    const replay = await callback('line', 'auth-code-5', state);
    assert.strictEqual(deepLinkParams(replay).get('error'), 'OAUTH_STATE_INVALID');
  }],

  ['在別的渠道使用他人的 state 會被拒絕', async () => {
    prepare();
    const started = await startLogin('line');
    const cb = await callback('discord', 'auth-code-6', started.body.data.state);
    assert.strictEqual(deepLinkParams(cb).get('error'), 'OAUTH_STATE_INVALID');
  }],

  ['選擇建立帳號時電子郵件已註冊回 409 ACCOUNT_EXISTS_LINK_REQUIRED，一次性碼保留給登入並綁定', async () => {
    prepare();
    h.addUser({ email: 'line@example.com' });
    const started = await startLogin('line');
    const cb = await callback('line', 'auth-code-7', started.body.data.state);
    const code = deepLinkParams(cb).get('code');

    const res = await exchange(code, { create: true });
    assert.strictEqual(res.status, 409);
    assert.strictEqual(res.body.code, 'ACCOUNT_EXISTS_LINK_REQUIRED');
    assert.strictEqual(res.body.provider_email, 'line@example.com');
    assert.strictEqual(h.prisma.rows('oauth_results').length, 1, '使用者可改為登入既有帳號並綁定，不必重新授權');
  }],

  ['不允許直接註冊時選擇建立帳號回 403 SIGNUP_NOT_ALLOWED', async () => {
    prepare();
    h.setAuthSettings({ social_enabled: true, providers: { line: { enabled: true, signup: false } } });
    const started = await startLogin('line');
    const cb = await callback('line', 'auth-code-8', started.body.data.state);
    const code = deepLinkParams(cb).get('code');

    const res = await exchange(code, { create: true });
    assert.strictEqual(res.status, 403);
    assert.strictEqual(res.body.code, 'SIGNUP_NOT_ALLOWED');
  }],

  ['LINE 未提供 Email 時回 400 EMAIL_REQUIRED，補送後以同一組碼建立帳號', async () => {
    prepare();
    lineTokenBody = { access_token: 'line-access-token', id_token: '' };
    const started = await startLogin('line');
    const cb = await callback('line', 'auth-code-9', started.body.data.state);
    assert.strictEqual(deepLinkParams(cb).get('error'), null, '缺電子郵件不再是回呼階段的錯誤');
    const code = deepLinkParams(cb).get('code');

    const first = await exchange(code, { create: true });
    assert.strictEqual(first.status, 400);
    assert.strictEqual(first.body.code, 'EMAIL_REQUIRED');
    assert.strictEqual(h.prisma.rows('oauth_results').length, 1, '補資料期間一次性碼要留著');

    const second = await exchange(code, { create: true, email: 'Line-New@Example.com', nickname: '阿線' });
    assert.strictEqual(second.status, 200);
    assert.strictEqual(h.prisma.rows('users')[0].email, 'line-new@example.com');
  }],

  ['未綁定時取消登入不留下任何帳號', async () => {
    prepare();
    const started = await startLogin('discord');
    const cb = await callback('discord', 'auth-code-9b', started.body.data.state);
    const code = deepLinkParams(cb).get('code');

    const asked = await exchange(code);
    assert.strictEqual(asked.status, 404);
    assert.strictEqual(asked.body.code, 'NO_ACCOUNT_FOR_PROVIDER');
    assert.strictEqual(h.prisma.rows('users').length, 0);
    assert.strictEqual(h.prisma.rows('user_identities').length, 0);
  }],

  ['第三方交換失敗時回呼帶 AUTH_PROVIDER_ERROR', async () => {
    prepare();
    const started = await startLogin('discord');
    discordTokenBody = null;
    const cb = await callback('discord', 'auth-code-10', started.body.data.state);
    assert.strictEqual(deepLinkParams(cb).get('error'), 'AUTH_PROVIDER_ERROR');
  }],

  ['Discord 登入建立帳號並採用全域名稱', async () => {
    prepare();
    const started = await startLogin('discord');
    const cb = await callback('discord', 'auth-code-11', started.body.data.state);
    const code = deepLinkParams(cb).get('code');
    const exchanged = await exchange(code, { create: true });

    assert.strictEqual(exchanged.status, 200);
    const user = h.prisma.rows('users')[0];
    assert.strictEqual(user.email, 'discord@example.com');
    assert.strictEqual(user.nickname, 'Discord 使用者');
  }],

  ['mode=link 完成綁定，exchange 回傳 linked', async () => {
    prepare();
    const user = h.addUser({ email: 'linkme@example.com' });
    const token = h.tokenFor(user);

    const started = await h.request('POST', '/api/auth/oauth/line/start', {
      token, headers: h.verifyHeaders(user), body: { mode: 'link' }
    });
    assert.strictEqual(started.status, 200);
    assert.strictEqual(h.prisma.rows('oauth_states')[0].mode, 'link');

    const cb = await callback('line', 'auth-code-12', started.body.data.state);
    const code = deepLinkParams(cb).get('code');

    const exchanged = await exchange(code);
    assert.strictEqual(exchanged.status, 200);
    assert.deepStrictEqual(exchanged.body.data, { linked: true, provider: 'line' });
    assert.strictEqual(h.prisma.rows('user_identities').length, 1);
    assert.strictEqual(h.prisma.rows('user_identities')[0].user_id, user.user_id);
  }],

  ['綁定至已被他人使用的第三方帳號時回呼帶 IDENTITY_TAKEN', async () => {
    prepare();
    const owner = h.addUser({ email: 'owner-line@example.com' });
    h.addIdentity({ userId: owner.user_id, provider: 'line', subject: LINE_PROFILE.userId });
    const other = h.addUser({ email: 'other-line@example.com' });

    const started = await h.request('POST', '/api/auth/oauth/line/start', {
      token: h.tokenFor(other), headers: h.verifyHeaders(other), body: { mode: 'link' }
    });
    const cb = await callback('line', 'auth-code-13', started.body.data.state);
    assert.strictEqual(deepLinkParams(cb).get('error'), 'IDENTITY_TAKEN');
  }],

  ['既有 identity 直接登入，不會重複建立帳號', async () => {
    prepare();
    const user = h.addUser({ email: 'line-known@example.com' });
    h.addIdentity({ userId: user.user_id, provider: 'line', subject: LINE_PROFILE.userId });

    const started = await startLogin('line');
    const cb = await callback('line', 'auth-code-14', started.body.data.state);
    const code = deepLinkParams(cb).get('code');
    const exchanged = await exchange(code);

    assert.strictEqual(exchanged.status, 200);
    assert.strictEqual(h.prisma.rows('users').length, 1);
  }],

  ['交換時帳號已停權則拒絕登入', async () => {
    prepare();
    const user = h.addUser({ email: 'line-block@example.com' });
    h.addIdentity({ userId: user.user_id, provider: 'line', subject: LINE_PROFILE.userId });

    const started = await startLogin('line');
    const cb = await callback('line', 'auth-code-15', started.body.data.state);
    const code = deepLinkParams(cb).get('code');

    user.is_active = false;
    const exchanged = await exchange(code);
    assert.strictEqual(exchanged.status, 403);
    assert.strictEqual(exchanged.body.code, 'ACCOUNT_INACTIVE');
  }],

  ['排程清理逾期的 state 與一次性碼', async () => {
    prepare();
    const oauth = h.api('services/oauth-providers');
    h.prisma.rows('oauth_states').push(
      { state: 'a'.repeat(32), provider: 'line', mode: 'login', user_id: null, created_at: new Date(Date.now() - 20 * 60 * 1000) },
      { state: 'b'.repeat(32), provider: 'line', mode: 'login', user_id: null, created_at: new Date() }
    );
    h.prisma.rows('oauth_results').push(
      { code: 'c'.repeat(32), payload: '{}', created_at: new Date(Date.now() - 20 * 60 * 1000) },
      { code: 'd'.repeat(32), payload: '{}', created_at: new Date() }
    );

    await oauth.cleanupExpired();
    assert.deepStrictEqual(h.prisma.rows('oauth_states').map((r) => r.state), ['b'.repeat(32)]);
    assert.deepStrictEqual(h.prisma.rows('oauth_results').map((r) => r.code), ['d'.repeat(32)]);
  }]
];

module.exports = { name: 'LINE／Discord OAuth', tests };

if (require.main === module) {
  h.runSuite(module.exports.name, tests).then((r) => {
    h.close();
    process.exit(r.failures.length ? 1 : 0);
  });
}
