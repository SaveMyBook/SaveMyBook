const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const { env } = require('../config/env');

// 只放雜湊的 SHA-256 前 16 碼：token 內容可被解碼，不能放雜湊本身。
const passwordVersion = (passwordHash) =>
  crypto.createHash('sha256').update(String(passwordHash ?? '')).digest('hex').slice(0, 16);

const readToken = (req) => {
  const header = req.headers.authorization;
  if (typeof header !== 'string') return null;
  const [scheme, token] = header.trim().split(/\s+/);
  return /^bearer$/i.test(scheme) && token ? token : null;
};

const sign = (payload, expiresIn) => jwt.sign(payload, env.jwtSecret, { algorithm: 'HS256', expiresIn });

const verify = (token, options = {}) => jwt.verify(token, env.jwtSecret, { algorithms: ['HS256'], ...options });

const signToken = (user, sid) =>
  sign(
    {
      userId: user.user_id,
      role: user.role,
      email: user.email,
      pwv: passwordVersion(user.password_hash),
      ...(sid && { sid })
    },
    env.jwtExpiresIn
  );

module.exports = { passwordVersion, readToken, sign, verify, signToken };
