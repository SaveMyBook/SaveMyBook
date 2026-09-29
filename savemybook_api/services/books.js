const prisma = require('../lib/prisma');
const { badRequest, forbidden, notFound, conflict } = require('../lib/errors');
const { bookCard, cabinetLocation, categoryName } = require('../lib/selects');
const { BOOK_STATUSES } = require('../constants/domain');
const { LISTING_MAX_IMAGES } = require('../constants/policy');
const share = require('./share');
const isbnLookup = require('./isbn-lookup');
const ranking = require('./ranking');
const recommendationEvents = require('./recommendation-events');
const reservations = require('./reservations');
const { notifyMany } = require('./notify');
const moderation = require('./ai/moderation');
const reviews = require('./ai/reviews');
const screening = require('./listing-screening');
const aiImages = require('./ai/images');
const cabinets = require('./cabinets');
const catalog = require('./ai/catalog-search');
const traces = require('./ai/trace');
const enrichment = require('./ai/enrich');
const deposits = require('./book-deposits');
const takedown = require('./book-takedown');
const { violationLocked } = require('./book-violations');

const MAX_IMAGES_PER_BOOK = LISTING_MAX_IMAGES;
const SELLER_STATUSES = ['on_sale', 'removed'];
// 書況說明只能在編輯時填寫，同樣會公開在書籍頁，須一併重新審核。
const MODERATED_FIELDS = ['title', 'author', 'publisher', 'description', 'condition_note'];

const SORTS = {
  newest: { created_at: 'desc' },
  // 有關鍵字時依相關程度（關鍵字＋語意）排序，沒有關鍵字時同最新上架。
  relevance: { created_at: 'desc' },
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

const keywordWhere = (keyword) => {
  const isbn = catalog.isbnOf(keyword);
  return {
    OR: [
      { title: { contains: keyword } },
      { author: { contains: keyword } },
      { publisher: { contains: keyword } },
      ...(isbn ? [{ isbn: { in: catalog.isbnForms(isbn) } }] : [])
    ]
  };
};

const listWhere = ({ status, sellerId, ownView, categoryIds, keyword }) => ({
  ...(status !== 'all' ? { status } : !ownView && { status: { not: 'removed' } }),
  ...(sellerId && { seller_id: sellerId }),
  ...(!ownView && { is_approved: true }),
  ...(categoryIds.length > 0 && { category_id: { in: categoryIds } }),
  ...(keyword && keywordWhere(keyword))
});

const inIdOrder = async (ids, where = {}) => {
  const rows = ids.length > 0
    ? await prisma.books.findMany({ where: { book_id: { in: ids }, ...where }, include: listInclude })
    : [];
  const byId = new Map(rows.map((b) => [b.book_id, b]));
  return deposits.withCabinetFlag(ids.map((bookId) => byId.get(bookId)).filter(Boolean));
};

const RELEVANCE_LIMIT = 200;
const SEARCH_ORIGIN = traces.origin('book_search');
const SIMILAR_ORIGIN = traces.origin('similar_books');

// 相關度排序：先放混合檢索的結果，再補上字面包含關鍵字但未被檢索排進來的書，避免漏掉只有部分字相符的書名。
const relevanceIds = async (where, { keyword, categoryIds, viewerId }) => {
  const categories = new Set(categoryIds);
  const ranked = await catalog.search([{ text: keyword, weight: 1 }], {
    query: keyword,
    limit: RELEVANCE_LIMIT,
    userId: viewerId ?? null,
    trace: SEARCH_ORIGIN,
    filter: categories.size > 0 ? (doc) => categories.has(doc.category_id) : null
  });
  const literal = await prisma.books.findMany({
    where,
    orderBy: [{ view_count: 'desc' }, { book_id: 'desc' }],
    take: RELEVANCE_LIMIT,
    select: { book_id: true }
  });
  const ids = ranked.map((r) => r.book_id);
  const seen = new Set(ids);
  for (const { book_id: id } of literal) if (!seen.has(id)) ids.push(id);
  return ids;
};

const list = async ({ skip, limit, sort, viewerId, ...filters }) => {
  const where = listWhere(filters);

  if (sort === 'relevance' && filters.keyword && !filters.sellerId && filters.status === 'on_sale') {
    const baseWhere = listWhere({ ...filters, keyword: null });
    const ids = await relevanceIds(where, { ...filters, viewerId });
    const page = await inIdOrder(ids.slice(skip, skip + limit), baseWhere);
    return { total: ids.length, books: page };
  }

  if (sort === 'popular' && !filters.sellerId) {
    const ranked = await ranking.rankedIds(where, viewerId);
    return { total: ranked.length, books: await inIdOrder(ranked.slice(skip, skip + limit)) };
  }

  const [books, total] = await Promise.all([
    prisma.books.findMany({ where, skip, take: limit, orderBy: SORTS[sort], include: listInclude }),
    prisma.books.count({ where })
  ]);
  const shaped = filters.ownView ? await withHolds(await reviews.withReviewStatus(books)) : books;
  return { total, books: await deposits.withCabinetFlag(shaped, { owner: filters.ownView }) };
};

const withHolds = async (list) => {
  const onSale = list.filter((b) => b.status === 'on_sale').map((b) => b.book_id);
  if (onSale.length === 0) return list;
  const holds = new Map((await reservations.activeHoldsFor(onSale)).map((h) => [h.book_id, h]));
  return list.map((b) => {
    const hold = holds.get(b.book_id);
    return hold ? { ...b, reservation: { reserved_until: hold.pickup_deadline, reserved_for_me: false } } : b;
  });
};

const recommended = async (viewerId, viewedIds, limit) => {
  const [ranked, dismissed] = await Promise.all([ranking.recommendedIds(viewerId, viewedIds), recommendationEvents.dismissedIds(viewerId)]);
  const ids = ranked.filter((id) => !dismissed.has(Number(id))).slice(0, limit);
  return inIdOrder(ids, { status: 'on_sale', is_approved: true });
};

const briefs = (ids) => inIdOrder(ids, { status: { not: 'removed' }, is_approved: true });

const SIMILAR_LIMIT = 10;

const similar = async (bookId, viewerId) => {
  const book = await prisma.books.findUnique({
    where: { book_id: bookId },
    select: {
      book_id: true, title: true, author: true, publisher: true, description: true, is_approved: true,
      book_categories: { select: { category_name: true } }
    }
  });
  if (!book || !book.is_approved) throw notFound('找不到該書籍', 'BOOK_NOT_FOUND');
  const ids = await catalog.similar(book, {
    limit: SIMILAR_LIMIT,
    userId: viewerId ?? null,
    trace: SIMILAR_ORIGIN,
    filter: viewerId ? (doc) => doc.seller_id !== viewerId : null
  });
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
  return deposits.decorate({ ...book, reservation: hold });
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
  if (!book || (!book.is_approved && viewerId !== book.seller_id)) throw notFound('找不到該書籍', 'BOOK_NOT_FOUND');

  if (viewerId !== book.seller_id && ranking.shouldCountView(bookId, viewerId ?? viewerKey)) {
    prisma.books.update({ where: { book_id: bookId }, data: { view_count: { increment: 1 } } }).catch(() => {});
  }
  const [hold, enriched] = await Promise.all([reservations.holdForViewer(bookId, viewerId), enrichment.infoFor(bookId)]);
  const owner = viewerId != null && viewerId === book.seller_id;
  const shaped = await deposits.decorate({ ...book, reservation: hold, enrichment: enriched }, { owner });
  return owner ? reviews.withReviewStatus(shaped) : shaped;
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
  if (cabinetId && (await cabinets.isUnderMaintenance(cabinetId))) throw badRequest('此書櫃維修中，請選擇其他書櫃');
};

const pendingReview = (decision) => ({ status: 'pending_review', reasons: decision.reasons });

// 書籍與照片已寫入，審核紀錄寫入失敗不能讓請求回 500：App 重送會重複新增照片、重複審核與計費。
const markSafely = (bookId, decision, options) => reviews.mark(prisma, bookId, decision, options)
  .catch((err) => console.error('[寫入上架審核紀錄失敗]:', err.message));

const create = async (data, images, { files = [] } = {}) => {
  await assertRefsExist({ categoryId: data.category_id, cabinetId: data.cabinet_id });

  const { decision: ruled, hint, peer } = await screening.ruleDecision(data);
  const created = await prisma.$transaction(async (tx) => {
    const row = await tx.books.create({ data: ruled ? { ...data, is_approved: false } : data });
    if (images.length > 0) {
      await tx.book_images.createMany({
        data: images.map((img) => ({ ...img, book_id: row.book_id }))
      });
    }
    if (ruled) await screening.hold(tx, row, ruled);
    return row;
  });
  screening.screenLater(created, files, { hint, peer, held: Boolean(ruled) });
  if (enrichment.FIELDS.some((f) => !String(created[f] ?? '').trim())) enrichment.later(created.book_id);

  return {
    book: { ...created, review_status: ruled ? 'pending' : null, in_cabinet: false, deposit: null },
    moderation: ruled ? pendingReview(ruled) : null
  };
};

const findOwnedBook = async (bookId, user, deniedMessage) => {
  const book = await prisma.books.findUnique({ where: { book_id: bookId } });
  if (!book) throw notFound('找不到該書籍');
  if (book.seller_id !== user.userId && user.role !== 'admin') throw forbidden(deniedMessage);
  return book;
};

// 已違規下架的書不可轉為待審核：待審核不算違規鎖定，會讓賣家得以自行重新上架。
const reviewPlan = async (book, decision) => {
  if (decision.action === 'allow' && !decision.provider) return null;
  const current = book.is_approved === false ? await reviews.statusOf(book.book_id) : null;
  if (decision.action === 'review') {
    if (book.is_approved !== false || current === 'pending') return { hold: true, notify: current !== 'pending' };
    return null;
  }
  return current === 'pending' ? { release: true } : null;
};

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

// 訂單已成立（reserved）或已完成（sold）的書，內容與照片必須維持買家下單時的樣子。
const assertEditable = (book, user) => {
  if (user.role === 'admin' || !['reserved', 'sold'].includes(book.status)) return;
  throw conflict(book.status === 'sold' ? '此書籍已完成交易，無法編輯' : '此書籍已售出，無法編輯', 'BOOK_LOCKED');
};

// 存放於書櫃中的書，內容須與櫃內實體書一致；只改狀態（重新上架）不在此限，另由存書流程把關。
const assertNotStored = async (book, user, data) => {
  if (user.role === 'admin' || !Object.keys(data).some((k) => k !== 'status')) return;
  if (await deposits.rowOf(book.book_id)) {
    throw conflict('此書籍存放於書櫃中，無法編輯；如需修改，請先至書櫃取回書籍', 'BOOK_DEPOSITED');
  }
};

const allowedStatuses = (user) => (user.role === 'admin' ? BOOK_STATUSES : SELLER_STATUSES);

const booksAdmin = () => require('./books-admin');

const soldTakedown = () => conflict('此書籍已完成交易，無法下架', 'BOOK_LOCKED');

const update = async (bookId, user, data, { req = null } = {}) => {
  const isAdmin = user.role === 'admin';
  const book = await findOwnedBook(bookId, user, '無權限修改此書籍');
  if (!isAdmin) await reservations.assertNotHeld(bookId);

  // 管理員下架與後台強制下架同一流程（鎖定、取消訂單與預約），不可只改狀態等排程處理。
  const adminTakedown = isAdmin && data.status === 'removed' && book.status !== 'removed';
  if (adminTakedown) {
    if (book.status === 'sold') throw soldTakedown();
    data.status = undefined;
  }

  if (data.status === 'on_sale' && book.status !== 'on_sale') {
    if (!isAdmin) {
      if (await violationLocked(book)) throw forbidden('此書籍因違規遭下架，無法自行重新上架，請聯絡客服', 'BOOK_NOT_APPROVED');
      await deposits.assertRelistable(bookId);
    }
    await takedown.assertNoOpenOrder(prisma, bookId);
  }
  const relist = isAdmin && data.status === 'on_sale';
  if (relist) data.is_approved = true;
  const adminStatus = isAdmin && data.status !== undefined;

  // 保留中的書已有人付款，改回上架會被第二人買走。
  if (data.status && data.status !== book.status && ['reserved', 'sold'].includes(book.status) && !isAdmin) {
    throw conflict(book.status === 'sold' ? '此書籍已完成交易，無法變更狀態' : '此書籍已售出（訂單進行中），無法變更狀態');
  }

  assertEditable(book, user);
  await assertNotStored(book, user, data);

  if (data.cabinet_id !== undefined && data.cabinet_id !== book.cabinet_id) await deposits.assertCabinetUnchanged(bookId);
  await assertRefsExist({ categoryId: data.category_id, cabinetId: data.cabinet_id }, book);

  const changed = (field) => data[field] !== undefined && data[field] !== book[field];
  const enrichPlan = enrichment.editPlan(book, data);
  let plan = null;
  let decision = null;
  let rules = null;
  const textChanged = MODERATED_FIELDS.some(changed);
  if (!isAdmin && (textChanged || (data.price !== undefined && Number(data.price) !== Number(book.price)))) {
    const merged = Object.fromEntries(Object.keys(book).map((k) => [k, data[k] !== undefined ? data[k] : book[k]]));
    rules = await screening.ruleDecision(merged);
    decision = rules.decision;
    if (!decision && textChanged) {
      decision = await moderation.screen({
        userId: user.userId,
        book: merged,
        hint: rules.hint,
        peer: rules.peer,
        loadImages: (max) => screening.storedImages(bookId, max),
        interactive: true
      });
    }
  }
  if (decision) {
    moderation.assertNotRejected(decision);
    plan = await reviewPlan(book, decision);
    if (plan?.hold) data.is_approved = false;
    if (plan?.release) data.is_approved = true;
  }

  await enrichment.clearAutoFields(bookId, data, enrichPlan);

  const write = async (db) => db.books.update({
    where: { book_id: bookId },
    data: { ...data, updated_at: new Date() }
  });
  let updatedBook = plan || adminStatus
    ? await prisma.$transaction(async (tx) => {
        const row = await write(tx);
        if (adminStatus) await deposits.syncAdminStatus(tx, bookId, data.status);
        if (plan?.hold) await reviews.hold(tx, { bookId, decision, actor: 'seller_edit' });
        if (plan?.hold && plan.notify) {
          await reviews.notifyHeld(tx, row);
          await screening.notifyAdmins(tx, row, decision.reasons);
        }
        if (plan?.release) await reviews.settle(tx, bookId);
        if (relist) await reviews.settle(tx, bookId, user.userId);
        return row;
      })
    : await write(prisma);

  if (decision) await markSafely(bookId, decision);
  if (plan?.hold && decision.model === 'rules') {
    screening.screenLater(updatedBook, [], { hint: rules.hint, peer: rules.peer, held: true });
  }

  enrichment.afterEdit(bookId, enrichPlan);

  if (adminTakedown) {
    await booksAdmin().setStatus(bookId, 'removed', null, { adminId: user.userId, req });
    updatedBook = await prisma.books.findUnique({ where: { book_id: bookId } });
  }

  if (!reservations.isListed(book) && reservations.isListed(updatedBook)) {
    await reservations.notifyRelisted(null, bookId).catch((err) => console.error('[重新上架通知失敗]:', err.message));
  }

  const oldPrice = Number(book.price);
  if (data.price !== undefined && data.price < oldPrice && updatedBook.status === 'on_sale') {
    notifyPriceDrop(updatedBook, oldPrice).catch((err) => console.error('[降價通知失敗]:', err.message));
  }
  if (updatedBook.seller_id === user.userId) {
    const shaped = await deposits.decorate(await reviews.withReviewStatus(updatedBook), { owner: true });
    return { book: shaped, moderation: plan?.hold ? pendingReview(decision) : null };
  }
  return { book: updatedBook, moderation: null };
};

const remove = async (bookId, user, { req = null } = {}) => {
  const book = await findOwnedBook(bookId, user, '無權限刪除此書籍');
  if (book.status === 'sold') {
    throw user.role === 'admin' ? soldTakedown() : conflict('此書籍已完成交易，無法取消上架', 'BOOK_LOCKED');
  }
  if (user.role === 'admin') return booksAdmin().setStatus(bookId, 'removed', null, { adminId: user.userId, req });
  await reservations.assertNotHeld(bookId);

  if (book.status === 'reserved') throw conflict('此書籍已售出（訂單進行中），請先處理訂單再取消上架');

  await prisma.books.update({
    where: { book_id: bookId },
    data: { status: 'removed', updated_at: new Date() }
  });
};

const addImages = async (bookId, user, images, { files = [] } = {}) => {
  const book = await findOwnedBook(bookId, user, '無權限修改此書籍');
  assertEditable(book, user);
  await assertNotStored(book, user, { images });
  if (user.role !== 'admin') await reservations.assertNotHeld(bookId);
  if (images.length === 0) throw badRequest('請選擇要上傳的圖片');

  const existing = await prisma.book_images.count({ where: { book_id: bookId } });
  if (existing + images.length > MAX_IMAGES_PER_BOOK) {
    throw badRequest(`每本書最多 ${MAX_IMAGES_PER_BOOK} 張照片，目前已有 ${existing} 張`);
  }

  let plan = null;
  let decision = null;
  if (user.role !== 'admin') {
    decision = await moderation.screen({
      userId: user.userId,
      book,
      hint: screening.sourceHint(book),
      loadImages: (max) => aiImages.fromUploads(files, max),
      interactive: true
    });
    moderation.assertNotRejected(decision);
    plan = decision.action === 'review' ? await reviewPlan(book, decision) : null;
  }

  const insert = (db) => db.book_images.createMany({
    data: images.map((img) => ({ book_id: bookId, ...img }))
  });
  if (plan?.hold) {
    await prisma.$transaction(async (tx) => {
      await insert(tx);
      await tx.books.update({ where: { book_id: bookId }, data: { is_approved: false, updated_at: new Date() } });
      await reviews.hold(tx, { bookId, decision, actor: 'seller_edit' });
      if (plan.notify) {
        await reviews.notifyHeld(tx, book);
        await screening.notifyAdmins(tx, book, decision.reasons);
      }
    });
  } else {
    await insert(prisma);
  }
  if (decision) await markSafely(bookId, decision, { partial: true });

  const rows = await prisma.book_images.findMany({ where: { book_id: bookId } });
  return { images: rows, moderation: plan?.hold ? pendingReview(decision) : null };
};

const removeImage = async (bookId, imageId, user) => {
  const book = await findOwnedBook(bookId, user, '無權限修改此書籍');
  assertEditable(book, user);
  await assertNotStored(book, user, { imageId });
  if (user.role !== 'admin') await reservations.assertNotHeld(bookId);

  const result = await prisma.book_images.deleteMany({ where: { image_id: imageId, book_id: bookId } });
  if (result.count === 0) throw notFound('找不到該圖片');
};

module.exports = {
  SORTS, listInclude, allowedStatuses, lookupIsbn, list, recommended, similar, briefs, inIdOrder, findByShareToken, shareLink, detail, create,
  update, remove, addImages, removeImage
};
