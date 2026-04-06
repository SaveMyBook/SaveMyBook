const express = require('express');
const prisma = require('../lib/prisma');
const authenticateToken = require('../middleware/auth');

const router = express.Router();

router.get('/', async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const skip = (page - 1) * limit;
    
    const keyword = req.query.keyword || '';
    const status = req.query.status || 'on_sale'; 
    const sort = req.query.sort || 'newest';
    
    let categoryIdsArray = [];
    if (req.query.category_ids) {
      categoryIdsArray = req.query.category_ids.split(',').map(id => parseInt(id)).filter(id => !isNaN(id));
    }

    const whereCondition = {
      status: status,
      is_approved: true,
      ...(categoryIdsArray.length > 0 && { category_id: { in: categoryIdsArray } }),
      ...(keyword && {
        OR: [
          { title: { contains: keyword } },
          { author: { contains: keyword } },
          { publisher: { contains: keyword } }
        ]
      })
    };

    let orderByCondition = { created_at: 'desc' };
    switch (sort) {
      case 'price_asc':
        orderByCondition = { price: 'asc' };
        break;
      case 'price_desc':
        orderByCondition = { price: 'desc' };
        break;
      case 'popular':
        orderByCondition = { view_count: 'desc' };
        break;
      case 'newest':
      default:
        orderByCondition = { created_at: 'desc' };
        break;
    }

    const [books, totalCount] = await Promise.all([
      prisma.books.findMany({
        where: whereCondition,
        skip: skip,
        take: limit,
        orderBy: orderByCondition,
        include: {
          users: { select: { nickname: true, avatar_url: true } },
          book_images: { select: { image_url: true, image_type: true } }, 
          book_categories: { select: { category_name: true } }
        }
      }),
      prisma.books.count({ where: whereCondition })
    ]);

    res.status(200).json({ 
      success: true, 
      pagination: {
        total: totalCount,
        page: page,
        limit: limit,
        total_pages: Math.ceil(totalCount / limit)
      },
      data: books 
    });
  } catch (err) {
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.get('/:id', async (req, res) => {
  const bookId = parseInt(req.params.id);

  try {
    const book = await prisma.books.findUnique({
      where: { book_id: bookId },
      include: {
        users: { select: { nickname: true, avatar_url: true, created_at: true } },
        book_images: true,
        book_categories: { select: { category_name: true } }
      }
    });
    
    if (!book) {
      return res.status(404).json({ success: false, message: '找不到該書籍' });
    }

    prisma.books.update({
      where: { book_id: bookId },
      data: { view_count: { increment: 1 } }
    }).catch(() => {});
    
    res.status(200).json({ success: true, data: book });
  } catch (err) {
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.post('/', authenticateToken, async (req, res) => {
  const { 
    title, author, publisher, publish_date, isbn, 
    category_id, price, quantity = 1, condition_level = 'good', 
    condition_note, description, cabinet_id 
  } = req.body;
  
  if (!title || price === undefined) {
    return res.status(400).json({ success: false, message: '缺少必要欄位：書名(title) 或 價格(price)' });
  }

  try {
    const newBook = await prisma.books.create({
      data: {
        title, author, publisher, publish_date, isbn,
        price: parseFloat(price),
        quantity: parseInt(quantity),
        condition_level, condition_note, description,
        category_id: category_id ? parseInt(category_id) : null,
        cabinet_id: cabinet_id ? parseInt(cabinet_id) : null,
        status: 'on_sale', is_approved: true, 
        seller_id: req.user.userId 
      }
    });
    res.status(201).json({ success: true, message: '書籍上架成功', data: newBook });
  } catch (err) {
    if (err.name === 'PrismaClientValidationError') {
      return res.status(400).json({ success: false, message: '提供的資料格式錯誤或包含無效的列舉值' });
    }
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.put('/:id', authenticateToken, async (req, res) => {
  const bookId = parseInt(req.params.id);
  const { 
    title, author, publisher, publish_date, isbn, 
    category_id, price, quantity, condition_level, 
    condition_note, description, cabinet_id, status 
  } = req.body;

  try {
    const targetBook = await prisma.books.findUnique({ where: { book_id: bookId } });

    if (!targetBook) {
      return res.status(404).json({ success: false, message: '找不到該書籍' });
    }

    if (targetBook.seller_id !== req.user.userId && req.user.role !== 'admin') {
      return res.status(403).json({ success: false, message: '存取被拒，您無權限修改他人的商品' });
    }

    const updatedBook = await prisma.books.update({
      where: { book_id: bookId },
      data: { 
        title, author, publisher, publish_date, isbn, 
        price: price !== undefined ? parseFloat(price) : undefined, 
        quantity: quantity !== undefined ? parseInt(quantity) : undefined,
        condition_level, condition_note, description,
        category_id: category_id !== undefined ? parseInt(category_id) : undefined,
        cabinet_id: cabinet_id !== undefined ? parseInt(cabinet_id) : undefined,
        status, updated_at: new Date()
      }
    });
    res.status(200).json({ success: true, message: '書籍資料更新成功', data: updatedBook });
  } catch (err) {
    if (err.name === 'PrismaClientValidationError') {
      return res.status(400).json({ success: false, message: '提供的資料格式錯誤或包含無效的值' });
    }
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.delete('/:id', authenticateToken, async (req, res) => {
  const bookId = parseInt(req.params.id);
  
  try {
    const targetBook = await prisma.books.findUnique({ where: { book_id: bookId } });

    if (!targetBook) {
      return res.status(404).json({ success: false, message: '找不到該書籍' });
    }

    if (targetBook.seller_id !== req.user.userId && req.user.role !== 'admin') {
      return res.status(403).json({ success: false, message: '存取被拒，您無權限刪除他人的書籍' });
    }

    await prisma.books.update({
      where: { book_id: bookId },
      data: { status: 'removed', updated_at: new Date() }
    });
    
    res.status(200).json({ success: true, message: '書籍已成功下架' });
  } catch (err) {
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

module.exports = router;