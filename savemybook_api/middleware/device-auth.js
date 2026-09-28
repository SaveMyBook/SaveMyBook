const devices = require('../services/cabinet-devices');
const access = require('../services/cabinet-access');

const TOKEN_RE = /^Device\s+(\S+)$/;

// 開機後第一個請求必須是以 boot 事件開頭的 POST /events，才允許切換 boot_id（4.1）。
const bootEventId = (req) => {
  if (req.method !== 'POST' || req.path !== '/events') return null;
  const first = Array.isArray(req.body?.events) ? req.body.events[0] : null;
  return first?.type === 'boot' && typeof first.data?.boot_id === 'string' ? first.data.boot_id : null;
};

const deviceAuth = async (req, res, next) => {
  try {
    const match = TOKEN_RE.exec(String(req.get('authorization') ?? '').trim());
    if (!match) throw devices.authRequired();

    const bootId = req.get('x-device-boot');
    if (!devices.isValidBootId(bootId)) throw devices.payloadInvalid();

    const found = await devices.findByToken(match[1]);
    if (!found || found.status !== 'active') throw devices.revokedError();
    if (found.kind === 'simulator' && !access.isSimulatorEnabled()) throw devices.disabledError();

    const now = new Date();
    const verified = await devices.verifyBoot(found, { bootId, bootEventId: bootEventId(req), ip: req.ip, now });
    req.device = await devices.touch(verified, req.ip, now);
    req.deviceBoot = bootId;
    next();
  } catch (err) {
    next(err);
  }
};

module.exports = { deviceAuth };
