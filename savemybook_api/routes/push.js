const express = require('express');
const authenticateToken = require('../middleware/auth');
const { rateLimit, byUser } = require('../middleware/rateLimit');
const v = require('../lib/validate');
const prisma = require('../lib/prisma');
const { badRequest, conflict, forbidden, HttpError } = require('../lib/errors');
const push = require('../services/push');
const { notify } = require('../services/notify');

const router = express.Router();

router.use(authenticateToken);

const deviceLimiter = rateLimit({ windowMs: 60 * 1000, max: 20, key: byUser });

const TOKEN_RE = /^[\w:-]{20,255}$/;

const readToken = (body) => {
  const token = v.text(body.token, { label: '裝置 token', max: 255 });
  if (!TOKEN_RE.test(token)) throw badRequest('裝置 token 格式不正確');
  return token;
};

const assertReady = () => {
  if (!push.isReady()) throw new HttpError(503, '推播服務尚未啟用', 'PUSH_DISABLED');
};

router.get('/devices', async (req, res) => {
  assertReady();
  const rows = await push.listDevices(req.user.userId);
  res.status(200).json({
    success: true,
    data: rows.map((r) => ({
      device_id: Number(r.device_id),
      platform: r.platform,
      app_version: r.app_version,
      token_tail: r.token_tail,
      created_at: r.created_at,
      last_seen_at: r.last_seen_at
    }))
  });
});

router.post('/devices', deviceLimiter, async (req, res) => {
  const token = readToken(req.body);
  const platform = v.oneOf(req.body.platform, push.PLATFORMS, 'platform 僅接受：ios, android');
  const appVersion = v.optionalText(req.body.app_version, { label: 'App 版本', max: 20 }) ?? null;
  assertReady();

  await push.registerDevice(req.user.userId, { token, platform, appVersion, sessionSid: req.user.sid });
  res.status(200).json({ success: true, message: '已登記推播裝置' });
});

router.delete('/devices', deviceLimiter, async (req, res) => {
  const token = readToken(req.body);
  assertReady();
  await push.unregisterDevice(req.user.userId, token);
  res.status(200).json({ success: true, message: '已取消推播裝置' });
});

const TEST_DELAY_SECONDS = 10;

const testLimiter = rateLimit({
  windowMs: 10 * 60 * 1000,
  max: 5,
  key: byUser,
  message: '測試通知送太多次了，請 10 分鐘後再試'
});

router.post('/test', testLimiter, async (req, res) => {
  if (req.user.role !== 'admin') throw forbidden('只有管理員可以傳送測試通知');
  assertReady();

  const devices = await push.deviceCount(req.user.userId);
  if (devices === 0) {
    throw conflict('伺服器上沒有這個帳號的推播裝置。App 沒有成功取得或上傳推播 token。', 'NO_PUSH_DEVICE');
  }

  await notify(prisma, {
    userId: req.user.userId,
    title: '測試通知',
    content: '收到這則通知，代表推播設定正常。',
    relatedType: 'push_test',
    createdAt: new Date(Date.now() + TEST_DELAY_SECONDS * 1000)
  });

  res.status(200).json({
    success: true,
    message: `${TEST_DELAY_SECONDS} 秒後送出，請先回到主畫面或鎖定手機`,
    data: { devices, delay_seconds: TEST_DELAY_SECONDS }
  });
});

module.exports = router;
