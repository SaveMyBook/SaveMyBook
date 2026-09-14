const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const prisma = require('../lib/prisma');
const { env } = require('../config/env');
const sessions = require('../services/sessions');

const deny = (res, status, message, code) =>
  res.status(status).json({ success: false, ...(code && { code }), message });

// 只放雜湊的 SHA-256 前 16 碼：token 內容可被解碼，不能放雜湊本身。
const passwordVersion = (passwordHash) =>
  crypto.createHash('sha256').update(String(passwordHash ?? '')).digest('hex').slice(0, 16);

const readToken = (req) => {
  const header = req.headers.authorization;
  if (typeof header !== 'string') return null;
  const [scheme, token] = header.trim().split(/\s+/);
  return /^bearer$/i.test(scheme) && token ? token : null;
};

const loadUser = (userId) => prisma.users.findUnique({
  where: { user_id: userId },
  select: { user_id: true, email: true, role: true, is_active: true, is_blacklisted: true, password_hash: true }
});

const accountProblem = (user, decoded) => {
  if (!user) return [401, '帳號不存在，請重新登入', 'ACCOUNT_NOT_FOUND'];
  if (decoded.pwv !== undefined && decoded.pwv !== passwordVersion(user.password_hash)) {
    return [401, '密碼已經變更，請重新登入', 'TOKEN_REVOKED'];
  }
  if (user.is_blacklisted) return [401, '此帳號已被列入黑名單，如有疑問請聯絡客服', 'ACCOUNT_BLACKLISTED'];
  if (!user.is_active) return [401, '此帳號已被停權，如有疑問請聯絡客服', 'ACCOUNT_INACTIVE'];
  return null;
};

const sessionProblem = async (userId, decoded) => {
  const state = await sessions.lookup(userId, decoded.sid);
  if (!state.available) return null;
  if (decoded.sid) {
    if (!state.session || state.session.userId !== userId || state.session.revoked) {
      return [401, '這台裝置已經登出，請重新登入', 'SESSION_REVOKED'];
    }
    return null;
  }
  if (state.validAfter && decoded.iat < Math.floor(state.validAfter.getTime() / 1000)) {
    return [401, '這台裝置已經登出，請重新登入', 'SESSION_REVOKED'];
  }
  return null;
};

const authenticateToken = async (req, res, next) => {
  const token = readToken(req);
  if (!token) return deny(res, 401, '存取被拒，未提供 Token');

  let decoded;
  try {
    decoded = jwt.verify(token, env.jwtSecret, { algorithms: ['HS256'] });
  } catch (err) {
    if (err.name === 'TokenExpiredError') return deny(res, 403, '登入已逾時', 'TOKEN_EXPIRED');
    return deny(res, 403, 'Token 無效或已過期');
  }

  const userId = Number(decoded?.userId);
  if (decoded?.typ || !Number.isSafeInteger(userId) || userId < 1) return deny(res, 403, 'Token 無效或已過期');

  const [user, revoked] = await Promise.all([loadUser(userId), sessionProblem(userId, decoded)]);
  const problem = accountProblem(user, decoded) ?? revoked;
  if (problem) return deny(res, ...problem);

  if (decoded.sid) sessions.touch(decoded.sid, req.ip);

  req.user = { userId: user.user_id, role: user.role, email: user.email, sid: decoded.sid ?? null };
  next();
};

const signToken = (user, sid) =>
  jwt.sign(
    {
      userId: user.user_id,
      role: user.role,
      email: user.email,
      pwv: passwordVersion(user.password_hash),
      ...(sid && { sid })
    },
    env.jwtSecret,
    { algorithm: 'HS256', expiresIn: env.jwtExpiresIn }
  );

const peekUserId = (req) => {
  const token = readToken(req);
  if (!token) return null;
  try {
    const decoded = jwt.verify(token, env.jwtSecret, { algorithms: ['HS256'] });
    const userId = Number(decoded?.userId);
    return !decoded.typ && Number.isSafeInteger(userId) && userId > 0 ? userId : null;
  } catch {
    return null;
  }
};

module.exports = authenticateToken;
module.exports.peekUserId = peekUserId;
module.exports.signToken = signToken;
module.exports.readToken = readToken;
module.exports.loadUser = loadUser;
module.exports.accountProblem = accountProblem;
