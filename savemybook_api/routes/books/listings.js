const express = require('express');
const authenticateToken = require('../../middleware/auth');
const v = require('../../lib/validate');
const { imageUpload } = require('../../lib/upload');
const { badRequest } = require('../../lib/errors');
const { CONDITION_LEVELS } = require('../../constants/domain');
const books = require('../../services/books');

const router = express.Router();

const photos = imageUpload({ folder: 'books', maxFileSize: 10 * 1024 * 1024 });

const MAX_PRICE = 99999;
const IMAGE_TYPES = ['cover', 'back', 'inside', 'other'];

const IMAGE_FIELDS = [
  { name: 'cover_image', maxCount: 1, type: 'cover' },
  { name: 'back_image', maxCount: 1, type: 'back' },
  { name: 'barcode_image', maxCount: 1, type: 'other' },
  { name: 'optional_images', maxCount: 7, type: 'inside' }
];

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

    const images = IMAGE_FIELDS.flatMap(({ name, type }) =>
      (req.files?.[name] ?? []).map((f) => ({ image_url: photos.urlOf(f), image_type: type })));

    const files = IMAGE_FIELDS.flatMap(({ name }) => req.files?.[name] ?? []);
    const { book, moderation } = await books.create(data, images, { files });
    res.status(201).json({
      success: true,
      message: moderation ? '書籍已送交審核，審核通過後將公開販售' : '書籍上架成功',
      data: book,
      ...(moderation && { moderation })
    });
  });

router.put('/:id', authenticateToken, async (req, res) => {
  const bookId = v.id(req.params.id, '書籍編號');
  const body = req.body;

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
    status: body.status === undefined ? undefined : v.oneOf(body.status, books.allowedStatuses(req.user), '不支援的書籍狀態')
  };
  if (data.title === '') throw badRequest('書名不可為空');

  const { book, moderation } = await books.update(bookId, req.user, data);
  res.status(200).json({
    success: true,
    message: moderation ? '書籍資料已更新並送交審核，審核通過後將公開販售' : '書籍資料更新成功',
    data: book,
    ...(moderation && { moderation })
  });
});

router.delete('/:id', authenticateToken, async (req, res) => {
  await books.remove(v.id(req.params.id, '書籍編號'), req.user);
  res.status(200).json({ success: true, message: '書籍已成功下架' });
});

router.post('/:id/images', authenticateToken, ...photos.array('images', 8), async (req, res) => {
  const bookId = v.id(req.params.id, '書籍編號');
  const types = typeof req.body.image_types === 'string' ? req.body.image_types.split(',') : [];
  const typeAt = (i) => (IMAGE_TYPES.includes(types[i]) ? types[i] : 'other');
  const images = (req.files ?? []).map((f, i) => ({ image_url: photos.urlOf(f), image_type: typeAt(i) }));

  const { images: data, moderation } = await books.addImages(bookId, req.user, images, { files: req.files ?? [] });
  res.status(201).json({
    success: true,
    message: moderation ? '圖片已新增，書籍已送交審核' : '圖片已新增',
    data,
    ...(moderation && { moderation })
  });
});

router.delete('/:id/images/:imageId', authenticateToken, async (req, res) => {
  const bookId = v.id(req.params.id, '書籍編號');
  const imageId = v.id(req.params.imageId, '圖片編號');
  await books.removeImage(bookId, imageId, req.user);
  res.status(200).json({ success: true, message: '圖片已刪除' });
});

module.exports = router;
