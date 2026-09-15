const { spawn } = require('child_process');
const crypto = require('crypto');
const fs = require('fs');
const os = require('os');
const path = require('path');
const zlib = require('zlib');
const { pipeline } = require('stream/promises');
const { env } = require('../config/env');
const { parseDatabaseUrl } = require('./db-url');

// 密碼經 --defaults-extra-file 傳入：命令列參數可被 ps 看到，MYSQL_PWD 已淘汰且部分用戶端不讀。
const writeOptionFile = (cfg) => {
  const quote = (value) => `"${String(value).replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`;
  const file = path.join(os.tmpdir(), `smb-dump-${crypto.randomBytes(8).toString('hex')}.cnf`);
  fs.writeFileSync(file, `[client]\npassword=${quote(cfg.password)}\n`, { mode: 0o600 });
  return file;
};

const withOptionFile = async (task) => {
  const cfg = parseDatabaseUrl(env.databaseUrl);
  const optionFile = writeOptionFile(cfg);
  try {
    return await task(cfg, optionFile);
  } finally {
    fs.rmSync(optionFile, { force: true });
  }
};

// --no-tablespaces 與不加 --routines/--events：這些需要一般帳號沒有的權限，mysqldump 會直接中止。
const dumpArgs = (cfg, optionFile) => [
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

// 以 spawn 執行而非 shell 管線：管線結束碼是 gzip 的，mysqldump 失敗也會被當成成功。
const spawnDump = async (args, filePath) => {
  const child = spawn('mysqldump', args, { stdio: ['ignore', 'pipe', 'pipe'] });
  const stderr = collectStderr(child);
  const exited = exitOf(child, 'mysqldump');
  const [, code] = await Promise.all([pipeline(child.stdout, zlib.createGzip(), fs.createWriteStream(filePath)), exited]);
  return { code, stderr: stderr() };
};

const dumpDatabase = (filePath) => withOptionFile(async (cfg, optionFile) => {
  let result = await spawnDump([...dumpArgs(cfg, optionFile), cfg.database], filePath);

  // MySQL 8 的 mysqldump 連 MariaDB 或 5.7 時會因查詢 COLUMN_STATISTICS 而失敗。
  if (result.code !== 0 && /column.statistics/i.test(result.stderr)) {
    result = await spawnDump([...dumpArgs(cfg, optionFile), '--column-statistics=0', cfg.database], filePath);
  }

  // mysqldump 會把警告寫到 stderr，須以結束碼判斷成敗。
  if (result.code !== 0) throw new Error(result.stderr || `mysqldump 結束碼 ${result.code}`);
});

const importDatabase = (filePath) => withOptionFile(async (cfg, optionFile) => {
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
});

const dumpToolVersion = () => new Promise((resolve) => {
  const child = spawn('mysqldump', ['--version'], { stdio: ['ignore', 'pipe', 'ignore'] });
  let out = '';
  child.stdout.on('data', (chunk) => { out += chunk; });
  child.on('error', () => resolve(null));
  child.on('close', (code) => resolve(code === 0 ? out.trim() : null));
});

module.exports = { dumpDatabase, importDatabase, dumpToolVersion };
