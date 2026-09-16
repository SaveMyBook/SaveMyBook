const assert = require('assert');
const h = require('./harness');

const { prisma, request } = h;
const security = h.api('services/security');
const sessions = h.api('services/sessions');

const PIN = '135790';

// 建立一位已登入的使用者，回傳連線所需的權杖與裝置。
const signedIn = ({ pin = null } = {}) => {
  const user = h.addUser();
  const session = h.addSession(user);
  if (pin) h.setPin(user, pin);
  return { user, session, token: h.tokenFor(user, session.sid) };
};

const verify = (ctx, body) => request('POST', '/api/security/verify', { token: ctx.token, body });

const sensitiveHeaders = (ctx) => ({ 'x-verify-token': h.verifyTokenFor({ user: ctx.user, sid: ctx.session.sid }) });

module.exports = {
  name: '平台：帳號安全',
  tests: [
    ['尚未執行 007 時安全設定回報為不可用', async () => {
      h.reset({ schema: h.without(h.FULL_SCHEMA, ['user_sessions', 'user_security']) });
      const ctx = signedIn();
      const res = await request('GET', '/api/security', { token: ctx.token });
      assert.strictEqual(res.status, 200);
      assert.deepStrictEqual(res.body.data, {
        available: false, has_password: true, has_payment_pin: false, pin_locked_until: null, biometric_pay_enabled: false,
        passkey_available: true, has_passkey: false
      });

      const set = await request('PUT', '/api/security/payment-pin', { token: ctx.token, body: { pin: PIN } });
      assert.strictEqual(set.status, 503);
      assert.strictEqual(set.body.code, 'SECURITY_UNAVAILABLE');
      assert.strictEqual(set.body.message, '交易密碼功能暫時無法使用，請稍後再試');
    }],

    ['尚未設定交易密碼時的安全設定內容', async () => {
      const ctx = signedIn();
      const res = await request('GET', '/api/security', { token: ctx.token });
      assert.strictEqual(res.body.data.available, true);
      assert.strictEqual(res.body.data.has_payment_pin, false);
      assert.strictEqual(res.body.data.biometric_pay_enabled, false);
      assert.strictEqual(res.body.data.pin_locked_until, null);
    }],

    ['驗證的範圍與方式都必須在允許清單內', async () => {
      const ctx = signedIn({ pin: PIN });
      const scope = await verify(ctx, { scope: 'everything', method: 'pin' });
      assert.strictEqual(scope.status, 400);
      assert.strictEqual(scope.body.message, '驗證範圍不正確');

      const method = await verify(ctx, { scope: 'payment', method: 'password' });
      assert.strictEqual(method.status, 400);
      assert.strictEqual(method.body.message, '不支援此驗證方式');

      const sensitive = await verify(ctx, { scope: 'sensitive', method: 'face' });
      assert.strictEqual(sensitive.body.message, '不支援此驗證方式');

      // 後台範圍只收登入密碼，交易密碼與生物辨識連簽發都不允許。
      const admin = await verify(ctx, { scope: 'admin', method: 'pin', pin: PIN });
      assert.strictEqual(admin.status, 400);
      assert.strictEqual(admin.body.message, '不支援此驗證方式');
    }],

    ['以登入密碼驗證身分：密碼錯誤用 400 回報，避免 App 直接登出', async () => {
      const ctx = signedIn();
      const wrong = await verify(ctx, { scope: 'sensitive', method: 'password', password: '錯的密碼' });
      assert.strictEqual(wrong.status, 400);
      assert.strictEqual(wrong.body.code, 'INVALID_PASSWORD');
      assert.strictEqual(wrong.body.message, '密碼錯誤');

      const ok = await verify(ctx, { scope: 'sensitive', method: 'password', password: 'Passw0rd123' });
      assert.strictEqual(ok.status, 200);
      assert.strictEqual(ok.body.data.scope, 'sensitive');
      assert.strictEqual(ok.body.data.expires_in, 300);
      assert.ok(ok.body.data.verify_token);
    }],

    ['交易驗證必須先設定交易密碼', async () => {
      const ctx = signedIn();
      const res = await verify(ctx, { scope: 'payment', method: 'pin', pin: PIN });
      assert.strictEqual(res.status, 403);
      assert.strictEqual(res.body.code, 'PAYMENT_PIN_NOT_SET');
      assert.strictEqual(res.body.message, '尚未設定交易密碼');
    }],

    ['交易密碼必須是不易猜測的 6 位數字', async () => {
      const ctx = signedIn();
      const set = (pin) => request('PUT', '/api/security/payment-pin', {
        token: ctx.token, body: { pin }, headers: sensitiveHeaders(ctx)
      });

      for (const pin of ['12345', '1234567', 'abcdef', '', null]) {
        const res = await set(pin);
        assert.strictEqual(res.body.code, 'PIN_FORMAT', String(pin));
        assert.strictEqual(res.body.message, '交易密碼必須是 6 位數字');
      }
      assert.strictEqual((await set('111111')).body.message, '交易密碼不可為 6 個相同的數字');
      assert.strictEqual((await set('123456')).body.message, '交易密碼不可為連續的數字');
      assert.strictEqual((await set('987654')).body.message, '交易密碼不可為連續的數字');
      assert.strictEqual((await set('121212')).body.message, '交易密碼不可為重複的數字組合');
      assert.strictEqual((await set('123123')).body.message, '交易密碼不可為重複的數字組合');
      assert.strictEqual((await set('111111')).body.code, 'PIN_TOO_WEAK');
    }],

    ['設定與變更交易密碼的訊息不同，變更時會通知本人', async () => {
      const ctx = signedIn();
      const first = await request('PUT', '/api/security/payment-pin', {
        token: ctx.token, body: { pin: PIN }, headers: sensitiveHeaders(ctx)
      });
      assert.strictEqual(first.status, 200);
      assert.strictEqual(first.body.message, '交易密碼已設定');
      assert.strictEqual(prisma.rows('notifications').length, 0);
      assert.strictEqual(prisma.rows('user_security').length, 1);

      const second = await request('PUT', '/api/security/payment-pin', {
        token: ctx.token, body: { pin: '246813' }, headers: sensitiveHeaders(ctx)
      });
      assert.strictEqual(second.body.message, '交易密碼已變更');
      const [notice] = prisma.rows('notifications');
      assert.strictEqual(notice.title, '交易密碼已變更');
      assert.strictEqual(notice.related_type, 'security');
      assert.strictEqual(Number(notice.user_id), ctx.user.user_id);

      const status = await request('GET', '/api/security', { token: ctx.token });
      assert.strictEqual(status.body.data.has_payment_pin, true);
    }],

    ['變更交易密碼需要先完成身分驗證', async () => {
      const ctx = signedIn();
      const res = await request('PUT', '/api/security/payment-pin', { token: ctx.token, body: { pin: PIN } });
      assert.strictEqual(res.status, 403);
      assert.strictEqual(res.body.code, 'VERIFICATION_REQUIRED');
      assert.strictEqual(res.body.message, '請先驗證身分');
      assert.deepStrictEqual(res.body.verification, { scope: 'sensitive', methods: ['password', 'passkey', 'pin', 'biometric'] });
    }],

    ['交易密碼錯誤會回報剩餘次數，成功後歸零', async () => {
      const ctx = signedIn({ pin: PIN });
      const wrong = await verify(ctx, { scope: 'payment', method: 'pin', pin: '246813' });
      assert.strictEqual(wrong.status, 400);
      assert.strictEqual(wrong.body.code, 'INVALID_PIN');
      assert.strictEqual(wrong.body.message, '交易密碼錯誤，剩餘嘗試次數 4 次');
      assert.strictEqual(wrong.body.remaining_attempts, 4);
      assert.strictEqual(Number(prisma.rows('user_security')[0].pin_failed_count), 1);

      const second = await verify(ctx, { scope: 'payment', method: 'pin', pin: '246813' });
      assert.strictEqual(second.body.remaining_attempts, 3);

      const ok = await verify(ctx, { scope: 'payment', method: 'pin', pin: PIN });
      assert.strictEqual(ok.status, 200);
      assert.strictEqual(Number(prisma.rows('user_security')[0].pin_failed_count), 0);
    }],

    ['連續錯 5 次會鎖定 15 分鐘並發出安全通知', async () => {
      const ctx = signedIn({ pin: PIN });
      let res;
      for (let i = 0; i < 5; i += 1) res = await verify(ctx, { scope: 'payment', method: 'pin', pin: '246813' });

      assert.strictEqual(res.status, 423);
      assert.strictEqual(res.body.code, 'PIN_LOCKED');
      assert.strictEqual(res.body.message, '交易密碼錯誤次數過多，請 15 分鐘後再試');
      assert.ok(res.body.locked_until);
      assert.strictEqual(Number(prisma.rows('user_security')[0].pin_failed_count), 0);

      const [notice] = prisma.rows('notifications');
      assert.strictEqual(notice.title, '交易密碼已暫時鎖定');
      assert.ok(notice.content.includes('連續輸入錯誤 5 次'));

      // 鎖定期間即使輸入正確也會被擋下。
      const locked = await verify(ctx, { scope: 'payment', method: 'pin', pin: PIN });
      assert.strictEqual(locked.status, 423);
      assert.strictEqual(locked.body.code, 'PIN_LOCKED');
      assert.ok(/請 1[0-5] 分鐘後再試/.test(locked.body.message));

      const status = await request('GET', '/api/security', { token: ctx.token });
      assert.ok(status.body.data.pin_locked_until);
    }],

    ['鎖定時間過後即可再次嘗試', async () => {
      const ctx = signedIn({ pin: PIN });
      prisma.rows('user_security')[0].pin_locked_until = new Date(Date.now() - 1000);
      const res = await verify(ctx, { scope: 'payment', method: 'pin', pin: PIN });
      assert.strictEqual(res.status, 200);
      const status = await request('GET', '/api/security', { token: ctx.token });
      assert.strictEqual(status.body.data.pin_locked_until, null);
    }],

    ['交易用的驗證權杖只能使用一次', async () => {
      const ctx = signedIn({ pin: PIN });
      const issued = await verify(ctx, { scope: 'payment', method: 'pin', pin: PIN });
      const raw = issued.body.data.verify_token;
      const user = { userId: ctx.user.user_id, sid: ctx.session.sid };

      const decoded = security.consumeToken(raw, user, 'payment');
      assert.strictEqual(decoded.scope, 'payment');
      assert.strictEqual(decoded.method, 'pin');
      assert.throws(
        () => security.consumeToken(raw, user, 'payment'),
        (err) => err.code === 'VERIFICATION_REQUIRED' && err.message === '此驗證已使用，請重新驗證'
      );

      // 呼叫失敗時會把權杖釋放回去，讓使用者不必重新驗證。
      security.releaseToken(decoded.jti);
      assert.strictEqual(security.consumeToken(raw, user, 'payment').jti, decoded.jti);
    }],

    ['敏感操作的驗證權杖可在效期內重複使用，但不可跨範圍或跨裝置', async () => {
      const ctx = signedIn({ pin: PIN });
      const issued = await verify(ctx, { scope: 'sensitive', method: 'password', password: 'Passw0rd123' });
      const raw = issued.body.data.verify_token;
      const user = { userId: ctx.user.user_id, sid: ctx.session.sid };

      assert.strictEqual(security.consumeToken(raw, user, 'sensitive').scope, 'sensitive');
      assert.strictEqual(security.consumeToken(raw, user, 'sensitive').scope, 'sensitive');

      assert.throws(() => security.consumeToken(raw, user, 'payment'), (err) => err.code === 'VERIFICATION_REQUIRED');
      assert.throws(
        () => security.consumeToken(raw, { userId: ctx.user.user_id + 999, sid: ctx.session.sid }, 'sensitive'),
        (err) => err.code === 'VERIFICATION_REQUIRED'
      );
      assert.throws(
        () => security.consumeToken(raw, { userId: ctx.user.user_id, sid: 'other-device' }, 'sensitive'),
        (err) => err.code === 'VERIFICATION_REQUIRED'
      );
      assert.throws(
        () => security.consumeToken('壞掉的權杖', user, 'sensitive'),
        (err) => err.message === '驗證已逾時，請重新驗證'
      );
      assert.throws(
        () => security.consumeToken(null, user, 'payment'),
        (err) => err.message === '請輸入交易密碼以完成付款' && err.extra.verification.methods.join() === 'pin,biometric'
      );
    }],

    ['後台範圍的驗證權杖只認登入密碼簽發的那一份', async () => {
      const ctx = signedIn({ pin: PIN });
      const user = { userId: ctx.user.user_id, sid: ctx.session.sid };

      const byPassword = await verify(ctx, { scope: 'admin', method: 'password', password: 'Passw0rd123' });
      assert.strictEqual(byPassword.status, 200);
      assert.strictEqual(byPassword.body.data.scope, 'admin');
      assert.strictEqual(security.consumeToken(byPassword.body.data.verify_token, user, 'admin').method, 'password');

      // sensitive 與 admin 是不同範圍：兩邊的權杖都不能互相頂替。
      const sensitive = await verify(ctx, { scope: 'sensitive', method: 'password', password: 'Passw0rd123' });
      assert.throws(
        () => security.consumeToken(sensitive.body.data.verify_token, user, 'admin'),
        (err) => err.code === 'VERIFICATION_REQUIRED' && err.extra.verification.methods.join() === 'password,passkey'
      );
      assert.throws(
        () => security.consumeToken(byPassword.body.data.verify_token, user, 'sensitive'),
        (err) => err.code === 'VERIFICATION_REQUIRED'
      );

      // 直接偽造一份以交易密碼簽發的 admin 權杖，仍不得通行。
      const forged = h.verifyTokenFor({ user: ctx.user, sid: ctx.session.sid, scope: 'admin', method: 'pin' });
      assert.throws(() => security.consumeToken(forged, user, 'admin'), (err) => err.code === 'VERIFICATION_REQUIRED');
    }],

    ['後台端點要求登入密碼驗證，交易密碼簽發的權杖不通過', async () => {
      const admin = h.addAdmin({ can_manage_system: true });
      const session = h.addSession(admin);
      const token = h.tokenFor(admin, session.sid);
      h.setPin(admin, PIN);
      const body = { settings: { ai_enabled: false } };

      const bare = await request('PUT', '/api/admin/ai/settings', { token, body });
      assert.strictEqual(bare.status, 403);
      assert.strictEqual(bare.body.code, 'VERIFICATION_REQUIRED');
      assert.strictEqual(bare.body.message, '請以登入密碼或通行密鑰驗證身分以執行此後台操作');
      assert.deepStrictEqual(bare.body.verification, { scope: 'admin', methods: ['password', 'passkey'] });

      const withPin = await request('PUT', '/api/admin/ai/settings', {
        token, body, headers: { 'x-verify-token': h.verifyTokenFor({ user: admin, sid: session.sid, scope: 'admin', method: 'pin' }) }
      });
      assert.strictEqual(withPin.status, 403);
      assert.strictEqual(withPin.body.code, 'VERIFICATION_REQUIRED');

      const withPassword = await request('PUT', '/api/admin/ai/settings', {
        token, body, headers: { 'x-verify-token': h.verifyTokenFor({ user: admin, sid: session.sid, scope: 'admin' }) }
      });
      assert.strictEqual(withPassword.status, 200);
    }],

    ['沒有設定登入密碼的帳號不能以密碼驗證身分', async () => {
      const ctx = signedIn();
      ctx.user.password_set = 0;

      const res = await verify(ctx, { scope: 'admin', method: 'password', password: 'Passw0rd123' });
      assert.strictEqual(res.status, 403);
      assert.strictEqual(res.body.code, 'PASSWORD_NOT_SET');
      assert.strictEqual(res.body.message, '此帳號尚未設定登入密碼，請先於「帳號安全」設定密碼');

      const status = await request('GET', '/api/security', { token: ctx.token });
      assert.strictEqual(status.body.data.has_password, false);
    }],

    ['裝置清單只列出未登出且近期使用過的裝置，目前裝置排在最前面', async () => {
      const ctx = signedIn();
      const older = h.addSession(ctx.user, { deviceName: 'Pixel', platform: 'android', lastSeenAt: new Date(Date.now() - 86400000) });
      h.addSession(ctx.user, { deviceName: '已登出的裝置', revokedAt: new Date() });
      h.addSession(ctx.user, { deviceName: '太久沒用的裝置', lastSeenAt: new Date(Date.now() - 31 * 86400000) });
      h.addSession(h.addUser(), { deviceName: '別人的裝置' });
      older.pay_key_hash = 'a'.repeat(64);

      const res = await request('GET', '/api/security/sessions', { token: ctx.token });
      assert.strictEqual(res.status, 200);
      assert.deepStrictEqual(res.body.data.map((s) => s.device_name), ['iPhone 17', 'Pixel']);
      assert.strictEqual(res.body.data[0].is_current, true);
      assert.strictEqual(res.body.data[0].biometric_pay, false);
      assert.strictEqual(res.body.data[1].biometric_pay, true);
      assert.strictEqual(res.body.data[1].platform, 'android');
    }],

    ['登出單一裝置會註銷該裝置並清掉它的推播裝置', async () => {
      const ctx = signedIn();
      const other = h.addSession(ctx.user, { deviceName: 'Pixel' });
      h.addDevice(ctx.user, { token: `fcm-other-${'x'.repeat(20)}`, sessionSid: other.sid });
      h.addDevice(ctx.user, { token: `fcm-mine-${'x'.repeat(20)}`, sessionSid: ctx.session.sid });

      const res = await request('DELETE', `/api/security/sessions/${other.session_id}`, {
        token: ctx.token, headers: sensitiveHeaders(ctx)
      });
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.body.message, '已登出此裝置');
      assert.strictEqual(res.body.data.signed_out_current, false);
      assert.ok(other.revoked_at);
      assert.deepStrictEqual(prisma.rows('push_devices').map((d) => d.session_sid), [ctx.session.sid]);

      const again = await request('DELETE', `/api/security/sessions/${other.session_id}`, {
        token: ctx.token, headers: sensitiveHeaders(ctx)
      });
      assert.strictEqual(again.status, 404);
      assert.strictEqual(again.body.message, '找不到此裝置，可能已登出');
    }],

    ['登出自己的裝置時會告知需要重新登入', async () => {
      const ctx = signedIn();
      const res = await request('DELETE', `/api/security/sessions/${ctx.session.session_id}`, {
        token: ctx.token, headers: sensitiveHeaders(ctx)
      });
      assert.strictEqual(res.body.data.signed_out_current, true);
    }],

    ['登出其他裝置預設保留目前裝置', async () => {
      const ctx = signedIn();
      h.addSession(ctx.user, { deviceName: 'Pixel' });
      h.addSession(ctx.user, { deviceName: 'iPad' });

      const res = await request('POST', '/api/security/sessions/revoke-all', {
        token: ctx.token, headers: sensitiveHeaders(ctx), body: {}
      });
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.body.message, '已登出其他 2 台裝置');
      assert.strictEqual(res.body.data.revoked, 2);
      assert.strictEqual(res.body.data.signed_out_current, false);
      assert.strictEqual(prisma.rows('user_sessions').filter((s) => s.revoked_at == null).length, 1);
      // 沒有裝置代碼的舊 Token 以時間點一併作廢。
      assert.ok(prisma.rows('user_security')[0].tokens_valid_after);
    }],

    ['登出所有裝置時連自己也一起登出', async () => {
      const ctx = signedIn();
      h.addSession(ctx.user, { deviceName: 'Pixel' });

      const res = await request('POST', '/api/security/sessions/revoke-all', {
        token: ctx.token, headers: sensitiveHeaders(ctx), body: { include_current: true }
      });
      assert.strictEqual(res.body.message, '已登出所有裝置');
      assert.strictEqual(res.body.data.signed_out_current, true);
      assert.strictEqual(prisma.rows('user_sessions').filter((s) => s.revoked_at == null).length, 0);
    }],

    ['生物辨識付款必須先設定交易密碼，且綁定在單一裝置', async () => {
      const ctx = signedIn();
      const denied = await request('POST', '/api/security/biometric-key', { token: ctx.token, headers: sensitiveHeaders(ctx) });
      assert.strictEqual(denied.status, 403);
      assert.strictEqual(denied.body.code, 'PAYMENT_PIN_NOT_SET');
      assert.strictEqual(denied.body.message, '請先設定交易密碼，作為生物辨識失敗時的替代驗證方式');

      h.setPin(ctx.user, PIN);
      const enabled = await request('POST', '/api/security/biometric-key', { token: ctx.token, headers: sensitiveHeaders(ctx) });
      assert.strictEqual(enabled.status, 200);
      assert.strictEqual(enabled.body.message, '已於此裝置啟用生物辨識付款');
      const key = enabled.body.data.key;
      assert.ok(key.length >= 20);
      assert.ok(ctx.session.pay_key_hash);
      assert.notStrictEqual(ctx.session.pay_key_hash, key);

      const paid = await verify(ctx, { scope: 'payment', method: 'biometric', key });
      assert.strictEqual(paid.status, 200);
      assert.strictEqual(paid.body.data.scope, 'payment');

      const wrong = await verify(ctx, { scope: 'payment', method: 'biometric', key: 'x'.repeat(43) });
      assert.strictEqual(wrong.status, 400);
      assert.strictEqual(wrong.body.code, 'BIOMETRIC_KEY_INVALID');
      assert.strictEqual(wrong.body.message, '此裝置的生物辨識付款已失效，請改用交易密碼');

      const off = await request('DELETE', '/api/security/biometric-key', { token: ctx.token });
      assert.strictEqual(off.body.message, '已關閉此裝置的生物辨識付款');
      assert.strictEqual(ctx.session.pay_key_hash, null);
      assert.strictEqual((await verify(ctx, { scope: 'payment', method: 'biometric', key })).body.code, 'BIOMETRIC_KEY_INVALID');
    }],

    ['沒有裝置代碼的登入無法使用生物辨識付款', async () => {
      const user = h.addUser();
      h.setPin(user, PIN);
      const token = h.tokenFor(user);
      const res = await request('POST', '/api/security/biometric-key', {
        token, headers: { 'x-verify-token': h.verifyTokenFor({ user }) }
      });
      assert.strictEqual(res.status, 403);
      assert.strictEqual(res.body.code, 'SESSION_REQUIRED');
      assert.strictEqual(res.body.message, '請重新登入後再使用此功能');
    }],

    ['裝置名稱會依平台補上作業系統', () => {
      assert.strictEqual(sessions.deviceLabel({ deviceName: 'iPhone 17', platform: 'ios' }), 'iPhone 17（iOS）');
      assert.strictEqual(sessions.deviceLabel({ deviceName: 'Pixel', platform: 'android' }), 'Pixel（Android）');
      assert.strictEqual(sessions.deviceLabel({ platform: 'ios' }), 'iOS');
      assert.strictEqual(sessions.deviceLabel({ deviceName: 'Pixel' }), 'Pixel');
      assert.strictEqual(sessions.deviceLabel(), '未知裝置');
      assert.strictEqual(sessions.deviceLabel({ deviceName: 'x'.repeat(200), platform: 'ios' }).length, '（iOS）'.length + 80);
    }],

    ['生物辨識金鑰比對可抵擋長度不符與空值', () => {
      assert.strictEqual(sessions.matchesPayKey(null, 'x'.repeat(43)), false);
      assert.strictEqual(sessions.matchesPayKey({ pay_key_hash: 'ab' }, 'x'.repeat(43)), false);
      assert.strictEqual(sessions.matchesPayKey({ pay_key_hash: 'a'.repeat(64) }, '短金鑰'), false);
      assert.strictEqual(sessions.matchesPayKey({ pay_key_hash: 'a'.repeat(64) }, null), false);
    }]
  ]
};
