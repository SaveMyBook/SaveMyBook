const prisma = require('../lib/prisma');
const settingsService = require('./ai/settings');
const moderation = require('./ai/moderation');
const reviews = require('./ai/reviews');
const aiImages = require('./ai/images');
const { adminIdsWith } = require('./admin-permissions');
const { notify, notifyMany } = require('./notify');

const PRICE_CEILING = 3000;
const PEER_RATIO = 3;
const PEER_MARGIN = 300;
const SOURCE_PATTERN = /圖書館|館藏|借閱|索書號|公播|非賣品|贈閱|樣書|試讀本|公關書|影印本|盜版|翻印|掃描檔|電子檔|\bpdf\b/i;

const median = (values) => {
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
};

const peerPrice = async (book) => {
  if (!book.isbn) return null;
  const rows = await prisma.books.findMany({
    where: {
      isbn: book.isbn,
      is_approved: true,
      status: { not: 'removed' },
      ...(book.book_id && { book_id: { not: book.book_id } })
    },
    select: { price: true },
    take: 50
  });
  const prices = rows.map((r) => Number(r.price)).filter((n) => Number.isFinite(n) && n > 0);
  return prices.length ? median(prices) : null;
};

// 不經 AI 的即時規則：價格異常與非正規來源一律先送人工審核，AI 關閉或逾時也攔得住。
const ruleDecision = async (book) => {
  if (!(await settingsService.migrationReady())) return null;
  const reasons = [];
  const categories = [];

  const price = Number(book.price);
  const peer = await peerPrice(book);
  if (peer != null && price >= Math.max(peer * PEER_RATIO, peer + PEER_MARGIN)) {
    reasons.push(`售價明顯高於站上同書行情（約 ${Math.round(peer)} 代幣）`);
    categories.push('price');
  } else if (price >= PRICE_CEILING) {
    reasons.push(`售價 ${price} 代幣明顯高於一般二手書行情`);
    categories.push('price');
  }

  if (SOURCE_PATTERN.test([book.title, book.description].filter(Boolean).join('\n'))) {
    reasons.push(moderation.CATEGORY_LABELS.source);
    categories.push('source');
  }

  if (reasons.length === 0) return null;
  return { action: 'review', verdict: 'review', confidence: 1, reasons, categories, provider: null, model: 'rules' };
};

const notifyAdmins = async (db, book, reasons) => {
  const adminIds = (await adminIdsWith('content')).filter((id) => id !== book.seller_id);
  if (adminIds.length === 0) return;
  await notifyMany(db, adminIds, {
    title: '有書籍待審核',
    content: `《${book.title}》需要人工審核：${reasons.join('、')}`,
    relatedId: book.book_id,
    relatedType: 'book_review'
  });
};

const hold = async (db, book, decision, { notifySeller = true } = {}) => {
  await reviews.hold(db, { bookId: book.book_id, decision });
  if (notifySeller) await reviews.notifyHeld(db, book);
  await notifyAdmins(db, book, decision.reasons);
};

const inFlight = new Set();

// AI 審核改在回應之後執行：上架不必等模型（含圖片判讀常需十幾秒），有疑慮時再撤下送審。
const applyLater = async (bookId, decision) => {
  if (decision.action === 'allow') return;
  const book = await prisma.books.findUnique({ where: { book_id: bookId } });
  if (!book || book.is_approved === false) return;

  const reject = decision.action === 'reject';
  await prisma.$transaction(async (tx) => {
    const row = await tx.books.update({
      where: { book_id: bookId },
      data: { is_approved: false, ...(reject && book.status === 'on_sale' && { status: 'removed' }), updated_at: new Date() }
    });
    if (!reject) {
      await hold(tx, row, decision);
      return;
    }
    await reviews.hold(tx, { bookId, decision });
    await tx.$executeRaw`UPDATE ai_book_reviews SET status = 'rejected', reviewed_at = ${new Date()} WHERE book_id = ${bookId}`;
    await notify(tx, {
      userId: row.seller_id,
      title: '書籍未通過上架審核',
      content: `您的書籍《${row.title}》未通過上架審核，已下架。原因：${decision.reasons.join('、')}。如有疑問請聯絡客服。`,
      relatedId: bookId,
      relatedType: 'book'
    });
  });
};

const screenLater = (book, files) => {
  const job = moderation.screen({ userId: book.seller_id, book, loadImages: () => aiImages.fromUploads(files) })
    .then((decision) => applyLater(book.book_id, decision))
    .catch((err) => console.error('[背景上架審核失敗]:', err.message))
    .finally(() => inFlight.delete(job));
  inFlight.add(job);
  return job;
};

const settled = () => Promise.all([...inFlight]);

module.exports = { PRICE_CEILING, SOURCE_PATTERN, ruleDecision, notifyAdmins, hold, screenLater, settled };
