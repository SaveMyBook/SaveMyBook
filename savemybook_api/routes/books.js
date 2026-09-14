const express = require('express');
const prisma = require('../lib/prisma');
const authenticateToken = require('../middleware/auth');
const { rateLimit, byUser } = require('../middleware/rateLimit');
const v = require('../lib/validate');
const { imageUpload } = require('../lib/upload');
const { publicBase } = require('../lib/public-url');
const { env } = require('../config/env');
const { badRequest, forbidden, notFound, conflict, HttpError } = require('../lib/errors');
const { BOOK_STATUSES, CONDITION_LEVELS } = require('../constants/domain');
const { ensureBookToken } = require('../services/share');
const { peekUserId } = require('../middleware/auth');
const ranking = require('../services/ranking');
const reservations = require('../services/reservations');
const { notifyMany } = require('../services/notify');

const router = express.Router();

const photos = imageUpload({ folder: 'books', maxFileSize: 10 * 1024 * 1024 });

const MAX_PRICE = 99999;
const SORTS = {
  newest: { created_at: 'desc' },
  price_asc: { price: 'asc' },
  price_desc: { price: 'desc' },
  popular: { view_count: 'desc' }
};

const cabinetSelect = {
  cabinet_id: true, cabinet_name: true, address: true, open_time: true, close_time: true, latitude: true, longitude: true
};

const isbnLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 30,
  key: byUser,
  message: '查詢過於頻繁，請稍後再試'
});

const price = (value) => {
  const n = Number(value);
  if (!Number.isFinite(n) || n <= 0) throw badRequest('售價必須大於 0 元');
  if (n > MAX_PRICE) throw badRequest(`售價不可超過 ${MAX_PRICE} 元`);
  return n;
};

// 不強制 10/13 碼：既有資料含 12 碼 UPC，太嚴格會讓舊書無法編輯。
const isbn = (value) => {
  const s = v.optionalText(value, { label: 'ISBN', max: 20 });
  if (s == null) return s;
  const digits = s.replace(/[-\s]/g, '');
  if (!/^[\dXx]{1,13}$/.test(digits)) throw badRequest('ISBN 只能包含數字，且不超過 13 碼');
  return digits.toUpperCase();
};

const publishDate = (value) => {
  const s = v.optionalText(value, { label: '出版日期', max: 20 });
  if (s == null) return s;
  return s.replace(/-+$/, '') || null;
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

const findOwnedBook = async (bookId, user, deniedMessage) => {
  const book = await prisma.books.findUnique({ where: { book_id: bookId } });
  if (!book) throw notFound('找不到該書籍');
  if (book.seller_id !== user.userId && user.role !== 'admin') throw forbidden(deniedMessage);
  return book;
};

router.get('/isbn/:isbn', authenticateToken, isbnLimiter, async (req, res) => {
  const code = String(req.params.isbn || '').replace(/[-\s]/g, '');
  if (!/^(\d{9}[\dXx]|\d{13})$/.test(code)) throw badRequest('ISBN 必須是 10 或 13 碼');

  const url = new URL('https://www.googleapis.com/books/v1/volumes');
  url.searchParams.set('q', `isbn:${code}`);
  url.searchParams.set('printType', 'books');
  url.searchParams.set('projection', 'lite');
  if (env.googleBooksApiKey) url.searchParams.set('key', env.googleBooksApiKey);

  let data;
  try {
    const response = await fetch(url, { signal: AbortSignal.timeout(8000) });
    if (!response.ok) throw new Error(`Google Books HTTP ${response.status}`);
    data = await response.json();
  } catch (err) {
    console.error('[查詢 ISBN 失敗]:', err.message);
    throw new HttpError(502, '查詢外部書籍資訊發生錯誤');
  }

  const info = data?.items?.[0]?.volumeInfo;
  if (!info) throw notFound('外部書庫找不到此 ISBN 的書籍資訊');

  res.status(200).json({
    success: true,
    data: {
      title: info.title || '',
      author: Array.isArray(info.authors) ? info.authors.join(', ') : '',
      publisher: info.publisher || '',
      publish_date: info.publishedDate || '',
      description: info.description || ''
    }
  });
});

router.get('/', async (req, res) => {
  const { page, limit, skip } = v.pagination(req.query);
  const keyword = v.text(req.query.keyword, { label: '關鍵字', max: 100 });
  const status = req.query.status || 'on_sale';
  const sort = SORTS[req.query.sort] ? req.query.sort : 'newest';
  const sellerId = v.optionalId(req.query.seller_id, '賣家編號');

  if (status !== 'all') v.oneOf(status, BOOK_STATUSES, '不支援的書籍狀態');

  const categoryIds = typeof req.query.category_ids === 'string'
    ? req.query.category_ids.split(',').map(v.toInt).filter((n) => Number.isSafeInteger(n) && n > 0).slice(0, 50)
    : [];

  const where = {
    ...(status !== 'all' && { status }),
    ...(sellerId ? { seller_id: sellerId } : { is_approved: true }),
    ...(categoryIds.length > 0 && { category_id: { in: categoryIds } }),
    ...(keyword && {
      OR: [
        { title: { contains: keyword } },
        { author: { contains: keyword } },
        { publisher: { contains: keyword } }
      ]
    })
  };

  const include = {
    users: { select: { user_id: true, nickname: true, avatar_url: true } },
    book_images: { select: { image_id: true, image_url: true, image_type: true } },
    book_categories: { select: { category_name: true } },
    smart_cabinets: { select: cabinetSelect }
  };

  if (sort === 'popular' && !sellerId) {
    const ranked = await ranking.rankedIds(where, peekUserId(req));
    const pageIds = ranked.slice(skip, skip + limit);
    const rows = pageIds.length > 0
      ? await prisma.books.findMany({ where: { book_id: { in: pageIds } }, include })
      : [];
    const byId = new Map(rows.map((b) => [b.book_id, b]));
    const books = pageIds.map((bookId) => byId.get(bookId)).filter(Boolean);
    return res.status(200).json({
      success: true,
      pagination: v.pageMeta(ranked.length, { page, limit }),
      data: books
    });
  }

  const [books, total] = await Promise.all([
    prisma.books.findMany({ where, skip, take: limit, orderBy: SORTS[sort], include }),
    prisma.books.count({ where })
  ]);

  res.status(200).json({ success: true, pagination: v.pageMeta(total, { page, limit }), data: books });
});

router.get('/:id/share-link', async (req, res) => {
  const bookId = v.id(req.params.id, '書籍編號');

  const book = await prisma.books.findUnique({
    where: { book_id: bookId },
    select: { book_id: true, title: true, status: true }
  });
  if (!book) throw notFound('找不到此書籍');

  if (book.status === 'removed') throw conflict('此書籍已下架，無法分享');

  const token = await ensureBookToken(bookId);
  res.status(200).json({
    success: true,
    data: { url: `${publicBase(req)}/b/${token}`, title: book.title }
  });
});

router.get('/:id', async (req, res) => {
  const bookId = v.id(req.params.id, '書籍編號');

  const book = await prisma.books.findUnique({
    where: { book_id: bookId },
    include: {
      users: { select: { user_id: true, nickname: true, avatar_url: true, created_at: true } },
      book_images: true,
      book_categories: { select: { category_name: true } },
      smart_cabinets: { select: cabinetSelect }
    }
  });
  if (!book) throw notFound('找不到該書籍');

  const viewerId = peekUserId(req);
  if (viewerId !== book.seller_id && ranking.shouldCountView(bookId, viewerId ?? req.ip)) {
    prisma.books.update({ where: { book_id: bookId }, data: { view_count: { increment: 1 } } }).catch(() => {});
  }
  const hold = await reservations.holdForViewer(bookId, viewerId);
  res.status(200).json({ success: true, data: { ...book, reservation: hold } });
});

const IMAGE_FIELDS = [
  { name: 'cover_image', maxCount: 1, type: 'cover' },
  { name: 'back_image', maxCount: 1, type: 'back' },
  { name: 'barcode_image', maxCount: 1, type: 'other' },
  { name: 'optional_images', maxCount: 7, type: 'inside' }
];

router.post('/', authenticateToken, ...photos.fields(IMAGE_FIELDS.map(({ name, maxCount }) => ({ name, maxCount }))),
  async (req, res) => {
    const body = req.body;

    const title = v.text(body.title, { label: '書名', max: 255 });
    if (!title || body.price === undefined) {
      throw badRequest('缺少必要欄位：書名(title) 或 價格(price)');
    }

    const data = {
      title,
      author: v.optionalText(body.author, { label: '作者', max: 255 }) ?? null,
      publisher: v.optionalText(body.publisher, { label: '出版社', max: 255 }) ?? null,
      publish_date: publishDate(body.publish_date) ?? null,
      isbn: isbn(body.isbn) ?? null,
      description: v.optionalText(body.description, { label: '書籍描述', max: 5000 }) ?? null,
      price: price(body.price),
      quantity: 1,
      condition_level: body.condition_level
        ? v.oneOf(body.condition_level, CONDITION_LEVELS, '不支援的書況')
        : 'good',
      category_id: v.optionalId(body.category_id, '分類編號'),
      cabinet_id: v.optionalId(body.cabinet_id, '書櫃編號'),
      status: 'on_sale',
      is_approved: true,
      seller_id: req.user.userId
    };

    await assertRefsExist({ categoryId: data.category_id, cabinetId: data.cabinet_id });

    const images = IMAGE_FIELDS.flatMap(({ name, type }) =>
      (req.files?.[name] ?? []).map((f) => ({ image_url: photos.urlOf(f), image_type: type })));

    const newBook = await prisma.$transaction(async (tx) => {
      const created = await tx.books.create({ data });
      if (images.length > 0) {
        await tx.book_images.createMany({
          data: images.map((img) => ({ ...img, book_id: created.book_id }))
        });
      }
      return created;
    });

    res.status(201).json({ success: true, message: '書籍上架成功', data: newBook });
  });

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

const SELLER_STATUSES = ['on_sale', 'removed'];

router.put('/:id', authenticateToken, async (req, res) => {
  const bookId = v.id(req.params.id, '書籍編號');
  const body = req.body;
  const isAdmin = req.user.role === 'admin';

  const data = {
    title: body.title === undefined ? undefined : v.text(body.title, { label: '書名', max: 255 }),
    author: v.optionalText(body.author, { label: '作者', max: 255 }),
    publisher: v.optionalText(body.publisher, { label: '出版社', max: 255 }),
    publish_date: publishDate(body.publish_date),
    isbn: isbn(body.isbn),
    price: body.price === undefined ? undefined : price(body.price),
    quantity: body.quantity === undefined ? undefined : v.int(body.quantity, { label: '數量', min: 1, max: 999 }),
    condition_level: body.condition_level === undefined
      ? undefined
      : v.oneOf(body.condition_level, CONDITION_LEVELS, '不支援的書況'),
    condition_note: v.optionalText(body.condition_note, { label: '書況說明', max: 2000 }),
    description: v.optionalText(body.description, { label: '書籍描述', max: 5000 }),
    category_id: body.category_id === undefined ? undefined : v.optionalId(body.category_id, '分類編號'),
    cabinet_id: body.cabinet_id === undefined ? undefined : v.optionalId(body.cabinet_id, '書櫃編號'),
    status: body.status === undefined ? undefined : v.oneOf(body.status, isAdmin ? BOOK_STATUSES : SELLER_STATUSES, '不支援的書籍狀態')
  };
  if (data.title === '') throw badRequest('書名不可為空');

  const book = await findOwnedBook(bookId, req.user, '存取被拒，您無權限修改他人的商品');

  // 檢舉成立的書 is_approved=false，賣家不可自行重新上架。
  if (data.status === 'on_sale' && book.is_approved === false && !isAdmin) {
    throw forbidden('此書籍因違規遭下架，無法自行重新上架，請聯絡客服', 'BOOK_NOT_APPROVED');
  }

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

  res.status(200).json({ success: true, message: '書籍資料更新成功', data: updatedBook });
});

router.delete('/:id', authenticateToken, async (req, res) => {
  const bookId = v.id(req.params.id, '書籍編號');
  const book = await findOwnedBook(bookId, req.user, '存取被拒，您無權限刪除他人的書籍');

  if (book.status === 'reserved') throw conflict('此書籍交易中，請先處理訂單再下架');

  await prisma.books.update({
    where: { book_id: bookId },
    data: { status: 'removed', updated_at: new Date() }
  });
  res.status(200).json({ success: true, message: '書籍已成功下架' });
});

const MAX_IMAGES_PER_BOOK = 10;
const IMAGE_TYPES = ['cover', 'back', 'inside', 'other'];

router.post('/:id/images', authenticateToken, ...photos.array('images', 8), async (req, res) => {
  const bookId = v.id(req.params.id, '書籍編號');
  await findOwnedBook(bookId, req.user, '存取被拒，您無權限修改他人的商品');
  if (!req.files || req.files.length === 0) throw badRequest('請選擇要上傳的圖片');

  const existing = await prisma.book_images.count({ where: { book_id: bookId } });
  if (existing + req.files.length > MAX_IMAGES_PER_BOOK) {
    throw badRequest(`每本書最多 ${MAX_IMAGES_PER_BOOK} 張照片，目前已有 ${existing} 張`);
  }

  const types = typeof req.body.image_types === 'string' ? req.body.image_types.split(',') : [];
  const typeAt = (i) => (IMAGE_TYPES.includes(types[i]) ? types[i] : 'other');
  await prisma.book_images.createMany({
    data: req.files.map((f, i) => ({ book_id: bookId, image_url: photos.urlOf(f), image_type: typeAt(i) }))
  });

  const images = await prisma.book_images.findMany({ where: { book_id: bookId } });
  res.status(201).json({ success: true, message: '圖片已新增', data: images });
});

router.delete('/:id/images/:imageId', authenticateToken, async (req, res) => {
  const bookId = v.id(req.params.id, '書籍編號');
  const imageId = v.id(req.params.imageId, '圖片編號');
  await findOwnedBook(bookId, req.user, '存取被拒，您無權限修改他人的商品');

  const result = await prisma.book_images.deleteMany({ where: { image_id: imageId, book_id: bookId } });
  if (result.count === 0) throw notFound('找不到該圖片');

  res.status(200).json({ success: true, message: '圖片已刪除' });
});

module.exports = router;
