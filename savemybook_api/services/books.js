const prisma = require('../lib/prisma');
const { badRequest, forbidden, notFound, conflict } = require('../lib/errors');
const { bookCard, cabinetLocation, categoryName } = require('../lib/selects');
const { BOOK_STATUSES } = require('../constants/domain');
const share = require('./share');
const isbnLookup = require('./isbn-lookup');
const ranking = require('./ranking');
const reservations = require('./reservations');
const { notifyMany } = require('./notify');

const MAX_IMAGES_PER_BOOK = 10;
const SELLER_STATUSES = ['on_sale', 'removed'];

const SORTS = {
  newest: { created_at: 'desc' },
  price_asc: { price: 'asc' },
  price_desc: { price: 'desc' },
  popular: { view_count: 'desc' }
};

const listInclude = { ...bookCard, smart_cabinets: { select: cabinetLocation } };

const detailInclude = {
  users: { select: { user_id: true, nickname: true, avatar_url: true, created_at: true } },
  book_images: true,
  book_categories: { select: categoryName },
  smart_cabinets: { select: cabinetLocation }
};

const lookupIsbn = (isbn) => isbnLookup.lookup(isbn);

const listWhere = ({ status, sellerId, ownView, categoryIds, keyword }) => ({
  ...(status !== 'all' ? { status } : !ownView && { status: { not: 'removed' } }),
  ...(sellerId && { seller_id: sellerId }),
  ...(!ownView && { is_approved: true }),
  ...(categoryIds.length > 0 && { category_id: { in: categoryIds } }),
  ...(keyword && {
    OR: [
      { title: { contains: keyword } },
      { author: { contains: keyword } },
      { publisher: { contains: keyword } }
    ]
  })
});

const inIdOrder = async (ids, where = {}) => {
  const rows = ids.length > 0
    ? await prisma.books.findMany({ where: { book_id: { in: ids }, ...where }, include: listInclude })
    : [];
  const byId = new Map(rows.map((b) => [b.book_id, b]));
  return ids.map((bookId) => byId.get(bookId)).filter(Boolean);
};

const list = async ({ skip, limit, sort, viewerId, ...filters }) => {
  const where = listWhere(filters);

  if (sort === 'popular' && !filters.sellerId) {
    const ranked = await ranking.rankedIds(where, viewerId);
    return { total: ranked.length, books: await inIdOrder(ranked.slice(skip, skip + limit)) };
  }

  const [books, total] = await Promise.all([
    prisma.books.findMany({ where, skip, take: limit, orderBy: SORTS[sort], include: listInclude }),
    prisma.books.count({ where })
  ]);
  return { total, books };
};

const recommended = async (viewerId, viewedIds, limit) => {
  const ids = (await ranking.recommendedIds(viewerId, viewedIds)).slice(0, limit);
  return inIdOrder(ids, { status: 'on_sale', is_approved: true });
};

const findByShareToken = async (token, viewerId) => {
  if (!share.TOKEN_RE.test(token)) throw notFound('找不到此書籍');
  const book = await prisma.books.findFirst({
    where: { share_token: token, status: { not: 'removed' }, is_approved: true },
    include: detailInclude
  });
  if (!book) throw notFound('找不到此書籍');
  const hold = await reservations.holdForViewer(book.book_id, viewerId);
  return { ...book, reservation: hold };
};

const shareLink = async (bookId, baseUrl) => {
  const book = await prisma.books.findUnique({
    where: { book_id: bookId },
    select: { book_id: true, title: true, status: true, is_approved: true }
  });
  if (!book) throw notFound('找不到此書籍');

  if (book.status === 'removed' || !book.is_approved) throw conflict('此書籍已下架，無法分享');

  const token = await share.ensureBookToken(bookId);
  return { url: `${baseUrl}/b/${token}`, title: book.title };
};

const detail = async (bookId, { viewerId, viewerKey }) => {
  const book = await prisma.books.findUnique({ where: { book_id: bookId }, include: detailInclude });
  if (!book || (!book.is_approved && viewerId !== book.seller_id)) throw notFound('找不到該書籍');

  if (viewerId !== book.seller_id && ranking.shouldCountView(bookId, viewerId ?? viewerKey)) {
    prisma.books.update({ where: { book_id: bookId }, data: { view_count: { increment: 1 } } }).catch(() => {});
  }
  const hold = await reservations.holdForViewer(bookId, viewerId);
  return { ...book, reservation: hold };
};

// 只檢查有變更的關聯，否則書櫃停用後賣家送回舊 cabinet_id 會被擋。
const assertRefsExist = async ({ categoryId, cabinetId }, current = {}) => {
  if (categoryId === current.category_id) categoryId = null;
  if (cabinetId === current.cabinet_id) cabinetId = null;
  const [category, cabinet] = await Promise.all([
    categoryId ? prisma.book_categories.count({ where: { category_id: categoryId } }) : 1,
    cabinetId ? prisma.smart_cabinets.count({ where: { cabinet_id: cabinetId, is_active: true } }) : 1
  ]);
  if (!category) throw badRequest('找不到此分類');
  if (!cabinet) throw badRequest('找不到此書櫃，或書櫃已停用');
};

const create = async (data, images) => {
  await assertRefsExist({ categoryId: data.category_id, cabinetId: data.cabinet_id });

  return prisma.$transaction(async (tx) => {
    const created = await tx.books.create({ data });
    if (images.length > 0) {
      await tx.book_images.createMany({
        data: images.map((img) => ({ ...img, book_id: created.book_id }))
      });
    }
    return created;
  });
};

const findOwnedBook = async (bookId, user, deniedMessage) => {
  const book = await prisma.books.findUnique({ where: { book_id: bookId } });
  if (!book) throw notFound('找不到該書籍');
  if (book.seller_id !== user.userId && user.role !== 'admin') throw forbidden(deniedMessage);
  return book;
};

const violationLocked = async (book) => book.is_approved === false
  || (await prisma.reports.count({ where: { target_type: 'book', target_id: book.book_id, status: 'resolved' } })) > 0;

const notifyPriceDrop = async (book, oldPrice) => {
  const fans = await prisma.favorites.findMany({
    where: { book_id: book.book_id, user_id: { not: book.seller_id } },
    select: { user_id: true }
  });
  if (fans.length === 0) return;
  await notifyMany(null, fans.map((f) => f.user_id), {
    type: 'promotion',
    title: '收藏的書籍已降價',
    content: `《${book.title}》從 ${oldPrice} 降至 ${Number(book.price)} 代幣。`,
    relatedId: book.book_id,
    relatedType: 'book'
  });
};

const allowedStatuses = (user) => (user.role === 'admin' ? BOOK_STATUSES : SELLER_STATUSES);

const update = async (bookId, user, data) => {
  const isAdmin = user.role === 'admin';
  const book = await findOwnedBook(bookId, user, '存取被拒，您無權限修改他人的商品');

  // 檢舉成立但管理員未勾選下架時 is_approved 仍為 true，須一併查檢舉紀錄，否則賣家自行下架後可再上架。
  if (data.status === 'on_sale' && book.status !== 'on_sale' && !isAdmin && await violationLocked(book)) {
    throw forbidden('此書籍因違規遭下架，無法自行重新上架，請聯絡客服', 'BOOK_NOT_APPROVED');
  }
  if (isAdmin && data.status === 'on_sale') data.is_approved = true;

  // 保留中的書已有人付款，改回上架會被第二人買走。
  if (data.status && data.status !== book.status && ['reserved', 'sold'].includes(book.status) && !isAdmin) {
    throw conflict(book.status === 'sold' ? '此書籍已售出，無法變更狀態' : '此書籍交易中，無法變更狀態');
  }

  await assertRefsExist({ categoryId: data.category_id, cabinetId: data.cabinet_id }, book);

  const updatedBook = await prisma.books.update({
    where: { book_id: bookId },
    data: { ...data, updated_at: new Date() }
  });

  const oldPrice = Number(book.price);
  if (data.price !== undefined && data.price < oldPrice && updatedBook.status === 'on_sale') {
    notifyPriceDrop(updatedBook, oldPrice).catch((err) => console.error('[降價通知失敗]:', err.message));
  }
  return updatedBook;
};

const remove = async (bookId, user) => {
  const book = await findOwnedBook(bookId, user, '存取被拒，您無權限刪除他人的書籍');

  if (book.status === 'reserved') throw conflict('此書籍交易中，請先處理訂單再下架');

  await prisma.books.update({
    where: { book_id: bookId },
    data: { status: 'removed', updated_at: new Date() }
  });
};

const addImages = async (bookId, user, images) => {
  await findOwnedBook(bookId, user, '存取被拒，您無權限修改他人的商品');
  if (images.length === 0) throw badRequest('請選擇要上傳的圖片');

  const existing = await prisma.book_images.count({ where: { book_id: bookId } });
  if (existing + images.length > MAX_IMAGES_PER_BOOK) {
    throw badRequest(`每本書最多 ${MAX_IMAGES_PER_BOOK} 張照片，目前已有 ${existing} 張`);
  }

  await prisma.book_images.createMany({
    data: images.map((img) => ({ book_id: bookId, ...img }))
  });

  return prisma.book_images.findMany({ where: { book_id: bookId } });
};

const removeImage = async (bookId, imageId, user) => {
  await findOwnedBook(bookId, user, '存取被拒，您無權限修改他人的商品');

  const result = await prisma.book_images.deleteMany({ where: { image_id: imageId, book_id: bookId } });
  if (result.count === 0) throw notFound('找不到該圖片');
};

module.exports = {
  SORTS, allowedStatuses, lookupIsbn, list, recommended, findByShareToken, shareLink, detail, create, update, remove,
  addImages, removeImage
};
