const assert = require('assert');
const h = require('./harness');

const social = (body) => h.request('POST', '/api/auth/social', { body });

const tests = [
  ['GET /api/auth/providers 列出各渠道狀態', async () => {
    const res = await h.request('GET', '/api/auth/providers');
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.data.social_enabled, true);
    const ids = res.body.data.providers.map((p) => p.id);
    assert.deepStrictEqual(ids, ['google', 'apple', 'phone', 'line', 'discord']);
    const google = res.body.data.providers.find((p) => p.id === 'google');
    assert.deepStrictEqual(google, { id: 'google', enabled: true, signup: true, configured: true });
    // 預設 LINE 關閉但憑證已設定
    const line = res.body.data.providers.find((p) => p.id === 'line');
    assert.strictEqual(line.enabled, false);
    assert.strictEqual(line.configured, true);
  }],

  ['未帶 create 時不建立帳號，回 404 NO_ACCOUNT_FOR_PROVIDER', async () => {
    const res = await social({
      provider: 'google',
      id_token: h.firebaseToken({ sub: 'g-0', email: 'nobody@example.com', name: '小明' })
    });
    assert.strictEqual(res.status, 404);
    assert.strictEqual(res.body.code, 'NO_ACCOUNT_FOR_PROVIDER');
    assert.ok(res.body.message.includes('Google'), '訊息要指出是哪個渠道');
    assert.strictEqual(h.prisma.rows('users').length, 0, '不得自動建立帳號');
    assert.strictEqual(h.prisma.rows('user_identities').length, 0);
  }],

  ['未帶 create 時即使電子郵件已註冊也先回 NO_ACCOUNT_FOR_PROVIDER', async () => {
    h.addUser({ email: 'taken-first@example.com' });
    const res = await social({
      provider: 'google',
      id_token: h.firebaseToken({ sub: 'g-0b', email: 'taken-first@example.com' })
    });
    assert.strictEqual(res.status, 404);
    assert.strictEqual(res.body.code, 'NO_ACCOUNT_FOR_PROVIDER');
  }],

  ['帶 create=true 且尚無帳號時建立新帳號並登入', async () => {
    const res = await social({
      provider: 'google',
      create: true,
      id_token: h.firebaseToken({ sub: 'g-1', email: 'New@Example.com', name: '小明' })
    });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.message, '登入成功');
    assert.ok(res.body.data.token, '應回傳 token');

    const user = h.prisma.rows('users')[0];
    assert.strictEqual(user.email, 'new@example.com');
    assert.strictEqual(user.nickname, '小明');
    assert.strictEqual(user.password_set, 0);
    const identity = h.prisma.rows('user_identities')[0];
    assert.strictEqual(identity.provider, 'google');
    assert.strictEqual(identity.subject, 'g-1');
    assert.strictEqual(h.prisma.rows('login_logs')[0].login_method, 'google');
  }],

  ['已有 identity 時直接登入並更新 last_login_at', async () => {
    const user = h.addUser({ email: 'known@example.com' });
    h.addIdentity({ userId: user.user_id, provider: 'google', subject: 'g-2' });

    const res = await social({ provider: 'google', id_token: h.firebaseToken({ sub: 'g-2', email: 'known@example.com' }) });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(h.prisma.rows('users').length, 1, '不應建立新帳號');
    assert.ok(h.prisma.rows('user_identities')[0].last_login_at, 'last_login_at 應更新');
  }],

  ['社群登入回應結構與密碼登入完全相同', async () => {
    const user = h.addUser({ email: 'same@example.com', password: 'password123' });
    h.addIdentity({ userId: user.user_id, provider: 'google', subject: 'g-3' });

    const byPassword = await h.request('POST', '/api/auth/login', {
      body: { email: 'same@example.com', password: 'password123' }
    });
    const bySocial = await social({ provider: 'google', id_token: h.firebaseToken({ sub: 'g-3' }) });

    assert.strictEqual(byPassword.status, bySocial.status);
    assert.deepStrictEqual(Object.keys(bySocial.body).sort(), Object.keys(byPassword.body).sort());
    assert.deepStrictEqual(Object.keys(bySocial.body.data).sort(), Object.keys(byPassword.body.data).sort());
    assert.strictEqual(bySocial.body.message, byPassword.body.message);
  }],

  ['Email 已註冊但未綁定時回 409 ACCOUNT_EXISTS_LINK_REQUIRED', async () => {
    h.addUser({ email: 'exists@example.com' });
    const res = await social({
      provider: 'google',
      create: true,
      id_token: h.firebaseToken({ sub: 'g-4', email: 'exists@example.com' })
    });
    assert.strictEqual(res.status, 409);
    assert.strictEqual(res.body.code, 'ACCOUNT_EXISTS_LINK_REQUIRED');
    assert.strictEqual(res.body.provider_email, 'exists@example.com', '供 App 預填登入並綁定的電子郵件');
  }],

  ['渠道停用時回 403 SIGN_IN_METHOD_DISABLED', async () => {
    h.setAuthSettings({ social_enabled: true, providers: { google: { enabled: false, signup: true } } });
    const res = await social({
      provider: 'google', create: true, id_token: h.firebaseToken({ sub: 'g-5', email: 'x@example.com' })
    });
    assert.strictEqual(res.status, 403);
    assert.strictEqual(res.body.code, 'SIGN_IN_METHOD_DISABLED');
  }],

  ['總開關關閉時所有渠道停用', async () => {
    h.setAuthSettings({ social_enabled: false, providers: { google: { enabled: true, signup: true } } });
    const res = await social({
      provider: 'google', create: true, id_token: h.firebaseToken({ sub: 'g-6', email: 'x@example.com' })
    });
    assert.strictEqual(res.status, 403);
    assert.strictEqual(res.body.code, 'SIGN_IN_METHOD_DISABLED');

    const providers = await h.request('GET', '/api/auth/providers');
    assert.strictEqual(providers.body.data.social_enabled, false);
  }],

  ['不允許註冊時回 403 SIGNUP_NOT_ALLOWED，既有帳號仍可登入', async () => {
    h.setAuthSettings({ social_enabled: true, providers: { google: { enabled: true, signup: false } } });

    const denied = await social({
      provider: 'google', create: true, id_token: h.firebaseToken({ sub: 'g-7', email: 'fresh@example.com' })
    });
    assert.strictEqual(denied.status, 403);
    assert.strictEqual(denied.body.code, 'SIGNUP_NOT_ALLOWED');
    assert.strictEqual(denied.body.message, '此登入方式僅供既有帳號使用');

    const user = h.addUser({ email: 'old@example.com' });
    h.addIdentity({ userId: user.user_id, provider: 'google', subject: 'g-8' });
    const ok = await social({ provider: 'google', id_token: h.firebaseToken({ sub: 'g-8' }) });
    assert.strictEqual(ok.status, 200);
  }],

  ['手機登入沒有 Email 時回 400 EMAIL_REQUIRED，補送後建立帳號', async () => {
    const idToken = h.firebaseToken({ provider: 'phone', sub: 'p-1', phoneNumber: '+886912345678' });

    const first = await social({ provider: 'phone', create: true, id_token: idToken });
    assert.strictEqual(first.status, 400);
    assert.strictEqual(first.body.code, 'EMAIL_REQUIRED');

    const second = await social({
      provider: 'phone', create: true, id_token: idToken, email: 'Phone@Example.com', nickname: '阿明'
    });
    assert.strictEqual(second.status, 200);
    const user = h.prisma.rows('users')[0];
    assert.strictEqual(user.email, 'phone@example.com');
    assert.strictEqual(user.nickname, '阿明');
    assert.strictEqual(user.phone, '+886912345678');
  }],

  ['手機登入補送的 Email 已註冊時同樣回 409', async () => {
    h.addUser({ email: 'taken@example.com' });
    const idToken = h.firebaseToken({ provider: 'phone', sub: 'p-2', phoneNumber: '+886922222222' });
    const res = await social({
      provider: 'phone', create: true, id_token: idToken, email: 'taken@example.com', nickname: '阿華'
    });
    assert.strictEqual(res.status, 409);
    assert.strictEqual(res.body.code, 'ACCOUNT_EXISTS_LINK_REQUIRED');
  }],

  ['沒有名稱時自動產生暱稱且不含流水號', async () => {
    const res = await social({
      provider: 'google', create: true, id_token: h.firebaseToken({ sub: 'g-9', email: 'noname@example.com' })
    });
    assert.strictEqual(res.status, 200);
    assert.match(h.prisma.rows('users')[0].nickname, /^使用者\d{4}$/);
  }],

  ['sign_in_provider 與 provider 不符時回 400 PROVIDER_MISMATCH', async () => {
    const res = await social({
      provider: 'apple',
      id_token: h.firebaseToken({ provider: 'google.com', sub: 'g-10', email: 'mismatch@example.com' })
    });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.code, 'PROVIDER_MISMATCH');
  }],

  ['aud 不正確的 Token 一律拒絕', async () => {
    const res = await social({
      provider: 'google',
      id_token: h.firebaseToken({ sub: 'g-11', email: 'a@example.com', audience: 'other-project' })
    });
    assert.strictEqual(res.status, 401);
    assert.strictEqual(res.body.code, 'INVALID_ID_TOKEN');
  }],

  ['iss 不正確的 Token 一律拒絕', async () => {
    const res = await social({
      provider: 'google',
      id_token: h.firebaseToken({ sub: 'g-12', email: 'a@example.com', issuer: 'https://evil.example.com' })
    });
    assert.strictEqual(res.status, 401);
    assert.strictEqual(res.body.code, 'INVALID_ID_TOKEN');
  }],

  ['已過期的 Token 一律拒絕', async () => {
    const res = await social({
      provider: 'google',
      id_token: h.firebaseToken({ sub: 'g-13', email: 'a@example.com', expiresIn: -60 })
    });
    assert.strictEqual(res.status, 401);
    assert.strictEqual(res.body.code, 'INVALID_ID_TOKEN');
  }],

  ['簽章不符的 Token 一律拒絕', async () => {
    const res = await social({
      provider: 'google',
      id_token: h.firebaseToken({ sub: 'g-14', email: 'a@example.com', key: h.wrongKey })
    });
    assert.strictEqual(res.status, 401);
    assert.strictEqual(res.body.code, 'INVALID_ID_TOKEN');
  }],

  ['未知 kid 的 Token 一律拒絕', async () => {
    const res = await social({
      provider: 'google',
      id_token: h.firebaseToken({ sub: 'g-15', email: 'a@example.com', kid: 'unknown-kid' })
    });
    assert.strictEqual(res.status, 401);
    assert.strictEqual(res.body.code, 'INVALID_ID_TOKEN');
  }],

  ['停權與黑名單帳號沿用既有登入規則', async () => {
    const inactive = h.addUser({ email: 'inactive@example.com', isActive: false });
    h.addIdentity({ userId: inactive.user_id, provider: 'google', subject: 'g-16' });
    const res = await social({ provider: 'google', id_token: h.firebaseToken({ sub: 'g-16' }) });
    assert.strictEqual(res.status, 403);
    assert.strictEqual(res.body.code, 'ACCOUNT_INACTIVE');

    const blocked = h.addUser({ email: 'black@example.com', isBlacklisted: true });
    h.addIdentity({ userId: blocked.user_id, provider: 'google', subject: 'g-17' });
    const res2 = await social({ provider: 'google', id_token: h.firebaseToken({ sub: 'g-17' }) });
    assert.strictEqual(res2.status, 403);
    assert.strictEqual(res2.body.code, 'ACCOUNT_BLACKLISTED');
  }],

  ['GET /api/users/me/identities 以遮罩呈現，不含流水號', async () => {
    const user = h.addUser({ email: 'list@example.com', passwordSet: 0, phone: '0912345678' });
    h.addIdentity({
      userId: user.user_id, provider: 'google', subject: 'g-18', email: 'abcdef@gmail.com', displayName: '小明'
    });
    h.addIdentity({ userId: user.user_id, provider: 'phone', subject: 'p-3', phone: '+886912345678' });

    const res = await h.request('GET', '/api/users/me/identities', { token: h.tokenFor(user) });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.data.password_set, false);
    const [google, phone] = res.body.data.identities;
    assert.strictEqual(google.masked_email, 'ab***@gmail.com');
    assert.strictEqual(phone.masked_phone, '09**-***-678');
    assert.ok(!JSON.stringify(res.body).includes('identity_id'));
    assert.ok(!JSON.stringify(res.body).includes('user_id'));
  }],

  ['綁定成功後可於列表看到', async () => {
    const user = h.addUser({ email: 'bind@example.com' });
    const res = await h.request('POST', '/api/auth/link', {
      token: h.tokenFor(user),
      headers: h.verifyHeaders(user),
      body: { provider: 'google', id_token: h.firebaseToken({ sub: 'g-19', email: 'bind@example.com', name: '綁定者' }) }
    });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.data.identities.length, 1);
    assert.strictEqual(res.body.data.identities[0].provider, 'google');
  }],

  ['已綁在其他帳號時回 409 IDENTITY_TAKEN', async () => {
    const owner = h.addUser({ email: 'owner@example.com' });
    h.addIdentity({ userId: owner.user_id, provider: 'google', subject: 'g-20' });
    const other = h.addUser({ email: 'other@example.com' });

    const res = await h.request('POST', '/api/auth/link', {
      token: h.tokenFor(other),
      headers: h.verifyHeaders(other),
      body: { provider: 'google', id_token: h.firebaseToken({ sub: 'g-20' }) }
    });
    assert.strictEqual(res.status, 409);
    assert.strictEqual(res.body.code, 'IDENTITY_TAKEN');
  }],

  ['同一帳號重複綁定同一渠道時回 409 ALREADY_LINKED', async () => {
    const user = h.addUser({ email: 'dup@example.com' });
    h.addIdentity({ userId: user.user_id, provider: 'google', subject: 'g-21' });

    const res = await h.request('POST', '/api/auth/link', {
      token: h.tokenFor(user),
      headers: h.verifyHeaders(user),
      body: { provider: 'google', id_token: h.firebaseToken({ sub: 'g-22' }) }
    });
    assert.strictEqual(res.status, 409);
    assert.strictEqual(res.body.code, 'ALREADY_LINKED');
  }],

  ['解除綁定後若無其他登入方式則回 400 LAST_SIGN_IN_METHOD', async () => {
    const user = h.addUser({ email: 'only@example.com', passwordSet: 0 });
    h.addIdentity({ userId: user.user_id, provider: 'google', subject: 'g-23' });

    const res = await h.request('DELETE', '/api/auth/link/google', { token: h.tokenFor(user), headers: h.verifyHeaders(user) });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.code, 'LAST_SIGN_IN_METHOD');
    assert.strictEqual(h.prisma.rows('user_identities').length, 1, '不應刪除');
  }],

  ['有密碼時可解除唯一的社群綁定', async () => {
    const user = h.addUser({ email: 'haspw@example.com', passwordSet: 1 });
    h.addIdentity({ userId: user.user_id, provider: 'google', subject: 'g-24' });

    const res = await h.request('DELETE', '/api/auth/link/google', { token: h.tokenFor(user), headers: h.verifyHeaders(user) });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.data.identities.length, 0);
    assert.strictEqual(h.prisma.rows('user_identities').length, 0);
  }],

  ['沒有密碼但有兩個社群綁定時可解除其一', async () => {
    const user = h.addUser({ email: 'two@example.com', passwordSet: 0 });
    h.addIdentity({ userId: user.user_id, provider: 'google', subject: 'g-25' });
    h.addIdentity({ userId: user.user_id, provider: 'apple', subject: 'a-1' });

    const res = await h.request('DELETE', '/api/auth/link/apple', { token: h.tokenFor(user), headers: h.verifyHeaders(user) });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.data.identities.length, 1);
  }],

  ['未綁定的渠道解除時回 404', async () => {
    const user = h.addUser({ email: 'none@example.com' });
    const res = await h.request('DELETE', '/api/auth/link/discord', { token: h.tokenFor(user), headers: h.verifyHeaders(user) });
    assert.strictEqual(res.status, 404);
  }],

  ['POST /api/auth/password/set 僅限尚未設定密碼的帳號', async () => {
    const user = h.addUser({ email: 'setpw@example.com', passwordSet: 0 });
    h.addIdentity({ userId: user.user_id, provider: 'google', subject: 'g-26' });

    const weak = await h.request('POST', '/api/auth/password/set', {
      token: h.tokenFor(user), body: { password: 'short' }
    });
    assert.strictEqual(weak.status, 400);

    const res = await h.request('POST', '/api/auth/password/set', {
      token: h.tokenFor(user), body: { password: 'newpassword123' }
    });
    assert.strictEqual(res.status, 200);
    assert.ok(res.body.data.token);
    assert.strictEqual(h.prisma.rows('users')[0].password_set, 1);

    const again = await h.request('POST', '/api/auth/password/set', {
      token: h.tokenFor(h.prisma.rows('users')[0]), body: { password: 'anotherpass123' }
    });
    assert.strictEqual(again.status, 400);
    assert.strictEqual(again.body.code, 'PASSWORD_ALREADY_SET');
  }],

  ['未設定密碼的帳號不能走變更密碼流程', async () => {
    const user = h.addUser({ email: 'nopw@example.com', passwordSet: 0 });
    const res = await h.request('PUT', '/api/users/me/password', {
      token: h.tokenFor(user),
      body: { current_password: 'whatever123', new_password: 'newpassword123' }
    });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.code, 'PASSWORD_NOT_SET');
  }],

  ['管理端讀取與更新設定需要系統維運權限', async () => {
    const member = h.addUser({ email: 'member@example.com' });
    const denied = await h.request('GET', '/api/admin/auth/settings', { token: h.tokenFor(member) });
    assert.strictEqual(denied.status, 403);

    const admin = h.addUser({ email: 'admin@example.com', role: 'admin' });
    // 未明確開啟 can_manage_system 的管理員也不得存取
    const noPermission = await h.request('GET', '/api/admin/auth/settings', { token: h.tokenFor(admin) });
    assert.strictEqual(noPermission.status, 403);
    assert.strictEqual(noPermission.body.code, 'ADMIN_PERMISSION_REQUIRED');

    h.prisma.rows('admin_permissions').push({ user_id: admin.user_id, can_manage_system: true });
    const ok = await h.request('GET', '/api/admin/auth/settings', { token: h.tokenFor(admin) });
    assert.strictEqual(ok.status, 200);
    assert.strictEqual(ok.body.data.settings.social_enabled, true);
    assert.ok(ok.body.data.providers.every((p) => 'configured' in p && !('secret' in p)));
  }],

  ['管理端更新設定會驗證內容並寫入操作紀錄', async () => {
    const admin = h.addUser({ email: 'admin2@example.com', role: 'admin' });
    h.prisma.rows('admin_permissions').push({ user_id: admin.user_id, can_manage_system: true });
    const token = h.tokenFor(admin);
    const headers = h.verifyHeaders(admin, 'admin');

    const missing = await h.request('PUT', '/api/admin/auth/settings', { token, headers, body: {} });
    assert.strictEqual(missing.status, 400);

    const invalid = await h.request('PUT', '/api/admin/auth/settings', {
      token, headers, body: { settings: { social_enabled: 'yes' } }
    });
    assert.strictEqual(invalid.status, 400);

    const invalidChannel = await h.request('PUT', '/api/admin/auth/settings', {
      token, headers, body: { settings: { providers: { line: { enabled: 1 } } } }
    });
    assert.strictEqual(invalidChannel.status, 400);

    const ok = await h.request('PUT', '/api/admin/auth/settings', {
      token, headers, body: { settings: { social_enabled: true, providers: { line: { enabled: true, signup: true } } } }
    });
    assert.strictEqual(ok.status, 200);
    assert.strictEqual(ok.body.data.settings.providers.line.enabled, true);
    // 未送出的渠道回到預設值
    assert.strictEqual(ok.body.data.settings.providers.google.enabled, true);
    assert.strictEqual(h.prisma.rows('admin_operation_logs').length, 1);
    const detail = JSON.parse(h.prisma.rows('admin_operation_logs')[0].detail);
    assert.ok(detail.summary.includes('LINE'));
  }],

  ['未設定 Firebase 專案時 Firebase 系列渠道視為未設定', async () => {
    const saved = process.env.FIREBASE_PROJECT_ID;
    delete process.env.FIREBASE_PROJECT_ID;
    const envModule = h.api('config/env');
    envModule.env.firebaseProjectId = '';
    h.api('lib/firebase-token').resetCache();
    h.authSettings.clearCache();
    try {
      const res = await h.request('GET', '/api/auth/providers');
      const google = res.body.data.providers.find((p) => p.id === 'google');
      assert.strictEqual(google.configured, false);
      assert.strictEqual(google.enabled, false);
    } finally {
      process.env.FIREBASE_PROJECT_ID = saved;
      envModule.env.firebaseProjectId = saved;
      h.api('lib/firebase-token').resetCache();
      h.authSettings.clearCache();
    }
  }],

  ['帳號匯出與匿名化涵蓋登入方式', async () => {
    const account = h.api('services/account');
    const user = h.addUser({ email: 'export@example.com', passwordSet: 0 });
    h.addIdentity({ userId: user.user_id, provider: 'google', subject: 'g-27', email: 'export@example.com' });

    const exported = await account.exportData(user.user_id);
    assert.strictEqual(exported.sign_in_methods.password_set, false);
    assert.strictEqual(exported.sign_in_methods.items.length, 1);
    assert.strictEqual(exported.sign_in_methods.items[0].provider, 'google');

    user.deletion_requested_at = new Date(Date.now() - 40 * 86400000);
    await account.processDueDeletions();
    assert.strictEqual(h.prisma.rows('user_identities').length, 0, '匿名化須清除登入方式');
    assert.strictEqual(h.prisma.rows('users')[0].password_set, 1);
  }]
];

module.exports = { name: '社群登入（Firebase）', tests };

if (require.main === module) {
  h.runSuite(module.exports.name, tests).then((r) => {
    h.close();
    process.exit(r.failures.length ? 1 : 0);
  });
}
