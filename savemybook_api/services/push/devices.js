const prisma = require('../../lib/prisma');
const { isReady } = require('./setup');

const PLATFORMS = ['ios', 'android'];
const MAX_DEVICES_PER_USER = 10;

const registerDevice = async (userId, { token, platform, appVersion, sessionSid = null }) => {
  // 同一個 token 換帳號登入時須轉給新帳號，否則前帳號的通知會推到這支手機。
  await prisma.$executeRaw`
    INSERT INTO push_devices (user_id, token, platform, app_version, session_sid, created_at, last_seen_at)
    VALUES (${userId}, ${token}, ${platform}, ${appVersion}, ${sessionSid}, NOW(), NOW())
    ON DUPLICATE KEY UPDATE
      user_id = VALUES(user_id), platform = VALUES(platform), app_version = VALUES(app_version),
      session_sid = VALUES(session_sid), last_seen_at = NOW()`;

  await prisma.$executeRaw`
    DELETE FROM push_devices
    WHERE user_id = ${userId} AND device_id NOT IN (
      SELECT device_id FROM (
        SELECT device_id FROM push_devices WHERE user_id = ${userId}
        ORDER BY last_seen_at DESC LIMIT ${MAX_DEVICES_PER_USER}
      ) AS keep
    )`;
};

const unregisterDevice = (userId, token) =>
  prisma.$executeRaw`DELETE FROM push_devices WHERE user_id = ${userId} AND token = ${token}`;

const removeUserDevices = async (userId) => {
  try {
    await prisma.$executeRaw`DELETE FROM push_devices WHERE user_id = ${userId}`;
  } catch (err) {
    if (isReady()) console.error('[清除推播裝置失敗]:', err.message);
  }
};

const listDevices = (userId) => prisma.$queryRaw`
  SELECT device_id, platform, app_version, created_at, last_seen_at, RIGHT(token, 6) AS token_tail
  FROM push_devices WHERE user_id = ${userId} ORDER BY last_seen_at DESC`;

const deviceCount = async (userId) => {
  const rows = await prisma.$queryRaw`SELECT COUNT(*) AS n FROM push_devices WHERE user_id = ${userId}`;
  return Number(rows[0]?.n ?? 0);
};

const removeStaleDevices = () =>
  prisma.$executeRaw`DELETE FROM push_devices WHERE last_seen_at < NOW() - INTERVAL 90 DAY`;

module.exports = {
  PLATFORMS, registerDevice, unregisterDevice, removeUserDevices, removeStaleDevices, deviceCount, listDevices
};
