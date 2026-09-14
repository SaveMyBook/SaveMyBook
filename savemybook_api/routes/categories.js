const express = require('express');
const prisma = require('../lib/prisma');
const authenticateToken = require('../middleware/auth');
const requireAdmin = require('../middleware/requireAdmin');
const v = require('../lib/validate');
const { badRequest, notFound } = require('../lib/errors');
const audit = require('../services/audit');

const FIELDS = { category_name: '名稱', parent_id: '父分類編號', sort_order: '排序' };

const router = express.Router();

const canManage = [authenticateToken, requireAdmin('content')];

const categoryName = (value) => {
  const name = v.text(value, { label: '分類名稱', max: 50 });
  if (!name) throw badRequest('缺少必要欄位：分類名稱(category_name)');
  return name;
};

const assertParent = async (parentId, selfId) => {
  if (parentId == null) return;
  if (parentId === selfId) throw badRequest('父分類不能設定為自己');

  const seen = new Set([selfId]);
  let cursor = parentId;
  while (cursor != null) {
    if (seen.has(cursor)) throw badRequest('父分類不能是自己的子分類');
    seen.add(cursor);
    const row = await prisma.book_categories.findUnique({
      where: { category_id: cursor },
      select: { parent_id: true }
    });
    if (!row) throw badRequest('找不到指定的父分類');
    cursor = row.parent_id;
  }
};

router.get('/', async (req, res) => {
  if (req.query.flat === 'true') {
    const categories = await prisma.book_categories.findMany({
      orderBy: [{ parent_id: 'asc' }, { sort_order: 'asc' }]
    });
    return res.status(200).json({ success: true, data: categories });
  }

  const categoryTree = await prisma.book_categories.findMany({
    where: { parent_id: null },
    orderBy: { sort_order: 'asc' },
    include: { other_book_categories: { orderBy: { sort_order: 'asc' } } }
  });

  res.status(200).json({ success: true, data: categoryTree });
});

router.get('/:id', async (req, res) => {
  const category = await prisma.book_categories.findUnique({
    where: { category_id: v.id(req.params.id, '分類編號') },
    include: { other_book_categories: true }
  });
  if (!category) throw notFound('找不到該分類');

  res.status(200).json({ success: true, data: category });
});

router.post('/', ...canManage, async (req, res) => {
  const name = categoryName(req.body.category_name);
  const parentId = v.optionalId(req.body.parent_id, '父分類編號');
  const sortOrder = req.body.sort_order === undefined ? 0 : v.int(req.body.sort_order, { label: '排序', min: 0, max: 100000 });

  await assertParent(parentId, null);

  const newCategory = await prisma.book_categories.create({
    data: { category_name: name, parent_id: parentId, sort_order: sortOrder }
  });
  await audit.record(null, {
    adminId: req.user.userId,
    action: '新增分類',
    targetType: 'category',
    targetId: newCategory.category_id,
    summary: `新增了分類「${name}」`,
    undo: [audit.undoCreate('book_categories', newCategory.category_id)],
    req
  });
  res.status(201).json({ success: true, message: '分類建立成功', data: newCategory });
});

router.put('/:id', ...canManage, async (req, res) => {
  const categoryId = v.id(req.params.id, '分類編號');
  const body = req.body;

  const data = {
    category_name: body.category_name === undefined ? undefined : categoryName(body.category_name),
    parent_id: body.parent_id === undefined ? undefined : v.optionalId(body.parent_id, '父分類編號'),
    sort_order: body.sort_order === undefined ? undefined : v.int(body.sort_order, { label: '排序', min: 0, max: 100000 })
  };

  const before = await prisma.book_categories.findUnique({ where: { category_id: categoryId } });
  if (!before) throw notFound('找不到該分類');
  if (data.parent_id !== undefined) await assertParent(data.parent_id, categoryId);

  const updatedCategory = await prisma.book_categories.update({ where: { category_id: categoryId }, data });
  const changes = audit.diff(before, data, FIELDS);
  if (changes.length) {
    await audit.record(null, {
      adminId: req.user.userId,
      action: '編輯分類',
      targetType: 'category',
      targetId: categoryId,
      summary: `編輯了分類「${before.category_name}」`,
      changes,
      undo: [audit.undoUpdate('book_categories', categoryId, before, data, FIELDS)],
      req
    });
  }
  res.status(200).json({ success: true, message: '分類更新成功', data: updatedCategory });
});

router.delete('/:id', ...canManage, async (req, res) => {
  const categoryId = v.id(req.params.id, '分類編號');

  const before = await prisma.book_categories.findUnique({ where: { category_id: categoryId } });
  if (!before) throw notFound('找不到該分類');

  try {
    await prisma.book_categories.delete({ where: { category_id: categoryId } });
    await audit.record(null, {
      adminId: req.user.userId,
      action: '刪除分類',
      targetType: 'category',
      targetId: categoryId,
      summary: `刪除了分類「${before.category_name}」`,
      undo: [audit.undoDelete('book_categories', before)],
      req
    });
  } catch (err) {
    if (err.code === 'P2003') {
      throw badRequest('無法刪除！此分類下可能還有子分類或書籍，請先轉移或刪除關聯資料');
    }
    throw err;
  }
  res.status(200).json({ success: true, message: '分類已成功刪除' });
});

module.exports = router;
