const prisma = require('../lib/prisma');
const publicId = require('../lib/public-id');
const { badRequest, notFound, conflict } = require('../lib/errors');
const { userBrief, coverImage } = require('../lib/selects');
const { BOOK_STATUS_LABELS, CONDITION_LABELS } = require('../constants/domain');
const { notify } = require('./notify');
const audit = require('./audit');

const ADMIN_FIELDS = {
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

const ADMIN_STATUS_FIELDS = {
  status: { label: '狀態', format: (v) => BOOK_STATUS_LABELS[v] ?? v },
  is_approved: { label: '審核通過', format: (v) => (v ? '是' : '否（違規）') }
};

const findOrThrow = async (bookId) => {
  const book = await prisma.books.findUnique({ where: { book_id: bookId } });
  if (!book) throw notFound('找不到此書籍');
  return book;
};

const adminList = async ({ keyword, status, skip, limit }) => {
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
        users: { select: userBrief },
        book_categories: { select: { category_id: true, category_name: true } },
        book_images: coverImage
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

  return {
    total,
    rows: books.map((b) => ({
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
  };
};

const assertCategoryExists = async (categoryId) => {
  if (!categoryId) return;
  const exists = await prisma.book_categories.count({ where: { category_id: categoryId } });
  if (!exists) throw badRequest('找不到此分類');
};

const adminEdit = async (bookId, book, data, { adminId, req }) => {
  const changes = [];
  if (data.title !== undefined && data.title !== book.title) changes.push(`書名改為《${data.title}》`);
  if (data.price !== undefined && data.price !== Number(book.price)) changes.push(`售價改為 ${data.price.toFixed(0)} 代幣`);

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

  const logged = audit.diff(book, data, ADMIN_FIELDS);
  await audit.record(null, {
    adminId,
    action: '修改書籍資料',
    targetType: 'book',
    targetId: bookId,
    summary: logged.length
      ? `修改《${book.title}》的${logged.map((c) => c.label).join('、')}，並通知賣家`
      : `重新儲存《${book.title}》（無實際變更）`,
    changes: logged,
    undo: logged.length ? [audit.undoUpdate('books', bookId, book, data, ADMIN_FIELDS)] : null,
    req
  });
};

const adminSetStatus = async (bookId, status, reason, { adminId, req }) => {
  const book = await findOrThrow(bookId);

  // 已售出或交易中的書改回上架會被第二個買家買走。
  if (status === 'on_sale' && ['reserved', 'sold'].includes(book.status)) {
    throw conflict(book.status === 'sold' ? '此書籍已售出，無法恢復上架' : '此書籍交易中，無法恢復上架');
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
    adminId,
    action: status === 'removed' ? '強制下架書籍' : '恢復書籍上架',
    targetType: 'book',
    targetId: bookId,
    summary: `${status === 'removed' ? '下架' : '恢復上架'}《${book.title}》${reason ? `，原因：${reason}` : ''}`,
    changes: audit.diff(book, statusData, ADMIN_STATUS_FIELDS),
    undo: [audit.undoUpdate('books', bookId, book, statusData, ADMIN_STATUS_FIELDS)],
    req
  });
};

const inTransaction = () => conflict('此書籍交易或預約進行中，請先處理後再刪除', 'BOOK_IN_TRANSACTION');
const hasOrders = () => conflict('此書籍已有訂單紀錄，為保留交易資料無法刪除，如需停止販售請使用強制下架', 'BOOK_HAS_ORDERS');

const assertDeletable = async (tx, book) => {
  const now = new Date();
  const [activeReservations, orderItems] = await Promise.all([
    tx.reservations.count({
      where: {
        book_id: book.book_id,
        OR: [{ status: 'pending' }, { status: 'confirmed', pickup_deadline: { gt: now } }]
      }
    }),
    tx.order_items.count({ where: { book_id: book.book_id } })
  ]);
  if (book.status === 'reserved' || activeReservations > 0) throw inTransaction();
  if (orderItems > 0) throw hasOrders();
};

const adminRemove = async (bookId, reason, { adminId, req }) => {
  const book = await findOrThrow(bookId);
  const bookNo = publicId.encode('book', bookId);

  try {
    await prisma.$transaction(async (tx) => {
      await assertDeletable(tx, book);
      await tx.reservations.deleteMany({ where: { book_id: bookId } });
      await tx.shopping_cart.deleteMany({ where: { book_id: bookId } });
      await tx.favorites.deleteMany({ where: { book_id: bookId } });
      await tx.recommendation_logs.deleteMany({ where: { book_id: bookId } });
      await tx.chat_rooms.updateMany({ where: { book_id: bookId }, data: { book_id: null } });
      await tx.books.delete({ where: { book_id: bookId } });

      await notify(tx, {
        userId: book.seller_id,
        title: '您的書籍已被刪除',
        content: `您的書籍《${book.title}》已由管理員刪除${reason ? `。原因：${reason}` : ''}`
      });
      await audit.record(tx, {
        adminId,
        action: '刪除書籍',
        targetType: 'book',
        targetId: bookId,
        summary: `刪除書籍 ${bookNo}《${book.title}》，並通知賣家${reason ? `，原因：${reason}` : ''}`,
        req
      });
    });
  } catch (err) {
    // 檢查後、刪除前若有人下單，order_items 外鍵會讓刪除失敗。
    if (err?.code === 'P2003') throw hasOrders();
    throw err;
  }
};

module.exports = {
  findOrThrow, assertCategoryExists, list: adminList, edit: adminEdit, setStatus: adminSetStatus, remove: adminRemove
};
