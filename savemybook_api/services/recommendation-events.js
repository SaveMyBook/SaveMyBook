const prisma = require('../lib/prisma');
const { notFound } = require('../lib/errors');

// 推薦的曝光、點擊與「不感興趣」。曝光在同一來源 6 小時內每本書只記一次（與 AI 推薦快取期限相同），
// 首頁重新整理不會重複計入；點擊只記在 7 日內最近一次曝光上。
const SOURCES = ['ai', 'rules'];
const IMPRESSION_WINDOW_MS = 6 * 60 * 60 * 1000;
const CLICK_WINDOW_MS = 7 * 24 * 60 * 60 * 1000;
const RETENTION_DAYS = 90;
const DAY_MS = 24 * 60 * 60 * 1000;
const MAX_IMPRESSIONS = 30;

const logImpressions = async (userId, bookIds, source, now = new Date()) => {
  if (!userId || !SOURCES.includes(source)) return 0;
  const ids = [...new Set(bookIds.map(Number).filter((n) => Number.isSafeInteger(n) && n > 0))].slice(0, MAX_IMPRESSIONS);
  if (ids.length === 0) return 0;
  const recent = await prisma.recommendation_logs.findMany({
    where: { user_id: userId, book_id: { in: ids }, source, created_at: { gte: new Date(now.getTime() - IMPRESSION_WINDOW_MS) } },
    select: { book_id: true }
  });
  const seen = new Set(recent.map((r) => Number(r.book_id)));
  const fresh = ids.filter((id) => !seen.has(id));
  if (fresh.length === 0) return 0;
  await prisma.recommendation_logs.createMany({
    data: fresh.map((bookId) => ({ user_id: userId, book_id: bookId, rec_type: 'personalized', source, created_at: now }))
  });
  return fresh.length;
};

// 背景記錄，失敗不影響推薦回應。
const logImpressionsSafely = (userId, bookIds, source) => logImpressions(userId, bookIds, source)
  .catch((err) => console.error('[推薦曝光紀錄寫入失敗]:', err.message));

// AI 推薦中只有附推薦理由或依據的書算 AI 推薦；模型沒有選上而補在後面的候選書與一般推薦同樣記為規則式。
// hiddenIds 為 App 端最近瀏覽的書，首頁不顯示，不記曝光。
const logServedSafely = (userId, items, { ai, hiddenIds = [] }) => {
  const hidden = new Set(hiddenIds.map(Number));
  const bySource = { ai: [], rules: [] };
  for (const item of items) {
    const bookId = Number(item.book?.book_id);
    if (hidden.has(bookId)) continue;
    bySource[ai && (item.reason || item.basis) ? 'ai' : 'rules'].push(bookId);
  }
  return Promise.all(Object.entries(bySource)
    .filter(([, ids]) => ids.length > 0)
    .map(([source, ids]) => logImpressionsSafely(userId, ids, source)));
};

const click = async (userId, bookId, now = new Date()) => {
  const latest = await prisma.recommendation_logs.findFirst({
    where: { user_id: userId, book_id: bookId, created_at: { gte: new Date(now.getTime() - CLICK_WINDOW_MS) } },
    orderBy: { created_at: 'desc' },
    select: { rec_id: true, is_clicked: true }
  });
  if (!latest || latest.is_clicked) return false;
  await prisma.recommendation_logs.update({ where: { rec_id: latest.rec_id }, data: { is_clicked: true, clicked_at: now } });
  return true;
};

const dismiss = async (userId, bookId) => {
  const exists = await prisma.books.count({ where: { book_id: bookId } });
  if (!exists) throw notFound('找不到該書籍', 'BOOK_NOT_FOUND');
  try {
    await prisma.recommendation_dismissals.create({ data: { user_id: userId, book_id: bookId, created_at: new Date() } });
  } catch (err) {
    if (err.code !== 'P2002') throw err;
  }
};

const dismissedIds = async (userId) => {
  if (!userId) return new Set();
  const rows = await prisma.recommendation_dismissals.findMany({ where: { user_id: userId }, select: { book_id: true } });
  return new Set(rows.map((r) => Number(r.book_id)));
};

const purgeExpired = async (now = new Date()) => {
  const { count } = await prisma.recommendation_logs.deleteMany({
    where: { created_at: { lt: new Date(now.getTime() - RETENTION_DAYS * DAY_MS) } }
  });
  return count;
};

const exportUser = async (userId) => {
  const [impressions, dismissals] = await Promise.all([
    prisma.recommendation_logs.findMany({
      where: { user_id: userId },
      orderBy: { created_at: 'asc' },
      select: { book_id: true, source: true, is_clicked: true, clicked_at: true, created_at: true }
    }),
    prisma.recommendation_dismissals.findMany({
      where: { user_id: userId },
      orderBy: { created_at: 'asc' },
      select: { book_id: true, created_at: true }
    })
  ]);
  return { impressions, not_interested: dismissals };
};

const purgeUser = async (tx, userId) => {
  await tx.recommendation_logs.deleteMany({ where: { user_id: userId } });
  await tx.recommendation_dismissals.deleteMany({ where: { user_id: userId } });
};

module.exports = {
  SOURCES, RETENTION_DAYS, logImpressions, logImpressionsSafely, logServedSafely, click, dismiss, dismissedIds, purgeExpired, exportUser,
  purgeUser
};
