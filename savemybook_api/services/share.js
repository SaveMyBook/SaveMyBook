const crypto = require('crypto');
const prisma = require('../lib/prisma');

/// 分享連結用的權杖。
///
/// 流水號可被枚舉，UUID v1 由時間與網卡位址推導、v4 多半也只是 Math.random，
/// 都不該拿來當「知道連結就看得到」的憑證。這裡用密碼學亂數。
const newToken = () => crypto.randomBytes(16).toString('hex');

/// 公開路由只認這個格式。舊的 /u/<流水號>、/b/<流水號> 一律視為無效，
/// 否則加密等於沒做。
const TOKEN_RE = /^[0-9a-f]{32}$/;

/// 只在欄位仍為 NULL 時寫入。兩個請求同時首次索取時，後寫的那個不會
/// 蓋掉先發出去的連結，雙方最後都拿到資料庫裡那一組。
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
