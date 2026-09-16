const { readToken, verify } = require('../lib/auth-token');
const auth = require('../services/auth');
const sessions = require('../services/sessions');

const deny = (res, status, message, code) =>
  res.status(status).json({ success: false, ...(code && { code }), message });

const authenticateToken = async (req, res, next) => {
  const token = readToken(req);
  if (!token) return deny(res, 401, '請先登入');

  let decoded;
  try {
    decoded = verify(token);
  } catch (err) {
    if (err.name === 'TokenExpiredError') return deny(res, 403, '登入已逾時', 'TOKEN_EXPIRED');
    return deny(res, 403, '登入已失效，請重新登入');
  }

  const userId = Number(decoded?.userId);
  if (decoded?.typ || !Number.isSafeInteger(userId) || userId < 1) return deny(res, 403, '登入已失效，請重新登入');

  const [user, revoked] = await Promise.all([auth.loadUser(userId), auth.sessionProblem(userId, decoded)]);
  const problem = auth.accountProblem(user, decoded) ?? revoked;
  if (problem) return deny(res, ...problem);

  if (decoded.sid) sessions.touch(decoded.sid, req.ip);

  req.user = { userId: user.user_id, role: user.role, email: user.email, sid: decoded.sid ?? null };
  next();
};

const peekUserId = (req) => {
  const token = readToken(req);
  if (!token) return null;
  try {
    const decoded = verify(token);
    const userId = Number(decoded?.userId);
    return !decoded.typ && Number.isSafeInteger(userId) && userId > 0 ? userId : null;
  } catch {
    return null;
  }
};

module.exports = authenticateToken;
module.exports.peekUserId = peekUserId;
