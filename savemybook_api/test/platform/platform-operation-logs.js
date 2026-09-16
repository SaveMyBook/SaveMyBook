const assert = require('assert');
const h = require('./harness');

const { prisma, request } = h;
const audit = h.api('services/audit');
const publicId = h.api('lib/public-id');

const addLog = ({ adminId, action = '變更會員狀態', targetType = 'user', targetId = 1, detail }) => {
  const row = {
    log_id: prisma.nextId('admin_operation_logs'),
    admin_id: adminId,
    action,
    target_type: targetType,
    target_id: targetId,
    ip_address: '10.0.0.1',
    detail: typeof detail === 'string' ? detail : JSON.stringify({
      v: 2, summary: '摘要', changes: [], undo: null, reverted: null, ...detail
    }),
    created_at: new Date()
  };
  prisma.rows('admin_operation_logs').push(row);
  return row;
};

const verifiedAs = (admin) => ({ 'x-verify-token': h.verifyTokenFor({ user: admin }) });

module.exports = {
  name: '平台：操作紀錄',
  tests: [
    ['操作紀錄會保存摘要、變更內容與來源 IP', async () => {
      const admin = h.addAdmin();
      const created = await audit.record(null, {
        adminId: admin.user_id,
        action: '動'.repeat(200),
        targetType: 'book',
        targetId: 7,
        summary: '下架書籍',
        changes: [{ field: 'status', label: '狀態', from: '上架中', to: '已下架' }],
        undo: [audit.undoUpdate('books', 7, { status: 'on_sale' }, { status: 'removed' }, { status: '狀態' })],
        req: { ip: 'x'.repeat(60) }
      });
      assert.strictEqual(created.action.length, 100);
      assert.strictEqual(created.ip_address.length, 45);

      const detail = audit.parseDetail(created.detail);
      assert.strictEqual(detail.v, 2);
      assert.strictEqual(detail.summary, '下架書籍');
      assert.strictEqual(detail.reverted, null);
      assert.strictEqual(detail.undo[0].model, 'books');
      assert.deepStrictEqual(detail.undo[0].before, { status: 'on_sale' });
    }],

    ['舊版的純文字紀錄仍可讀取', () => {
      assert.deepStrictEqual(audit.parseDetail('刪除了一本書'), {
        v: 1, summary: '刪除了一本書', changes: [], undo: null, reverted: null
      });
      assert.deepStrictEqual(audit.parseDetail(null).summary, '');
      assert.deepStrictEqual(audit.parseDetail('{壞掉的 JSON').summary, '{壞掉的 JSON');
      assert.strictEqual(audit.parseDetail(JSON.stringify({ v: 1, summary: 'x' })).v, 1);
    }],

    ['變更比較會忽略沒有實際變動的欄位', () => {
      const fields = { price: '售價', title: '書名', is_active: { label: '啟用', format: (v) => (v ? '是' : '否') } };
      const changes = audit.diff(
        { price: '100', title: '書名', is_active: true },
        { price: 100, title: '新書名', is_active: false },
        fields
      );
      assert.deepStrictEqual(changes.map((c) => c.field), ['title', 'is_active']);
      assert.deepStrictEqual(changes[0], { field: 'title', label: '書名', from: '書名', to: '新書名' });
      assert.deepStrictEqual(changes[1], { field: 'is_active', label: '啟用', from: '是', to: '否' });

      // 沒有出現在 after 的欄位不會被視為變更。
      assert.deepStrictEqual(audit.diff({ price: 1 }, {}, fields), []);
      assert.deepStrictEqual(audit.diff({ price: 1 }, { price: undefined }, fields), []);
    }],

    ['值的顯示會轉成中文與可讀格式', () => {
      assert.strictEqual(audit.display(null), '（空白）');
      assert.strictEqual(audit.display(''), '（空白）');
      assert.strictEqual(audit.display(true), '是');
      assert.strictEqual(audit.display(false), '否');
      assert.strictEqual(audit.display('文'.repeat(200)).length, 120);
      assert.ok(audit.display('文'.repeat(200)).endsWith('…'));
      assert.ok(audit.display(new Date('2026-05-10T04:00:00Z')).includes('2026'));
    }],

    ['操作紀錄列表以加密編號呈現紀錄與對象', async () => {
      const admin = h.addAdmin();
      const log = addLog({
        adminId: admin.user_id,
        targetType: 'book',
        targetId: 42,
        detail: { summary: '下架書籍《挪威的森林》', changes: [{ field: 'status', label: '狀態', from: '上架中', to: '已下架' }] }
      });

      const res = await request('GET', '/api/admin/operation-logs', { token: h.tokenFor(admin) });
      assert.strictEqual(res.status, 200);
      const [row] = res.body.data;
      assert.strictEqual(row.log_no, publicId.encode('log', log.log_id));
      assert.strictEqual(row.target_no, publicId.encode('book', 42));
      assert.ok(row.log_no.startsWith('LG'));
      assert.ok(row.target_no.startsWith('BK'));
      assert.strictEqual(row.summary, '下架書籍《挪威的森林》');
      // 舊版 App 讀的是 detail 欄位。
      assert.strictEqual(row.detail, row.summary);
      assert.strictEqual(row.can_undo, false);
      assert.strictEqual(row.changes.length, 1);
      // 使用者看得到的文字不得出現流水號。
      assert.strictEqual(/\b42\b/.test(row.summary), false);
    }],

    ['沒有對象的紀錄不會產生對象編號', async () => {
      const admin = h.addAdmin();
      addLog({ adminId: admin.user_id, targetType: null, targetId: null, action: '修改 AI 設定' });
      const res = await request('GET', '/api/admin/operation-logs', { token: h.tokenFor(admin) });
      assert.strictEqual(res.body.data[0].target_no, null);
    }],

    ['可依對象類型、管理員與關鍵字篩選', async () => {
      const admin = h.addAdmin();
      const other = h.addAdmin();
      addLog({ adminId: admin.user_id, targetType: 'book', targetId: 42, detail: { summary: '下架書籍' } });
      addLog({ adminId: other.user_id, targetType: 'user', targetId: 9, action: '重設會員密碼', detail: { summary: '重設密碼' } });
      const token = h.tokenFor(admin);

      const byType = await request('GET', '/api/admin/operation-logs?target_type=book', { token });
      assert.strictEqual(byType.body.data.length, 1);
      assert.strictEqual(byType.body.pagination.total, 1);

      const byAdmin = await request('GET', `/api/admin/operation-logs?admin_id=${other.user_id}`, { token });
      assert.strictEqual(byAdmin.body.data.length, 1);
      assert.strictEqual(byAdmin.body.data[0].action, '重設會員密碼');

      const byKeyword = await request('GET', '/api/admin/operation-logs?keyword=重設', { token });
      assert.strictEqual(byKeyword.body.data.length, 1);

      const bad = await request('GET', '/api/admin/operation-logs?target_type=planet', { token });
      assert.strictEqual(bad.status, 400);
      assert.strictEqual(bad.body.message, '不支援的對象類型');
    }],

    ['以對象的加密編號搜尋可找到對應的紀錄', async () => {
      const admin = h.addAdmin();
      addLog({ adminId: admin.user_id, targetType: 'book', targetId: 42, detail: { summary: '下架書籍' } });
      addLog({ adminId: admin.user_id, targetType: 'book', targetId: 43, detail: { summary: '下架另一本' } });

      const res = await request('GET', `/api/admin/operation-logs?keyword=${publicId.encode('book', 42)}`, {
        token: h.tokenFor(admin)
      });
      assert.strictEqual(res.body.data.length, 1);
      assert.strictEqual(res.body.data[0].summary, '下架書籍');
    }],

    ['維運紀錄只包含書櫃相關的操作', async () => {
      const admin = h.addAdmin();
      addLog({ adminId: admin.user_id, targetType: 'cabinet', targetId: 1, action: '新增書櫃' });
      addLog({ adminId: admin.user_id, targetType: 'cabinet_slot', targetId: 2, action: '調整櫃位狀態' });
      addLog({ adminId: admin.user_id, targetType: 'book', targetId: 3, action: '下架書籍' });

      const res = await request('GET', '/api/admin/maintenance-logs', { token: h.tokenFor(admin) });
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.body.data.length, 2);
      assert.deepStrictEqual(res.body.data.map((r) => r.target_type).sort(), ['cabinet', 'cabinet_slot']);
    }],

    ['還原：找不到紀錄、無法還原與已還原都有明確訊息', async () => {
      const admin = h.addAdmin({ can_manage_members: true });
      const token = h.tokenFor(admin);
      const headers = verifiedAs(admin);

      const missing = await request('POST', '/api/admin/operation-logs/999/undo', { token, headers, body: {} });
      assert.strictEqual(missing.status, 404);
      assert.strictEqual(missing.body.message, '找不到此操作紀錄');

      const noUndo = addLog({ adminId: admin.user_id, detail: { summary: '重設密碼', undo: null } });
      const cannot = await request('POST', `/api/admin/operation-logs/${noUndo.log_id}/undo`, { token, headers, body: {} });
      assert.strictEqual(cannot.status, 409);
      assert.strictEqual(
        cannot.body.message,
        '此操作無法自動還原（例如涉及金流、密碼或已刪除的檔案），請至對應頁面手動處理'
      );

      const done = addLog({
        adminId: admin.user_id,
        detail: { summary: '變更狀態', undo: [{ op: 'update', model: 'users', id: 1, before: {}, after: {} }], reverted: { at: '2026-01-01' } }
      });
      const already = await request('POST', `/api/admin/operation-logs/${done.log_id}/undo`, { token, headers, body: {} });
      assert.strictEqual(already.status, 409);
      assert.strictEqual(already.body.message, '此操作已還原');
    }],

    ['還原：沒有該功能權限的管理員不能還原', async () => {
      const admin = h.addAdmin({ can_manage_members: false });
      const log = addLog({
        adminId: admin.user_id,
        targetType: 'user',
        detail: { summary: '停權會員', undo: [{ op: 'update', model: 'users', id: 1, before: { is_active: true }, after: { is_active: false } }] }
      });

      const res = await request('POST', `/api/admin/operation-logs/${log.log_id}/undo`, {
        token: h.tokenFor(admin), headers: verifiedAs(admin), body: {}
      });
      assert.strictEqual(res.status, 403);
      assert.strictEqual(res.body.message, '您沒有此功能的權限，無法還原此操作');
    }],

    ['還原：會還原欄位並留下互為反向的新紀錄', async () => {
      const admin = h.addAdmin({ can_manage_members: true });
      const token = h.tokenFor(admin);
      const headers = verifiedAs(admin);
      const target = h.addUser({ nickname: '會員甲' });

      await request('PATCH', `/api/admin/members/${target.user_id}`, { token, body: { is_active: false } });
      assert.strictEqual(target.is_active, false);
      const original = prisma.rows('admin_operation_logs').at(-1);

      const res = await request('POST', `/api/admin/operation-logs/${original.log_id}/undo`, { token, headers, body: {} });
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.body.message, '已還原');
      assert.strictEqual(target.is_active, true);

      const reverted = audit.parseDetail(prisma.rows('admin_operation_logs')[0].detail).reverted;
      assert.strictEqual(reverted.by, admin.user_id);
      assert.ok(reverted.log_id);

      const entry = prisma.rows('admin_operation_logs').at(-1);
      assert.strictEqual(entry.action, '還原：變更會員狀態');
      const detail = audit.parseDetail(entry.detail);
      // 摘要以加密編號指向原紀錄，不會出現流水號。
      assert.ok(detail.summary.includes(publicId.encode('log', original.log_id)));
      assert.deepStrictEqual(detail.changes.map((c) => [c.from, c.to]), [['停權', '啟用']]);

      const list = await request('GET', '/api/admin/operation-logs', { token });
      const shown = list.body.data.find((r) => r.log_id === original.log_id);
      assert.strictEqual(shown.can_undo, false);
      assert.strictEqual(shown.reverted.by, admin.user_id);
    }],

    ['還原：對象資料之後又被改過時會擋下', async () => {
      const admin = h.addAdmin({ can_manage_members: true });
      const token = h.tokenFor(admin);
      const target = h.addUser();

      await request('PATCH', `/api/admin/members/${target.user_id}`, { token, body: { is_active: false } });
      const original = prisma.rows('admin_operation_logs').at(-1);
      target.is_active = true;

      const res = await request('POST', `/api/admin/operation-logs/${original.log_id}/undo`, {
        token, headers: verifiedAs(admin), body: {}
      });
      assert.strictEqual(res.status, 409);
      assert.ok(res.body.message.includes('之後曾再次修改'));
      assert.ok(res.body.message.includes('帳號啟用目前是 是'));
      assert.strictEqual(res.body.code, 'UNDO_CONFLICT');
    }],

    ['還原需要先完成身分驗證', async () => {
      const admin = h.addAdmin({ can_manage_members: true });
      const log = addLog({ adminId: admin.user_id });
      const res = await request('POST', `/api/admin/operation-logs/${log.log_id}/undo`, { token: h.tokenFor(admin), body: {} });
      assert.strictEqual(res.status, 403);
      assert.strictEqual(res.body.code, 'VERIFICATION_REQUIRED');
    }]
  ]
};
