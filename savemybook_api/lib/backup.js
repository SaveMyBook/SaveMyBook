const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');
const prisma = require('./prisma');

const BACKUP_DIR = process.env.BACKUP_DIR || path.join(__dirname, '../backups');

/// 保留份數。超過就從最舊的開始刪，避免磁碟被塞爆。
const KEEP = parseInt(process.env.BACKUP_KEEP, 10) || 14;

const ensureDir = () => {
  if (!fs.existsSync(BACKUP_DIR)) fs.mkdirSync(BACKUP_DIR, { recursive: true });
};

const dbConfig = () => {
  const url = new URL(process.env.DATABASE_URL);
  const decode = (v) => {
    try { return decodeURIComponent(v); } catch { return v; }
  };
  return {
    host: url.hostname,
    port: parseInt(url.port, 10) || 3306,
    user: decode(url.username),
    password: decode(url.password),
    database: decode(url.pathname.substring(1))
  };
};

const stamp = () => new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);

/// 執行 mysqldump 並寫入一筆紀錄。
///
/// 密碼走環境變數 MYSQL_PWD 而不是 -p 參數：命令列參數在同一台機器上
/// 任何人都能用 ps 看到。
const run = async ({ adminId = null, trigger = 'schedule' } = {}) => {
  ensureDir();
  const cfg = dbConfig();
  const fileName = `savemybook-${stamp()}.sql.gz`;
  const filePath = path.join(BACKUP_DIR, fileName);

  const cmd = [
    'mysqldump',
    `--host=${cfg.host}`,
    `--port=${cfg.port}`,
    `--user=${cfg.user}`,
    '--single-transaction',
    '--quick',
    '--routines',
    '--events',
    '--default-character-set=utf8mb4',
    cfg.database,
    '| gzip >',
    JSON.stringify(filePath)
  ].join(' ');

  try {
    await new Promise((resolve, reject) => {
      exec(cmd, {
        env: { ...process.env, MYSQL_PWD: cfg.password },
        maxBuffer: 1024 * 1024 * 64,
        shell: '/bin/bash'
      }, (err, _stdout, stderr) => {
        // mysqldump 會把版本提示寫到 stderr，不能只看 stderr 有沒有東西。
        if (err) return reject(new Error(stderr || err.message));
        resolve();
      });
    });

    const size = fs.statSync(filePath).size;
    if (size === 0) throw new Error('備份檔為空，請確認 mysqldump 是否可用');

    const record = await prisma.db_backups.create({
      data: {
        file_name: fileName,
        size_bytes: size,
        trigger_by: trigger,
        admin_id: adminId,
        status: 'success'
      }
    });

    await prune();
    return record;
  } catch (err) {
    if (fs.existsSync(filePath)) fs.unlinkSync(filePath);
    await prisma.db_backups.create({
      data: {
        file_name: fileName,
        size_bytes: 0,
        trigger_by: trigger,
        admin_id: adminId,
        status: 'failed',
        detail: String(err.message).slice(0, 1000)
      }
    });
    throw err;
  }
};

/// 只保留最新的 KEEP 份成功備份，其餘連檔案帶紀錄一起清掉。
const prune = async () => {
  const success = await prisma.db_backups.findMany({
    where: { status: 'success' },
    orderBy: { created_at: 'desc' },
    skip: KEEP
  });

  for (const old of success) {
    const p = path.join(BACKUP_DIR, old.file_name);
    if (fs.existsSync(p)) fs.unlinkSync(p);
    await prisma.db_backups.delete({ where: { backup_id: old.backup_id } });
  }
};

const list = async ({ page = 1, limit = 30 } = {}) => {
  const [rows, total] = await Promise.all([
    prisma.db_backups.findMany({
      orderBy: { created_at: 'desc' },
      skip: (page - 1) * limit,
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
      available: fs.existsSync(path.join(BACKUP_DIR, r.file_name))
    }))
  };
};

const filePathOf = (fileName) => {
  // 只允許自己產生的檔名格式，擋掉 ../ 這類路徑穿越。
  if (!/^savemybook-[\w-]+\.sql\.gz$/.test(fileName)) return null;
  const p = path.join(BACKUP_DIR, fileName);
  return fs.existsSync(p) ? p : null;
};

const remove = async (backupId) => {
  const record = await prisma.db_backups.findUnique({ where: { backup_id: backupId } });
  if (!record) return false;
  const p = path.join(BACKUP_DIR, record.file_name);
  if (fs.existsSync(p)) fs.unlinkSync(p);
  await prisma.db_backups.delete({ where: { backup_id: backupId } });
  return true;
};

module.exports = { BACKUP_DIR, KEEP, run, list, filePathOf, remove, prune };
