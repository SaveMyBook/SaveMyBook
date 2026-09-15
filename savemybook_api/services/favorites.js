const prisma = require('../lib/prisma');
const { notFound } = require('../lib/errors');
const { bookCard } = require('../lib/selects');

const list = async (userId) => {
  const favorites = await prisma.favorites.findMany({
    where: { user_id: userId, books: { is_approved: true } },
    orderBy: { created_at: 'desc' },
    include: { books: { include: bookCard } }
  });
  return favorites.map((f) => f.books);
};

const bookIds = async (userId) => {
  const favorites = await prisma.favorites.findMany({
    where: { user_id: userId },
    select: { book_id: true }
  });
  return favorites.map((f) => f.book_id);
};

const add = async (userId, bookId) => {
  const book = await prisma.books.findUnique({ where: { book_id: bookId }, select: { book_id: true } });
  if (!book) throw notFound('找不到該書籍');

  return prisma.favorites.upsert({
    where: { user_id_book_id: { user_id: userId, book_id: bookId } },
    update: {},
    create: { user_id: userId, book_id: bookId }
  });
};

const remove = (userId, bookId) => prisma.favorites.deleteMany({ where: { user_id: userId, book_id: bookId } });

module.exports = { list, bookIds, add, remove };
