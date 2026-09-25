const express = require('express');
const authenticateToken = require('../middleware/auth');
const { requireVerification } = require('../middleware/verification');
const { rateLimit, byUser } = require('../middleware/rateLimit');
const v = require('../lib/validate');
const security = require('../services/security');
const sessions = require('../services/sessions');
const passkeys = require('../services/passkeys');

const router = express.Router();

router.use(authenticateToken);

const verifyLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 30,
  key: byUser,
  message: '驗證嘗試次數過多，請 15 分鐘後再試'
});

router.get('/', async (req, res) => {
  const data = await security.status(req.user.userId, req.user.sid);
  res.status(200).json({ success: true, data });
});

router.post('/verify/passkey/options', verifyLimiter, async (req, res) => {
  const scopes = Object.keys(security.SCOPES).filter((id) => security.SCOPES[id].methods.includes('passkey'));
  const scope = v.oneOf(req.body.scope, scopes, '驗證範圍不正確');

  const options = await passkeys.verifyOptions(req.user.userId, scope);
  res.status(200).json({ success: true, data: { options } });
});

router.post('/verify', verifyLimiter, async (req, res) => {
  const scopes = Object.keys(security.SCOPES);
  const scope = v.oneOf(req.body.scope, scopes, '驗證範圍不正確');
  const allowed = security.SCOPES[scope].methods;
  const method = v.oneOf(req.body.method, allowed, '不支援此驗證方式');

  const data = await security.verify({
    userId: req.user.userId,
    sid: req.user.sid,
    scope,
    method,
    plainPassword: req.body.password,
    pin: req.body.pin,
    key: req.body.key,
    assertion: req.body.assertion
  });
  res.status(200).json({ success: true, data });
});

router.put('/payment-pin', requireVerification('sensitive'), async (req, res) => {
  const pin = typeof req.body.pin === 'string' ? req.body.pin : '';
  const changed = await security.changePin(req.user.userId, req.user.sid, pin);
  res.status(200).json({ success: true, message: changed ? '交易密碼已變更' : '交易密碼已設定' });
});

router.post('/biometric-key', requireVerification('sensitive'), async (req, res) => {
  const key = await security.enableBiometric(req.user.userId, req.user.sid);
  res.status(200).json({ success: true, message: '已於此裝置啟用生物辨識付款', data: { key } });
});

router.delete('/biometric-key', async (req, res) => {
  await security.disableBiometric(req.user.sid);
  res.status(200).json({ success: true, message: '已關閉此裝置的生物辨識付款' });
});

router.get('/sessions', async (req, res) => {
  const data = await security.listSessions(req.user.userId, req.user.sid);
  res.status(200).json({ success: true, data });
});

router.delete('/sessions/:id', requireVerification('sensitive'), async (req, res) => {
  security.assertSessionSupport(req.user.sid);
  const sessionId = v.id(req.params.id, '裝置編號');
  const sid = await security.revokeSession(req.user.userId, sessionId);

  res.status(200).json({
    success: true,
    message: '已登出此裝置',
    data: { signed_out_current: sid === req.user.sid }
  });
});

router.post('/sessions/revoke-all', requireVerification('sensitive'), async (req, res) => {
  security.assertSessionSupport(req.user.sid);
  const includeCurrent = req.body.include_current === true;
  const count = await sessions.revokeAll(req.user.userId, { exceptSid: includeCurrent ? null : req.user.sid });

  res.status(200).json({
    success: true,
    message: includeCurrent ? '已登出所有裝置' : `已登出其他 ${count} 台裝置`,
    data: { revoked: count, signed_out_current: includeCurrent }
  });
});

module.exports = router;
