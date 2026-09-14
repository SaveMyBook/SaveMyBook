const { env } = require('../config/env');
const { processDueDeletions } = require('../services/account');
const backup = require('../services/backup');
const push = require('../services/push');

const MINUTE = 60 * 1000;
const HOUR = 60 * MINUTE;
const BACKUP_EVERY = 24 * HOUR;

const runDeletionSweep = async () => {
  try {
    const count = await processDueDeletions();
    if (count > 0) console.log(`🗑️  已檢查 ${count} 個逾期帳號`);
  } catch (err) {
    console.error('[刪除排程失敗]:', err);
  }
};

/// 每小時檢查一次「距離上次成功備份是否超過 24 小時」。
///
/// 過去是 setInterval(備份, 24 小時)：計時從行程啟動算起，只要服務在 24 小時內
/// 重啟過（部署、pm2 自動重啟、當機），計時就歸零，備份永遠不會執行。
/// 失敗後至少隔一小時才重試，避免設定錯誤時每次重啟都塞一筆失敗紀錄。
const runBackupIfDue = async () => {
  if (!env.backupEnabled) return;
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
  if (!push.isReady()) return;
  try {
    await push.removeStaleDevices();
  } catch (err) {
    console.error('[清理推播裝置失敗]:', err.message);
  }
};

/// 回傳停止函式，關機時要清掉，否則行程會卡在計時器上無法結束。
const startScheduler = () => {
  let stopDispatcher = () => {};
  push.init()
    .then((ok) => { if (ok) stopDispatcher = push.startDispatcher(); })
    .catch((err) => console.error('[推播初始化失敗]:', err.message));

  const timers = [
    setInterval(runDeviceCleanup, 24 * HOUR),
    setInterval(runDeletionSweep, HOUR),
    setInterval(runBackupIfDue, HOUR),
    setTimeout(runDeletionSweep, 30 * 1000),
    // 啟動後稍等再檢查備份，讓資料庫連線與流量先穩定下來。重啟時若 24 小時內已備份過就不會重複備份。
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
