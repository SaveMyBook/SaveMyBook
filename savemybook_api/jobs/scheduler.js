const { env } = require('../config/env');
const { processDueDeletions } = require('../services/account');
const backup = require('../services/backup');
const push = require('../services/push');
const maintenance = require('../lib/maintenance');
const sessions = require('../services/sessions');
const reservations = require('../services/reservations');
const transferRecords = require('../services/chat/transfer-records');
const oauth = require('../services/oauth-providers');
const passkeys = require('../services/passkeys');
const uploadsCleanup = require('../services/uploads-cleanup');
const supportAttachments = require('../services/support-attachments');
const catalogSearch = require('../services/ai/catalog-search');
const knowledge = require('../services/ai/knowledge');

const MINUTE = 60 * 1000;
const HOUR = 60 * MINUTE;
const BACKUP_EVERY = 24 * HOUR;

const runDeletionSweep = async () => {
  if (maintenance.current().active) return;
  try {
    const count = await processDueDeletions();
    if (count > 0) console.log(`🗑️  已檢查 ${count} 個逾期帳號`);
  } catch (err) {
    console.error('[刪除排程失敗]:', err);
  }
};

// 依上次成功備份時間判斷，不用 setInterval(24h)：重啟會讓計時歸零而永遠不備份。
const runBackupIfDue = async () => {
  if (!env.backupEnabled || maintenance.current().active) return;
  try {
    const lastSuccess = await backup.lastSuccessAt();
    if (lastSuccess && Date.now() - lastSuccess.getTime() < BACKUP_EVERY) return;

    const lastAttempt = await backup.lastAttemptAt('schedule');
    if (lastAttempt && Date.now() - lastAttempt.getTime() < HOUR) return;

    const record = await backup.run({ trigger: 'schedule' });
    console.log(`💾 資料庫已備份：${record.file_name}`);
  } catch (err) {
    if (err.status === 409) return;
    console.error('[備份排程失敗]:', err.message);
  }
};

const runDeviceCleanup = async () => {
  try {
    if (push.isReady()) await push.removeStaleDevices();
    await sessions.removeStale();
  } catch (err) {
    console.error('[清理裝置失敗]:', err.message);
  }
};

const runOauthCleanup = async () => {
  try {
    await oauth.cleanupExpired();
  } catch (err) {
    console.error('[清理社群登入暫存資料失敗]:', err.message);
  }
  try {
    await passkeys.cleanupExpired();
  } catch (err) {
    console.error('[清理通行密鑰挑戰值失敗]:', err.message);
  }
};

const runReservationExpiry = async () => {
  if (maintenance.current().active) return;
  try {
    await reservations.expireDue();
  } catch (err) {
    console.error('[預約到期處理失敗]:', err.message);
  }
  try {
    await transferRecords.expireDue();
  } catch (err) {
    console.error('[請款到期處理失敗]:', err.message);
  }
};

// 上傳目錄可能因為部署覆蓋而遺失檔案；每天清一次，避免畫面長期出現破圖。
const runUploadsSweep = async () => {
  if (maintenance.current().active) return;
  try {
    const { missingCount } = await uploadsCleanup.sweep({ apply: true });
    if (missingCount > 0) console.log(`🖼️  已清除 ${missingCount} 筆找不到檔案的圖片欄位`);
  } catch (err) {
    console.error('[清理失效圖片欄位失敗]:', err.message);
  }
  try {
    await supportAttachments.purgeStale();
  } catch (err) {
    console.error('[清理未送出的客服附件失敗]:', err.message);
  }
};

// 預先建立語意檢索的向量；未設定金鑰、AI 關閉或尚未執行 020 時不做任何事。
const runEmbeddingSync = async () => {
  if (maintenance.current().active) return;
  try {
    const [books, docs] = await Promise.all([catalogSearch.warm(), knowledge.warm()]);
    if (books + docs > 0) console.log(`🧭 已更新語意索引：書籍 ${books} 筆、客服知識 ${docs} 筆`);
  } catch (err) {
    console.error('[更新語意索引失敗]:', err.message);
  }
};

const startScheduler = () => {
  let stopDispatcher = () => {};
  push.init()
    .then((ok) => { if (ok) stopDispatcher = push.startDispatcher(); })
    .catch((err) => console.error('[推播初始化失敗]:', err.message));

  const timers = [
    setInterval(runDeviceCleanup, 24 * HOUR),
    setInterval(runDeletionSweep, HOUR),
    setInterval(runBackupIfDue, HOUR),
    setInterval(runReservationExpiry, 5 * MINUTE),
    setInterval(runOauthCleanup, 10 * MINUTE),
    setInterval(runUploadsSweep, 24 * HOUR),
    setInterval(runEmbeddingSync, 10 * MINUTE),
    setTimeout(runEmbeddingSync, MINUTE),
    setTimeout(runUploadsSweep, 3 * MINUTE),
    setTimeout(runReservationExpiry, MINUTE),
    setTimeout(runDeletionSweep, 30 * 1000),
    setTimeout(runBackupIfDue, 2 * MINUTE)
  ];

  if (env.backupEnabled) {
    backup.checkTool().then((version) => {
      if (version) console.log(`💾 備份工具：${version}`);
      else console.warn('⚠️  找不到 mysqldump，自動備份將會失敗。Ubuntu 可執行 apt install mysql-client 安裝。');
    });
  }

  return () => {
    timers.forEach((t) => clearTimeout(t));
    stopDispatcher();
  };
};

module.exports = { startScheduler, runBackupIfDue };
