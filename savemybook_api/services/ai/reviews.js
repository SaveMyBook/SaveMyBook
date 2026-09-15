const prisma = require('../../lib/prisma');
const { placeholders } = require('../../lib/sql');
const { notFound, conflict } = require('../../lib/errors');
const { userBrief, bookImageFields, categoryName } = require('../../lib/selects');
const { notify } = require('../notify');
const audit = require('../audit');
const settingsService = require('./settings');

const STATUSES = ['pending', 'approved', 'rejected'];
const DECISIONS = ['approve', 'reject'];

const parseList = (value) => {
  try {
    const list = JSON.parse(String(value ?? '[]'));
    return Array.isArray(list) ? list.filter((x) => typeof x === 'string') : [];
  } catch {
    return [];
  }
};

const statusMap = async (bookIds) => {
  const ids = [...new Set(bookIds.map(Number).filter((n) => Number.isSafeInteger(n) && n > 0))];
  if (ids.length === 0 || !(await settingsService.migrationReady())) return new Map();
  const rows = await prisma.$queryRawUnsafe(
    `SELECT book_id, status FROM ai_book_reviews WHERE book_id IN (${placeholders(ids)})`,
    ...ids
  );
  return new Map(rows.map((r) => [Number(r.book_id), r.status]));
};

const reviewStatusOf = (status) => (status === 'pending' || status === 'rejected' ? status : null);

const statusOf = async (bookId) => (await statusMap([bookId])).get(Number(bookId)) ?? null;

const withReviewStatus = async (books) => {
  const list = Array.isArray(books) ? books : [books];
  const map = await statusMap(list.filter((b) => b && b.is_approved === false).map((b) => b.book_id));
  const shaped = list.map((b) => (b ? { ...b, review_status: reviewStatusOf(map.get(Number(b.book_id))) } : b));
  return Array.isArray(books) ? shaped : shaped[0];
};

const hold = (db, { bookId, decision }) => db.$executeRaw`
  INSERT INTO ai_book_reviews (book_id, verdict, reasons, categories, status, provider, model, created_at, reviewed_by, reviewed_at)
  VALUES (${bookId}, ${decision.verdict}, ${JSON.stringify(decision.reasons)}, ${JSON.stringify(decision.categories)}, 'pending',
    ${decision.provider}, ${decision.model}, ${new Date()}, NULL, NULL)
  ON DUPLICATE KEY UPDATE verdict = VALUES(verdict), reasons = VALUES(reasons), categories = VALUES(categories), status = 'pending',
    provider = VALUES(provider), model = VALUES(model), created_at = VALUES(created_at), reviewed_by = NULL, reviewed_at = NULL`;

// 管理員恢復上架或編輯通過時，未結的 AI 審核一併結案，否則賣家端仍會顯示審核中。
const settle = async (db, bookId, adminId = null) => {
  if (!(await settingsService.migrationReady())) return;
  await db.$executeRaw`
    UPDATE ai_book_reviews SET status = 'approved', reviewed_by = ${adminId}, reviewed_at = ${new Date()}
    WHERE book_id = ${bookId} AND status IN ('pending', 'rejected')`;
};

const notifyHeld = (db, book) => notify(db, {
  userId: book.seller_id,
  title: '書籍已送交審核',
  content: `您的書籍《${book.title}》已送交審核，審核通過後將公開販售。`,
  relatedId: book.book_id,
  relatedType: 'book'
});

const adminList = async (status) => {
  if (!(await settingsService.migrationReady())) throw settingsService.unavailable();
  const rows = status
    ? await prisma.$queryRaw`
        SELECT book_id, verdict, reasons, categories, status, provider, model, created_at, reviewed_by, reviewed_at
        FROM ai_book_reviews WHERE status = ${status} ORDER BY created_at DESC LIMIT 200`
    : await prisma.$queryRaw`
        SELECT book_id, verdict, reasons, categories, status, provider, model, created_at, reviewed_by, reviewed_at
        FROM ai_book_reviews ORDER BY created_at DESC LIMIT 200`;
  if (rows.length === 0) return [];

  const books = await prisma.books.findMany({
    where: { book_id: { in: rows.map((r) => Number(r.book_id)) } },
    include: {
      users: { select: userBrief },
      book_images: { select: bookImageFields },
      book_categories: { select: categoryName }
    }
  });
  const byId = new Map(books.map((b) => [b.book_id, b]));

  return rows
    .filter((r) => byId.has(Number(r.book_id)))
    .map((r) => {
      const book = byId.get(Number(r.book_id));
      const { users, ...card } = book;
      return {
        book_id: Number(r.book_id),
        book: card,
        seller: users ?? null,
        verdict: r.verdict,
        reasons: parseList(r.reasons),
        categories: parseList(r.categories),
        status: r.status,
        provider: r.provider,
        model: r.model,
        created_at: r.created_at,
        reviewed_at: r.reviewed_at
      };
    });
};

const decide = async (bookId, { decision, note }, { adminId, req }) => {
  if (!(await settingsService.migrationReady())) throw settingsService.unavailable();
  const [review] = await prisma.$queryRaw`SELECT book_id, status FROM ai_book_reviews WHERE book_id = ${bookId}`;
  if (!review) throw notFound('找不到此審核紀錄');
  const book = await prisma.books.findUnique({ where: { book_id: bookId } });
  if (!book) throw notFound('找不到此書籍');

  const approve = decision === 'approve';
  if (review.status === (approve ? 'approved' : 'rejected')) throw conflict(approve ? '此書籍已通過審核' : '此書籍已駁回');

  const bookData = approve
    ? { is_approved: true, ...(review.status === 'rejected' && book.status === 'removed' && { status: 'on_sale' }) }
    : { is_approved: false, ...(book.status === 'on_sale' && { status: 'removed' }) };

  await prisma.$transaction(async (tx) => {
    await tx.books.update({ where: { book_id: bookId }, data: { ...bookData, updated_at: new Date() } });
    await tx.$executeRaw`
      UPDATE ai_book_reviews SET status = ${approve ? 'approved' : 'rejected'}, reviewed_by = ${adminId}, reviewed_at = ${new Date()}
      WHERE book_id = ${bookId}`;
    await notify(tx, {
      userId: book.seller_id,
      title: approve ? '書籍已通過審核' : '書籍未通過審核',
      content: approve
        ? `您的書籍《${book.title}》已通過審核${(bookData.status ?? book.status) === 'on_sale' ? '，現已公開販售' : ''}。`
        : `您的書籍《${book.title}》未通過上架審核，已下架。${note ? `原因：${note}` : ''}如有疑問請聯絡客服。`,
      relatedId: bookId,
      relatedType: 'book'
    });
  });

  await audit.record(null, {
    adminId,
    action: approve ? '核准 AI 審核書籍' : '駁回 AI 審核書籍',
    targetType: 'book',
    targetId: bookId,
    summary: `${approve ? '核准' : '駁回'}《${book.title}》的上架審核，並通知賣家${!approve && note ? `，原因：${note}` : ''}`,
    changes: audit.diff(book, bookData, {
      status: '狀態',
      is_approved: { label: '審核通過', format: (v) => (v ? '是' : '否') }
    }),
    req
  });
  return { book_id: bookId, status: approve ? 'approved' : 'rejected' };
};

module.exports = {
  STATUSES, DECISIONS, statusMap, statusOf, reviewStatusOf, withReviewStatus, hold, settle, notifyHeld, adminList, decide
};
