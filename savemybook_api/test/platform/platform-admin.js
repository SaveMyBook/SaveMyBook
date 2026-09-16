const assert = require('assert');
const h = require('./harness');

const { prisma, request } = h;
const { ADMIN_PERMISSIONS, ADMIN_PERMISSION_LABELS } = h.api('constants/domain');
const adminPermissions = h.api('services/admin-permissions');
const members = h.api('services/members');
const requireAdmin = h.api('middleware/requireAdmin');

const PERMISSION_KEYS = Object.keys(ADMIN_PERMISSIONS);

const runGuard = async (permission, user) => {
  const res = { code: null, body: null };
  res.status = (code) => {
    res.code = code;
    return res;
  };
  res.json = (body) => {
    res.body = body;
    return res;
  };
  let passed = false;
  await requireAdmin(permission)({ user }, res, () => { passed = true; });
  return { passed, ...res };
};

const verifiedAs = (admin) => ({ 'x-verify-token': h.verifyTokenFor({ user: admin }) });

module.exports = {
  name: '平台：後台權限與會員管理',
  tests: [
    ['沒有權限資料列的管理員預設全開，但系統維運必須明確開啟', () => {
      const all = adminPermissions.effectivePermissions(null);
      for (const column of Object.values(ADMIN_PERMISSIONS)) {
        assert.strictEqual(all[column], column !== 'can_manage_system', column);
      }

      const row = Object.fromEntries(Object.values(ADMIN_PERMISSIONS).map((c) => [c, false]));
      const none = adminPermissions.effectivePermissions({ ...row, can_manage_members: true });
      assert.strictEqual(none.can_manage_members, true);
      assert.strictEqual(none.can_manage_content, false);
      assert.strictEqual(adminPermissions.effectivePermissions({ can_manage_system: true }).can_manage_system, true);
    }],

    ['權限檢查：非管理員一律為否，未指定權限時僅需管理員身分', async () => {
      const member = h.addUser();
      assert.strictEqual(await adminPermissions.hasPermission(null, 'members'), false);
      assert.strictEqual(await adminPermissions.hasPermission({ userId: member.user_id, role: 'buyer_seller' }, 'members'), false);

      const admin = h.addAdmin();
      assert.strictEqual(await adminPermissions.hasPermission({ userId: admin.user_id, role: 'admin' }, null), true);
    }],

    ['權限檢查：打錯權限名稱會拋錯，不會變成對所有管理員開放', async () => {
      const admin = h.addAdmin();
      await assert.rejects(
        () => adminPermissions.hasPermission({ userId: admin.user_id, role: 'admin' }, 'everything'),
        (err) => err.message === '未知的管理員權限：everything'
      );
      assert.throws(() => requireAdmin('everything'), (err) => err.message === '未知的管理員權限：everything');
      await assert.rejects(() => adminPermissions.adminIdsWith('everything'), (err) => err.message === '未知的管理員權限：everything');
    }],

    ['每一個權限關閉時都有對應的中文提示', async () => {
      const admin = h.addAdmin(Object.fromEntries(Object.values(ADMIN_PERMISSIONS).map((c) => [c, false])));
      const user = { userId: admin.user_id, role: 'admin' };

      for (const key of PERMISSION_KEYS) {
        const result = await runGuard(key, user);
        assert.strictEqual(result.passed, false, key);
        assert.strictEqual(result.code, 403, key);
        assert.strictEqual(result.body.code, 'ADMIN_PERMISSION_REQUIRED', key);
        assert.strictEqual(
          result.body.message,
          key === 'system'
            ? '需要「系統維運」權限。此權限預設關閉，請由具備此權限的管理員為您開啟。'
            : `您沒有「${ADMIN_PERMISSION_LABELS[key]}」的權限`,
          key
        );
      }
    }],

    ['每一個權限開啟時都會放行', async () => {
      const admin = h.addAdmin(Object.fromEntries(Object.values(ADMIN_PERMISSIONS).map((c) => [c, true])));
      const user = { userId: admin.user_id, role: 'admin' };
      for (const key of PERMISSION_KEYS) {
        assert.strictEqual((await runGuard(key, user)).passed, true, key);
      }
    }],

    ['沒有權限資料列時只有系統維運被擋下', async () => {
      const admin = h.addUser({ role: 'admin' });
      const user = { userId: admin.user_id, role: 'admin' };
      for (const key of PERMISSION_KEYS) {
        assert.strictEqual((await runGuard(key, user)).passed, key !== 'system', key);
      }
    }],

    ['非管理員存取後台一律回權限不足', async () => {
      const guard = await runGuard('members', { userId: 1, role: 'buyer_seller' });
      assert.strictEqual(guard.code, 403);
      assert.strictEqual(guard.body.message, '權限不足，僅限管理員執行此操作');
      assert.strictEqual(guard.body.code, undefined);

      const res = await request('GET', '/api/admin/members', { token: h.tokenFor(h.addUser()) });
      assert.strictEqual(res.status, 403);
      assert.strictEqual(res.body.message, '權限不足，僅限管理員執行此操作');

      const anonymous = await request('GET', '/api/admin/members');
      assert.strictEqual(anonymous.status, 401);
    }],

    ['後台端點確實掛上對應的權限', async () => {
      const cases = [
        ['GET', '/api/admin/members', 'members'],
        ['GET', '/api/admin/wallets', 'wallets'],
        ['GET', '/api/admin/legal', 'announcements'],
        ['GET', '/api/admin/faqs', 'announcements'],
        ['GET', '/api/admin/tickets', 'support'],
        ['GET', '/api/admin/backups', 'system'],
        ['GET', '/api/admin/reports', 'reports'],
        ['GET', '/api/admin/disputes', 'transactions'],
        ['GET', '/api/admin/levels', 'levels'],
        ['GET', '/api/admin/categories', 'content'],
        ['GET', '/api/admin/deletions', 'members']
      ];
      const admin = h.addAdmin(Object.fromEntries(Object.values(ADMIN_PERMISSIONS).map((c) => [c, false])));
      const token = h.tokenFor(admin);

      for (const [method, url, key] of cases) {
        const res = await request(method, url, { token });
        assert.strictEqual(res.status, 403, `${url}`);
        assert.strictEqual(res.body.code, 'ADMIN_PERMISSION_REQUIRED', `${url}`);
        assert.ok(
          res.body.message.includes(ADMIN_PERMISSION_LABELS[key]),
          `${url} 應提到「${ADMIN_PERMISSION_LABELS[key]}」，實際為 ${res.body.message}`
        );
      }
    }],

    ['具備權限的管理員可以讀取備份清單與待刪除帳號', async () => {
      const admin = h.addAdmin({ can_manage_system: true, can_manage_members: true });
      const token = h.tokenFor(admin);
      const target = h.addUser({ nickname: '待刪除' });
      target.deletion_requested_at = new Date();

      const backups = await request('GET', '/api/admin/backups', { token });
      assert.strictEqual(backups.status, 200);
      assert.strictEqual(backups.body.keep, 14);
      assert.deepStrictEqual(backups.body.data, []);

      const deletions = await request('GET', '/api/admin/deletions', { token });
      assert.strictEqual(deletions.status, 200);
      assert.strictEqual(deletions.body.data.length, 1);
      assert.strictEqual(deletions.body.data[0].nickname, '待刪除');
      assert.strictEqual(
        new Date(deletions.body.data[0].purge_at).getTime(),
        new Date(target.deletion_requested_at).getTime() + 30 * 86400000
      );
    }],

    ['有客服權限的管理員名單只含啟用中的管理員', async () => {
      const active = h.addAdmin({ can_manage_support: true });
      const suspended = h.addUser({ role: 'admin', isActive: false });
      const blacklisted = h.addUser({ role: 'admin', isBlacklisted: true });
      const member = h.addUser();

      const ids = await adminPermissions.adminIdsWith('support');
      assert.ok(ids.includes(active.user_id));
      assert.ok(!ids.includes(suspended.user_id));
      assert.ok(!ids.includes(blacklisted.user_id));
      assert.ok(!ids.includes(member.user_id));
    }],

    ['變更會員狀態：不能改自己，也必須指定欄位', async () => {
      const admin = h.addAdmin({ can_manage_members: true });
      const token = h.tokenFor(admin);

      const self = await request('PATCH', `/api/admin/members/${admin.user_id}`, { token, body: { is_active: false } });
      assert.strictEqual(self.status, 400);
      assert.strictEqual(self.body.message, '無法變更自己的帳號狀態');

      const target = h.addUser();
      const empty = await request('PATCH', `/api/admin/members/${target.user_id}`, { token, body: {} });
      assert.strictEqual(empty.status, 400);
      assert.strictEqual(empty.body.message, '沒有需要變更的欄位');

      const badRole = await request('PATCH', `/api/admin/members/${target.user_id}`, { token, body: { role: 'god' } });
      assert.strictEqual(badRole.body.message, '不支援的身分');
    }],

    ['變更會員狀態：會留下可還原的操作紀錄', async () => {
      const admin = h.addAdmin({ can_manage_members: true });
      const target = h.addUser({ nickname: '違規會員' });

      const res = await request('PATCH', `/api/admin/members/${target.user_id}`, {
        token: h.tokenFor(admin), body: { is_blacklisted: true, is_active: false }
      });
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.body.message, '會員狀態已更新');
      assert.strictEqual(target.is_blacklisted, true);
      assert.strictEqual(target.is_active, false);

      const [log] = prisma.rows('admin_operation_logs');
      assert.strictEqual(log.action, '變更會員狀態');
      assert.strictEqual(log.target_type, 'user');
      const detail = JSON.parse(log.detail);
      assert.ok(detail.summary.includes('違規會員'));
      assert.deepStrictEqual(detail.changes.map((c) => c.label).sort(), ['帳號啟用', '黑名單']);
      assert.ok(detail.changes.some((c) => c.field === 'is_active' && c.from === '啟用' && c.to === '停權'));
      assert.strictEqual(detail.undo[0].op, 'update');
      assert.strictEqual(detail.undo[0].model, 'users');
    }],

    ['變更已匿名化的帳號會被拒絕', async () => {
      const admin = h.addAdmin({ can_manage_members: true });
      const target = h.addUser();
      target.anonymized_at = new Date();

      const res = await request('PATCH', `/api/admin/members/${target.user_id}`, {
        token: h.tokenFor(admin), body: { is_active: false }
      });
      assert.strictEqual(res.status, 409);
      assert.strictEqual(res.body.message, '此帳號已刪除，無法變更狀態');
    }],

    ['重設密碼：不可重設自己或其他管理員，成功時登出所有裝置', async () => {
      const admin = h.addAdmin({ can_manage_members: true });
      const token = h.tokenFor(admin);
      const headers = verifiedAs(admin);

      const self = await request('POST', `/api/admin/members/${admin.user_id}/reset-password`, { token, headers });
      assert.strictEqual(self.status, 400);
      assert.strictEqual(self.body.message, '無法重設自己的密碼，請使用「更改密碼」');

      const otherAdmin = h.addAdmin();
      const denied = await request('POST', `/api/admin/members/${otherAdmin.user_id}/reset-password`, { token, headers });
      assert.strictEqual(denied.status, 403);
      assert.strictEqual(denied.body.message, '無法重設其他管理員的密碼');

      const target = h.addUser({ nickname: '一般會員' });
      const before = target.password_hash;
      h.addSession(target);
      h.addDevice(target, { token: `fcm-${'m'.repeat(30)}` });

      const res = await request('POST', `/api/admin/members/${target.user_id}/reset-password`, { token, headers });
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.headers.get('cache-control'), 'no-store');
      assert.strictEqual(res.body.message, '已重設，請將臨時密碼提供給使用者');
      assert.strictEqual(res.body.data.temp_password.length, 14);
      assert.notStrictEqual(target.password_hash, before);
      assert.ok(prisma.rows('user_sessions')[0].revoked_at);
      assert.deepStrictEqual(prisma.rows('push_devices'), []);

      const [notice] = prisma.rows('notifications');
      assert.strictEqual(notice.title, '密碼已被重設');
      assert.strictEqual(notice.related_type, 'password');

      // 臨時密碼不可寫進操作紀錄。
      const [log] = prisma.rows('admin_operation_logs');
      assert.strictEqual(log.action, '重設會員密碼');
      assert.strictEqual(log.detail.includes(res.body.data.temp_password), false);
    }],

    ['重設密碼需要先完成身分驗證', async () => {
      const admin = h.addAdmin({ can_manage_members: true });
      const target = h.addUser();
      const res = await request('POST', `/api/admin/members/${target.user_id}/reset-password`, { token: h.tokenFor(admin) });
      assert.strictEqual(res.status, 403);
      assert.strictEqual(res.body.code, 'VERIFICATION_REQUIRED');
    }],

    ['調整權限：只有管理員帳號需要細部權限，且不能開啟自己沒有的權限', async () => {
      const admin = h.addAdmin({ can_manage_members: true, can_manage_system: false, can_manage_content: false });
      const token = h.tokenFor(admin);
      const headers = verifiedAs(admin);

      const self = await request('PUT', `/api/admin/members/${admin.user_id}/permissions`, {
        token, headers, body: { can_manage_content: true }
      });
      assert.strictEqual(self.status, 400);
      assert.strictEqual(self.body.message, '無法變更自己的權限');

      const member = h.addUser();
      const notAdmin = await request('PUT', `/api/admin/members/${member.user_id}/permissions`, {
        token, headers, body: { can_manage_members: true }
      });
      assert.strictEqual(notAdmin.status, 400);
      assert.strictEqual(notAdmin.body.message, '只有管理員帳號才需要設定細部權限');

      const target = h.addAdmin({ can_manage_members: false });
      const beyond = await request('PUT', `/api/admin/members/${target.user_id}/permissions`, {
        token, headers, body: { can_manage_content: true }
      });
      assert.strictEqual(beyond.status, 403);
      assert.strictEqual(beyond.body.message, '無法開啟您本身未具備的權限');

      const system = await request('PUT', `/api/admin/members/${target.user_id}/permissions`, {
        token, headers, body: { can_manage_system: true }
      });
      assert.strictEqual(system.status, 403);
      assert.strictEqual(system.body.message, '「系統維運」僅能由具備此權限的管理員開啟');

      const empty = await request('PUT', `/api/admin/members/${target.user_id}/permissions`, { token, headers, body: {} });
      assert.strictEqual(empty.status, 400);
      assert.strictEqual(empty.body.message, '沒有需要更新的權限');
    }],

    ['調整權限：成功時寫入權限並記錄變更內容', async () => {
      const admin = h.addAdmin({ can_manage_members: true });
      const target = h.addAdmin({ can_manage_members: true, can_manage_content: true });

      const res = await request('PUT', `/api/admin/members/${target.user_id}/permissions`, {
        token: h.tokenFor(admin), headers: verifiedAs(admin), body: { can_manage_content: false }
      });
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.body.message, '已更新權限');

      const row = prisma.rows('admin_permissions').find((r) => Number(r.user_id) === target.user_id);
      assert.strictEqual(row.can_manage_content, false);

      const log = prisma.rows('admin_operation_logs').at(-1);
      assert.strictEqual(log.action, '調整管理員權限');
      const detail = JSON.parse(log.detail);
      assert.ok(detail.summary.includes('內容管理關閉'));
      assert.deepStrictEqual(detail.changes.map((c) => [c.label, c.from, c.to]), [['內容管理', '開啟', '關閉']]);
    }],

    ['錢包調整：金額與原因的檢查都在寫入前完成', async () => {
      const admin = h.addAdmin({ can_manage_wallets: true });
      const token = h.tokenFor(admin);
      const headers = verifiedAs(admin);
      const target = h.addUser();
      const adjust = (body) => request('POST', `/api/admin/wallets/${target.user_id}/adjust`, { token, headers, body });

      assert.strictEqual((await adjust({ amount: 0, description: '測試' })).body.message, '請輸入非零的調整金額');
      assert.strictEqual((await adjust({ amount: 'abc', description: '測試' })).body.message, '請輸入非零的調整金額');
      assert.strictEqual((await adjust({ amount: 1000001, description: '測試' })).body.message, '單次調整不可超過 1,000,000');
      assert.strictEqual((await adjust({ amount: 1.005, description: '測試' })).body.message, '金額最多可至小數點後兩位');
      assert.strictEqual((await adjust({ amount: 100, description: '' })).body.message, '請填寫調整原因，此原因將記錄於帳務紀錄');
      assert.strictEqual(prisma.rows('wallet_transactions').length, 0);
    }],

    ['錢包調整需要錢包管理權限與身分驗證', async () => {
      const denied = h.addAdmin({ can_manage_wallets: false });
      const target = h.addUser();
      const noPermission = await request('POST', `/api/admin/wallets/${target.user_id}/adjust`, {
        token: h.tokenFor(denied), body: { amount: 100, description: '補償' }
      });
      assert.strictEqual(noPermission.status, 403);
      assert.strictEqual(noPermission.body.message, '您沒有「錢包管理」的權限');

      const admin = h.addAdmin({ can_manage_wallets: true });
      const unverified = await request('POST', `/api/admin/wallets/${target.user_id}/adjust`, {
        token: h.tokenFor(admin), body: { amount: 100, description: '補償' }
      });
      assert.strictEqual(unverified.status, 403);
      assert.strictEqual(unverified.body.code, 'VERIFICATION_REQUIRED');
    }],

    ['會員清單的權限欄位以權限代碼呈現', () => {
      assert.deepStrictEqual(members.PERMISSION_COLUMNS, Object.values(ADMIN_PERMISSIONS));
      assert.strictEqual(members.PERMISSION_COLUMNS.length, 12);
    }]
  ]
};
