const assert = require('assert');
const h = require('./harness');

const { prisma, request } = h;
const authToken = h.api('lib/auth-token');
const { buildInfo } = h.api('lib/build-info');
const maintenance = h.api('lib/maintenance');
const schemaCheck = h.api('lib/schema-check');
const security = h.api('middleware/security');

const ME = '/api/notifications/unread-count';

const fakeRes = () => {
  const res = { headers: {}, code: null, body: null };
  res.setHeader = (key, value) => {
    res.headers[key.toLowerCase()] = value;
  };
  res.status = (code) => {
    res.code = code;
    return res;
  };
  res.json = (body) => {
    res.body = body;
    return res;
  };
  return res;
};

module.exports = {
  name: '平台：狀態與共用中介層',
  tests: [
    ['狀態端點回報版本、啟動時間與待執行的資料庫更新', async () => {
      const res = await request('GET', '/api/status');
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.headers.get('cache-control'), 'no-store');
      const { data } = res.body;
      assert.strictEqual(data.maintenance, false);
      assert.strictEqual(data.message, null);
      assert.strictEqual(data.api_revision, buildInfo.apiRevision);
      assert.strictEqual(data.commit, buildInfo.commit);
      assert.strictEqual(data.started_at, buildInfo.startedAt.toISOString());
      assert.deepStrictEqual(data.restore, { state: 'idle', started_at: null, finished_at: null });
      assert.deepStrictEqual(data.pending_migrations, []);
    }],

    ['缺少資料表或欄位時列出對應的 migration 檔名', async () => {
      h.reset({ schema: h.without(h.FULL_SCHEMA, ['user_sessions', 'ai_chat_sessions', 'users.share_token']) });
      const missing = await schemaCheck.missingSchema();
      const migrations = [...new Set(missing.map((m) => m.migration))];
      assert.deepStrictEqual(migrations.sort(), [
        '004_account_privacy_and_ops.sql', '007_consent_sessions_payment.sql', '013_ai_book_chat.sql'
      ]);
      assert.ok(missing.some((m) => m.table === 'users' && m.column === 'share_token'));
    }],

    ['資料表檢查結果會被快取，直到手動清除', async () => {
      h.reset({ schema: h.without(h.FULL_SCHEMA, ['user_sessions']) });
      assert.strictEqual(await schemaCheck.hasTables(['user_sessions', 'user_security']), false);
      // 快取只保留「不存在」60 秒，資料表補上後仍會沿用舊結果，直到快取被清掉。
      prisma.schema = h.FULL_SCHEMA;
      assert.strictEqual(await schemaCheck.hasTables(['user_sessions', 'user_security']), false);
      schemaCheck.resetCache();
      assert.strictEqual(await schemaCheck.hasTables(['user_sessions', 'user_security']), true);
      assert.strictEqual(await schemaCheck.hasColumn('users', 'share_token'), true);
      assert.strictEqual(await schemaCheck.hasColumn('users', '沒有這個欄位'), false);
    }],

    ['維護模式只放行狀態端點', () => {
      maintenance.enter('系統維護中，請稍後再試');
      assert.strictEqual(maintenance.current().active, true);

      const blocked = fakeRes();
      let passed = false;
      maintenance.middleware({ path: '/api/books' }, blocked, () => { passed = true; });
      assert.strictEqual(passed, false);
      assert.strictEqual(blocked.code, 503);
      assert.strictEqual(blocked.body.code, 'MAINTENANCE');
      assert.strictEqual(blocked.body.message, '系統維護中，請稍後再試');
      assert.strictEqual(blocked.headers['retry-after'], '30');

      maintenance.middleware({ path: '/api/status' }, fakeRes(), () => { passed = true; });
      assert.strictEqual(passed, true);

      maintenance.leave();
      assert.deepStrictEqual(maintenance.current(), { active: false, message: null, since: null });
    }],

    ['未提供或不合法的 Token 會被擋下', async () => {
      const none = await request('GET', ME);
      assert.strictEqual(none.status, 401);
      assert.strictEqual(none.body.message, '請先登入');

      const garbage = await request('GET', ME, { token: 'not-a-token' });
      assert.strictEqual(garbage.status, 403);
      assert.strictEqual(garbage.body.message, '登入已失效，請重新登入');

      const user = h.addUser();
      const expired = authToken.sign({ userId: user.user_id, role: user.role }, -1);
      const stale = await request('GET', ME, { token: expired });
      assert.strictEqual(stale.status, 403);
      assert.strictEqual(stale.body.code, 'TOKEN_EXPIRED');
      assert.strictEqual(stale.body.message, '登入已逾時');
    }],

    ['身分驗證權杖不能當成登入權杖使用', async () => {
      const user = h.addUser();
      const verifyToken = h.verifyTokenFor({ user });
      const res = await request('GET', ME, { token: verifyToken });
      assert.strictEqual(res.status, 403);
      assert.strictEqual(res.body.message, '登入已失效，請重新登入');
    }],

    ['帳號狀態異常時各有對應的錯誤代碼', async () => {
      const ghost = h.addUser();
      const ghostToken = h.tokenFor(ghost);
      prisma.store.users = prisma.rows('users').filter((u) => u.user_id !== ghost.user_id);
      const missing = await request('GET', ME, { token: ghostToken });
      assert.strictEqual(missing.status, 401);
      assert.strictEqual(missing.body.code, 'ACCOUNT_NOT_FOUND');

      const blacklisted = h.addUser({ isBlacklisted: true });
      const blocked = await request('GET', ME, { token: h.tokenFor(blacklisted) });
      assert.strictEqual(blocked.status, 401);
      assert.strictEqual(blocked.body.code, 'ACCOUNT_BLACKLISTED');
      assert.strictEqual(blocked.body.message, '此帳號已被列入黑名單，如有疑問請聯絡客服');

      const inactive = h.addUser({ isActive: false });
      const suspended = await request('GET', ME, { token: h.tokenFor(inactive) });
      assert.strictEqual(suspended.status, 401);
      assert.strictEqual(suspended.body.code, 'ACCOUNT_INACTIVE');
    }],

    ['密碼變更後舊的 Token 立即失效', async () => {
      const user = h.addUser();
      const token = h.tokenFor(user);
      assert.strictEqual((await request('GET', ME, { token })).status, 200);

      user.password_hash = 'changed-hash';
      const res = await request('GET', ME, { token });
      assert.strictEqual(res.status, 401);
      assert.strictEqual(res.body.code, 'TOKEN_REVOKED');
      assert.strictEqual(res.body.message, '密碼已變更，請重新登入');
    }],

    ['裝置登出後帶有該裝置的 Token 會被拒絕', async () => {
      const user = h.addUser();
      const session = h.addSession(user);
      const token = h.tokenFor(user, session.sid);
      assert.strictEqual((await request('GET', ME, { token })).status, 200);

      session.revoked_at = new Date();
      const res = await request('GET', ME, { token });
      assert.strictEqual(res.status, 401);
      assert.strictEqual(res.body.code, 'SESSION_REVOKED');
      assert.strictEqual(res.body.message, '此裝置已登出，請重新登入');
    }],

    ['沒有裝置代碼的舊 Token 以登出時間點一併作廢', async () => {
      const user = h.addUser();
      const token = h.tokenFor(user);
      assert.strictEqual((await request('GET', ME, { token })).status, 200);

      prisma.rows('user_security').push({ user_id: user.user_id, tokens_valid_after: new Date(Date.now() + 60000) });
      const res = await request('GET', ME, { token });
      assert.strictEqual(res.status, 401);
      assert.strictEqual(res.body.code, 'SESSION_REVOKED');
    }],

    ['使用中的裝置會更新最後使用時間與來源 IP', async () => {
      const user = h.addUser();
      const session = h.addSession(user, { lastSeenAt: new Date(Date.now() - 60 * 60 * 1000), ip: '203.0.113.9' });
      await request('GET', ME, { token: h.tokenFor(user, session.sid) });
      assert.ok(Date.now() - new Date(session.last_seen_at).getTime() < 5000);
      assert.notStrictEqual(session.ip_address, '203.0.113.9');
    }],

    ['找不到的端點會回 ROUTE_NOT_FOUND', async () => {
      const res = await request('GET', '/api/沒有這個端點');
      assert.strictEqual(res.status, 404);
      assert.strictEqual(res.body.code, 'ROUTE_NOT_FOUND');
      assert.strictEqual(res.body.message, '找不到此端點');
    }],

    ['各類例外都會轉成使用者看得懂的回應', () => {
      const multer = h.api('node_modules/multer');
      const { HttpError } = h.api('lib/errors');
      const { errorHandler } = h.api('middleware/errorHandler');

      const run = (err) => {
        const res = fakeRes();
        res.headersSent = false;
        errorHandler(err, { method: 'GET', originalUrl: '/api/x' }, res, () => {});
        return res;
      };

      const known = run(new HttpError(409, '資料衝突', 'CONFLICT', { remaining_attempts: 2 }));
      assert.strictEqual(known.code, 409);
      assert.deepStrictEqual(known.body, { success: false, code: 'CONFLICT', message: '資料衝突', remaining_attempts: 2 });

      assert.strictEqual(run({ type: 'entity.parse.failed' }).body.message, '資料格式不正確');
      assert.strictEqual(run({ type: 'entity.too.large' }).code, 413);
      assert.strictEqual(run({ code: 'P2025' }).code, 404);
      assert.strictEqual(run({ code: 'P2002' }).body.message, '資料重複，請確認後再試');
      assert.strictEqual(run({ code: 'P2003' }).body.message, '此紀錄仍有關聯資料，無法執行');
      assert.strictEqual(run({ code: 'P2000' }).body.message, '欄位內容超過長度上限');
      assert.strictEqual(run({ name: 'PrismaClientValidationError' }).body.message, '提供的資料格式錯誤或包含無效的值');
      assert.strictEqual(run(new multer.MulterError('LIMIT_FILE_SIZE')).code, 413);
      assert.strictEqual(run(new multer.MulterError('LIMIT_FILE_COUNT')).body.message, '上傳的檔案數量超過上限');

      // 未預期的錯誤不得把內部訊息外洩給使用者。
      const unexpected = run(new Error('資料庫密碼錯誤'));
      assert.strictEqual(unexpected.code, 500);
      assert.deepStrictEqual(unexpected.body, { success: false, message: '系統發生錯誤，請稍後再試' });
    }],

    ['超過限流上限時回 429 並附上重試秒數', async () => {
      const user = h.addUser();
      const token = h.tokenFor(user);
      const body = { token: `fcm-${'a'.repeat(30)}`, platform: 'ios' };

      let last;
      for (let i = 0; i < 21; i += 1) last = await request('POST', '/api/push/devices', { token, body });

      assert.strictEqual(last.status, 429);
      assert.strictEqual(last.body.code, 'RATE_LIMITED');
      assert.strictEqual(last.body.message, '操作過於頻繁，請稍後再試');
      assert.ok(Number(last.headers.get('retry-after')) > 0);

      // 限流以使用者為單位，換一個帳號不受影響。
      const other = await request('POST', '/api/push/devices', { token: h.tokenFor(h.addUser()), body });
      assert.notStrictEqual(other.status, 429);
    }],

    ['安全標頭與請求內容保護', () => {
      const res = fakeRes();
      let called = false;
      security.securityHeaders({}, res, () => { called = true; });
      assert.strictEqual(called, true);
      assert.strictEqual(res.headers['x-content-type-options'], 'nosniff');
      assert.strictEqual(res.headers['x-frame-options'], 'DENY');
      assert.strictEqual(res.headers['referrer-policy'], 'strict-origin-when-cross-origin');

      const uploads = fakeRes();
      security.uploadHeaders(uploads);
      assert.ok(uploads.headers['content-security-policy'].includes("default-src 'none'"));
      assert.ok(uploads.headers['content-security-policy'].includes('sandbox'));

      for (const value of [undefined, null, 'text']) {
        const req = { body: value };
        security.ensureBody(req, fakeRes(), () => {});
        assert.deepStrictEqual(req.body, {});
      }
      const kept = { body: { a: 1 } };
      security.ensureBody(kept, fakeRes(), () => {});
      assert.deepStrictEqual(kept.body, { a: 1 });
    }]
  ]
};
