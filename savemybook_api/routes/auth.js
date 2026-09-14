const express = require('express');
const prisma = require('../lib/prisma');
const authenticateToken = require('../middleware/auth');
const { signToken } = require('../middleware/auth');
const { rateLimit, byIp } = require('../middleware/rateLimit');
const { text } = require('../lib/validate');
const password = require('../lib/password');
const { badRequest, notFound, unauthorized, forbidden } = require('../lib/errors');
const { deletionStatus } = require('../services/account');

const router = express.Router();

/// 以 IP + Email 計數。只看 IP 的話，校園或公司 NAT 後面的整群人會一起被鎖；
/// 只看 Email 的話，任何人都能故意打錯密碼把別人的帳號鎖住。
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

router.post('/login', loginBurstLimiter, loginLimiter, async (req, res) => {
  const email = text(req.body.email, { max: 255 });
  const plain = typeof req.body.password === 'string' ? req.body.password : '';

  if (!email || !plain) throw badRequest('請提供 email 與密碼');

  const user = await prisma.users.findUnique({ where: { email } });

  if (!user) throw notFound('此 Email 尚未註冊', 'ACCOUNT_NOT_FOUND');
  if (!(await password.verify(plain, user.password_hash))) throw unauthorized('密碼錯誤', 'INVALID_PASSWORD');
  if (user.is_blacklisted) throw forbidden('此帳號已被停用，請聯絡客服', 'ACCOUNT_BLACKLISTED');
  if (!user.is_active) throw forbidden('此帳號已停權，請聯絡客服', 'ACCOUNT_INACTIVE');

  const token = signToken(user);

  // 申請刪除後仍可登入，這是取消刪除的唯一入口。
  const deletion = user.deletion_requested_at ? deletionStatus(user.deletion_requested_at) : null;

  res.status(200).json({
    success: true,
    message: '登入成功',
    data: { token, ...(deletion && { pending_deletion: deletion }) }
  });
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
