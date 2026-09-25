#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');
const { env } = require('../config/env');

const MODELS = require('@prisma/client').Prisma.dmmf.datamodel.models;

const missingSchema = async (prisma) => {
  const rows = await prisma.$queryRaw`SELECT TABLE_NAME AS t, COLUMN_NAME AS c FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE()`;
  const columns = new Set(rows.map((r) => `${r.t}.${r.c}`));
  const tables = new Set(rows.map((r) => String(r.t)));
  return MODELS.flatMap((m) => {
    const table = m.dbName ?? m.name;
    if (!tables.has(table)) return [table];
    return m.fields.filter((f) => f.kind !== 'object' && !columns.has(`${table}.${f.dbName ?? f.name}`)).map((f) => `${table}.${f.dbName ?? f.name}`);
  });
};

const results = [];
const report = (ok, label, detail = '') => results.push({ ok, label, detail });

const tool = (bin) => {
  const r = spawnSync(bin, ['--version'], { encoding: 'utf8' });
  return r.status === 0 ? (r.stdout || r.stderr).trim().split('\n')[0] : null;
};

const main = async () => {
  report(Boolean(env.databaseUrl), 'DATABASE_URL 已設定');
  report(Boolean(env.jwtSecret) && env.jwtSecret.length >= 32, 'JWT_SECRET 已設定且長度足夠');

  const git = spawnSync('git', ['rev-parse', '--short', 'HEAD'], { cwd: path.join(__dirname, '..'), encoding: 'utf8' });
  const fetch = spawnSync('git', ['status', '-sb'], { cwd: path.join(__dirname, '..'), encoding: 'utf8' });
  report(git.status === 0, '程式碼版本', git.status === 0 ? `commit ${git.stdout.trim()}；${fetch.stdout.split('\n')[0]}` : '不是 git 目錄');

  const { MOUNTS } = require('../routes');
  report(MOUNTS.some(([p]) => p === '/api/security'), '路由包含帳號安全（/api/security）');

  let prisma;
  try {
    prisma = require('../lib/prisma');
    await prisma.$queryRaw`SELECT 1`;
    report(true, '資料庫連線');
  } catch (err) {
    report(false, '資料庫連線', err.message);
  }

  if (prisma) {
    try {
      const missing = await missingSchema(prisma);
      report(missing.length === 0, '資料庫結構與 prisma/schema.prisma 一致', missing.length
        ? `缺少 ${missing.join('、')}，請執行 npx prisma db push`
        : `${MODELS.length} 個資料表皆已建立`);
    } catch (err) {
      report(false, '資料庫結構與 prisma/schema.prisma 一致', err.message);
    }
  }

  const declared = [...fs.readFileSync(path.join(__dirname, '../prisma/schema.prisma'), 'utf8').matchAll(/^model (\w+) \{/gm)].map((m) => m[1]);
  const stale = declared.filter((name) => !MODELS.some((m) => m.name === name));
  report(stale.length === 0, 'Prisma Client 與 schema.prisma 一致', stale.length
    ? `缺少 ${stale.join('、')}，請執行 npx prisma generate 後重新啟動 API`
    : '');

  const { PROVIDERS, keyConfigured } = require('../lib/ai');
  const aiKeys = Object.values(PROVIDERS).map((p) => `${p.name} ${keyConfigured(p.id) ? '已設定' : '未設定'}`);
  const anyAiKey = Object.keys(PROVIDERS).some((id) => keyConfigured(id));
  report(true, 'AI 服務商金鑰', `${aiKeys.join('、')}${anyAiKey ? '' : '（AI 功能將維持關閉）'}`);

  const authSettings = require('../services/auth-settings');
  const authChannels = authSettings.PROVIDER_IDS
    .map((id) => `${authSettings.PROVIDER_LABELS[id]} ${authSettings.isConfigured(id) ? '已設定' : '未設定'}`);
  const anyChannel = authSettings.PROVIDER_IDS.some((id) => authSettings.isConfigured(id));
  report(true, '社群登入渠道憑證', `${authChannels.join('、')}${anyChannel ? '' : '（社群登入將維持關閉）'}`);

  if (authSettings.isConfigured('line') || authSettings.isConfigured('discord')) {
    const base = env.oauthRedirectBase;
    report(Boolean(base), 'OAuth 回呼網址前綴', base
      ? `${base}/api/auth/oauth/<provider>/callback`
      : '未設定 OAUTH_REDIRECT_BASE 或 PUBLIC_WEB_URL，LINE 與 Discord 無法使用');
  }

  const origins = env.passkeyOrigins;
  const badOrigins = origins.filter((o) => !/^https:\/\/[^/]+$/.test(o) && !/^android:apk-key-hash:[A-Za-z0-9_-]{43}$/.test(o));
  report(Boolean(env.passkeyRpId) && origins.length > 0 && badOrigins.length === 0, '通行密鑰 RP ID 與來源',
    badOrigins.length
      ? `PASSKEY_ORIGINS 格式不正確：${badOrigins.join('、')}`
      : `RP ID ${env.passkeyRpId || '（未設定）'}，來源 ${origins.length} 組`);
  if (!origins.includes(`https://${env.passkeyRpId}`)) {
    report(false, '通行密鑰 iOS 來源', `PASSKEY_ORIGINS 須包含 https://${env.passkeyRpId}`);
  }
  report(true, '通行密鑰 Android 來源', origins.some((o) => o.startsWith('android:apk-key-hash:'))
    ? '已設定'
    : 'PASSKEY_ORIGINS 未包含 android:apk-key-hash:<指紋>，Android 將無法使用通行密鑰');
  report(true, '/.well-known 關聯檔案', [
    env.appleTeamId && env.iosBundleId ? 'apple-app-site-association 由 API 提供' : 'apple-app-site-association 未由 API 提供（須由 nginx 提供靜態檔案）',
    env.androidPackageName && env.androidCertFingerprints.length ? 'assetlinks.json 由 API 提供' : 'assetlinks.json 未由 API 提供（須由 nginx 提供靜態檔案）'
  ].join('；'));

  const uploads = path.join(__dirname, '../uploads');
  const UPLOAD_FOLDERS = ['avatars', 'books', 'chat', 'evidence', 'voice'];
  try {
    for (const folder of UPLOAD_FOLDERS) fs.mkdirSync(path.join(uploads, folder), { recursive: true });
    fs.accessSync(uploads, fs.constants.W_OK);
    report(true, '上傳目錄可寫入', uploads);
  } catch (err) {
    report(false, '上傳目錄可寫入', err.message);
  }

  // 以 SFTP 覆蓋整個專案目錄時很容易把 uploads/ 一起洗掉，
  // 而 App 端只會看到一片替代圖，不會有任何錯誤訊息，因此這裡主動點名。
  const countFiles = (dir) => {
    let total = 0;
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      if (entry.name.startsWith('.')) continue;
      total += entry.isDirectory() ? countFiles(path.join(dir, entry.name)) : 1;
    }
    return total;
  };

  try {
    const counts = UPLOAD_FOLDERS.map((folder) => {
      const dir = path.join(uploads, folder);
      return { folder, files: fs.existsSync(dir) ? countFiles(dir) : null };
    });
    const empty = counts.filter((c) => !c.files).map((c) => c.folder);
    report(
      empty.length < UPLOAD_FOLDERS.length,
      '上傳檔案存在',
      `${counts.map((c) => `${c.folder} ${c.files === null ? '不存在' : `${c.files} 個檔案`}`).join('、')}` +
        (empty.length === UPLOAD_FOLDERS.length ? '；uploads/ 疑似在部署時被覆蓋或刪除' : '')
    );
  } catch (err) {
    report(false, '上傳檔案存在', err.message);
  }

  if (prisma) {
    try {
      const { sweep } = require('../services/uploads-cleanup');
      const { results: sweepResults, missingCount } = await sweep({ apply: false });
      const checked = sweepResults.reduce((sum, r) => sum + (r.checked ?? 0), 0);
      report(
        missingCount === 0,
        '資料庫圖片對得到檔案',
        missingCount === 0
          ? `檢查 ${checked} 筆，全部找得到檔案`
          : `檢查 ${checked} 筆，其中 ${missingCount} 筆在 uploads/ 找不到檔案，請確認部署時是否覆蓋了 uploads/；` +
            '確定檔案已無法救回時可執行 node scripts/prune-missing-uploads.js --apply 清除失效欄位'
      );
    } catch (err) {
      report(false, '資料庫圖片對得到檔案', err.message);
    }
  }

  const dump = tool('mysqldump');
  const client = tool('mysql');
  report(Boolean(dump), 'mysqldump（備份）', dump ?? '找不到，請安裝 mysql-client');
  report(Boolean(client), 'mysql（還原）', client ?? '找不到，請安裝 mysql-client');

  if (env.pushEnabled) {
    const file = env.fcmServiceAccountFile;
    const readable = Boolean(file) && fs.existsSync(file);
    report(readable, 'Firebase 服務帳戶金鑰', file ? (readable ? file : `找不到檔案：${file}`) : '未設定 FCM_SERVICE_ACCOUNT_FILE');
  }

  const width = Math.max(...results.map((r) => r.label.length));
  for (const r of results) {
    console.log(`${r.ok ? '✅' : '❌'} ${r.label.padEnd(width)}  ${r.detail}`);
  }
  const failed = results.filter((r) => !r.ok).length;
  console.log(failed ? `\n${failed} 項需要處理` : '\n部署檢查全部通過');
  if (prisma) await prisma.$disconnect().catch(() => {});
  process.exit(failed ? 1 : 0);
};

main();
