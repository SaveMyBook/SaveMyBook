const express = require('express');
const requireAdmin = require('../../middleware/requireAdmin');
const v = require('../../lib/validate');
const { actorOf } = require('../../lib/request-context');
const { badRequest } = require('../../lib/errors');
const { BOOK_STATUSES, CONDITION_LEVELS } = require('../../constants/domain');
const booksAdmin = require('../../services/books-admin');
const categories = require('../../services/categories');

const router = express.Router();
const canManage = requireAdmin('content');

const MAX_PRICE = 999999;

router.get('/books', canManage, async (req, res) => {
  const keyword = v.text(req.query.keyword, { label: '關鍵字', max: 100 });
  const status = req.query.status;
  const { page, limit, skip } = v.pagination(req.query);

  if (status && status !== 'all') v.oneOf(status, BOOK_STATUSES, '不支援的書籍狀態');

  const { rows, total } = await booksAdmin.list({ keyword, status, skip, limit });
  res.status(200).json({ success: true, pagination: v.pageMeta(total, { page, limit }), data: rows });
});

router.put('/books/:id', canManage, async (req, res) => {
  const bookId = v.id(req.params.id, '書籍編號');
  const body = req.body;

  const title = v.optionalText(body.title, { label: '書名', max: 255 });
  if (title === null) throw badRequest('書名為必填，且不可超過 255 個字元');

  const price = body.price === undefined ? undefined : Number(body.price);
  if (price !== undefined && (!Number.isFinite(price) || price < 0 || price > MAX_PRICE)) {
    throw badRequest(`售價必須介於 0 ~ ${MAX_PRICE}`);
  }

  if (body.condition_level !== undefined) v.oneOf(body.condition_level, CONDITION_LEVELS, '不支援的書況');

  const isbn = v.optionalText(body.isbn, { label: 'ISBN', max: 13 });
  if (isbn && !/^\d{10}(\d{3})?$/.test(isbn)) throw badRequest('ISBN 必須是 10 或 13 位數字');

  const categoryId = body.category_id === undefined ? undefined : v.optionalId(body.category_id, '分類編號');

  const book = await booksAdmin.findOrThrow(bookId);
  await booksAdmin.assertCategoryExists(categoryId);

  const data = {
    ...(title !== undefined && { title }),
    ...(body.author !== undefined && { author: v.optionalText(body.author, { label: '作者', max: 255 }) }),
    ...(body.publisher !== undefined && { publisher: v.optionalText(body.publisher, { label: '出版社', max: 255 }) }),
    ...(body.publish_date !== undefined && { publish_date: v.optionalText(body.publish_date, { label: '出版日期', max: 20 }) }),
    ...(isbn !== undefined && { isbn }),
    ...(categoryId !== undefined && { category_id: categoryId }),
    ...(body.condition_level !== undefined && { condition_level: body.condition_level }),
    ...(body.condition_note !== undefined && { condition_note: v.optionalText(body.condition_note, { label: '書況說明', max: 2000 }) }),
    ...(price !== undefined && { price }),
    ...(body.description !== undefined && { description: v.optionalText(body.description, { label: '書籍描述', max: 5000 }) })
  };

  if (Object.keys(data).length === 0) throw badRequest('沒有需要修改的欄位');

  await booksAdmin.edit(bookId, book, data, actorOf(req));
  res.status(200).json({ success: true, message: '已更新' });
});

router.patch('/books/:id', canManage, async (req, res) => {
  const bookId = v.id(req.params.id, '書籍編號');
  const status = v.oneOf(req.body.status, ['on_sale', 'removed'], '僅可設定為上架或下架');
  const reason = v.optionalText(req.body.reason, { label: '原因', max: 500 }) ?? null;

  await booksAdmin.setStatus(bookId, status, reason, actorOf(req));
  res.status(200).json({ success: true, message: status === 'removed' ? '已下架' : '已恢復上架' });
});

router.delete('/books/:id', canManage, async (req, res) => {
  const bookId = v.id(req.params.id, '書籍編號');
  const reason = v.optionalText(req.body?.reason, { label: '原因', max: 200 }) ?? null;

  await booksAdmin.remove(bookId, reason, actorOf(req));
  res.status(200).json({ success: true, message: '已刪除書籍' });
});

const categoryName = (value) => {
  const name = v.text(value, { label: '分類名稱', max: 50 });
  if (!name) throw badRequest('請輸入分類名稱');
  return name;
};

const sortOrder = (value) => (v.isBlank(value) ? 0 : v.int(value, { label: '排序', min: 0, max: 100000 }));

router.get('/categories', canManage, async (req, res) => {
  res.status(200).json({ success: true, data: await categories.adminList() });
});

router.post('/categories', canManage, async (req, res) => {
  const data = { category_name: categoryName(req.body.category_name), sort_order: sortOrder(req.body.sort_order) };
  const created = await categories.create(data, actorOf(req));
  res.status(201).json({ success: true, data: { category_id: created.category_id } });
});

// 必須排在 /categories/:id 之前，否則 reorder 會被當成 id。
router.put('/categories/reorder', canManage, async (req, res) => {
  const ids = v.sortOrder(req.body.order, '請提供排序後的分類順序');
  await categories.reorder(ids, actorOf(req));
  res.status(200).json({ success: true, message: '已更新排序' });
});

router.put('/categories/:id', canManage, async (req, res) => {
  const categoryId = v.id(req.params.id, '分類編號');
  const name = categoryName(req.body.category_name);

  const before = await categories.findOrThrow(categoryId);
  const data = { category_name: name, sort_order: sortOrder(req.body.sort_order) };

  await categories.adminUpdate(categoryId, before, data, actorOf(req));
  res.status(200).json({ success: true, message: '已更新分類' });
});

router.delete('/categories/:id', canManage, async (req, res) => {
  await categories.adminRemove(v.id(req.params.id, '分類編號'), actorOf(req));
  res.status(200).json({ success: true, message: '已刪除分類' });
});

module.exports = router;
