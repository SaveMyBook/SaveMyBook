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
const { conflict } = require('../lib/errors');

const BACKUP_DIR = env.backupDir || path.join(__dirname, '../backups');

/// 保留份數。超過就從最舊的開始刪，避免磁碟被塞爆。
const KEEP = env.backupKeep > 0 ? env.backupKeep : 14;

const FILE_RE = /^savemybook-[\w-]+\.sql\.gz$/;

const ensureDir = () => fs.mkdirSync(BACKUP_DIR, { recursive: true });

const stamp = () => new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);

/// 手動與排程同時觸發時，兩個 mysqldump 會搶同一個資料庫的讀取鎖，也可能寫出同名檔案。
let running = null;

/// 密碼寫進只有自己讀得到的暫存選項檔，用 --defaults-extra-file 交給 mysqldump。
///
/// 命令列參數在同一台機器上任何人都能用 ps 看到；MYSQL_PWD 環境變數已被 MySQL 標為淘汰，
/// 用戶端不讀它時會變成「using password: NO」連不上。選項檔 MySQL 與 MariaDB 都支援。
const writeOptionFile = (cfg) => {
  const quote = (value) => `"${String(value).replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`;
  const file = path.join(os.tmpdir(), `smb-dump-${crypto.randomBytes(8).toString('hex')}.cnf`);
  fs.writeFileSync(file, `[client]\npassword=${quote(cfg.password)}\n`, { mode: 0o600 });
  return file;
};

/// --no-tablespaces：MySQL 8.0.21 起匯出 tablespace 需要 PROCESS 權限，一般帳號沒有。
/// 不加 --routines / --events：專案沒有預存程序與事件，而這兩個選項需要額外權限，
/// 權限不足時 mysqldump 會直接中止。
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

const spawnDump = (args, filePath) => new Promise((resolve, reject) => {
  // 以 spawn 直接執行，不經過 shell：過去組成字串交給 bash 並用管線接 gzip，
  // 管線的結束碼是 gzip 的，mysqldump 失敗也會被當成成功，留下一個空的備份檔。
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

    // MySQL 8 的 mysqldump 連到 MariaDB 或 5.7 時會查不存在的 COLUMN_STATISTICS 而失敗。
    if (result.code !== 0 && /column.statistics/i.test(result.stderr)) {
      result = await spawnDump([...baseArgs(cfg, optionFile), '--column-statistics=0', cfg.database], filePath);
    }

    // mysqldump 會把警告寫到 stderr，不能只看 stderr 有沒有東西，要看結束碼。
    if (result.code !== 0) throw new Error(result.stderr || `mysqldump 結束碼 ${result.code}`);
  } finally {
    fs.rmSync(optionFile, { force: true });
  }
};

const runOnce = async ({ adminId, trigger }) => {
  ensureDir();
  const fileName = `savemybook-${stamp()}.sql.gz`;
  const filePath = path.join(BACKUP_DIR, fileName);

  try {
    await dump(filePath);

    const size = fs.statSync(filePath).size;
    // 空資料庫壓縮後也有幾百位元組，只有 gzip 標頭代表 mysqldump 什麼都沒輸出。
    if (size <= 20) throw new Error('備份檔為空，請確認 mysqldump 是否可用');

    const record = await prisma.db_backups.create({
      data: { file_name: fileName, size_bytes: size, trigger_by: trigger, admin_id: adminId, status: 'success' }
    });

    await prune();
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
  if (running) throw conflict('已有備份正在進行，請稍後再試');
  running = runOnce({ adminId, trigger });
  try {
    return await running;
  } finally {
    running = null;
  }
};

/// 只保留最新的 KEEP 份成功備份，其餘連檔案帶紀錄一起清掉。
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
      // 檔案可能被手動刪掉，前端要據此決定能不能下載。
      available: r.status === 'success' && !!filePathOf(r.file_name)
    }))
  };
};

/// 只允許自己產生的檔名格式，擋掉 ../ 這類路徑穿越。
const filePathOf = (fileName, { mustExist = true } = {}) => {
  if (typeof fileName !== 'string' || !FILE_RE.test(fileName)) return null;
  const p = path.join(BACKUP_DIR, fileName);
  return !mustExist || fs.existsSync(p) ? p : null;
};

/// 最近一次成功備份的時間。排程依這個判斷該不該備份，而不是依行程啟動後經過多久。
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

/// 啟動時確認 mysqldump 叫得起來，缺少時提早在日誌裡講清楚。
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

module.exports = { BACKUP_DIR, KEEP, run, list, filePathOf, remove, prune, lastSuccessAt, lastAttemptAt, checkTool };
