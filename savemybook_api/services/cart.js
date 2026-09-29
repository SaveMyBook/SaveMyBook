const prisma = require('../lib/prisma');
const { badRequest, forbidden, notFound } = require('../lib/errors');
const { bookCard, cabinetBrief } = require('../lib/selects');
const reservations = require('./reservations');
const deposits = require('./book-deposits');

const MAX_CART_ITEMS = 100;

const cartInclude = {
  books: { include: { ...bookCard, smart_cabinets: { select: cabinetBrief } } }
};

const list = async (userId) => {
  const items = await prisma.shopping_cart.findMany({
    where: { user_id: userId },
    orderBy: { added_at: 'desc' },
    include: cartInclude
  });

  const holds = items.length > 0 ? await reservations.activeHoldsFor(items.map((i) => i.book_id)) : [];
  const holdOf = new Map(holds.map((h) => [h.book_id, h]));
  const books = await deposits.withCabinetFlag(items.map((i) => i.books));
  // 舊資料的購物車數量可能大於 1，一律以 1 本回傳與計價，與結帳一致。
  const data = items.map((i, index) => {
    const hold = holdOf.get(i.book_id);
    return {
      ...i,
      quantity: 1,
      books: hold
        ? { ...books[index], reservation: { reserved_until: hold.pickup_deadline, reserved_for_me: hold.buyer_id === userId } }
        : books[index]
    };
  });

  const total = items.reduce((sum, i) => sum + Number(i.books.price), 0);
  return { items: data, total };
};

const add = async (userId, bookId) => {
  const book = await prisma.books.findUnique({
    where: { book_id: bookId },
    select: { book_id: true, title: true, seller_id: true, status: true, is_approved: true }
  });
  if (!book) throw notFound('找不到該書籍');
  if (book.seller_id === userId) throw badRequest('無法將自己上架的書籍加入購物車');
  if (book.status !== 'on_sale' || !book.is_approved) throw badRequest('此書籍目前無法購買');
  await reservations.assertNotHeldByOthers(null, [book], userId);

  const existing = await prisma.shopping_cart.findUnique({
    where: { user_id_book_id: { user_id: userId, book_id: bookId } },
    select: { cart_id: true }
  });
  if (existing) return { alreadyInCart: true, item: { book_id: bookId, quantity: 1 } };
  if ((await prisma.shopping_cart.count({ where: { user_id: userId } })) >= MAX_CART_ITEMS) {
    throw badRequest(`購物車最多可放入 ${MAX_CART_ITEMS} 項商品`);
  }

  const item = await prisma.shopping_cart.upsert({
    where: { user_id_book_id: { user_id: userId, book_id: bookId } },
    update: { quantity: 1 },
    create: { user_id: userId, book_id: bookId, quantity: 1 }
  });
  return { alreadyInCart: false, created: true, item };
};

const bookIds = async (userId) => {
  const items = await prisma.shopping_cart.findMany({ where: { user_id: userId }, select: { book_id: true } });
  return items.map((i) => i.book_id);
};

const setQuantity = async (userId, cartId) => {
  const item = await prisma.shopping_cart.findUnique({ where: { cart_id: cartId } });
  if (!item) throw notFound('找不到該購物車項目');
  if (item.user_id !== userId) throw forbidden();

  return prisma.shopping_cart.update({ where: { cart_id: cartId }, data: { quantity: 1 } });
};

const remove = async (userId, cartId) => {
  const result = await prisma.shopping_cart.deleteMany({ where: { cart_id: cartId, user_id: userId } });
  if (result.count === 0) throw notFound('找不到該購物車項目');
};

module.exports = { list, add, bookIds, setQuantity, remove };
