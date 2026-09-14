const express = require('express');
const prisma = require('../lib/prisma');
const { TOKEN_RE } = require('../services/share');
const views = require('../views/public-page');
const legalViews = require('../views/legal-page');
const legal = require('../services/legal');

const router = express.Router();

const sendHtml = (res, status, html) => res.status(status).type('html').send(html);

const isVisibleUser = (user) => user && user.is_active && !user.is_blacklisted && !user.anonymized_at;

const htmlRoute = (label, handler) => async (req, res) => {
  try {
    await handler(req, res);
  } catch (err) {
    console.error(`[${label}]:`, err);
    sendHtml(res, 500, views.errorPage());
  }
};

router.get('/u/:token', htmlRoute('公開個人頁失敗', async (req, res) => {
  const token = String(req.params.token || '');
  if (!TOKEN_RE.test(token)) return sendHtml(res, 404, views.userNotFound());

  const user = await prisma.users.findFirst({
    where: { share_token: token },
    select: {
      user_id: true,
      nickname: true,
      avatar_url: true,
      bio: true,
      created_at: true,
      is_active: true,
      is_blacklisted: true,
      anonymized_at: true,
      _count: { select: { books: true } }
    }
  });

  if (!isVisibleUser(user)) return sendHtml(res, 404, views.userNotFound());

  const origin = `${req.protocol}://${req.get('host')}`;
  sendHtml(res, 200, views.userProfile({ origin, user, token }));
}));

router.get('/b/:token', htmlRoute('公開書籍頁失敗', async (req, res) => {
  const token = String(req.params.token || '');
  if (!TOKEN_RE.test(token)) return sendHtml(res, 404, views.bookNotFound());

  const book = await prisma.books.findFirst({
    where: { share_token: token },
    select: {
      book_id: true,
      title: true,
      author: true,
      price: true,
      status: true,
      condition_level: true,
      book_categories: { select: { category_name: true } },
      book_images: { select: { image_url: true }, orderBy: { image_id: 'asc' }, take: 1 },
      users: {
        select: { nickname: true, avatar_url: true, is_active: true, is_blacklisted: true, anonymized_at: true }
      }
    }
  });

  if (!book || book.status === 'removed' || !isVisibleUser(book.users)) {
    return sendHtml(res, 404, views.bookNotFound());
  }

  const origin = `${req.protocol}://${req.get('host')}`;
  sendHtml(res, 200, views.bookDetail({ origin, book, token }));
}));

const LEGAL_PATHS = { terms: '/terms', privacy: '/privacy', about: '/about' };

const legalRoute = (fixedKey) => htmlRoute('公開法律文件頁失敗', async (req, res) => {
  const key = fixedKey ?? String(req.params.key || '').toLowerCase();
  if (!/^[a-z0-9_-]{1,50}$/.test(key)) return sendHtml(res, 404, legalViews.legalNotFound());

  const docs = await prisma.legal_documents.findMany({
    select: { doc_id: true, doc_key: true, title: true, content: true, updated_at: true },
    orderBy: { doc_id: 'asc' }
  });
  const withMeta = await legal.withMeta(docs);
  const doc = withMeta.find((d) => d.doc_key === key);
  if (!doc || !String(doc.content ?? '').trim()) return sendHtml(res, 404, legalViews.legalNotFound());

  const links = withMeta
    .filter((d) => String(d.content ?? '').trim())
    .map((d) => ({ href: LEGAL_PATHS[d.doc_key] ?? `/legal/${encodeURIComponent(d.doc_key)}`, title: d.title, current: d.doc_key === key }));

  res.set('Cache-Control', 'public, max-age=300');
  sendHtml(res, 200, legalViews.legalPage({ doc, version: doc.version, links }));
});

router.get('/terms', legalRoute('terms'));
router.get('/privacy', legalRoute('privacy'));
router.get('/about', legalRoute('about'));
router.get('/legal/:key', legalRoute(null));

module.exports = router;
