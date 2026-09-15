const prisma = require('../lib/prisma');
const { badRequest, forbidden, notFound } = require('../lib/errors');
const { bookCard, cabinetBrief } = require('../lib/selects');
const reservations = require('./reservations');

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
  const data = items.map((i) => {
    const hold = holdOf.get(i.book_id);
    return hold
      ? { ...i, books: { ...i.books, reservation: { reserved_until: hold.pickup_deadline, reserved_for_me: hold.buyer_id === userId } } }
      : i;
  });

  const total = items.reduce((sum, i) => sum + Number(i.books.price) * i.quantity, 0);
  return { items: data, total };
};

const add = async (userId, bookId, quantity) => {
  const book = await prisma.books.findUnique({
    where: { book_id: bookId },
    select: { book_id: true, title: true, seller_id: true, status: true, is_approved: true, quantity: true }
  });
  if (!book) throw notFound('找不到該書籍');
  if (book.seller_id === userId) throw badRequest('無法將自己上架的書籍加入購物車');
  if (book.status !== 'on_sale' || !book.is_approved) throw badRequest('此書籍目前無法購買');
  await reservations.assertNotHeldByOthers(null, [book], userId);

  const existing = await prisma.shopping_cart.findUnique({
    where: { user_id_book_id: { user_id: userId, book_id: bookId } },
    select: { quantity: true }
  });
  if (!existing && (await prisma.shopping_cart.count({ where: { user_id: userId } })) >= MAX_CART_ITEMS) {
    throw badRequest(`購物車最多可放入 ${MAX_CART_ITEMS} 項商品`);
  }

  const max = Math.max(book.quantity, 1);
  if (existing && existing.quantity >= max) {
    return { alreadyInCart: true, item: { ...existing, book_id: bookId } };
  }

  // 重複加入不可累加數量，否則結帳會對同一本書重複收費。
  const capped = Math.min((existing?.quantity ?? 0) + quantity, max);

  const item = await prisma.shopping_cart.upsert({
    where: { user_id_book_id: { user_id: userId, book_id: bookId } },
    update: { quantity: capped },
    create: { user_id: userId, book_id: bookId, quantity: capped }
  });
  return { alreadyInCart: false, created: !existing, item };
};

const bookIds = async (userId) => {
  const items = await prisma.shopping_cart.findMany({ where: { user_id: userId }, select: { book_id: true } });
  return items.map((i) => i.book_id);
};

const setQuantity = async (userId, cartId, quantity) => {
  const item = await prisma.shopping_cart.findUnique({
    where: { cart_id: cartId },
    include: { books: { select: { quantity: true } } }
  });
  if (!item) throw notFound('找不到該購物車項目');
  if (item.user_id !== userId) throw forbidden('存取被拒');

  const max = Math.max(item.books.quantity, 1);
  if (quantity > max) throw badRequest(`此書籍數量僅 ${max} 本`);

  return prisma.shopping_cart.update({ where: { cart_id: cartId }, data: { quantity } });
};

const remove = async (userId, cartId) => {
  const result = await prisma.shopping_cart.deleteMany({ where: { cart_id: cartId, user_id: userId } });
  if (result.count === 0) throw notFound('找不到該購物車項目');
};

module.exports = { list, add, bookIds, setQuantity, remove };
