const express = require('express');
const authenticateToken = require('../middleware/auth');
const { rateLimit, byIp } = require('../middleware/rateLimit');
const { text } = require('../lib/validate');
const { readToken } = require('../lib/auth-token');
const { badRequest, unauthorized } = require('../lib/errors');
const auth = require('../services/auth');
const sessions = require('../services/sessions');

const router = express.Router();

// 以 IP + Email 計數：只看 IP 會連坐 NAT 後的使用者，只看 Email 則任何人都能鎖住他人帳號。
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  key: (req) => `${byIp(req)}|${text(req.body?.email).toLowerCase()}`,
  message: '登入嘗試次數過多，請 15 分鐘後再試'
});

const loginBurstLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  key: byIp,
  message: '登入嘗試次數過多，請稍後再試'
});

const refreshLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 60,
  key: byIp,
  message: '操作過於頻繁，請稍後再試'
});

const deviceFrom = (req) => ({
  deviceId: req.body.device_id,
  deviceName: req.body.device_name,
  platform: req.body.platform,
  appVersion: req.body.app_version,
  ip: req.ip
});

router.post('/login', loginBurstLimiter, loginLimiter, async (req, res) => {
  const email = text(req.body.email, { max: 255 });
  const plain = typeof req.body.password === 'string' ? req.body.password : '';

  if (!email || !plain) throw badRequest('請提供 Email 與密碼');

  const { token, deletion } = await auth.login(email, plain, deviceFrom(req));

  res.status(200).json({
    success: true,
    message: '登入成功',
    data: { token, ...(deletion && { pending_deletion: deletion }) }
  });
});

router.post('/refresh', refreshLimiter, async (req, res) => {
  const raw = readToken(req);
  if (!raw) throw unauthorized('存取被拒，未提供 Token');

  const token = await auth.refresh(raw, req.ip);
  res.status(200).json({ success: true, data: { token } });
});

router.post('/logout', authenticateToken, async (req, res) => {
  await sessions.revokeBySid(req.user.sid);
  res.status(200).json({ success: true, message: '已登出' });
});

router.get('/me', authenticateToken, async (req, res) => {
  const user = await auth.currentUser(req.user.userId);
  res.status(200).json({ success: true, data: user });
});

module.exports = router;
