const prisma = require('../lib/prisma');
const password = require('../lib/password');
const { passwordVersion, signToken, verify } = require('../lib/auth-token');
const { notFound, unauthorized, forbidden } = require('../lib/errors');
const sessions = require('./sessions');
const { notify } = require('./notify');
const { deletionStatus } = require('./account');

const loadUser = (userId) => prisma.users.findUnique({
  where: { user_id: userId },
  select: { user_id: true, email: true, role: true, is_active: true, is_blacklisted: true, password_hash: true }
});

const accountProblem = (user, decoded) => {
  if (!user) return [401, '帳號不存在，請重新登入', 'ACCOUNT_NOT_FOUND'];
  if (decoded.pwv !== undefined && decoded.pwv !== passwordVersion(user.password_hash)) {
    return [401, '密碼已變更，請重新登入', 'TOKEN_REVOKED'];
  }
  if (user.is_blacklisted) return [401, '此帳號已被列入黑名單，如有疑問請聯絡客服', 'ACCOUNT_BLACKLISTED'];
  if (!user.is_active) return [401, '此帳號已被停權，如有疑問請聯絡客服', 'ACCOUNT_INACTIVE'];
  return null;
};

const sessionProblem = async (userId, decoded) => {
  const state = await sessions.lookup(userId, decoded.sid);
  if (decoded.sid) {
    if (!state.session || state.session.userId !== userId || state.session.revoked) {
      return [401, '此裝置已登出，請重新登入', 'SESSION_REVOKED'];
    }
    return null;
  }
  if (state.validAfter && decoded.iat < Math.floor(state.validAfter.getTime() / 1000)) {
    return [401, '此裝置已登出，請重新登入', 'SESSION_REVOKED'];
  }
  return null;
};

const assertLoginAllowed = (user) => {
  if (user.is_blacklisted) throw forbidden('此帳號已被停用，請聯絡客服', 'ACCOUNT_BLACKLISTED');
  if (!user.is_active) throw forbidden('此帳號已停權，請聯絡客服', 'ACCOUNT_INACTIVE');
};

const logLogin = async (userId, device, method) => {
  const ip = device?.ip ? String(device.ip).slice(0, 45) : null;
  const label = sessions.deviceLabel(device);
  await prisma.$executeRaw`
    INSERT INTO login_logs (user_id, ip_address, device_info, login_at, login_method)
    VALUES (${userId}, ${ip}, ${label}, ${new Date()}, ${method})`;
};

// 密碼登入與社群登入共用：建立工作階段、簽發 Token、寫登入紀錄、提醒新裝置。
const issueLogin = async (user, device, method = 'password') => {
  const session = await sessions.create(user.user_id, device);
  const token = signToken(user, session.sid);

  logLogin(user.user_id, device, method).catch(() => {});

  if (session.isNewDevice) {
    await notify(null, {
      userId: user.user_id,
      title: '新裝置登入',
      content: `您的帳號已於「${sessions.deviceLabel(device)}」登入。若非本人操作，請立即變更密碼並至「登入裝置」登出該裝置。`,
      relatedType: 'security'
    }).catch(() => {});
  }

  // 申請刪除後仍須可登入，這是取消刪除的唯一入口。
  const deletion = user.deletion_requested_at ? deletionStatus(user.deletion_requested_at) : null;
  return { token, deletion };
};

const verifyPassword = async (email, plain) => {
  const user = await prisma.users.findUnique({ where: { email } });

  if (!user) throw notFound('此 Email 尚未註冊', 'ACCOUNT_NOT_FOUND');
  if (!(await password.verify(plain, user.password_hash))) throw unauthorized('密碼錯誤', 'INVALID_PASSWORD');
  assertLoginAllowed(user);
  return user;
};

const login = async (email, plain, device) => issueLogin(await verifyPassword(email, plain), device, 'password');

const refreshFailed = () => unauthorized('登入已失效，請重新登入', 'REFRESH_FAILED');

const refresh = async (raw, ip) => {
  let decoded;
  try {
    decoded = verify(raw, { ignoreExpiration: true });
  } catch {
    throw refreshFailed();
  }
  if (decoded.typ || !decoded.sid) throw refreshFailed();

  const [user, session] = await Promise.all([loadUser(Number(decoded.userId)), sessions.findActive(decoded.sid)]);
  if (!session || Number(session.user_id) !== Number(decoded.userId)) throw refreshFailed();
  const problem = accountProblem(user, decoded);
  if (problem) throw unauthorized(problem[1], problem[2]);

  sessions.touch(decoded.sid, ip);
  return signToken(user, decoded.sid);
};

const currentUser = async (userId) => {
  const user = await prisma.users.findUnique({
    where: { user_id: userId },
    omit: { password_hash: true }
  });
  if (!user) throw notFound('找不到使用者');
  return user;
};

module.exports = {
  loadUser, accountProblem, sessionProblem, assertLoginAllowed, logLogin, issueLogin, verifyPassword, login, refresh, currentUser
};
