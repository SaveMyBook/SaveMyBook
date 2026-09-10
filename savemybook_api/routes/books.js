const express = require('express');
const prisma = require('../lib/prisma');
const authenticateToken = require('../middleware/auth');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

const router = express.Router();

const uploadDir = path.join(__dirname, '../uploads/books');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, uploadDir);
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, uniqueSuffix + path.extname(file.originalname));
  }
});
const upload = multer({ storage: storage });

router.get('/isbn/:isbn', authenticateToken, async (req, res) => {
  const isbn = req.params.isbn;
  try {
    let apiUrl = `https://www.googleapis.com/books/v1/volumes?q=isbn:${isbn}&printType=books&projection=lite`;
    if (process.env.GOOGLE_BOOKS_API_KEY) {
      apiUrl += `&key=${process.env.GOOGLE_BOOKS_API_KEY}`;
    }
    const response = await fetch(apiUrl);
    const data = await response.json();

    if (data.items && data.items.length > 0) {
      const bookInfo = data.items[0].volumeInfo;
      return res.status(200).json({
        success: true,
        data: {
          title: bookInfo.title || '',
          author: bookInfo.authors ? bookInfo.authors.join(', ') : '',
          publisher: bookInfo.publisher || '',
          publish_date: bookInfo.publishedDate || '',
          description: bookInfo.description || '',
        }
      });
    } else {
      return res.status(404).json({ success: false, message: '外部書庫找不到此 ISBN 的書籍資訊' });
    }
  } catch (err) {
    res.status(500).json({ success: false, message: '查詢外部書籍資訊發生錯誤' });
  }
});

router.get('/', async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const skip = (page - 1) * limit;
    const keyword = req.query.keyword || '';
    const status = req.query.status || 'on_sale';
    const sort = req.query.sort || 'newest';
    const sellerId = req.query.seller_id ? parseInt(req.query.seller_id) : null;

    let categoryIdsArray = [];
    if (req.query.category_ids) {
      categoryIdsArray = req.query.category_ids.split(',').map(id => parseInt(id)).filter(id => !isNaN(id));
    }

    const whereCondition = {
      // 賣家在「書籍管理」要看得到全部狀態的書，因此 status=all 時不加狀態條件
      ...(status !== 'all' && { status: status }),
      // 查詢自己的書籍時不套用審核條件，避免待審核的書籍看不到
      ...(sellerId ? { seller_id: sellerId } : { is_approved: true }),
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
      case 'price_asc': orderByCondition = { price: 'asc' }; break;
      case 'price_desc': orderByCondition = { price: 'desc' }; break;
      case 'popular': orderByCondition = { view_count: 'desc' }; break;
      case 'newest': default: orderByCondition = { created_at: 'desc' }; break;
    }

    const [books, totalCount] = await Promise.all([
      prisma.books.findMany({
        where: whereCondition,
        skip: skip,
        take: limit,
        orderBy: orderByCondition,
        include: {
          users: { select: { user_id: true, nickname: true, avatar_url: true } },
          book_images: { select: { image_id: true, image_url: true, image_type: true } },
          book_categories: { select: { category_name: true } },
          smart_cabinets: { select: { cabinet_id: true, cabinet_name: true, address: true, open_time: true, close_time: true } }
        }
      }),
      prisma.books.count({ where: whereCondition })
    ]);

    res.status(200).json({
      success: true,
      pagination: { total: totalCount, page: page, limit: limit, total_pages: Math.ceil(totalCount / limit) },
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
        users: { select: { user_id: true, nickname: true, avatar_url: true, created_at: true } },
        book_images: true,
        book_categories: { select: { category_name: true } },
        smart_cabinets: { select: { cabinet_id: true, cabinet_name: true, address: true, open_time: true, close_time: true } }
      }
    });

    if (!book) return res.status(404).json({ success: false, message: '找不到該書籍' });

    prisma.books.update({ where: { book_id: bookId }, data: { view_count: { increment: 1 } } }).catch(() => {});
    res.status(200).json({ success: true, data: book });
  } catch (err) {
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.post('/', authenticateToken, upload.fields([
  { name: 'cover_image', maxCount: 1 },
  { name: 'back_image', maxCount: 1 },
  { name: 'barcode_image', maxCount: 1 },
  { name: 'optional_images', maxCount: 7 }
]), async (req, res) => {
  const {
    title, author, publisher, publish_date, isbn,
    category_id, price, condition_level, cabinet_id, description
  } = req.body;

  if (!title || price === undefined) {
    return res.status(400).json({ success: false, message: '缺少必要欄位：書名(title) 或 價格(price)' });
  }

  try {
    const cleanPrice = parseFloat(price);
    const cleanCategoryId = (category_id && category_id !== 'null') ? parseInt(category_id) : null;
    const cleanCabinetId = (cabinet_id && cabinet_id !== 'null') ? parseInt(cabinet_id) : null;

    let cleanDate = publish_date;
    if (cleanDate) {
      cleanDate = cleanDate.replace(/-+$/, '');
      if (cleanDate === '') cleanDate = null;
    }

    const newBook = await prisma.books.create({
      data: {
        title,
        author: author || null,
        publisher: publisher || null,
        publish_date: cleanDate || null,
        isbn: isbn || null,
        description: description || null,
        price: isNaN(cleanPrice) ? 0 : cleanPrice,
        quantity: 1,
        condition_level: condition_level || 'good',
        category_id: cleanCategoryId,
        cabinet_id: cleanCabinetId,
        status: 'on_sale',
        is_approved: true,
        seller_id: req.user.userId
      }
    });

    const imageRecords = [];
    if (req.files) {
      const processFile = (fileArray, type) => {
        if (fileArray && fileArray.length > 0) {
          fileArray.forEach(f => {
            imageRecords.push({
              book_id: newBook.book_id,
              image_url: `/uploads/books/${f.filename}`,
              image_type: type
            });
          });
        }
      };

      processFile(req.files['cover_image'], 'cover');
      processFile(req.files['back_image'], 'back');
      processFile(req.files['barcode_image'], 'other');
      processFile(req.files['optional_images'], 'inside');

      if (imageRecords.length > 0) {
        await prisma.book_images.createMany({ data: imageRecords });
      }
    }

    res.status(201).json({ success: true, message: '書籍上架成功', data: newBook });
  } catch (err) {
    console.error('[建立書籍失敗]:', err);
    res.status(500).json({ success: false, message: err.message || '資料庫寫入失敗' });
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
    if (!targetBook) return res.status(404).json({ success: false, message: '找不到該書籍' });
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
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.delete('/:id', authenticateToken, async (req, res) => {
  const bookId = parseInt(req.params.id);
  try {
    const targetBook = await prisma.books.findUnique({ where: { book_id: bookId } });
    if (!targetBook) return res.status(404).json({ success: false, message: '找不到該書籍' });
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

router.post('/:id/images', authenticateToken, upload.array('images', 8), async (req, res) => {
  const bookId = parseInt(req.params.id);
  try {
    const book = await prisma.books.findUnique({ where: { book_id: bookId } });
    if (!book) return res.status(404).json({ success: false, message: '找不到該書籍' });
    if (book.seller_id !== req.user.userId && req.user.role !== 'admin') {
      return res.status(403).json({ success: false, message: '存取被拒，您無權限修改他人的商品' });
    }
    if (!req.files || req.files.length === 0) {
      return res.status(400).json({ success: false, message: '請選擇要上傳的圖片' });
    }

    await prisma.book_images.createMany({
      data: req.files.map(f => ({
        book_id: bookId,
        image_url: `/uploads/books/${f.filename}`,
        image_type: 'other'
      }))
    });

    const images = await prisma.book_images.findMany({ where: { book_id: bookId } });
    res.status(201).json({ success: true, message: '圖片已新增', data: images });
  } catch (err) {
    console.error('[新增書籍圖片失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

router.delete('/:id/images/:imageId', authenticateToken, async (req, res) => {
  const bookId = parseInt(req.params.id);
  const imageId = parseInt(req.params.imageId);
  try {
    const book = await prisma.books.findUnique({ where: { book_id: bookId } });
    if (!book) return res.status(404).json({ success: false, message: '找不到該書籍' });
    if (book.seller_id !== req.user.userId && req.user.role !== 'admin') {
      return res.status(403).json({ success: false, message: '存取被拒，您無權限修改他人的商品' });
    }

    const result = await prisma.book_images.deleteMany({ where: { image_id: imageId, book_id: bookId } });
    if (result.count === 0) return res.status(404).json({ success: false, message: '找不到該圖片' });

    res.status(200).json({ success: true, message: '圖片已刪除' });
  } catch (err) {
    console.error('[刪除書籍圖片失敗]:', err);
    res.status(500).json({ success: false, message: '伺服器發生錯誤' });
  }
});

module.exports = router;
