const fs = require('fs');
const path = require('path');
const prisma = require('../lib/prisma');
const { env } = require('../config/env');
const { HttpError, badRequest, conflict, notFound } = require('../lib/errors');
const maintenance = require('../lib/maintenance');
const { dumpDatabase, importDatabase, dumpToolVersion } = require('../lib/mysql-client');
const audit = require('./audit');
const { passwordMatches } = require('./credentials');

const BACKUP_DIR = env.backupDir || path.join(__dirname, '../backups');

const KEEP = env.backupKeep > 0 ? env.backupKeep : 14;

const FILE_RE = /^savemybook-[\w-]+\.sql\.gz$/;

const ensureDir = () => fs.mkdirSync(BACKUP_DIR, { recursive: true });

const stamp = () => new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);

// 備份與還原不可同時進行，否則會搶鎖或產生壞檔。
let running = null;

let restoreState = { state: 'idle' };

const runOnce = async ({ adminId, trigger, pruneAfter = true }) => {
  ensureDir();
  const fileName = `savemybook-${stamp()}.sql.gz`;
  const filePath = path.join(BACKUP_DIR, fileName);

  try {
    await dumpDatabase(filePath);

    const size = fs.statSync(filePath).size;
    if (size <= 20) throw new Error('備份檔為空，請確認 mysqldump 是否可用');

    const record = await prisma.db_backups.create({
      data: { file_name: fileName, size_bytes: size, trigger_by: trigger, admin_id: adminId, status: 'success' }
    });

    if (pruneAfter) await prune();
    return record;
  } catch (err) {
    fs.rmSync(filePath, { force: true });
    await prisma.db_backups.create({
      data: {
        file_name: fileName,
        size_bytes: 0,
        trigger_by: trigger,
        admin_id: adminId,
        status: 'failed',
        detail: String(err.message).slice(0, 1000)
      }
    }).catch((logErr) => console.error('[寫入備份失敗紀錄失敗]:', logErr));
    throw err;
  }
};

const run = async ({ adminId = null, trigger = 'schedule' } = {}) => {
  if (running) throw conflict('已有備份或還原正在進行，請稍後再試');
  if (maintenance.current().active) throw conflict('系統維護中，請稍後再試');
  running = runOnce({ adminId, trigger });
  try {
    return await running;
  } finally {
    running = null;
  }
};

const prune = async () => {
  const old = await prisma.db_backups.findMany({
    where: { status: 'success' },
    orderBy: { created_at: 'desc' },
    skip: KEEP
  });

  for (const record of old) {
    const p = filePathOf(record.file_name, { mustExist: false });
    if (p) fs.rmSync(p, { force: true });
    await prisma.db_backups.delete({ where: { backup_id: record.backup_id } });
  }
};

const list = async ({ skip = 0, limit = 30 } = {}) => {
  const [rows, total] = await Promise.all([
    prisma.db_backups.findMany({
      orderBy: { created_at: 'desc' },
      skip,
      take: limit,
      include: { users: { select: { user_id: true, nickname: true } } }
    }),
    prisma.db_backups.count()
  ]);

  return {
    total,
    rows: rows.map((r) => ({
      backup_id: r.backup_id,
      file_name: r.file_name,
      size_bytes: Number(r.size_bytes),
      trigger_by: r.trigger_by,
      status: r.status,
      detail: r.detail,
      created_at: r.created_at,
      admin: r.users,
      available: r.status === 'success' && !!filePathOf(r.file_name)
    }))
  };
};

const filePathOf = (fileName, { mustExist = true } = {}) => {
  if (typeof fileName !== 'string' || !FILE_RE.test(fileName)) return null;
  const p = path.join(BACKUP_DIR, fileName);
  return !mustExist || fs.existsSync(p) ? p : null;
};

// 匯入會覆蓋 db_backups 表，須把還原前讀到的紀錄補回。
const restoreRecords = async (records) => {
  const existing = new Set((await prisma.db_backups.findMany({ select: { file_name: true } })).map((r) => r.file_name));
  const missing = records.filter((r) => !existing.has(r.file_name));
  for (const r of missing) {
    await prisma.db_backups.create({
      data: {
        file_name: r.file_name,
        size_bytes: r.size_bytes,
        trigger_by: r.trigger_by,
        // 管理員帳號可能不存在於還原後的資料庫，外鍵會失敗。
        admin_id: null,
        status: r.status,
        detail: r.detail,
        created_at: r.created_at
      }
    }).catch((err) => console.error('[補回備份紀錄失敗]:', r.file_name, err.message));
  }
};

const startRestore = async ({ backupId, adminId, onFinished }) => {
  if (running) throw conflict('已有備份或還原正在進行，請稍後再試');

  const target = await prisma.db_backups.findUnique({ where: { backup_id: backupId } });
  if (!target || target.status !== 'success') throw notFound('找不到此備份');
  const filePath = filePathOf(target.file_name);
  if (!filePath) throw notFound('備份檔已不存在，無法還原');

  let release;
  running = new Promise((resolve) => { release = resolve; });

  let safety;
  let records;
  try {
    // 不可在此輪替舊備份：要還原的若是最舊那份，會在匯入前被刪掉。
    safety = await runOnce({ adminId, trigger: 'pre_restore', pruneAfter: false });
    records = await prisma.db_backups.findMany();
  } catch (err) {
    running = null;
    release();
    throw err;
  }

  restoreState = {
    state: 'running',
    file_name: target.file_name,
    safety_file_name: safety.file_name,
    started_at: new Date()
  };
  maintenance.enter('系統正在還原資料庫，請稍後再試');

  (async () => {
    let error = null;
    try {
      await importDatabase(filePath);
    } catch (err) {
      error = err;
      console.error('[資料庫還原失敗]:', err);
    }

    try {
      await restoreRecords(records);
      await prune();
    } catch (err) {
      console.error('[補回備份紀錄失敗]:', err);
    } finally {
      maintenance.leave();
    }

    restoreState = {
      ...restoreState,
      state: error ? 'failed' : 'done',
      finished_at: new Date(),
      error: error ? String(error.message).slice(0, 500) : null
    };

    try {
      await onFinished?.({ target, safety, error });
    } catch (err) {
      console.error('[還原後續處理失敗]:', err);
    } finally {
      running = null;
      release();
    }
  })();

  return { target, safety };
};

const restoreStatus = () => restoreState;

const lastSuccessAt = async () => {
  const last = await prisma.db_backups.findFirst({
    where: { status: 'success' },
    orderBy: { created_at: 'desc' },
    select: { created_at: true }
  });
  return last?.created_at ?? null;
};

const lastAttemptAt = async (trigger) => {
  const last = await prisma.db_backups.findFirst({
    where: { trigger_by: trigger },
    orderBy: { created_at: 'desc' },
    select: { created_at: true }
  });
  return last?.created_at ?? null;
};

const remove = async (backupId) => {
  const record = await prisma.db_backups.findUnique({ where: { backup_id: backupId } });
  if (!record) return false;
  const p = filePathOf(record.file_name, { mustExist: false });
  if (p) fs.rmSync(p, { force: true });
  await prisma.db_backups.delete({ where: { backup_id: backupId } });
  return true;
};

const formatSize = (bytes) => (bytes >= 1024 * 1024 ? `${(bytes / 1024 / 1024).toFixed(1)} MB` : `${Math.ceil(bytes / 1024)} KB`);

const runManually = async ({ adminId, req }) => {
  let record;
  try {
    record = await run({ adminId, trigger: 'manual' });
  } catch (err) {
    if (err instanceof HttpError) throw err;
    console.error('[手動備份失敗]:', err);
    throw new HttpError(500, `備份失敗：${String(err.message).slice(0, 300)}`);
  }

  await audit.record(null, {
    adminId,
    action: '手動備份資料庫',
    targetType: 'backup',
    targetId: record.backup_id,
    summary: `建立資料庫備份 ${record.file_name}（${formatSize(Number(record.size_bytes))}）`,
    req
  });
  return record;
};

const prepareDownload = async (backupId, { adminId, req }) => {
  const record = await prisma.db_backups.findUnique({ where: { backup_id: backupId } });
  if (!record) throw notFound('找不到此備份');

  const filePath = filePathOf(record.file_name);
  if (!filePath) throw notFound('備份檔已不存在');

  await audit.record(null, {
    adminId,
    action: '下載資料庫備份',
    targetType: 'backup',
    targetId: backupId,
    summary: `下載資料庫備份 ${record.file_name}（含全站個資）`,
    req
  });
  return { filePath, fileName: record.file_name };
};

const restore = async (backupId, plain, { adminId, req }) => {
  if (!(await passwordMatches(adminId, plain))) throw badRequest('密碼錯誤');

  return startRestore({
    backupId,
    adminId,
    // 紀錄須在匯入之後才寫，否則會被備份檔裡的舊資料蓋掉。
    onFinished: async ({ target, safety, error }) => {
      const adminStillExists = await prisma.users.count({ where: { user_id: adminId } });
      if (!adminStillExists) return;
      await audit.record(null, {
        adminId,
        action: error ? '資料庫還原失敗' : '還原資料庫',
        targetType: 'backup',
        summary: error
          ? `嘗試將資料庫還原至 ${target.file_name} 失敗：${String(error.message).slice(0, 200)}。還原前備份為 ${safety.file_name}`
          : `將資料庫還原至 ${target.file_name}（${target.created_at.toISOString().slice(0, 16).replace('T', ' ')} UTC）。`
            + `還原前的狀態已備份為 ${safety.file_name}，如需復原請還原該備份`,
        req
      });
    }
  });
};

const removeWithAudit = async (backupId, { adminId, req }) => {
  const record = await prisma.db_backups.findUnique({ where: { backup_id: backupId } });
  const removed = await remove(backupId);
  if (!removed) throw notFound('找不到此備份');
  await audit.record(null, {
    adminId,
    action: '刪除資料庫備份',
    targetType: 'backup',
    targetId: backupId,
    summary: `刪除資料庫備份 ${record.file_name}（檔案已從磁碟移除，無法復原）`,
    req
  });
};

module.exports = {
  BACKUP_DIR, KEEP, run, list, filePathOf, lastSuccessAt, lastAttemptAt, checkTool: dumpToolVersion,
  restoreStatus, runManually, prepareDownload, restore, removeWithAudit
};
