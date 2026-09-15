const prisma = require('../lib/prisma');
const { badRequest, notFound, conflict } = require('../lib/errors');
const { userBrief, userName, coverImage } = require('../lib/selects');
const { REPORT_STATUS_LABELS } = require('../constants/domain');
const { notify } = require('./notify');
const audit = require('./audit');
const publicId = require('../lib/public-id');

const RESULTS = ['reviewing', 'resolved', 'dismissed'];
const FINAL = ['resolved', 'dismissed'];

const REPORT_FIELDS = {
  status: { label: '檢舉狀態', format: (s) => REPORT_STATUS_LABELS[s] ?? s },
  admin_note: '處理備註'
};
const BOOK_FIELDS = { status: '書籍狀態', is_approved: '審核通過' };

const listMine = (userId) => prisma.reports.findMany({
  where: { reporter_id: userId },
  orderBy: { created_at: 'desc' }
});

const resolveOwner = async (targetType, targetId, userId) => {
  if (targetType === 'book') {
    const book = await prisma.books.findUnique({ where: { book_id: targetId }, select: { seller_id: true } });
    if (!book) throw notFound('找不到該書籍');
    if (book.seller_id === userId) throw badRequest('無法檢舉自己上架的商品');
    return book.seller_id;
  }

  if (targetType === 'user') {
    if (targetId === userId) throw badRequest('無法檢舉自己');
    const target = await prisma.users.findUnique({ where: { user_id: targetId }, select: { user_id: true } });
    if (!target) throw notFound('找不到該使用者');
    return target.user_id;
  }

  const message = await prisma.chat_messages.findUnique({
    where: { message_id: targetId },
    select: { sender_id: true }
  });
  if (!message) throw notFound('找不到該訊息');
  if (message.sender_id === userId) throw badRequest('無法檢舉自己的訊息');
  return null;
};

const create = async (userId, { targetType, targetId, reason, evidenceUrls }) => {
  const ownerId = await resolveOwner(targetType, targetId, userId);

  const duplicate = await prisma.reports.findFirst({
    where: {
      reporter_id: userId,
      target_type: targetType,
      target_id: targetId,
      status: { in: ['pending', 'reviewing'] }
    },
    select: { report_id: true }
  });
  if (duplicate) throw conflict('您已檢舉過此項目，我們正在處理中');

  return prisma.$transaction(async (tx) => {
    const created = await tx.reports.create({
      data: {
        reporter_id: userId,
        target_type: targetType,
        target_id: targetId,
        reason,
        evidence_urls: evidenceUrls
      }
    });

    if (ownerId) {
      await notify(tx, {
        userId: ownerId,
        title: targetType === 'book' ? '您的商品遭到檢舉' : '您的帳號遭到檢舉',
        content: '我們已收到一則檢舉並開始審核，審核期間商品仍可正常販售。若違規成立將另行通知您。',
        relatedId: targetId,
        relatedType: targetType
      });
    }

    return created;
  });
};

const againstSeller = async (userId) => {
  const myBooks = await prisma.books.findMany({
    where: { seller_id: userId },
    select: { book_id: true }
  });

  const bookIds = myBooks.map((b) => b.book_id);
  if (bookIds.length === 0) return [];

  return prisma.reports.findMany({
    where: { target_type: 'book', target_id: { in: bookIds } },
    orderBy: { created_at: 'desc' },
    select: { report_id: true, target_id: true, status: true, reason: true, created_at: true, resolved_at: true }
  });
};

const adminList = async (status) => {
  const reports = await prisma.reports.findMany({
    where: { ...(status && { status }) },
    orderBy: { created_at: 'desc' },
    include: {
      users_reports_reporter_idTousers: { select: userBrief },
      users_reports_admin_idTousers: { select: userName }
    }
  });

  const bookIds = reports.filter((r) => r.target_type === 'book').map((r) => r.target_id);
  const userIds = reports.filter((r) => r.target_type === 'user').map((r) => r.target_id);

  const [books, users] = await Promise.all([
    bookIds.length
      ? prisma.books.findMany({
          where: { book_id: { in: bookIds } },
          select: { book_id: true, title: true, price: true, status: true, book_images: coverImage }
        })
      : [],
    userIds.length
      ? prisma.users.findMany({
          where: { user_id: { in: userIds } },
          select: userBrief
        })
      : []
  ]);

  const bookMap = new Map(books.map((b) => [b.book_id, b]));
  const userMap = new Map(users.map((u) => [u.user_id, u]));

  return reports.map((r) => ({
    ...r,
    target: r.target_type === 'book' ? bookMap.get(r.target_id) ?? null
      : r.target_type === 'user' ? userMap.get(r.target_id) ?? null
        : null
  }));
};

const review = async (reportId, { status, adminNote, removeTarget }, { adminId, req }) => {
  const report = await prisma.reports.findUnique({ where: { report_id: reportId } });
  if (!report) throw notFound('找不到該檢舉');
  if (report.status === status && FINAL.includes(status)) throw conflict('此檢舉已處理');

  let bookBefore = null;
  let bookAfter = null;

  const updated = await prisma.$transaction(async (tx) => {
    const r = await tx.reports.update({
      where: { report_id: reportId },
      data: {
        status,
        admin_id: adminId,
        admin_note: adminNote,
        resolved_at: FINAL.includes(status) ? new Date() : null
      }
    });

    let ownerId = null;
    if (report.target_type === 'book') {
      const book = await tx.books.findUnique({ where: { book_id: report.target_id } });
      ownerId = book?.seller_id ?? null;

      if (removeTarget && book) {
        bookBefore = book;
        bookAfter = { status: 'removed', is_approved: false };
        await tx.books.update({
          where: { book_id: report.target_id },
          data: { status: 'removed', is_approved: false, updated_at: new Date() }
        });
      }
    } else if (report.target_type === 'user') {
      ownerId = report.target_id;
    }

    await notify(tx, {
      userId: report.reporter_id,
      title: '您的檢舉已處理',
      content: status === 'dismissed' ? '經審核未違反社群規範，感謝您的回報。' : '感謝您的回報，我們已完成處理。',
      relatedId: reportId,
      relatedType: 'report'
    });

    if (ownerId && ownerId !== report.reporter_id) {
      const resolved = status === 'resolved';
      await notify(tx, {
        userId: ownerId,
        title: resolved ? '檢舉審核結果：違規成立' : '檢舉審核結果：未違規',
        content: resolved
          ? (removeTarget && report.target_type === 'book'
              ? '經審核違規成立，該商品已下架。如有疑問請聯絡客服。'
              : '經審核違規成立，請留意社群規範，重複違規將影響帳號權益。')
          : '經審核未違反社群規範，您的商品／帳號不受影響。',
        relatedId: report.target_id,
        relatedType: report.target_type
      });
    }

    return r;
  });

  await audit.record(null, {
    adminId,
    action: '處理檢舉',
    targetType: 'report',
    targetId: reportId,
    summary: `將檢舉 ${publicId.encode('report', reportId)} 標為「${REPORT_STATUS_LABELS[status]}」`
      + `${bookBefore ? `，並下架《${bookBefore.title}》` : ''}。已通知檢舉人與被檢舉人（通知無法收回）`,
    changes: [
      ...audit.diff(report, updated, REPORT_FIELDS),
      ...(bookBefore ? audit.diff(bookBefore, bookAfter, BOOK_FIELDS) : [])
    ],
    undo: [
      audit.undoUpdate('reports', reportId, report, updated, ['status', 'admin_id', 'admin_note', 'resolved_at']),
      ...(bookBefore ? [audit.undoUpdate('books', bookBefore.book_id, bookBefore, bookAfter, BOOK_FIELDS)] : [])
    ],
    req
  });
  return updated;
};

module.exports = { RESULTS, listMine, create, againstSeller, adminList, review };
