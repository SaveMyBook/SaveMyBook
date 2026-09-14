const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const prisma = require('../lib/prisma');
const password = require('../lib/password');
const { env } = require('../config/env');
const { badRequest, forbidden, HttpError } = require('../lib/errors');
const sessions = require('./sessions');
const { notify } = require('./notify');

const MAX_PIN_ATTEMPTS = 5;
const PIN_LOCK_MINUTES = 15;

const SCOPES = {
  payment: { ttl: 3 * 60, singleUse: true, methods: ['pin', 'biometric'] },
  sensitive: { ttl: 5 * 60, singleUse: false, methods: ['password', 'pin', 'biometric'] }
};

const assertPinPolicy = (pin) => {
  if (typeof pin !== 'string' || !/^\d{6}$/.test(pin)) throw badRequest('交易密碼必須是 6 位數字', 'PIN_FORMAT');
  if (/^(\d)\1{5}$/.test(pin)) throw badRequest('交易密碼不能是 6 個相同的數字', 'PIN_TOO_WEAK');
  const digits = [...pin].map(Number);
  const steps = new Set(digits.slice(1).map((d, i) => (d - digits[i] + 10) % 10));
  if (steps.size === 1 && (steps.has(1) || steps.has(9))) {
    throw badRequest('交易密碼不能是連續的數字', 'PIN_TOO_WEAK');
  }
  if (/^(\d\d)\1\1$|^(\d\d\d)\2$/.test(pin)) throw badRequest('交易密碼不能是重複的數字組合', 'PIN_TOO_WEAK');
};

const securityRow = async (userId) => {
  const [row] = await prisma.$queryRaw`
    SELECT payment_pin_hash, pin_failed_count, pin_locked_until, pin_updated_at
    FROM user_security WHERE user_id = ${userId}`;
  return row ?? null;
};

const status = async (userId, sid) => {
  if (!(await sessions.isAvailable())) {
    return { available: false, has_payment_pin: false, pin_locked_until: null, biometric_pay_enabled: false };
  }
  const [row, session] = await Promise.all([securityRow(userId), sessions.findActive(sid)]);
  const lockedUntil = row?.pin_locked_until && new Date(row.pin_locked_until) > new Date() ? row.pin_locked_until : null;
  return {
    available: true,
    has_payment_pin: Boolean(row?.payment_pin_hash),
    pin_updated_at: row?.pin_updated_at ?? null,
    pin_locked_until: lockedUntil,
    biometric_pay_enabled: Boolean(session?.pay_key_hash)
  };
};

const assertAvailable = async () => {
  if (!(await sessions.isAvailable())) {
    throw new HttpError(503, '伺服器尚未完成交易密碼的資料庫更新，請聯絡管理員', 'SECURITY_UNAVAILABLE');
  }
};

const setPin = async (userId, pin) => {
  await assertAvailable();
  assertPinPolicy(pin);
  const hashed = await password.hash(pin);
  const now = new Date();
  await prisma.$executeRaw`
    INSERT INTO user_security (user_id, payment_pin_hash, pin_failed_count, pin_locked_until, pin_updated_at)
    VALUES (${userId}, ${hashed}, 0, NULL, ${now})
    ON DUPLICATE KEY UPDATE payment_pin_hash = VALUES(payment_pin_hash), pin_failed_count = 0,
      pin_locked_until = NULL, pin_updated_at = VALUES(pin_updated_at)`;
};

const minutesLeft = (until) => Math.max(1, Math.ceil((new Date(until).getTime() - Date.now()) / 60000));

const verifyPin = async (userId, pin) => {
  await assertAvailable();
  const row = await securityRow(userId);
  if (!row?.payment_pin_hash) throw forbidden('尚未設定交易密碼', 'PAYMENT_PIN_NOT_SET');
  if (row.pin_locked_until && new Date(row.pin_locked_until) > new Date()) {
    throw new HttpError(423, `交易密碼錯誤次數過多，請 ${minutesLeft(row.pin_locked_until)} 分鐘後再試`, 'PIN_LOCKED', {
      locked_until: row.pin_locked_until
    });
  }

  if (typeof pin === 'string' && /^\d{6}$/.test(pin) && (await password.verify(pin, row.payment_pin_hash))) {
    if (row.pin_failed_count > 0) {
      await prisma.$executeRaw`UPDATE user_security SET pin_failed_count = 0, pin_locked_until = NULL WHERE user_id = ${userId}`;
    }
    return;
  }

  const failed = Number(row.pin_failed_count) + 1;
  if (failed >= MAX_PIN_ATTEMPTS) {
    const until = new Date(Date.now() + PIN_LOCK_MINUTES * 60 * 1000);
    await prisma.$executeRaw`
      UPDATE user_security SET pin_failed_count = 0, pin_locked_until = ${until} WHERE user_id = ${userId}`;
    await notify(null, {
      userId,
      title: '交易密碼已暫時鎖定',
      content: `交易密碼連續輸入錯誤 ${MAX_PIN_ATTEMPTS} 次，已鎖定 ${PIN_LOCK_MINUTES} 分鐘。如果不是你本人操作，請立即修改登入密碼並登出其他裝置。`,
      relatedType: 'security'
    }).catch(() => {});
    throw new HttpError(423, `交易密碼錯誤次數過多，請 ${PIN_LOCK_MINUTES} 分鐘後再試`, 'PIN_LOCKED', { locked_until: until });
  }
  await prisma.$executeRaw`UPDATE user_security SET pin_failed_count = ${failed} WHERE user_id = ${userId}`;
  throw badRequest(`交易密碼錯誤，還可以再試 ${MAX_PIN_ATTEMPTS - failed} 次`, 'INVALID_PIN', {
    remaining_attempts: MAX_PIN_ATTEMPTS - failed
  });
};

const usedTokens = new Map();

const sweepUsed = setInterval(() => {
  const now = Date.now();
  for (const [jti, exp] of usedTokens) if (exp <= now) usedTokens.delete(jti);
}, 60 * 1000);
sweepUsed.unref();

const issueToken = ({ userId, sid, scope, method }) => {
  const rule = SCOPES[scope];
  const token = jwt.sign(
    { typ: 'verify', uid: userId, sid: sid ?? null, scope, method, jti: crypto.randomBytes(12).toString('hex') },
    env.jwtSecret,
    { algorithm: 'HS256', expiresIn: rule.ttl }
  );
  return { verify_token: token, scope, expires_in: rule.ttl };
};

const verificationRequired = (scope, message) =>
  forbidden(message ?? (scope === 'payment' ? '請輸入交易密碼以完成付款' : '請先驗證身分'), 'VERIFICATION_REQUIRED');

const consumeToken = (req, scope) => {
  const raw = req.get('x-verify-token');
  const withScope = (err) => Object.assign(err, { extra: { verification: { scope, methods: SCOPES[scope].methods } } });
  if (!raw) throw withScope(verificationRequired(scope));

  let decoded;
  try {
    decoded = jwt.verify(raw, env.jwtSecret, { algorithms: ['HS256'] });
  } catch {
    throw withScope(verificationRequired(scope, '驗證已逾時，請重新驗證'));
  }
  const sameSession = (decoded.sid ?? null) === (req.user.sid ?? null);
  if (decoded.typ !== 'verify' || decoded.uid !== req.user.userId || !sameSession || decoded.scope !== scope) {
    throw withScope(verificationRequired(scope));
  }
  if (SCOPES[scope].singleUse) {
    if (usedTokens.has(decoded.jti)) throw withScope(verificationRequired(scope, '這次驗證已經使用過了，請重新驗證'));
    usedTokens.set(decoded.jti, decoded.exp * 1000);
  }
  return decoded;
};

const requireVerification = (scope) => async (req, res, next) => {
  try {
    if (!(await sessions.isAvailable())) return next();
    const decoded = consumeToken(req, scope);
    req.verification = decoded;
    if (SCOPES[scope].singleUse) {
      res.on('finish', () => {
        if (res.statusCode >= 400) usedTokens.delete(decoded.jti);
      });
    }
    next();
  } catch (err) {
    next(err);
  }
};

module.exports = {
  SCOPES, MAX_PIN_ATTEMPTS, assertPinPolicy, status, setPin, verifyPin, issueToken, requireVerification
};
