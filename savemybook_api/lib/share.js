const crypto = require('crypto');
const prisma = require('./prisma');

/// 分享連結用的權杖。
///
/// 流水號可被枚舉，UUID v1 由時間與網卡位址推導、v4 多半也只是 Math.random，
/// 都不該拿來當「知道連結就看得到」的憑證。這裡用密碼學亂數。
const newToken = () => crypto.randomBytes(16).toString('hex');

/// 公開路由只認這個格式。舊的 /u/<流水號>、/b/<流水號> 一律視為無效，
/// 否則加密等於沒做。
const TOKEN_RE = /^[0-9a-f]{32}$/;

const ensureUserToken = async (userId) => {
  const user = await prisma.users.findUnique({
    where: { user_id: userId },
    select: { share_token: true }
  });
  if (user?.share_token) return user.share_token;

  const token = newToken();
  await prisma.users.update({ where: { user_id: userId }, data: { share_token: token } });
  return token;
};

const ensureBookToken = async (bookId) => {
  const book = await prisma.books.findUnique({
    where: { book_id: bookId },
    select: { share_token: true }
  });
  if (!book) return null;
  if (book.share_token) return book.share_token;

  const token = newToken();
  await prisma.books.update({ where: { book_id: bookId }, data: { share_token: token } });
  return token;
};

module.exports = { newToken, TOKEN_RE, ensureUserToken, ensureBookToken };
