const express = require('express');
const authenticateToken = require('../middleware/auth');
const { rateLimit, byUser } = require('../middleware/rateLimit');
const v = require('../lib/validate');
const { badRequest, HttpError } = require('../lib/errors');
const push = require('../services/push');

const router = express.Router();

router.use(authenticateToken);

const deviceLimiter = rateLimit({ windowMs: 60 * 1000, max: 20, key: byUser });

/// FCM 註冊 token 目前約 150～180 字元，只含英數與 : _ -。
const TOKEN_RE = /^[\w:-]{20,255}$/;

const readToken = (body) => {
  const token = v.text(body.token, { label: '裝置 token', max: 255 });
  if (!TOKEN_RE.test(token)) throw badRequest('裝置 token 格式不正確');
  return token;
};

const assertReady = () => {
  // 回 503 而不是 500：App 可以安靜略過，下次啟動再試。
  if (!push.isReady()) throw new HttpError(503, '推播服務尚未啟用', 'PUSH_DISABLED');
};

router.post('/devices', deviceLimiter, async (req, res) => {
  const token = readToken(req.body);
  const platform = v.oneOf(req.body.platform, push.PLATFORMS, 'platform 僅接受：ios, android');
  const appVersion = v.optionalText(req.body.app_version, { label: 'App 版本', max: 20 }) ?? null;
  assertReady();

  await push.registerDevice(req.user.userId, { token, platform, appVersion });
  res.status(200).json({ success: true, message: '已登記推播裝置' });
});

router.delete('/devices', deviceLimiter, async (req, res) => {
  const token = readToken(req.body);
  assertReady();
  await push.unregisterDevice(req.user.userId, token);
  res.status(200).json({ success: true, message: '已取消推播裝置' });
});

module.exports = router;
