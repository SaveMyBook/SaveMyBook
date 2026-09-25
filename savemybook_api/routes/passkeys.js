const express = require('express');
const { rateLimit, byIp } = require('../middleware/rateLimit');
const { text } = require('../lib/validate');
const { badRequest } = require('../lib/errors');
const passkeys = require('../services/passkeys');

const router = express.Router();

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

const optionsLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 60,
  key: byIp,
  message: '操作過於頻繁，請 15 分鐘後再試'
});

const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 30,
  key: byIp,
  message: '登入嘗試次數過多，請 15 分鐘後再試'
});

const deviceFrom = (req) => ({
  deviceId: req.body.device_id,
  deviceName: req.body.device_name,
  platform: req.body.platform,
  appVersion: req.body.app_version,
  ip: req.ip
});

router.get('/status', async (req, res) => {
  res.status(200).json({ success: true, data: { enabled: passkeys.isAvailable() } });
});

router.post('/login/options', optionsLimiter, async (req, res) => {
  const email = text(req.body.email, { label: '電子郵件', max: 255 });
  if (email && !EMAIL_RE.test(email)) throw badRequest('電子郵件格式不正確');

  const options = await passkeys.loginOptions(email || null);
  res.status(200).json({ success: true, data: { options } });
});

router.post('/login', loginLimiter, async (req, res) => {
  const { token, deletion } = await passkeys.login(req.body.assertion, deviceFrom(req));

  res.status(200).json({
    success: true,
    message: '登入成功',
    data: { token, ...(deletion && { pending_deletion: deletion }) }
  });
});

module.exports = router;
