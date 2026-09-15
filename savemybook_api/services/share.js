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

const isVisibleUser = (user) => user && user.is_active && !user.is_blacklisted && !user.anonymized_at;

const publicUserByToken = async (token) => {
  const user = await prisma.users.findFirst({
    where: { share_token: token },
    select: {
      user_id: true,
      nickname: true,
      avatar_url: true,
      bio: true,
      created_at: true,
      is_active: true,
      is_blacklisted: true,
      anonymized_at: true,
      _count: { select: { books: true } }
    }
  });
  return isVisibleUser(user) ? user : null;
};

const publicBookByToken = async (token) => {
  const book = await prisma.books.findFirst({
    where: { share_token: token },
    select: {
      book_id: true,
      title: true,
      author: true,
      price: true,
      status: true,
      is_approved: true,
      condition_level: true,
      book_categories: { select: { category_name: true } },
      book_images: { select: { image_url: true }, orderBy: { image_id: 'asc' }, take: 1 },
      users: {
        select: { nickname: true, avatar_url: true, is_active: true, is_blacklisted: true, anonymized_at: true }
      }
    }
  });
  if (!book || book.status === 'removed' || !book.is_approved || !isVisibleUser(book.users)) return null;
  return book;
};

module.exports = { TOKEN_RE, ensureUserToken, ensureBookToken, rotateUserToken, publicUserByToken, publicBookByToken };
