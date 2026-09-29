const prisma = require('../lib/prisma');
const moderation = require('./ai/moderation');
const reviews = require('./ai/reviews');
const aiImages = require('./ai/images');
const { risksIn } = require('./ai/text');
const { adminIdsWith } = require('./admin-permissions');
const { notify, notifyMany } = require('./notify');
const deposits = require('./book-deposits');
const { LISTING_REVIEW_PRICE } = require('../constants/policy');

const PRICE_CEILING = LISTING_REVIEW_PRICE;
const PEER_RATIO = 3;
const PEER_MARGIN = 300;
// 描述或書況說明出現強證據詞才直接送人工審核；只出現在書名或只命中弱詞時交給 AI 判斷，
// 否則《圖書館戰爭》、附 PDF 講義這類一般書會被直接送審，管理員也拿不到 AI 的第二意見。
const MARK_TERMS = '館藏(?:章|印|條碼|標籤|貼紙|編號)|索書號|影印本|(?:圖書館|圖書室)(?:淘汰|報廢)';
// 「無館藏章、索書號」「正版，非影印本」是常見的書況說明：否定詞後的強證據詞（含以頓號、及、與並列者）降為弱詞交給 AI。
// 除籍不適用，「未除籍」「無除籍章」反而表示書可能仍屬館藏。
const NEGATED = `(?:無|非|沒有|不是|未|並無|並非)\\s*(?:任何)?\\s*(?:(?:${MARK_TERMS})\\s*[、及與和或/]\\s*)*`;
const STRONG_SOURCE = new RegExp(`除籍|(?<!${NEGATED})(?:${MARK_TERMS})`);
const NEGATED_SOURCE = new RegExp(`${NEGATED}(?:${MARK_TERMS})`);
const WEAK_SOURCE = /圖書館|圖書室|館藏|借閱|公播|非賣品|贈閱|樣書|試讀本|公關書|盜版|翻印|掃描檔|電子檔|\bpdf\b/i;
const SOURCE_FIELDS = [['title', '書名'], ['description', '描述'], ['condition_note', '書況說明']];
// 詐騙與驗證碼類別不列入，聯絡方式與付款只認實際的識別字串：理財、資安、行銷書的書名常出現「高報酬」「存款帳戶」「IG 帳號」等字詞。
const CONTACT_RISKS = { categories: ['contact', 'payment', 'offsite', 'link'], identifiersOnly: true, bareDomains: 'strong' };

const RECHECK_AFTER_MS = 15 * 60 * 1000;
const RECHECK_GAP_MS = 10 * 60 * 1000;
const RECHECK_BATCH = 20;
const MAX_ATTEMPTS = 3;
const RETRY_HOLD_REASON = 'AI 審核多次無法完成，需要人工確認';

const sourceHint = (book) => {
  for (const [field, label] of SOURCE_FIELDS) {
    const text = String(book[field] ?? '');
    const word = (STRONG_SOURCE.exec(text) ?? NEGATED_SOURCE.exec(text) ?? WEAK_SOURCE.exec(text))?.[0];
    if (word) return `規則提示（僅供參考，可能誤判）：${label}含「${word}」，請確認是否為圖書館館藏或非正規來源書籍。`;
  }
  return null;
};

// 只命中弱詞而 AI 無法使用時仍直接送審，否則這類書會在完全沒有審核的情況下公開。
const ruleDecision = async (book) => {
  const reasons = [];
  const categories = [];

  const price = Number(book.price);
  const peer = await moderation.peerPrice(book);
  if (peer != null && price >= Math.max(peer * PEER_RATIO, peer + PEER_MARGIN)) {
    reasons.push(`售價明顯高於站上同書行情（約 ${Math.round(peer)} 代幣）`);
    categories.push('price');
  } else if (price >= PRICE_CEILING) {
    reasons.push(`售價 ${price} 代幣明顯高於一般二手書行情`);
    categories.push('price');
  }

  const hint = sourceHint(book);
  const detail = [book.description, book.condition_note].filter(Boolean).join('\n');
  if (STRONG_SOURCE.test(detail) || (hint && !(await moderation.available()))) {
    reasons.push(moderation.CATEGORY_LABELS.source);
    categories.push('source');
  }

  const text = [book.title, book.author, book.publisher, book.description, book.condition_note].filter(Boolean).join('\n');
  if (risksIn(text, CONTACT_RISKS).length > 0) {
    reasons.push(moderation.CATEGORY_LABELS.contact);
    categories.push('contact');
  }

  const decision = reasons.length
    ? { action: 'review', verdict: 'review', confidence: 1, reasons, categories, provider: null, model: 'rules' }
    : null;
  return { decision, hint, peer };
};

// 售價達到這個金額就會被上面的價格規則送人工審核；AI 建議價必須低於它。
const reviewPriceLimit = async (isbn) => {
  const peer = isbn ? await moderation.peerPrice({ isbn }) : null;
  return peer != null ? Math.max(peer * PEER_RATIO, peer + PEER_MARGIN) : PRICE_CEILING;
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

// 封面加上最新加入的照片：新增照片時 AI 失敗的書，補審與之後的編輯審核才看得到那幾張，而不是只看最早上傳的幾張。
const storedImages = async (bookId, max) => {
  const urls = (await prisma.book_images.findMany({
    where: { book_id: bookId },
    orderBy: { image_id: 'asc' },
    select: { image_url: true }
  })).map((i) => i.image_url);
  return aiImages.fromUrls([...urls.slice(0, 1), ...urls.slice(1).reverse()], max);
};

const inFlight = new Set();

// AI 審核改在回應之後執行：上架不必等模型（含圖片判讀常需十幾秒），有疑慮時再撤下送審。
// 補審時書可能已售出或被管理員處理，onSaleOnly 只處理仍在販售中的書。
const applyLater = async (bookId, decision, { onSaleOnly = false } = {}) => {
  if (decision.action === 'allow') return;
  const book = await prisma.books.findUnique({ where: { book_id: bookId } });
  if (!book || book.is_approved === false || (onSaleOnly && book.status !== 'on_sale')) return;

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
    await deposits.releaseAutoPause(tx, bookId);
    await reviews.hold(tx, { bookId, decision, status: 'rejected' });
    await notify(tx, {
      userId: row.seller_id,
      title: '書籍未通過上架審核',
      content: `您的書籍《${row.title}》未通過上架審核，已下架。原因：${decision.reasons.join('、')}。如有疑問請聯絡客服。`,
      relatedId: bookId,
      relatedType: 'book'
    });
  });
};

// 同一本書一再因本身的原因無法完成（輸出無法解析、服務商不接受請求），可能是內容刻意干擾審核，改送人工而不是無限重試。
const conclude = async (bookId, decision, { retry = false, since } = {}) => {
  await reviews.mark(prisma, bookId, decision, { retry, since });
  if (retry && decision.skipped && !decision.outage) {
    const marker = await reviews.markerOf(prisma, bookId);
    if (marker?.status === 'skipped' && marker.attempts >= MAX_ATTEMPTS) {
      const manual = {
        action: 'review', verdict: 'review', confidence: null, reasons: [RETRY_HOLD_REASON], categories: [], ...decision.attempted
      };
      await applyLater(bookId, manual, { onSaleOnly: true });
      return;
    }
  }
  await applyLater(bookId, decision, { onSaleOnly: retry });
};

// held：已由規則送審的書只把 AI 判定附在審核紀錄上，不改變書的狀態。
const screenLater = (book, files, { hint = null, peer, held = false } = {}) => {
  const loadImages = (max) => (files.length ? aiImages.fromUploads(files, max) : storedImages(book.book_id, max));
  const job = moderation.screen({ userId: book.seller_id, book, hint, peer, loadImages })
    .then((decision) => (held
      ? reviews.attachOpinion(prisma, book.book_id, decision)
      : conclude(book.book_id, decision, { since: null })))
    .catch((err) => console.error('[背景上架審核失敗]:', err.message))
    .finally(() => inFlight.delete(job));
  inFlight.add(job);
  return job;
};

const settled = () => Promise.all([...inFlight]);

// 補審放行但未審的書，以及超過 15 分鐘仍沒有任何審核紀錄的書（背景審核會在伺服器重啟時遺失）。
// 服務中斷或預算用盡時整批停止等下一輪，避免每本書各等一次逾時；只影響單一本書的失敗則跳過這本繼續。
const recheckDue = async (now = new Date()) => {
  if (!(await moderation.available())) return 0;
  const due = await reviews.dueForRecheck(now, { afterMs: RECHECK_AFTER_MS, gapMs: RECHECK_GAP_MS, take: RECHECK_BATCH });
  let done = 0;
  for (const { book, since } of due) {
    const decision = await moderation.screen({
      userId: book.seller_id,
      book,
      hint: sourceHint(book),
      loadImages: (max) => storedImages(book.book_id, max)
    });
    await conclude(book.book_id, decision, { retry: true, since });
    if (decision.outage) break;
    if (!decision.skipped) done += 1;
  }
  return done;
};

module.exports = {
  PRICE_CEILING, RETRY_HOLD_REASON, sourceHint, ruleDecision, reviewPriceLimit, notifyAdmins, hold, storedImages, screenLater, settled, recheckDue
};
