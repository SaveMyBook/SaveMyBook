const prisma = require('../lib/prisma');

const CANDIDATE_LIMIT = 2000;
const CACHE_TTL_MS = 60 * 1000;
const CACHE_MAX = 200;
const DAY = 24 * 60 * 60 * 1000;

const cache = new Map();

const CONDITION_BONUS = { like_new: 0.2, good: 0.1 };

const log1p = (n) => Math.log(1 + Math.max(0, Number(n) || 0));

const countsBy = (rows, key = 'book_id') => new Map(rows.map((r) => [Number(r[key]), Number(r._count?._all ?? r.n ?? 0)]));

const categoryDemand = async (since) => {
  const rows = await prisma.$queryRaw`
    SELECT b.category_id, COUNT(*) AS n
    FROM order_items oi
    JOIN orders o ON o.order_id = oi.order_id
    JOIN books b ON b.book_id = oi.book_id
    WHERE o.created_at >= ${since} AND o.status NOT IN ('cancelled', 'refunded') AND b.category_id IS NOT NULL
    GROUP BY b.category_id`;
  return new Map(rows.map((r) => [Number(r.category_id), Number(r.n)]));
};

const RECOMMEND_LIMIT = 30;
const SIGNAL_TAKE = 200;
const signalSelect = { book_id: true, books: { select: { category_id: true, author: true } } };

const normAuthor = (author) => String(author ?? '').trim().toLowerCase();

const viewerSignals = async (viewerId, viewedIds = []) => {
  const [favorites, cart, purchases, viewed] = await Promise.all([
    viewerId
      ? prisma.favorites.findMany({ where: { user_id: viewerId }, orderBy: { created_at: 'desc' }, take: SIGNAL_TAKE, select: signalSelect })
      : [],
    viewerId
      ? prisma.shopping_cart.findMany({ where: { user_id: viewerId }, take: SIGNAL_TAKE, select: signalSelect })
      : [],
    viewerId
      ? prisma.order_items.findMany({ where: { orders: { buyer_id: viewerId } }, orderBy: { item_id: 'desc' }, take: SIGNAL_TAKE, select: signalSelect })
      : [],
    viewedIds.length > 0
      ? prisma.books.findMany({ where: { book_id: { in: viewedIds } }, select: { book_id: true, category_id: true, author: true } })
      : []
  ]);

  const seen = new Set();
  const categories = new Map();
  const authors = new Map();
  const authorNames = new Set();
  const add = (bookId, book, weight) => {
    if (!book) return;
    seen.add(Number(bookId));
    if (book.category_id) categories.set(book.category_id, (categories.get(book.category_id) ?? 0) + weight);
    const author = normAuthor(book.author);
    if (!author) return;
    authors.set(author, (authors.get(author) ?? 0) + weight);
    authorNames.add(String(book.author).trim());
  };
  favorites.forEach((f) => add(f.book_id, f.books, 2));
  purchases.forEach((p) => add(p.book_id, p.books, 3));
  cart.forEach((c) => add(c.book_id, c.books, 1));
  viewed.forEach((b) => add(b.book_id, b, 1));

  const total = [...categories.values()].reduce((sum, n) => sum + n, 0);
  const affinity = new Map([...categories].map(([id, n]) => [id, total > 0 ? n / total : 0]));
  return { seen, affinity, authors, authorNames: [...authorNames] };
};

const scoreBook = (book, signals, now) => {
  const id = book.book_id;
  const engagement = 1
    + 1.0 * log1p(book.view_count)
    + 3.0 * (signals.recentFavorites.get(id) ?? 0)
    + 1.2 * (book._count?.favorites ?? 0)
    + 2.0 * (book._count?.shopping_cart ?? 0)
    + 0.8 * (book._count?.chat_rooms ?? 0);

  const imageCount = book._count?.book_images ?? 0;
  const quality = 1 + (imageCount >= 3 ? 0.15 : imageCount === 0 ? -0.3 : 0) + (CONDITION_BONUS[book.condition_level] ?? 0);

  const ageDays = Math.max(0, (now - new Date(book.created_at).getTime()) / DAY);
  const freshness = 1 / (1 + ageDays / 14) ** 0.8;

  const demand = 1 + 0.1 * log1p(signals.demand.get(book.category_id) ?? 0);
  const personal = 1 + 0.6 * (signals.affinity.get(book.category_id) ?? 0);

  return engagement * quality * freshness * demand * personal;
};

const diversify = (sorted, { window = 10, perSeller = 2 } = {}) => {
  const out = [];
  const deferred = [];
  const recentCount = (sellerId) => out.slice(-window).filter((b) => b.seller_id === sellerId).length;

  for (const book of sorted) {
    while (deferred.length > 0 && recentCount(deferred[0].seller_id) < perSeller) out.push(deferred.shift());
    if (recentCount(book.seller_id) < perSeller) out.push(book);
    else deferred.push(book);
  }
  return out.concat(deferred);
};

const loadCandidates = (where) => prisma.books.findMany({
  where,
  orderBy: { created_at: 'desc' },
  take: CANDIDATE_LIMIT,
  select: {
    book_id: true, seller_id: true, category_id: true, author: true, view_count: true, created_at: true, condition_level: true,
    _count: { select: { favorites: true, shopping_cart: true, chat_rooms: true, book_images: true } }
  }
});

const baseSignals = async (ids, now) => {
  const [recentFavorites, demand] = await Promise.all([
    ids.length > 0
      ? prisma.favorites.groupBy({
          by: ['book_id'],
          where: { book_id: { in: ids }, created_at: { gte: new Date(now - 7 * DAY) } },
          _count: { _all: true }
        }).then((rows) => countsBy(rows))
      : new Map(),
    categoryDemand(new Date(now - 30 * DAY))
  ]);
  return { recentFavorites, demand, affinity: new Map() };
};

const rankedIds = async (where, viewerId) => {
  const key = JSON.stringify([where, viewerId ?? 0]);
  const hit = cache.get(key);
  if (hit && Date.now() - hit.at < CACHE_TTL_MS) return hit.ids;

  const now = Date.now();
  const candidates = await loadCandidates(viewerId ? { AND: [where, { seller_id: { not: viewerId } }] } : where);
  const signals = await baseSignals(candidates.map((b) => b.book_id), now);
  const scored = candidates
    .map((b) => ({ ...b, score: scoreBook(b, signals, now) }))
    .sort((a, b) => b.score - a.score || b.book_id - a.book_id);
  const ranked = diversify(scored).map((b) => b.book_id);

  if (cache.size >= CACHE_MAX) cache.delete(cache.keys().next().value);
  cache.set(key, { ids: ranked, at: now });
  return ranked;
};

const recommendedIds = async (viewerId, viewedIds = []) => {
  const now = Date.now();
  const { seen, affinity, authors, authorNames } = await viewerSignals(viewerId, viewedIds);
  if (affinity.size === 0 && authorNames.length === 0) return [];

  const candidates = await loadCandidates({
    status: 'on_sale',
    is_approved: true,
    ...(viewerId && { seller_id: { not: viewerId } }),
    ...(seen.size > 0 && { book_id: { notIn: [...seen] } }),
    OR: [
      ...(affinity.size > 0 ? [{ category_id: { in: [...affinity.keys()] } }] : []),
      ...(authorNames.length > 0 ? [{ author: { in: authorNames } }] : [])
    ]
  });

  const signals = await baseSignals(candidates.map((b) => b.book_id), now);
  const topAuthor = Math.max(1, ...authors.values());
  const scored = candidates
    .map((b) => ({
      ...b,
      score: scoreBook(b, signals, now) * (1 + (affinity.get(b.category_id) ?? 0) + 0.8 * ((authors.get(normAuthor(b.author)) ?? 0) / topAuthor))
    }))
    .sort((a, b) => b.score - a.score || b.book_id - a.book_id);
  return diversify(scored).map((b) => b.book_id).slice(0, RECOMMEND_LIMIT);
};

const viewSeen = new Map();
const VIEW_WINDOW_MS = 60 * 60 * 1000;

const shouldCountView = (bookId, viewerKey) => {
  const key = `${bookId}:${viewerKey}`;
  const at = viewSeen.get(key);
  const now = Date.now();
  if (at && now - at < VIEW_WINDOW_MS) return false;
  viewSeen.set(key, now);
  return true;
};

setInterval(() => {
  const now = Date.now();
  for (const [key, at] of viewSeen) if (now - at > VIEW_WINDOW_MS) viewSeen.delete(key);
}, 10 * 60 * 1000).unref();

module.exports = { rankedIds, recommendedIds, scoreBook, diversify, shouldCountView, RECOMMEND_LIMIT };
