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

  ready = true;
  console.log(`🔔 手機推播已啟用（Firebase 專案：${client.projectId}）`);
  return true;
};

module.exports = { isReady, fcm, init };
