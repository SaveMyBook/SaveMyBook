const express = require('express');
const prisma = require('../lib/prisma');
const authenticateToken = require('../middleware/auth');

const router = express.Router();

const requireAdmin = (req, res, next) => {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ success: false, message: '權限不足，僅限管理員執行此操作' });
  }
  next();
};

router.get('/', async (req, res) => {
  const { flat } = req.query;

  try {
    if (flat === 'true') {
      const categories = await prisma.book_categories.findMany({
        orderBy: [{ parent_id: 'asc' }, { sort_order: 'asc' }]
      });
      return res.status(200).json({ success: true, data: categories });
    }

    const categoryTree = await prisma.book_categories.findMany({
      where: { parent_id: null },
      orderBy: { sort_order: 'asc' },
      include: {
        other_book_categories: {
          orderBy: { sort_order: 'asc' }
        }
      }
    });

    res.status(200).json({ success: true, data: categoryTree });
  } catch (err) {
    console.error('Error fetching categories:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.get('/:id', async (req, res) => {
  const categoryId = parseInt(req.params.id);

  try {
    const category = await prisma.book_categories.findUnique({
      where: { category_id: categoryId },
      include: {
        other_book_categories: true
      }
    });
    
    if (!category) {
      return res.status(404).json({ success: false, message: '找不到該分類' });
    }
    
    res.status(200).json({ success: true, data: category });
  } catch (err) {
    console.error(`Error fetching category with ID ${req.params.id}:`, err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.post('/', authenticateToken, requireAdmin, async (req, res) => {
  const { category_name, parent_id, sort_order = 0 } = req.body;
  
  if (!category_name) {
    return res.status(400).json({ success: false, message: '缺少必要欄位：分類名稱(category_name)' });
  }

  try {
    const newCategory = await prisma.book_categories.create({
      data: {
        category_name,
        parent_id: parent_id ? parseInt(parent_id) : null,
        sort_order: parseInt(sort_order)
      }
    });
    
    res.status(201).json({ success: true, message: '分類建立成功', data: newCategory });
  } catch (err) {
    console.error('Error creating category:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.put('/:id', authenticateToken, requireAdmin, async (req, res) => {
  const categoryId = parseInt(req.params.id);
  const { category_name, parent_id, sort_order } = req.body;

  if (parent_id === categoryId) {
    return res.status(400).json({ success: false, message: '父分類不能設定為自己' });
  }

  try {
    const targetCategory = await prisma.book_categories.findUnique({
      where: { category_id: categoryId }
    });

    if (!targetCategory) {
      return res.status(404).json({ success: false, message: '找不到該分類' });
    }

    const updatedCategory = await prisma.book_categories.update({
      where: { category_id: categoryId },
      data: { 
        category_name,
        parent_id: parent_id !== undefined ? (parent_id ? parseInt(parent_id) : null) : undefined,
        sort_order: sort_order !== undefined ? parseInt(sort_order) : undefined
      }
    });
    
    res.status(200).json({ success: true, message: '分類更新成功', data: updatedCategory });
  } catch (err) {
    console.error(`Error updating category with ID ${categoryId}:`, err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.delete('/:id', authenticateToken, requireAdmin, async (req, res) => {
  const categoryId = parseInt(req.params.id);
  
  try {
    await prisma.book_categories.delete({
      where: { category_id: categoryId }
    });
    
    res.status(200).json({ success: true, message: '分類已成功刪除' });
  } catch (err) {
    console.error(`Error deleting category with ID ${categoryId}:`, err);
    if (err.code === 'P2003') {
      return res.status(400).json({ 
        success: false, 
        message: '無法刪除！此分類下可能還有子分類或書籍，請先轉移或刪除關聯資料' 
      });
    }
    if (err.code === 'P2025') {
      return res.status(404).json({ success: false, message: '找不到該分類' });
    }
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

module.exports = router;