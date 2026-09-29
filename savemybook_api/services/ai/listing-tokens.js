const crypto = require('crypto');
const prisma = require('../../lib/prisma');

const TTL_MS = 24 * 60 * 60 * 1000;
const KEEP_MS = 2 * TTL_MS;

const hashOf = (token) => crypto.createHash('sha256').update(String(token)).digest('hex');

const startOfDay = (d = new Date()) => new Date(d.getFullYear(), d.getMonth(), d.getDate());

const issue = async (userId, now = new Date()) => {
  const token = crypto.randomBytes(24).toString('base64url');
  await prisma.ai_listing_tokens.create({ data: { token_hash: hashOf(token), user_id: userId, created_at: now, redeemed_at: null } });
  return token;
};

// 先佔用再呼叫模型，同一個權杖同時送出兩次時只有一次能折抵；呼叫失敗時以 release 歸還。
const claim = async (userId, token, now = new Date()) => {
  if (typeof token !== 'string' || !token || token.length > 100) return null;
  const tokenHash = hashOf(token);
  const { count } = await prisma.ai_listing_tokens.updateMany({
    where: { token_hash: tokenHash, user_id: userId, redeemed_at: null, created_at: { gte: new Date(now.getTime() - TTL_MS) } },
    data: { redeemed_at: now }
  });
  return count > 0 ? tokenHash : null;
};

const release = (tokenHash) => prisma.ai_listing_tokens.updateMany({ where: { token_hash: tokenHash }, data: { redeemed_at: null } })
  .catch(() => null);

// 已計費的失敗讓權杖作廢：直接刪除，否則仍留在 redeemedToday 的計數中，多折抵一次成功次數。
const revoke = (tokenHash) => prisma.ai_listing_tokens.deleteMany({ where: { token_hash: tokenHash } }).catch(() => null);

// 折抵過的第二步會記成一筆成功的上架輔助，計算每日次數時要扣回；失敗的折抵已由 release 或 revoke 移除。
const redeemedToday = (userId, now = new Date()) => prisma.ai_listing_tokens.count({
  where: { user_id: userId, redeemed_at: { gte: startOfDay(now) } }
});

const purgeExpired = async (now = new Date()) => {
  const { count } = await prisma.ai_listing_tokens.deleteMany({ where: { created_at: { lt: new Date(now.getTime() - KEEP_MS) } } });
  return count;
};

module.exports = { TTL_MS, hashOf, issue, claim, release, revoke, redeemedToday, purgeExpired };
