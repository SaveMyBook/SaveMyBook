const prisma = require('../../lib/prisma');
const { placeholders } = require('../../lib/sql');
const { notFound, conflict } = require('../../lib/errors');
const { userBrief, bookImageFields, categoryName } = require('../../lib/selects');
const { notify } = require('../notify');
const audit = require('../audit');

const STATUSES = ['pending', 'approved', 'rejected'];
const DECISIONS = ['approve', 'reject'];
const MARKERS = ['passed', 'skipped'];
const HOUR_MS = 60 * 60 * 1000;
// 沒有任何審核紀錄的書只往回找這段期間：上線前既有的書沒有紀錄，不能全部當成未審。
const UNMARKED_WINDOW_MS = 7 * 24 * HOUR_MS;
const UNREVIEWED_AFTER_MS = HOUR_MS;

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
  if (ids.length === 0) return new Map();
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

const confidenceOf = (decision) => {
  if (decision.model === 'rules' || decision.confidence == null) return null;
  const n = Number(decision.confidence);
  return Number.isFinite(n) ? Math.round(Math.min(Math.max(n, 0), 1) * 1000) / 1000 : null;
};

const originOf = (model) => (model === 'rules' ? 'rules' : 'ai');

const recordEvent = (db, { bookId, actor, prior = null, status, source, category = null, misjudged = null }) => db.ai_review_events.create({
  data: {
    book_id: bookId,
    actor,
    prior,
    status,
    verdict: source.verdict ?? 'none',
    origin: originOf(source.model),
    categories: typeof source.categories === 'string' ? source.categories : JSON.stringify(source.categories ?? []),
    confidence: source.confidence == null ? null : Number(source.confidence),
    category,
    misjudged,
    created_at: new Date()
  }
});

const hold = async (db, { bookId, decision, actor = 'system', status = 'pending' }) => {
  const prior = (await db.ai_book_reviews.findUnique({ where: { book_id: bookId }, select: { status: true } }))?.status ?? null;
  const confidence = confidenceOf(decision);
  await db.$executeRaw`
    INSERT INTO ai_book_reviews (book_id, verdict, reasons, categories, status, provider, model, confidence, created_at, reviewed_by, reviewed_at)
    VALUES (${bookId}, ${decision.verdict}, ${JSON.stringify(decision.reasons)}, ${JSON.stringify(decision.categories)}, 'pending',
      ${decision.provider}, ${decision.model}, ${confidence}, ${new Date()}, NULL, NULL)
    ON DUPLICATE KEY UPDATE verdict = VALUES(verdict), reasons = VALUES(reasons), categories = VALUES(categories), status = 'pending',
      provider = VALUES(provider), model = VALUES(model), confidence = VALUES(confidence), created_at = VALUES(created_at),
      reviewed_by = NULL, reviewed_at = NULL, skip_reason = NULL, attempts = 0, ai_opinion = NULL, decision_reason = NULL`;
  if (status === 'rejected') {
    await db.$executeRaw`UPDATE ai_book_reviews SET status = 'rejected', reviewed_at = ${new Date()} WHERE book_id = ${bookId}`;
  }
  await recordEvent(db, { bookId, actor, prior, status, source: { ...decision, confidence } });
};

// attempts 只累計與這本書內容有關的失敗（見 moderation 的 OUTAGE_SKIPS），服務中斷時補審不改動次數。
const markerData = (decision, retry) => {
  const base = { reasons: '[]', created_at: new Date(), reviewed_by: null, reviewed_at: null, ai_opinion: null };
  if (!decision.skipped) {
    return {
      ...base, status: 'passed', verdict: decision.verdict, categories: JSON.stringify(decision.categories ?? []),
      provider: decision.provider, model: decision.model, confidence: confidenceOf(decision), skip_reason: null, attempts: 0
    };
  }
  const counted = !decision.outage;
  const attempts = retry ? (counted ? { increment: 1 } : undefined) : Number(counted);
  return {
    ...base, status: 'skipped', verdict: 'none', categories: '[]', confidence: null,
    provider: decision.attempted?.provider ?? null, model: decision.attempted?.model ?? null,
    skip_reason: decision.skipped, ...(attempts !== undefined && { attempts })
  };
};

// 審核通過或放行但未審時留下紀錄，排程才分得出「審過」與「沒審過」。待審與駁回的紀錄不能被自動審核蓋掉。
// 管理員核准的書之後編輯時 AI 失敗，也要改記為略過，否則不會被補審。
// partial：只審了新加入的照片，不能據此把略過或沒有紀錄的書記為通過。
// since：背景審核開始時的紀錄（null 代表當時沒有）。期間紀錄已被編輯或新增照片改寫時以較新的為準，
// 否則依舊資料得出的結果會蓋掉新內容的略過紀錄。
const mark = async (db, bookId, decision, { retry = false, partial = false, since } = {}) => {
  if (!decision.skipped && !(decision.action === 'allow' && decision.provider)) return;
  if (partial && !decision.skipped) return;
  const data = markerData(decision, retry);
  if (since !== null) {
    const where = since
      ? { book_id: bookId, status: since.status, created_at: since.created_at }
      : { book_id: bookId, status: { in: decision.skipped ? [...MARKERS, 'approved'] : MARKERS } };
    const { count } = await db.ai_book_reviews.updateMany({ where, data });
    if (count > 0 || since) return;
  }
  try {
    await db.ai_book_reviews.create({ data: { book_id: bookId, ...data, attempts: data.attempts?.increment ?? data.attempts ?? 0 } });
  } catch (err) {
    if (err.code !== 'P2002') throw err;
  }
};

const markerOf = async (db, bookId) => (await db.ai_book_reviews.findUnique({
  where: { book_id: bookId },
  select: { status: true, attempts: true }
})) ?? null;

// 規則送審的書在背景取得的 AI 判定，只附在仍待審的紀錄上，供管理員參考。
const attachOpinion = async (db, bookId, decision) => {
  if (!decision.provider) return;
  const opinion = { verdict: decision.verdict, confidence: decision.confidence, categories: decision.categories, reasons: decision.reasons };
  await db.ai_book_reviews.updateMany({ where: { book_id: bookId, status: 'pending' }, data: { ai_opinion: JSON.stringify(opinion) } });
};

const unmarked = (now, olderThanMs) => ({
  created_at: { gte: new Date(now.getTime() - UNMARKED_WINDOW_MS), lte: new Date(now.getTime() - olderThanMs) },
  ai_book_reviews: { is: null }
});

const LISTED = { status: 'on_sale', is_approved: true };

// 補審順序：從未審過的書優先，其次依上次嘗試時間由舊到新，剛失敗的書排到最後，不會每輪都卡在同一本。
// since 供 mark 判斷審核期間紀錄是否已被改寫。
const dueForRecheck = async (now, { afterMs, gapMs, take }) => {
  const [fresh, retried] = await Promise.all([
    prisma.books.findMany({ where: { ...LISTED, ...unmarked(now, afterMs) }, orderBy: { created_at: 'asc' }, take }),
    prisma.ai_book_reviews.findMany({
      where: { status: 'skipped', created_at: { lte: new Date(now.getTime() - gapMs) }, books: { is: LISTED } },
      orderBy: { created_at: 'asc' },
      take,
      select: { book_id: true, status: true, created_at: true }
    })
  ]);
  const markers = retried.slice(0, Math.max(take - fresh.length, 0));
  const books = markers.length
    ? await prisma.books.findMany({ where: { book_id: { in: markers.map((m) => m.book_id) } } })
    : [];
  const byId = new Map(books.map((b) => [b.book_id, b]));
  const retries = markers
    .filter((m) => byId.has(m.book_id))
    .map((m) => ({ book: byId.get(m.book_id), since: { status: m.status, created_at: m.created_at } }));
  return [...fresh.map((book) => ({ book, since: null })), ...retries];
};

const unreviewedCount = (now = new Date()) => prisma.books.count({
  where: {
    ...LISTED,
    OR: [
      unmarked(now, UNREVIEWED_AFTER_MS),
      { created_at: { lte: new Date(now.getTime() - UNREVIEWED_AFTER_MS) }, ai_book_reviews: { is: { status: 'skipped' } } }
    ]
  }
});

// 背景審核直接駁回的紀錄沒有審核人；管理員駁回時會寫入 reviewed_by。
const systemRejected = (review) => review.status === 'rejected' && review.reviewed_by == null;

// 管理員恢復上架或編輯通過時，未結的 AI 審核一併結案，否則賣家端仍會顯示審核中。
// 沒有 adminId 的是賣家修改後重新審核通過，不代表原判定有誤。管理員恢復上架只在推翻背景審核的駁回時算誤判：
// 審核清單只列待審，被背景審核下架的書只能從書籍管理恢復。
const settle = async (db, bookId, adminId = null) => {
  const review = await db.ai_book_reviews.findUnique({ where: { book_id: bookId } });
  if (!review || !['pending', 'rejected'].includes(review.status)) return;
  await db.$executeRaw`
    UPDATE ai_book_reviews SET status = 'approved', reviewed_by = ${adminId}, reviewed_at = ${new Date()}
    WHERE book_id = ${bookId} AND status IN ('pending', 'rejected')`;
  await recordEvent(db, {
    bookId,
    actor: adminId ? 'relist' : 'seller_edit',
    prior: review.status,
    status: 'approved',
    source: review,
    misjudged: adminId && systemRejected(review) ? true : null
  });
};

// 待審不算違規鎖定：管理員或檢舉成立下架時須一併結案，否則賣家仍可自行重新上架。不代表 AI 判定正確與否，不計入誤判統計。
const closeForTakedown = async (db, bookId, adminId) => {
  const review = await db.ai_book_reviews.findUnique({ where: { book_id: bookId } });
  if (review?.status !== 'pending') return false;
  const closed = await db.$executeRaw`
    UPDATE ai_book_reviews SET status = 'rejected', reviewed_by = ${adminId}, reviewed_at = ${new Date()}
    WHERE book_id = ${bookId} AND status = 'pending'`;
  if (Number(closed) === 0) return false;
  await recordEvent(db, { bookId, actor: 'admin', prior: 'pending', status: 'rejected', source: review, misjudged: null });
  return true;
};

const notifyHeld = (db, book) => notify(db, {
  userId: book.seller_id,
  title: '書籍已送交審核',
  content: `您的書籍《${book.title}》已送交審核，審核通過後將公開販售。`,
  relatedId: book.book_id,
  relatedType: 'book'
});

const parseOpinion = (value) => {
  try {
    const opinion = JSON.parse(String(value ?? ''));
    if (!opinion || typeof opinion !== 'object' || typeof opinion.verdict !== 'string') return null;
    return {
      verdict: opinion.verdict,
      confidence: opinion.confidence == null || !Number.isFinite(Number(opinion.confidence)) ? null : Number(opinion.confidence),
      categories: Array.isArray(opinion.categories) ? opinion.categories.filter((c) => typeof c === 'string') : [],
      reasons: Array.isArray(opinion.reasons) ? opinion.reasons.filter((r) => typeof r === 'string') : []
    };
  } catch {
    return null;
  }
};

const adminList = async (status) => {
  const rows = status
    ? await prisma.$queryRaw`
        SELECT book_id, verdict, reasons, categories, status, provider, model, confidence, decision_reason, created_at, reviewed_by,
          reviewed_at, ai_opinion
        FROM ai_book_reviews WHERE status = ${status} ORDER BY created_at DESC LIMIT 200`
    : await prisma.$queryRaw`
        SELECT book_id, verdict, reasons, categories, status, provider, model, confidence, decision_reason, created_at, reviewed_by,
          reviewed_at, ai_opinion
        FROM ai_book_reviews WHERE status IN ('pending', 'approved', 'rejected') ORDER BY created_at DESC LIMIT 200`;
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
        origin: originOf(r.model),
        confidence: r.confidence == null ? null : Number(r.confidence),
        decision_reason: r.decision_reason ?? null,
        provider: r.provider,
        model: r.model,
        created_at: r.created_at,
        reviewed_at: r.reviewed_at,
        ai_opinion: parseOpinion(r.ai_opinion)
      };
    });
};

// 延後載入：moderation → usage → reviews 的載入鏈若在模組頂端引用會形成循環。
const reasonLabel = (category) => (category === 'other' ? '其他' : require('./moderation').CATEGORY_LABELS[category] ?? category);

// 誤判只認兩種：推翻自動審核的「駁回」判定，或核准時管理員標示送審原因不成立；「建議人工檢視」後核准不算 AI 判斷錯誤。
// 已由管理員核准或駁回的紀錄再改判是管理員之間的更正，不歸咎原判定，也不重複計入。
const misjudgedOf = (review, approve, unfounded) => {
  if (review.status === 'approved' || (review.status === 'rejected' && !systemRejected(review))) return null;
  if (!approve) return false;
  return review.verdict === 'reject' || systemRejected(review) || unfounded === true;
};

const decide = async (bookId, { decision, note, category = null, unfounded = false }, { adminId, req }) => {
  const review = await prisma.ai_book_reviews.findUnique({ where: { book_id: bookId } });
  if (!review || !STATUSES.includes(review.status)) throw notFound('找不到此審核紀錄');
  const book = await prisma.books.findUnique({ where: { book_id: bookId } });
  if (!book) throw notFound('找不到此書籍');

  const approve = decision === 'approve';
  if (review.status === (approve ? 'approved' : 'rejected')) throw conflict(approve ? '此書籍已通過審核' : '此書籍已拒絕上架');

  // 延後載入：book-deposits → book-violations → ai/reviews 的載入鏈若在模組頂端引用會形成循環。
  const deposits = require('../book-deposits');
  const reservations = require('../reservations');
  const takedown = require('../book-takedown');

  let bookData = approve
    ? { is_approved: true, ...(review.status === 'rejected' && book.status === 'removed' && { status: 'on_sale' }) }
    : null;
  if (bookData?.status === 'on_sale') await takedown.assertNoOpenOrder(prisma, bookId);
  let taken = null;

  await prisma.$transaction(async (tx) => {
    if (!approve) {
      taken = await takedown.apply(tx, book);
      bookData = taken.data;
    } else {
      await tx.books.update({ where: { book_id: bookId }, data: { ...bookData, updated_at: new Date() } });
      if (bookData.status === 'on_sale') await deposits.syncAdminStatus(tx, bookId, 'on_sale');
      if (!reservations.isListed(book)) await reservations.notifyRelisted(tx, bookId);
    }
    await tx.$executeRaw`
      UPDATE ai_book_reviews SET status = ${approve ? 'approved' : 'rejected'}, reviewed_by = ${adminId}, reviewed_at = ${new Date()},
        decision_reason = ${approve ? null : category}
      WHERE book_id = ${bookId}`;
    await recordEvent(tx, {
      bookId,
      actor: 'admin',
      prior: review.status,
      status: approve ? 'approved' : 'rejected',
      source: review,
      category: approve ? null : category,
      misjudged: misjudgedOf(review, approve, unfounded)
    });
    await notify(tx, {
      userId: book.seller_id,
      title: approve ? '書籍已通過審核' : '書籍未通過審核',
      content: approve
        ? `您的書籍《${book.title}》已通過審核${(bookData.status ?? book.status) === 'on_sale' ? '，現已公開販售' : ''}。`
        : `您的書籍《${book.title}》未通過上架審核，已${takedown.actionLabel(taken)}。${note ? `原因：${note}` : ''}如有疑問請聯絡客服。`,
      relatedId: bookId,
      relatedType: 'book'
    });
  });

  const orderResult = approve ? null : await takedown.cancelOrders(bookId);

  await audit.record(null, {
    adminId,
    action: approve ? '核准 AI 審核書籍' : '拒絕 AI 審核書籍',
    targetType: 'book',
    targetId: bookId,
    summary: `${approve ? `核准《${book.title}》的上架審核` : `拒絕《${book.title}》上架`}，並通知賣家`
      + `${!approve && category ? `，類別：${reasonLabel(category)}` : ''}${!approve && note ? `，原因：${note}` : ''}`
      + `${orderResult ? takedown.describe(orderResult) : ''}`,
    changes: audit.diff(book, bookData, {
      status: '狀態',
      is_approved: { label: '審核通過', format: (v) => (v ? '是' : '否') }
    }),
    req
  });
  return { book_id: bookId, status: approve ? 'approved' : 'rejected' };
};

module.exports = {
  STATUSES, DECISIONS, statusMap, statusOf, reviewStatusOf, withReviewStatus, hold, recordEvent, mark, markerOf, attachOpinion,
  dueForRecheck, unreviewedCount, settle, closeForTakedown, notifyHeld, adminList, decide
};
