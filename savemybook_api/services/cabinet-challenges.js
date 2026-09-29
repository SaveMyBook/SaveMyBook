const crypto = require('crypto');
const prisma = require('../lib/prisma');
const { env } = require('../config/env');
const { HttpError } = require('../lib/errors');
const policy = require('../constants/policy');

const REFRESH_MS = policy.CABINET_QR_REFRESH_SECONDS * 1000;
const TTL_MS = policy.CABINET_QR_TTL_SECONDS * 1000;
const PAYLOAD_PREFIX = 'savemybook://k/';
const CODE_RE = /^savemybook:\/\/k\/([0-9a-f]{32})\/?$/i;
const PURGE_AFTER_MS = 60 * 60 * 1000;

const sha256 = (text) => crypto.createHash('sha256').update(text).digest('hex');

// 金鑰在每次呼叫時推導，更換 CABINET_QR_SECRET 或測試改動 env 後立即生效。
const qrKey = () => crypto.createHmac('sha256', env.cabinetQrSecret || env.jwtSecret || 'savemybook').update('cabinet-qr-v1').digest();

const epochOf = (now) => Math.floor(now.getTime() / REFRESH_MS);

const tokenFor = (deviceId, qrSeq, epoch) =>
  crypto.createHmac('sha256', qrKey()).update(`${deviceId}:${qrSeq}:${epoch}`).digest('hex').slice(0, 32);

const invalidCode = () => new HttpError(400, '此 QR Code 並非 SaveMyBook 書櫃 QR Code', 'CABINET_CODE_INVALID');
const expiredCode = () => new HttpError(410, '書櫃 QR Code 已更新，請重新掃描書櫃螢幕上的 QR Code', 'CABINET_CODE_EXPIRED');
const busy = () => new HttpError(409, '書櫃使用中，請稍候再掃描', 'CABINET_BUSY');

const issue = async (device, now = new Date()) => {
  const epoch = epochOf(now);
  const token = tokenFor(device.device_id, device.qr_seq, epoch);
  const tokenHash = sha256(token);
  const expiresAt = new Date((epoch + 1) * REFRESH_MS + (TTL_MS - REFRESH_MS));

  const existing = await prisma.cabinet_challenges.findUnique({ where: { token_hash: tokenHash }, select: { challenge_id: true } });
  if (!existing) {
    try {
      await prisma.cabinet_challenges.create({
        data: {
          device_id: device.device_id, token_hash: tokenHash, qr_seq: device.qr_seq, epoch, expires_at: expiresAt, created_at: now
        }
      });
    } catch (err) {
      if (err?.code !== 'P2002') throw err;
    }
  }

  return {
    payload: `${PAYLOAD_PREFIX}${token}`,
    refresh_in_ms: (epoch + 1) * REFRESH_MS - now.getTime(),
    expires_in_ms: expiresAt.getTime() - now.getTime()
  };
};

const lookup = async (raw, now = new Date(), { userId } = {}) => {
  const match = CODE_RE.exec(String(raw ?? '').trim());
  if (!match) throw invalidCode();

  const challenge = await prisma.cabinet_challenges.findUnique({
    where: { token_hash: sha256(match[1].toLowerCase()) },
    include: { cabinet_devices: { include: { smart_cabinets: true } } }
  });
  if (!challenge?.cabinet_devices) throw expiredCode();

  const { cabinet_devices: deviceRow, ...rest } = challenge;
  const { smart_cabinets: cabinet, ...device } = deviceRow;
  const live = new Date(challenge.expires_at).getTime() > now.getTime();

  if (challenge.used_at) {
    if (userId && Number(challenge.used_by) === Number(userId) && live) return { challenge: rest, device, cabinet, used: true };
    throw expiredCode();
  }
  if (!live || Number(challenge.qr_seq) !== Number(device.qr_seq) || device.status !== 'active') throw expiredCode();
  if (device.kind === 'simulator' && !env.cabinetSimulator) throw expiredCode();
  return { challenge: rest, device, cabinet, used: false };
};

const claim = async (tx, { challenge, device, sessionId, userId, now = new Date() }) => {
  const used = await tx.cabinet_challenges.updateMany({
    where: { challenge_id: challenge.challenge_id, used_at: null, expires_at: { gt: now } },
    data: { used_at: now, used_by: userId }
  });
  if (used.count === 0) throw expiredCode();

  const locked = await tx.cabinet_devices.updateMany({
    where: { device_id: device.device_id, status: 'active', active_session_id: null, qr_seq: challenge.qr_seq },
    data: { active_session_id: sessionId, qr_seq: { increment: 1 }, updated_at: now }
  });
  if (locked.count === 0) {
    const current = await tx.cabinet_devices.findUnique({ where: { device_id: device.device_id }, select: { qr_seq: true, status: true } });
    if (!current || current.status !== 'active' || Number(current.qr_seq) !== Number(challenge.qr_seq)) throw expiredCode();
    throw busy();
  }
};

const purge = (now = new Date()) =>
  prisma.cabinet_challenges.deleteMany({ where: { expires_at: { lt: new Date(now.getTime() - PURGE_AFTER_MS) } } });

module.exports = { REFRESH_MS, TTL_MS, CODE_RE, sha256, epochOf, tokenFor, issue, lookup, claim, purge };
