const express = require('express');
const prisma = require('../../lib/prisma');
const requireAdmin = require('../../middleware/requireAdmin');
const v = require('../../lib/validate');
const { badRequest, notFound, conflict } = require('../../lib/errors');
const { BOOK_STATUSES, CONDITION_LEVELS } = require('../../constants/domain');
const { notify } = require('../../services/notify');
const audit = require('../../services/audit');

const router = express.Router();
const canManage = requireAdmin('content');

const MAX_PRICE = 999999;

const CONDITION_LABELS = { like_new: '近全新', good: '良好', fair: '普通', poor: '待修補' };
const BOOK_STATUS_LABELS = { on_sale: '上架中', reserved: '交易中', sold: '已售出', removed: '已下架' };

const BOOK_FIELDS = {
  title: '書名',
  author: '作者',
  publisher: '出版社',
  publish_date: '出版日期',
  isbn: 'ISBN',
  category_id: '分類編號',
  condition_level: { label: '書況', format: (v) => CONDITION_LABELS[v] ?? v },
  condition_note: '書況說明',
  price: { label: '售價', format: (v) => `${Number(v)} 代幣` },
  description: '書籍描述'
};

const BOOK_STATUS_FIELDS = {
  status: { label: '狀態', format: (v) => BOOK_STATUS_LABELS[v] ?? v },
  is_approved: { label: '審核通過', format: (v) => (v ? '是' : '否（違規）') }
};

router.get('/books', canManage, async (req, res) => {
  const keyword = v.text(req.query.keyword, { label: '關鍵字', max: 100 });
  const status = req.query.status;
  const { page, limit, skip } = v.pagination(req.query);

  if (status && status !== 'all') v.oneOf(status, BOOK_STATUSES, '不支援的書籍狀態');

  const where = {
    ...(status && status !== 'all' && { status }),
    ...(keyword && {
      OR: [
        { title: { contains: keyword } },
        { isbn: { contains: keyword } },
        { users: { nickname: { contains: keyword } } }
      ]
    })
  };

  const [books, total] = await Promise.all([
    prisma.books.findMany({
      where,
      include: {
        users: { select: { user_id: true, nickname: true, avatar_url: true } },
        book_categories: { select: { category_id: true, category_name: true } },
        book_images: { select: { image_url: true }, take: 1 }
      },
      orderBy: { created_at: 'desc' },
      skip,
      take: limit
    }),
    prisma.books.count({ where })
  ]);

  const reportRows = books.length
    ? await prisma.reports.groupBy({
        by: ['target_id'],
        where: { target_type: 'book', status: 'pending', target_id: { in: books.map((b) => b.book_id) } },
        _count: { target_id: true }
      })
    : [];
  const reportCounts = Object.fromEntries(reportRows.map((r) => [r.target_id, r._count.target_id]));

  res.status(200).json({
    success: true,
    pagination: v.pageMeta(total, { page, limit }),
    data: books.map((b) => ({
      book_id: b.book_id,
      pending_report_count: reportCounts[b.book_id] ?? 0,
      title: b.title,
      isbn: b.isbn,
      price: b.price,
      status: b.status,
      condition_level: b.condition_level,
      view_count: b.view_count,
      created_at: b.created_at,
      seller: b.users,
      category_id: b.category_id,
      category_name: b.book_categories?.category_name ?? '',
      image_url: b.book_images[0]?.image_url ?? null,
      // 編輯表單需要的欄位附在列表裡：GET /api/books/:id 每次呼叫都會增加瀏覽數。
      author: b.author,
      publisher: b.publisher,
      publish_date: b.publish_date,
      condition_note: b.condition_note,
      description: b.description
    }))
  });
});

router.put('/books/:id', canManage, async (req, res) => {
  const bookId = v.id(req.params.id, '書籍編號');
  const body = req.body;

  const title = v.optionalText(body.title, { label: '書名', max: 255 });
  if (title === null) throw badRequest('書名必填，且不能超過 255 個字元');

  const price = body.price === undefined ? undefined : Number(body.price);
  if (price !== undefined && (!Number.isFinite(price) || price < 0 || price > MAX_PRICE)) {
    throw badRequest(`售價必須介於 0 ~ ${MAX_PRICE}`);
  }

  if (body.condition_level !== undefined) v.oneOf(body.condition_level, CONDITION_LEVELS, '不支援的書況');

  const isbn = v.optionalText(body.isbn, { label: 'ISBN', max: 13 });
  if (isbn && !/^\d{10}(\d{3})?$/.test(isbn)) throw badRequest('ISBN 必須是 10 或 13 位數字');

  const categoryId = body.category_id === undefined ? undefined : v.optionalId(body.category_id, '分類編號');

  const book = await prisma.books.findUnique({ where: { book_id: bookId } });
  if (!book) throw notFound('找不到這本書');

  if (categoryId) {
    const exists = await prisma.book_categories.count({ where: { category_id: categoryId } });
    if (!exists) throw badRequest('找不到這個分類');
  }

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

  if (Object.keys(data).length === 0) throw badRequest('沒有要修改的欄位');

  const changes = [];
  if (title !== undefined && title !== book.title) changes.push(`書名改為《${title}》`);
  if (price !== undefined && price !== Number(book.price)) changes.push(`售價改為 ${price.toFixed(0)} 代幣`);

  await prisma.$transaction(async (tx) => {
    await tx.books.update({ where: { book_id: bookId }, data: { ...data, updated_at: new Date() } });
    await notify(tx, {
      userId: book.seller_id,
      title: '書籍資料已由客服更新',
      content: changes.length
        ? `《${book.title}》：${changes.join('，')}。如有疑問請聯絡客服。`
        : `《${book.title}》的商品資料已由客服協助更正。如有疑問請聯絡客服。`,
      relatedId: bookId,
      relatedType: 'book'
    });
  });

  const logged = audit.diff(book, data, BOOK_FIELDS);
  await audit.record(null, {
    adminId: req.user.userId,
    action: '修改書籍資料',
    targetType: 'book',
    targetId: bookId,
    summary: logged.length
      ? `修改了《${book.title}》的${logged.map((c) => c.label).join('、')}，並通知賣家`
      : `重新儲存了《${book.title}》（沒有實際變動）`,
    changes: logged,
    undo: logged.length ? [audit.undoUpdate('books', bookId, book, data, BOOK_FIELDS)] : null,
    req
  });

  res.status(200).json({ success: true, message: '已更新' });
});

router.patch('/books/:id', canManage, async (req, res) => {
  const bookId = v.id(req.params.id, '書籍編號');
  const status = v.oneOf(req.body.status, ['on_sale', 'removed'], '只能設定為上架或下架');
  const reason = v.optionalText(req.body.reason, { label: '原因', max: 500 }) ?? null;

  const book = await prisma.books.findUnique({ where: { book_id: bookId } });
  if (!book) throw notFound('找不到這本書');

  // 已售出或交易中的書改回上架會被第二個買家買走。
  if (status === 'on_sale' && ['reserved', 'sold'].includes(book.status)) {
    throw conflict(book.status === 'sold' ? '這本書已售出，無法恢復上架' : '這本書正在交易中，無法恢復上架');
  }

  // 恢復上架須一併解除違規標記，否則 is_approved=false 仍會被公開列表濾掉。
  const statusData = { status, ...(status === 'on_sale' && { is_approved: true }) };

  await prisma.$transaction(async (tx) => {
    await tx.books.update({
      where: { book_id: bookId },
      data: { ...statusData, updated_at: new Date() }
    });
    await notify(tx, {
      userId: book.seller_id,
      title: status === 'removed' ? '您的書籍已被下架' : '您的書籍已恢復上架',
      content: status === 'removed'
        ? `《${book.title}》已由管理員下架。${reason ? `原因：${reason}` : ''}`
        : `《${book.title}》已由管理員恢復上架。`,
      relatedId: bookId,
      relatedType: 'book'
    });
  });

  await audit.record(null, {
    adminId: req.user.userId,
    action: status === 'removed' ? '強制下架書籍' : '恢復書籍上架',
    targetType: 'book',
    targetId: bookId,
    summary: `${status === 'removed' ? '下架' : '恢復上架'}了《${book.title}》${reason ? `，原因：${reason}` : ''}`,
    changes: audit.diff(book, statusData, BOOK_STATUS_FIELDS),
    undo: [audit.undoUpdate('books', bookId, book, statusData, BOOK_STATUS_FIELDS)],
    req
  });
  res.status(200).json({ success: true, message: status === 'removed' ? '已下架' : '已恢復上架' });
});

const categoryName = (value) => {
  const name = v.text(value, { label: '分類名稱', max: 50 });
  if (!name) throw badRequest('請輸入分類名稱');
  return name;
};

const sortOrder = (value) => (v.isBlank(value) ? 0 : v.int(value, { label: '排序', min: 0, max: 100000 }));

router.get('/categories', canManage, async (req, res) => {
  const categories = await prisma.book_categories.findMany({
    orderBy: [{ sort_order: 'asc' }, { category_id: 'asc' }],
    include: { _count: { select: { books: true } } }
  });

  res.status(200).json({
    success: true,
    data: categories.map((c) => ({
      category_id: c.category_id,
      category_name: c.category_name,
      sort_order: c.sort_order,
      book_count: c._count.books
    }))
  });
});

router.post('/categories', canManage, async (req, res) => {
  const name = categoryName(req.body.category_name);
  const created = await prisma.book_categories.create({
    data: { category_name: name, sort_order: sortOrder(req.body.sort_order) }
  });
  await audit.record(null, {
    adminId: req.user.userId,
    action: '新增分類',
    targetType: 'category',
    targetId: created.category_id,
    summary: `新增了分類「${name}」`,
    undo: [audit.undoCreate('book_categories', created.category_id)],
    req
  });
  res.status(201).json({ success: true, data: { category_id: created.category_id } });
});

// 必須排在 /categories/:id 之前，否則 reorder 會被當成 id。
router.put('/categories/reorder', canManage, async (req, res) => {
  const order = req.body.order;
  if (!Array.isArray(order) || order.length === 0) throw badRequest('請提供排序後的分類順序');
  if (order.length > 1000) throw badRequest('排序資料過多');

  const ids = order.map((cid) => v.toInt(cid)).filter((n) => Number.isSafeInteger(n) && n > 0);
  if (ids.length !== order.length || new Set(ids).size !== ids.length) {
    throw badRequest('排序資料格式不正確');
  }

  const existing = await prisma.book_categories.findMany({
    where: { category_id: { in: ids } },
    select: { category_id: true, category_name: true, sort_order: true }
  });
  if (existing.length !== ids.length) throw badRequest('排序資料含有不存在的分類');

  await prisma.$transaction(
    ids.map((cid, index) => prisma.book_categories.update({ where: { category_id: cid }, data: { sort_order: index } }))
  );

  const byId = new Map(existing.map((c) => [c.category_id, c]));
  await audit.record(null, {
    adminId: req.user.userId,
    action: '調整分類排序',
    targetType: 'category',
    summary: '調整了分類的顯示順序',
    changes: [{
      label: '順序',
      from: [...existing].sort((a, b) => a.sort_order - b.sort_order).map((c) => c.category_name).join('、'),
      to: ids.map((cid) => byId.get(cid).category_name).join('、')
    }],
    undo: [audit.undoReorder('book_categories',
      ids.map((cid, index) => ({ id: cid, before: byId.get(cid).sort_order, after: index })))],
    req
  });
  res.status(200).json({ success: true, message: '已更新排序' });
});

router.put('/categories/:id', canManage, async (req, res) => {
  const categoryId = v.id(req.params.id, '分類編號');
  const name = categoryName(req.body.category_name);

  const before = await prisma.book_categories.findUnique({ where: { category_id: categoryId } });
  if (!before) throw notFound('找不到該分類');
  const data = { category_name: name, sort_order: sortOrder(req.body.sort_order) };

  await prisma.book_categories.update({ where: { category_id: categoryId }, data });

  const fields = { category_name: '名稱', sort_order: '排序' };
  const changes = audit.diff(before, data, fields);
  await audit.record(null, {
    adminId: req.user.userId,
    action: '編輯分類',
    targetType: 'category',
    targetId: categoryId,
    summary: changes.length ? `編輯了分類「${before.category_name}」` : `重新儲存了分類「${name}」（沒有實際變動）`,
    changes,
    undo: changes.length ? [audit.undoUpdate('book_categories', categoryId, before, data, fields)] : null,
    req
  });
  res.status(200).json({ success: true, message: '已更新分類' });
});

router.delete('/categories/:id', canManage, async (req, res) => {
  const categoryId = v.id(req.params.id, '分類編號');

  const [inUse, children] = await Promise.all([
    prisma.books.count({ where: { category_id: categoryId } }),
    prisma.book_categories.count({ where: { parent_id: categoryId } })
  ]);
  if (inUse > 0) throw badRequest(`還有 ${inUse} 本書屬於這個分類，請先調整後再刪除`);
  if (children > 0) throw badRequest(`這個分類底下還有 ${children} 個子分類，請先調整後再刪除`);

  const before = await prisma.book_categories.findUnique({ where: { category_id: categoryId } });
  if (!before) throw notFound('找不到該分類');
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
  res.status(200).json({ success: true, message: '已刪除分類' });
});

module.exports = router;
