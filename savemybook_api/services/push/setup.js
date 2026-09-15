const prisma = require('../../lib/prisma');
const { env } = require('../../config/env');
const { FcmClient } = require('../../lib/fcm');

let client = null;
let ready = false;

const isReady = () => ready;

const fcm = () => client;

const init = async () => {
  if (!env.pushEnabled) {
    console.log('🔕 推播已由 PUSH_ENABLED=false 停用');
    return false;
  }
  if (!env.fcmServiceAccountFile) {
    console.warn('⚠️  未設定 FCM_SERVICE_ACCOUNT_FILE，手機推播停用');
    return false;
  }

  try {
    client = FcmClient.fromFile(env.fcmServiceAccountFile);
  } catch (err) {
    console.error(`⚠️  無法讀取 Firebase 服務帳戶金鑰（${env.fcmServiceAccountFile}）：${err.message}`);
    return false;
  }

  const [tableRows, columnRows] = await Promise.all([
    prisma.$queryRaw`SELECT COUNT(*) AS n FROM information_schema.TABLES
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'push_devices'`,
    prisma.$queryRaw`SELECT COUNT(*) AS n FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'notifications' AND COLUMN_NAME = 'pushed_at'`
  ]);
  if (Number(tableRows[0].n) === 0 || Number(columnRows[0].n) === 0) {
    console.warn('⚠️  資料庫缺少推播用的資料表，請先執行 migrations/006_push_notifications.sql；手機推播停用');
    return false;
  }

  ready = true;
  console.log(`🔔 手機推播已啟用（Firebase 專案：${client.projectId}）`);
  return true;
};

module.exports = { isReady, fcm, init };
