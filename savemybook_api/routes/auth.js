const express = require('express');
const jwt = require('jsonwebtoken');
const prisma = require('../lib/prisma');
const authenticateToken = require('../middleware/auth');
const { signToken, readToken, loadUser, accountProblem } = require('../middleware/auth');
const { rateLimit, byIp } = require('../middleware/rateLimit');
const { text } = require('../lib/validate');
const password = require('../lib/password');
const { env } = require('../config/env');
const { badRequest, notFound, unauthorized, forbidden } = require('../lib/errors');
const { deletionStatus } = require('../services/account');
const sessions = require('../services/sessions');
const { notify } = require('../services/notify');
const { deviceLabel } = require('../services/devices');

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
  message: '操作太頻繁，請稍後再試'
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

  if (!email || !plain) throw badRequest('請提供 email 與密碼');

  const user = await prisma.users.findUnique({ where: { email } });

  if (!user) throw notFound('此 Email 尚未註冊', 'ACCOUNT_NOT_FOUND');
  if (!(await password.verify(plain, user.password_hash))) throw unauthorized('密碼錯誤', 'INVALID_PASSWORD');
  if (user.is_blacklisted) throw forbidden('此帳號已被停用，請聯絡客服', 'ACCOUNT_BLACKLISTED');
  if (!user.is_active) throw forbidden('此帳號已停權，請聯絡客服', 'ACCOUNT_INACTIVE');

  const device = deviceFrom(req);
  const session = await sessions.create(user.user_id, device);
  const token = signToken(user, session?.sid);

  prisma.login_logs.create({
    data: {
      user_id: user.user_id,
      ip_address: req.ip ? String(req.ip).slice(0, 45) : null,
      device_info: deviceLabel(device)
    }
  }).catch(() => {});

  if (session?.isNewDevice) {
    await notify(null, {
      userId: user.user_id,
      title: '新裝置登入',
      content: `你的帳號剛剛在「${deviceLabel(device)}」登入。如果不是你本人，請立即修改密碼並到「登入裝置」登出這台裝置。`,
      relatedType: 'security'
    }).catch(() => {});
  }

  // 申請刪除後仍須可登入，這是取消刪除的唯一入口。
  const deletion = user.deletion_requested_at ? deletionStatus(user.deletion_requested_at) : null;

  res.status(200).json({
    success: true,
    message: '登入成功',
    data: { token, ...(deletion && { pending_deletion: deletion }) }
  });
});

router.post('/refresh', refreshLimiter, async (req, res) => {
  const raw = readToken(req);
  if (!raw) throw unauthorized('存取被拒，未提供 Token');

  let decoded;
  try {
    decoded = jwt.verify(raw, env.jwtSecret, { algorithms: ['HS256'], ignoreExpiration: true });
  } catch {
    throw unauthorized('登入已失效，請重新登入', 'REFRESH_FAILED');
  }
  if (decoded.typ || !decoded.sid) throw unauthorized('登入已失效，請重新登入', 'REFRESH_FAILED');

  const [user, session] = await Promise.all([loadUser(Number(decoded.userId)), sessions.findActive(decoded.sid)]);
  if (!session || Number(session.user_id) !== Number(decoded.userId)) {
    throw unauthorized('登入已失效，請重新登入', 'REFRESH_FAILED');
  }
  const problem = accountProblem(user, decoded);
  if (problem) throw unauthorized(problem[1], problem[2]);

  sessions.touch(decoded.sid, req.ip);
  res.status(200).json({ success: true, data: { token: signToken(user, decoded.sid) } });
});

router.post('/logout', authenticateToken, async (req, res) => {
  await sessions.revokeBySid(req.user.sid);
  res.status(200).json({ success: true, message: '已登出' });
});

router.get('/me', authenticateToken, async (req, res) => {
  const user = await prisma.users.findUnique({
    where: { user_id: req.user.userId },
    omit: { password_hash: true }
  });
  if (!user) throw notFound('找不到使用者');

  res.status(200).json({ success: true, data: user });
});

module.exports = router;
