const assert = require('assert');
const fs = require('fs');
const path = require('path');
const h = require('./harness');

const { prisma, request } = h;
const backup = h.api('services/backup');

const writeFile = (fileName, content = 'x'.repeat(100)) => {
  fs.mkdirSync(backup.BACKUP_DIR, { recursive: true });
  fs.writeFileSync(path.join(backup.BACKUP_DIR, fileName), content);
};

const addBackup = ({ fileName, status = 'success', trigger = 'manual', adminId = null, size = 100 }) => {
  const row = {
    backup_id: prisma.nextId('db_backups'),
    file_name: fileName,
    size_bytes: size,
    trigger_by: trigger,
    admin_id: adminId,
    status,
    detail: null,
    created_at: new Date()
  };
  prisma.rows('db_backups').push(row);
  return row;
};

const verifiedAs = (admin) => ({ 'x-verify-token': h.verifyTokenFor({ user: admin }) });

const systemAdmin = () => {
  const admin = h.addAdmin({ can_manage_system: true });
  return { admin, token: h.tokenFor(admin) };
};

module.exports = {
  name: '平台：資料庫備份',
  before: () => {
    fs.rmSync(backup.BACKUP_DIR, { recursive: true, force: true });
    fs.mkdirSync(backup.BACKUP_DIR, { recursive: true });
  },
  tests: [
    ['備份檔名必須符合固定格式，擋掉路徑穿越', () => {
      writeFile('savemybook-2026-05-10T00-00-00.sql.gz');
      assert.ok(backup.filePathOf('savemybook-2026-05-10T00-00-00.sql.gz'));
      assert.strictEqual(backup.filePathOf('savemybook-不存在.sql.gz'), null);
      assert.strictEqual(backup.filePathOf('../../etc/passwd'), null);
      assert.strictEqual(backup.filePathOf('savemybook-x.sql.gz/../../etc/passwd'), null);
      assert.strictEqual(backup.filePathOf('other.sql.gz'), null);
      assert.strictEqual(backup.filePathOf(null), null);
      // mustExist 為 false 時只檢查檔名格式。
      assert.ok(backup.filePathOf('savemybook-2026-01-01T00-00-00.sql.gz', { mustExist: false }));
    }],

    ['備份清單會標示檔案是否還在磁碟上', async () => {
      const { admin, token } = systemAdmin();
      writeFile('savemybook-2026-05-10T00-00-00.sql.gz');
      addBackup({ fileName: 'savemybook-2026-05-10T00-00-00.sql.gz', adminId: admin.user_id });
      addBackup({ fileName: 'savemybook-2026-05-09T00-00-00.sql.gz' });
      addBackup({ fileName: 'savemybook-2026-05-08T00-00-00.sql.gz', status: 'failed', size: 0 });

      const res = await request('GET', '/api/admin/backups', { token });
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.body.keep, backup.KEEP);
      assert.strictEqual(res.body.pagination.total, 3);
      const byName = Object.fromEntries(res.body.data.map((r) => [r.file_name, r]));
      assert.strictEqual(byName['savemybook-2026-05-10T00-00-00.sql.gz'].available, true);
      assert.strictEqual(byName['savemybook-2026-05-09T00-00-00.sql.gz'].available, false);
      assert.strictEqual(byName['savemybook-2026-05-08T00-00-00.sql.gz'].available, false);
      assert.strictEqual(byName['savemybook-2026-05-08T00-00-00.sql.gz'].status, 'failed');
    }],

    ['下載備份會留下含警語的操作紀錄', async () => {
      const { admin, token } = systemAdmin();
      writeFile('savemybook-2026-05-10T00-00-00.sql.gz', '備份內容');
      const record = addBackup({ fileName: 'savemybook-2026-05-10T00-00-00.sql.gz', adminId: admin.user_id });

      const res = await request('GET', `/api/admin/backups/${record.backup_id}/download`, { token });
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.headers.get('cache-control'), 'no-store');
      assert.strictEqual(res.text, '備份內容');

      const [log] = prisma.rows('admin_operation_logs');
      assert.strictEqual(log.action, '下載資料庫備份');
      assert.strictEqual(log.target_type, 'backup');
      assert.ok(JSON.parse(log.detail).summary.includes('含全站個資'));
    }],

    ['下載不存在的備份或已遺失的檔案都會回 404', async () => {
      const { admin, token } = systemAdmin();
      const missing = await request('GET', '/api/admin/backups/999/download', { token });
      assert.strictEqual(missing.status, 404);
      assert.strictEqual(missing.body.message, '找不到此備份');

      const record = addBackup({ fileName: 'savemybook-2026-05-07T00-00-00.sql.gz', adminId: admin.user_id });
      const gone = await request('GET', `/api/admin/backups/${record.backup_id}/download`, { token });
      assert.strictEqual(gone.status, 404);
      assert.strictEqual(gone.body.message, '備份檔已不存在');
      assert.strictEqual(prisma.rows('admin_operation_logs').length, 0);
    }],

    ['刪除備份會一併移除檔案並記錄無法復原', async () => {
      const { admin, token } = systemAdmin();
      writeFile('savemybook-2026-05-10T00-00-00.sql.gz');
      const record = addBackup({ fileName: 'savemybook-2026-05-10T00-00-00.sql.gz', adminId: admin.user_id });

      const res = await request('DELETE', `/api/admin/backups/${record.backup_id}`, { token, headers: verifiedAs(admin) });
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.body.message, '已刪除備份');
      assert.deepStrictEqual(prisma.rows('db_backups'), []);
      assert.strictEqual(fs.existsSync(path.join(backup.BACKUP_DIR, 'savemybook-2026-05-10T00-00-00.sql.gz')), false);

      const [log] = prisma.rows('admin_operation_logs');
      assert.strictEqual(log.action, '刪除資料庫備份');
      assert.ok(JSON.parse(log.detail).summary.includes('無法復原'));
    }],

    ['刪除備份需要身分驗證，找不到時回 404', async () => {
      const { admin, token } = systemAdmin();
      const unverified = await request('DELETE', '/api/admin/backups/1', { token });
      assert.strictEqual(unverified.status, 403);
      assert.strictEqual(unverified.body.code, 'VERIFICATION_REQUIRED');

      const missing = await request('DELETE', '/api/admin/backups/999', { token, headers: verifiedAs(admin) });
      assert.strictEqual(missing.status, 404);
      assert.strictEqual(missing.body.message, '找不到此備份');
    }],

    ['還原必須輸入自己的登入密碼', async () => {
      const { admin, token } = systemAdmin();
      writeFile('savemybook-2026-05-10T00-00-00.sql.gz');
      const record = addBackup({ fileName: 'savemybook-2026-05-10T00-00-00.sql.gz', adminId: admin.user_id });

      const empty = await request('POST', `/api/admin/backups/${record.backup_id}/restore`, { token, body: {} });
      assert.strictEqual(empty.status, 400);
      assert.strictEqual(empty.body.message, '請輸入您的登入密碼以確認還原');

      const wrong = await request('POST', `/api/admin/backups/${record.backup_id}/restore`, {
        token, body: { password: '錯的密碼' }
      });
      assert.strictEqual(wrong.status, 400);
      assert.strictEqual(wrong.body.message, '密碼錯誤');
      assert.strictEqual(backup.restoreStatus().state, 'idle');
    }],

    ['密碼正確但備份不存在時回 404，且不會進入維護模式', async () => {
      const { token } = systemAdmin();
      const res = await request('POST', '/api/admin/backups/999/restore', { token, body: { password: 'Passw0rd123' } });
      assert.strictEqual(res.status, 404);
      assert.strictEqual(res.body.message, '找不到此備份');
      assert.strictEqual(h.maintenance.current().active, false);
      assert.strictEqual(backup.restoreStatus().state, 'idle');
    }],

    ['備份檔已遺失時無法還原', async () => {
      const { admin, token } = systemAdmin();
      const record = addBackup({ fileName: 'savemybook-2026-05-06T00-00-00.sql.gz', adminId: admin.user_id });
      const res = await request('POST', `/api/admin/backups/${record.backup_id}/restore`, {
        token, body: { password: 'Passw0rd123' }
      });
      assert.strictEqual(res.status, 404);
      assert.strictEqual(res.body.message, '備份檔已不存在，無法還原');
    }],

    ['還原失敗的備份不可作為還原來源', async () => {
      const { admin, token } = systemAdmin();
      writeFile('savemybook-2026-05-05T00-00-00.sql.gz');
      const record = addBackup({ fileName: 'savemybook-2026-05-05T00-00-00.sql.gz', status: 'failed', adminId: admin.user_id });
      const res = await request('POST', `/api/admin/backups/${record.backup_id}/restore`, {
        token, body: { password: 'Passw0rd123' }
      });
      assert.strictEqual(res.status, 404);
      assert.strictEqual(res.body.message, '找不到此備份');
    }],

    ['最近一次成功備份的時間可供排程判斷', async () => {
      const older = addBackup({ fileName: 'savemybook-2026-05-01T00-00-00.sql.gz' });
      older.created_at = new Date(2026, 4, 1);
      const newer = addBackup({ fileName: 'savemybook-2026-05-09T00-00-00.sql.gz' });
      newer.created_at = new Date(2026, 4, 9);
      const failed = addBackup({ fileName: 'savemybook-2026-05-10T00-00-00.sql.gz', status: 'failed', trigger: 'schedule' });
      failed.created_at = new Date(2026, 4, 10);

      assert.deepStrictEqual(await backup.lastSuccessAt(), new Date(2026, 4, 9));
      assert.deepStrictEqual(await backup.lastAttemptAt('schedule'), new Date(2026, 4, 10));
      assert.strictEqual(await backup.lastAttemptAt('pre_restore'), null);
    }],

    ['備份相關端點一律需要系統維運權限', async () => {
      const admin = h.addAdmin({ can_manage_system: false });
      const token = h.tokenFor(admin);
      const calls = [
        ['GET', '/api/admin/backups'],
        ['POST', '/api/admin/backups'],
        ['GET', '/api/admin/backups/1/download'],
        ['DELETE', '/api/admin/backups/1']
      ];
      for (const [method, url] of calls) {
        const res = await request(method, url, { token, ...(method === 'POST' ? { body: {} } : {}) });
        assert.strictEqual(res.status, 403, url);
        assert.strictEqual(res.body.code, 'ADMIN_PERMISSION_REQUIRED', url);
        assert.ok(res.body.message.includes('系統維運'), url);
      }
    }]
  ]
};
