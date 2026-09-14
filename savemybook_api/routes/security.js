const express = require('express');
const prisma = require('../lib/prisma');
const authenticateToken = require('../middleware/auth');
const { rateLimit, byUser } = require('../middleware/rateLimit');
const v = require('../lib/validate');
const password = require('../lib/password');
const { badRequest, forbidden, notFound, HttpError } = require('../lib/errors');
const security = require('../services/security');
const sessions = require('../services/sessions');
const { notify } = require('../services/notify');

const router = express.Router();

router.use(authenticateToken);

const verifyLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 30,
  key: byUser,
  message: '驗證嘗試次數過多，請 15 分鐘後再試'
});

const requireSessionSupport = async (req) => {
  if (!(await sessions.isAvailable())) {
    throw new HttpError(503, '伺服器尚未完成資料庫更新，請聯絡管理員', 'SECURITY_UNAVAILABLE');
  }
  if (!req.user.sid) throw forbidden('請重新登入後再使用這項功能', 'SESSION_REQUIRED');
};

router.get('/', async (req, res) => {
  const data = await security.status(req.user.userId, req.user.sid);
  res.status(200).json({ success: true, data });
});

router.post('/verify', verifyLimiter, async (req, res) => {
  const scope = v.oneOf(req.body.scope, Object.keys(security.SCOPES), 'scope 僅接受：payment, sensitive');
  const allowed = security.SCOPES[scope].methods;
  const method = v.oneOf(req.body.method, allowed, `method 僅接受：${allowed.join(', ')}`);
  const userId = req.user.userId;

  if (method === 'password') {
    const user = await prisma.users.findUnique({ where: { user_id: userId }, select: { password_hash: true } });
    // 用 400 不用 401：App 收到 401 會直接登出。
    if (!(await password.verify(req.body.password, user?.password_hash))) throw badRequest('密碼錯誤', 'INVALID_PASSWORD');
  }

  if (method === 'pin') await security.verifyPin(userId, req.body.pin);

  if (method === 'biometric') {
    await requireSessionSupport(req);
    const [session, state] = await Promise.all([
      sessions.findActive(req.user.sid),
      security.status(userId, req.user.sid)
    ]);
    if (!state.has_payment_pin) throw forbidden('尚未設定交易密碼', 'PAYMENT_PIN_NOT_SET');
    if (!sessions.matchesPayKey(session, req.body.key)) {
      throw badRequest('這台裝置的生物辨識付款已失效，請改用交易密碼', 'BIOMETRIC_KEY_INVALID');
    }
  }

  if (scope === 'payment' && method !== 'biometric') {
    const state = await security.status(userId, req.user.sid);
    if (!state.has_payment_pin) throw forbidden('尚未設定交易密碼', 'PAYMENT_PIN_NOT_SET');
  }

  const data = security.issueToken({ userId, sid: req.user.sid, scope, method });
  res.status(200).json({ success: true, data });
});

router.put('/payment-pin', security.requireVerification('sensitive'), async (req, res) => {
  const pin = typeof req.body.pin === 'string' ? req.body.pin : '';
  const before = await security.status(req.user.userId, req.user.sid);
  await security.setPin(req.user.userId, pin);

  if (before.has_payment_pin) {
    await notify(null, {
      userId: req.user.userId,
      title: '交易密碼已變更',
      content: '你的交易密碼剛剛被修改。如果不是你本人操作，請立即修改登入密碼並登出其他裝置。',
      relatedType: 'security'
    }).catch(() => {});
  }

  res.status(200).json({ success: true, message: before.has_payment_pin ? '交易密碼已變更' : '交易密碼已設定' });
});

router.post('/biometric-key', security.requireVerification('sensitive'), async (req, res) => {
  await requireSessionSupport(req);
  const state = await security.status(req.user.userId, req.user.sid);
  if (!state.has_payment_pin) throw forbidden('請先設定交易密碼，生物辨識失敗時才有替代方式', 'PAYMENT_PIN_NOT_SET');

  const key = await sessions.setPayKey(req.user.sid);
  res.status(200).json({ success: true, message: '已在這台裝置啟用生物辨識付款', data: { key } });
});

router.delete('/biometric-key', async (req, res) => {
  if (req.user.sid && (await sessions.isAvailable())) await sessions.clearPayKey(req.user.sid);
  res.status(200).json({ success: true, message: '已關閉這台裝置的生物辨識付款' });
});

const shapeSession = (row, currentSid) => ({
  session_id: Number(row.session_id),
  device_name: row.device_name,
  platform: row.platform,
  app_version: row.app_version,
  ip_address: row.ip_address,
  created_at: row.created_at,
  last_seen_at: row.last_seen_at,
  biometric_pay: Boolean(Number(row.biometric_pay)),
  is_current: row.sid === currentSid
});

router.get('/sessions', async (req, res) => {
  const rows = await sessions.list(req.user.userId);
  const data = rows.map((r) => shapeSession(r, req.user.sid));
  data.sort((a, b) => Number(b.is_current) - Number(a.is_current));
  res.status(200).json({ success: true, data });
});

router.delete('/sessions/:id', security.requireVerification('sensitive'), async (req, res) => {
  await requireSessionSupport(req);
  const sessionId = v.id(req.params.id, '裝置編號');
  const sid = await sessions.revoke(req.user.userId, sessionId);
  if (!sid) throw notFound('找不到這台裝置，可能已經登出了');

  res.status(200).json({
    success: true,
    message: '已登出這台裝置',
    data: { signed_out_current: sid === req.user.sid }
  });
});

router.post('/sessions/revoke-all', security.requireVerification('sensitive'), async (req, res) => {
  await requireSessionSupport(req);
  const includeCurrent = req.body.include_current === true;
  const count = await sessions.revokeAll(req.user.userId, { exceptSid: includeCurrent ? null : req.user.sid });

  res.status(200).json({
    success: true,
    message: includeCurrent ? '已登出所有裝置' : `已登出其他 ${count} 台裝置`,
    data: { revoked: count, signed_out_current: includeCurrent }
  });
});

module.exports = router;
