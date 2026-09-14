const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const prisma = require('../lib/prisma');
const { env } = require('../config/env');

const deny = (res, status, message, code) =>
  res.status(status).json({ success: false, ...(code && { code }), message });

/// 密碼雜湊的指紋，簽進 token。
///
/// 改密碼或被客服重設後雜湊會變，舊 token 的指紋就對不上而失效，不必在資料庫多開欄位記版本。
/// 只放雜湊的 SHA-256 前 16 碼，token 內容可被解碼，不能直接放雜湊本身。
const passwordVersion = (passwordHash) =>
  crypto.createHash('sha256').update(String(passwordHash ?? '')).digest('hex').slice(0, 16);

const readToken = (req) => {
  const header = req.headers.authorization;
  if (typeof header !== 'string') return null;
  const [scheme, token] = header.trim().split(/\s+/);
  return /^bearer$/i.test(scheme) && token ? token : null;
};

/// 每次請求都回資料庫確認帳號狀態。只驗 JWT 簽章的話，停權與黑名單要等
/// token 自然過期才生效，期間被停權者仍可持舊 token 呼叫全部端點；
/// role 被降級同理。代價是每個請求多一次 DB 查詢。
const authenticateToken = async (req, res, next) => {
  const token = readToken(req);
  if (!token) return deny(res, 401, '存取被拒，未提供 Token');

  let decoded;
  try {
    // 明確指定演算法，避免被換成 none 或其他演算法的 token 騙過。
    decoded = jwt.verify(token, env.jwtSecret, { algorithms: ['HS256'] });
  } catch {
    return deny(res, 403, 'Token 無效或已過期');
  }

  const userId = Number(decoded?.userId);
  if (!Number.isSafeInteger(userId) || userId < 1) return deny(res, 403, 'Token 無效或已過期');

  const user = await prisma.users.findUnique({
    where: { user_id: userId },
    select: { user_id: true, email: true, role: true, is_active: true, is_blacklisted: true, password_hash: true }
  });

  if (!user) return deny(res, 401, '帳號不存在，請重新登入', 'ACCOUNT_NOT_FOUND');
  // 部署前簽發的 token 沒有指紋，放行到它自然過期（最多 24 小時），避免所有人被強制登出。
  if (decoded.pwv !== undefined && decoded.pwv !== passwordVersion(user.password_hash)) {
    return deny(res, 401, '密碼已經變更，請重新登入', 'TOKEN_REVOKED');
  }
  if (user.is_blacklisted) {
    return deny(res, 401, '此帳號已被列入黑名單，如有疑問請聯絡客服', 'ACCOUNT_BLACKLISTED');
  }
  if (!user.is_active) return deny(res, 401, '此帳號已被停權，如有疑問請聯絡客服', 'ACCOUNT_INACTIVE');

  // role 以資料庫為準，管理員被降級後立刻失效。
  req.user = { userId: user.user_id, role: user.role, email: user.email };
  next();
};

const signToken = (user) =>
  jwt.sign(
    { userId: user.user_id, role: user.role, email: user.email, pwv: passwordVersion(user.password_hash) },
    env.jwtSecret,
    { algorithm: 'HS256', expiresIn: env.jwtExpiresIn }
  );

module.exports = authenticateToken;
module.exports.signToken = signToken;
