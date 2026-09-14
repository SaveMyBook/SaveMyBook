const crypto = require('crypto');
const prisma = require('../lib/prisma');

// 須用密碼學亂數：流水號與 UUID 可被枚舉或推導。
const newToken = () => crypto.randomBytes(16).toString('hex');

// 舊的流水號路徑一律視為無效，否則可被枚舉。
const TOKEN_RE = /^[0-9a-f]{32}$/;

// 只在欄位仍為 NULL 時寫入，避免並行首次索取時蓋掉已發出的連結。
const ensureToken = async (model, key, id) => {
  const row = await prisma[model].findUnique({ where: { [key]: id }, select: { share_token: true } });
  if (!row) return null;
  if (row.share_token) return row.share_token;

  await prisma[model].updateMany({ where: { [key]: id, share_token: null }, data: { share_token: newToken() } });
  const fresh = await prisma[model].findUnique({ where: { [key]: id }, select: { share_token: true } });
  return fresh?.share_token ?? null;
};

const ensureUserToken = (userId) => ensureToken('users', 'user_id', userId);
const ensureBookToken = (bookId) => ensureToken('books', 'book_id', bookId);

const rotateUserToken = async (userId) => {
  const token = newToken();
  await prisma.users.update({
    where: { user_id: userId },
    data: { share_token: token, updated_at: new Date() }
  });
  return token;
};

module.exports = { TOKEN_RE, newToken, ensureUserToken, ensureBookToken, rotateUserToken };
