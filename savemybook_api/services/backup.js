const { spawn } = require('child_process');
const crypto = require('crypto');
const fs = require('fs');
const os = require('os');
const path = require('path');
const zlib = require('zlib');
const { pipeline } = require('stream/promises');
const prisma = require('../lib/prisma');
const { env } = require('../config/env');
const { parseDatabaseUrl } = require('../lib/db-url');
const { conflict, notFound } = require('../lib/errors');
const maintenance = require('../lib/maintenance');

const BACKUP_DIR = env.backupDir || path.join(__dirname, '../backups');

const KEEP = env.backupKeep > 0 ? env.backupKeep : 14;

const FILE_RE = /^savemybook-[\w-]+\.sql\.gz$/;

const ensureDir = () => fs.mkdirSync(BACKUP_DIR, { recursive: true });

const stamp = () => new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);

// 備份與還原不可同時進行，否則會搶鎖或產生壞檔。
let running = null;

let restoreState = { state: 'idle' };

// 密碼經 --defaults-extra-file 傳入：命令列參數可被 ps 看到，MYSQL_PWD 已淘汰且部分用戶端不讀。
const writeOptionFile = (cfg) => {
  const quote = (value) => `"${String(value).replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`;
  const file = path.join(os.tmpdir(), `smb-dump-${crypto.randomBytes(8).toString('hex')}.cnf`);
  fs.writeFileSync(file, `[client]\npassword=${quote(cfg.password)}\n`, { mode: 0o600 });
  return file;
};

// --no-tablespaces 與不加 --routines/--events：這些需要一般帳號沒有的權限，mysqldump 會直接中止。
const baseArgs = (cfg, optionFile) => [
  `--defaults-extra-file=${optionFile}`,
  `--host=${cfg.host}`,
  `--port=${cfg.port}`,
  `--user=${cfg.user}`,
  '--single-transaction',
  '--quick',
  '--no-tablespaces',
  '--default-character-set=utf8mb4'
];

const collectStderr = (child) => {
  let stderr = '';
  child.stderr.on('data', (chunk) => {
    if (stderr.length < 4000) stderr += chunk;
  });
  return () => stderr.trim();
};

const exitOf = (child, tool) => new Promise((resolve, reject) => {
  child.on('error', (err) => reject(err.code === 'ENOENT' ? new Error(`找不到 ${tool}，請確認伺服器已安裝`) : err));
  child.on('close', (code) => resolve(code));
});

const spawnDump = (args, filePath) => new Promise((resolve, reject) => {
  // 以 spawn 執行而非 shell 管線：管線結束碼是 gzip 的，mysqldump 失敗也會被當成成功。
  const child = spawn('mysqldump', args, { stdio: ['ignore', 'pipe', 'pipe'] });

  let stderr = '';
  child.stderr.on('data', (chunk) => {
    if (stderr.length < 4000) stderr += chunk;
  });

  const exited = new Promise((res, rej) => {
    child.on('error', (err) => rej(err.code === 'ENOENT' ? new Error('找不到 mysqldump，請確認伺服器已安裝') : err));
    child.on('close', (code) => res(code));
  });

  Promise.all([pipeline(child.stdout, zlib.createGzip(), fs.createWriteStream(filePath)), exited])
    .then(([, code]) => resolve({ code, stderr: stderr.trim() }))
    .catch(reject);
});

const dump = async (filePath) => {
  const cfg = parseDatabaseUrl(env.databaseUrl);
  const optionFile = writeOptionFile(cfg);
  try {
    let result = await spawnDump([...baseArgs(cfg, optionFile), cfg.database], filePath);

    // MySQL 8 的 mysqldump 連 MariaDB 或 5.7 時會因查詢 COLUMN_STATISTICS 而失敗。
    if (result.code !== 0 && /column.statistics/i.test(result.stderr)) {
      result = await spawnDump([...baseArgs(cfg, optionFile), '--column-statistics=0', cfg.database], filePath);
    }

    // mysqldump 會把警告寫到 stderr，須以結束碼判斷成敗。
    if (result.code !== 0) throw new Error(result.stderr || `mysqldump 結束碼 ${result.code}`);
  } finally {
    fs.rmSync(optionFile, { force: true });
  }
};

const runOnce = async ({ adminId, trigger, pruneAfter = true }) => {
  ensureDir();
  const fileName = `savemybook-${stamp()}.sql.gz`;
  const filePath = path.join(BACKUP_DIR, fileName);

  try {
    await dump(filePath);

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

const importDump = async (filePath) => {
  const cfg = parseDatabaseUrl(env.databaseUrl);
  const optionFile = writeOptionFile(cfg);
  try {
    const child = spawn('mysql', [
      `--defaults-extra-file=${optionFile}`,
      `--host=${cfg.host}`,
      `--port=${cfg.port}`,
      `--user=${cfg.user}`,
      '--default-character-set=utf8mb4',
      cfg.database
    ], { stdio: ['pipe', 'ignore', 'pipe'] });
    const stderr = collectStderr(child);
    const exited = exitOf(child, 'mysql');
    exited.catch(() => {});

    await pipeline(fs.createReadStream(filePath), zlib.createGunzip(), child.stdin);
    const code = await exited;
    if (code !== 0) throw new Error(stderr() || `mysql 結束碼 ${code}`);
  } finally {
    fs.rmSync(optionFile, { force: true });
  }
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
  if (!target || target.status !== 'success') throw notFound('找不到這份備份');
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
      await importDump(filePath);
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

const checkTool = () => new Promise((resolve) => {
  const child = spawn('mysqldump', ['--version'], { stdio: ['ignore', 'pipe', 'ignore'] });
  let out = '';
  child.stdout.on('data', (chunk) => { out += chunk; });
  child.on('error', () => resolve(null));
  child.on('close', (code) => resolve(code === 0 ? out.trim() : null));
});

const remove = async (backupId) => {
  const record = await prisma.db_backups.findUnique({ where: { backup_id: backupId } });
  if (!record) return false;
  const p = filePathOf(record.file_name, { mustExist: false });
  if (p) fs.rmSync(p, { force: true });
  await prisma.db_backups.delete({ where: { backup_id: backupId } });
  return true;
};

module.exports = {
  BACKUP_DIR, KEEP, run, list, filePathOf, remove, prune, lastSuccessAt, lastAttemptAt, checkTool,
  startRestore, restoreStatus
};
