const crypto = require('crypto');
const prisma = require('../lib/prisma');
const { hasTables } = require('../lib/schema-check');
const { placeholders } = require('../lib/sql');

const IDLE_DAYS = 30;
const TOUCH_EVERY_MS = 5 * 60 * 1000;

const isAvailable = () => hasTables(['user_sessions', 'user_security']);

const clip = (value, max) => {
  if (typeof value !== 'string') return null;
  const s = value.trim().slice(0, max);
  return s || null;
};

const PLATFORM_NAMES = { ios: 'iOS', android: 'Android' };

const deviceLabel = ({ deviceName, platform } = {}) => {
  const name = typeof deviceName === 'string' ? deviceName.trim().slice(0, 80) : '';
  const os = PLATFORM_NAMES[platform] ?? (typeof platform === 'string' ? platform.slice(0, 20) : '');
  if (name && os) return `${name}（${os}）`;
  return name || os || '未知裝置';
};

const hashKey = (key) => crypto.createHash('sha256').update(String(key)).digest('hex');

const idleCutoff = () => new Date(Date.now() - IDLE_DAYS * 24 * 60 * 60 * 1000);

const create = async (userId, { deviceId, deviceName, platform, appVersion, ip } = {}) => {
  if (!(await isAvailable())) return null;

  const now = new Date();
  const sid = crypto.randomBytes(16).toString('hex');
  const device = clip(deviceId, 64);

  const [[known], [others]] = await Promise.all([
    device
      ? prisma.$queryRaw`SELECT COUNT(*) AS n FROM user_sessions WHERE user_id = ${userId} AND device_id = ${device}`
      : Promise.resolve([{ n: 0 }]),
    prisma.$queryRaw`SELECT COUNT(*) AS n FROM user_sessions WHERE user_id = ${userId}`
  ]);

  if (device) {
    await prisma.$executeRaw`
      UPDATE user_sessions SET revoked_at = ${now}
      WHERE user_id = ${userId} AND device_id = ${device} AND revoked_at IS NULL`;
  }

  await prisma.$executeRaw`
    INSERT INTO user_sessions
      (user_id, sid, device_id, device_name, platform, app_version, ip_address, created_at, last_seen_at)
    VALUES
      (${userId}, ${sid}, ${device}, ${clip(deviceName, 100)}, ${clip(platform, 20)},
       ${clip(appVersion, 20)}, ${clip(ip, 45)}, ${now}, ${now})`;

  return { sid, isNewDevice: Number(others.n) > 0 && Number(known.n) === 0 };
};

const lookup = async (userId, sid) => {
  if (!(await isAvailable())) return { available: false };
  const [row = {}] = await prisma.$queryRaw`
    SELECT s.user_id AS session_user, s.revoked_at, us.tokens_valid_after
    FROM (SELECT 1 AS one) d
    LEFT JOIN user_sessions s ON s.sid = ${sid ?? ''}
    LEFT JOIN user_security us ON us.user_id = ${userId}`;
  return {
    available: true,
    session: row.session_user == null ? null : { userId: Number(row.session_user), revoked: row.revoked_at != null },
    validAfter: row.tokens_valid_after ? new Date(row.tokens_valid_after) : null
  };
};

const touch = (sid, ip) => {
  const now = new Date();
  return prisma.$executeRaw`
    UPDATE user_sessions SET last_seen_at = ${now}, ip_address = COALESCE(${clip(ip, 45)}, ip_address)
    WHERE sid = ${sid} AND last_seen_at < ${new Date(now.getTime() - TOUCH_EVERY_MS)}`.catch(() => {});
};

const findActive = async (sid) => {
  if (!sid || !(await isAvailable())) return null;
  const rows = await prisma.$queryRaw`
    SELECT session_id, user_id, sid, pay_key_hash, last_seen_at FROM user_sessions
    WHERE sid = ${sid} AND revoked_at IS NULL AND last_seen_at >= ${idleCutoff()}`;
  return rows[0] ?? null;
};

const list = async (userId) => {
  if (!(await isAvailable())) return [];
  return prisma.$queryRaw`
    SELECT session_id, sid, device_name, platform, app_version, ip_address, created_at, last_seen_at,
           pay_key_hash IS NOT NULL AS biometric_pay
    FROM user_sessions
    WHERE user_id = ${userId} AND revoked_at IS NULL AND last_seen_at >= ${idleCutoff()}
    ORDER BY last_seen_at DESC`;
};

const removePushDevices = async (sids) => {
  if (sids.length === 0) return;
  try {
    await prisma.$executeRawUnsafe(
      `DELETE FROM push_devices WHERE session_sid IN (${placeholders(sids)})`,
      ...sids
    );
  } catch {}
};

const revoke = async (userId, sessionId) => {
  if (!(await isAvailable())) return null;
  const rows = await prisma.$queryRaw`
    SELECT sid FROM user_sessions WHERE session_id = ${sessionId} AND user_id = ${userId} AND revoked_at IS NULL`;
  if (rows.length === 0) return null;
  await prisma.$executeRaw`
    UPDATE user_sessions SET revoked_at = ${new Date()}, pay_key_hash = NULL WHERE session_id = ${sessionId}`;
  await removePushDevices([rows[0].sid]);
  return rows[0].sid;
};

const revokeBySid = async (sid) => {
  if (!sid || !(await isAvailable())) return;
  await prisma.$executeRaw`
    UPDATE user_sessions SET revoked_at = ${new Date()}, pay_key_hash = NULL WHERE sid = ${sid} AND revoked_at IS NULL`;
  await removePushDevices([sid]);
};

const revokeAll = async (userId, { exceptSid = null } = {}) => {
  if (!(await isAvailable())) return 0;
  const now = new Date();
  const rows = await prisma.$queryRaw`
    SELECT sid FROM user_sessions WHERE user_id = ${userId} AND revoked_at IS NULL AND sid <> ${exceptSid ?? ''}`;
  const sids = rows.map((r) => r.sid);
  if (sids.length > 0) {
    await prisma.$executeRawUnsafe(
      `UPDATE user_sessions SET revoked_at = ?, pay_key_hash = NULL WHERE sid IN (${placeholders(sids)})`,
      now,
      ...sids
    );
  }
  // 部署前簽發、沒有 sid 的 token 查不到裝置列，只能用時間點一併作廢。
  await prisma.$executeRaw`
    INSERT INTO user_security (user_id, tokens_valid_after) VALUES (${userId}, ${now})
    ON DUPLICATE KEY UPDATE tokens_valid_after = VALUES(tokens_valid_after)`;
  await removePushDevices(sids);
  return sids.length;
};

const setPayKey = async (sid) => {
  const key = crypto.randomBytes(32).toString('base64url');
  await prisma.$executeRaw`UPDATE user_sessions SET pay_key_hash = ${hashKey(key)} WHERE sid = ${sid}`;
  return key;
};

const clearPayKey = (sid) => prisma.$executeRaw`UPDATE user_sessions SET pay_key_hash = NULL WHERE sid = ${sid}`;

const matchesPayKey = (session, key) => {
  if (!session?.pay_key_hash || typeof key !== 'string' || key.length < 20) return false;
  const a = Buffer.from(session.pay_key_hash, 'hex');
  const b = Buffer.from(hashKey(key), 'hex');
  return a.length === b.length && crypto.timingSafeEqual(a, b);
};

const removeStale = async () => {
  if (!(await isAvailable())) return;
  const cutoff = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000);
  await prisma.$executeRaw`DELETE FROM user_sessions WHERE last_seen_at < ${cutoff}`;
};

module.exports = {
  isAvailable, deviceLabel, create, lookup, touch, findActive, list, revoke, revokeBySid, revokeAll,
  setPayKey, clearPayKey, matchesPayKey, removeStale
};
