const express = require('express');
const authenticateToken = require('../middleware/auth');
const requireAdmin = require('../middleware/requireAdmin');
const v = require('../lib/validate');
const { actorOf } = require('../lib/request-context');
const { badRequest } = require('../lib/errors');
const categories = require('../services/categories');

const router = express.Router();

const canManage = [authenticateToken, requireAdmin('content')];

const categoryName = (value) => {
  const name = v.text(value, { label: '分類名稱', max: 50 });
  if (!name) throw badRequest('缺少必要欄位：分類名稱(category_name)');
  return name;
};

router.get('/', async (req, res) => {
  const data = req.query.flat === 'true' ? await categories.flat() : await categories.tree();
  res.status(200).json({ success: true, data });
});

router.get('/:id', async (req, res) => {
  const category = await categories.detail(v.id(req.params.id, '分類編號'));
  res.status(200).json({ success: true, data: category });
});

router.post('/', ...canManage, async (req, res) => {
  const data = {
    category_name: categoryName(req.body.category_name),
    parent_id: v.optionalId(req.body.parent_id, '父分類編號'),
    sort_order: req.body.sort_order === undefined ? 0 : v.int(req.body.sort_order, { label: '排序', min: 0, max: 100000 })
  };

  const newCategory = await categories.create(data, actorOf(req));
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

  const updatedCategory = await categories.update(categoryId, data, actorOf(req));
  res.status(200).json({ success: true, message: '分類更新成功', data: updatedCategory });
});

router.delete('/:id', ...canManage, async (req, res) => {
  await categories.remove(v.id(req.params.id, '分類編號'), actorOf(req));
  res.status(200).json({ success: true, message: '分類已成功刪除' });
});

module.exports = router;
