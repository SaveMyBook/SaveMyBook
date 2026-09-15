const express = require('express');
const share = require('../services/share');
const legal = require('../services/legal');
const views = require('../views/public-page');
const legalViews = require('../views/legal-page');

const router = express.Router();

const LEGAL_PATHS = { terms: '/terms', privacy: '/privacy', about: '/about' };

const sendHtml = (res, status, html) => res.status(status).type('html').send(html);

const originOf = (req) => `${req.protocol}://${req.get('host')}`;

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
  const user = share.TOKEN_RE.test(token) ? await share.publicUserByToken(token) : null;
  if (!user) return sendHtml(res, 404, views.userNotFound());
  sendHtml(res, 200, views.userProfile({ origin: originOf(req), user, token }));
}));

router.get('/b/:token', htmlRoute('公開書籍頁失敗', async (req, res) => {
  const token = String(req.params.token || '');
  const book = share.TOKEN_RE.test(token) ? await share.publicBookByToken(token) : null;
  if (!book) return sendHtml(res, 404, views.bookNotFound());
  sendHtml(res, 200, views.bookDetail({ origin: originOf(req), book, token }));
}));

const legalRoute = (fixedKey) => htmlRoute('公開法律文件頁失敗', async (req, res) => {
  const key = fixedKey ?? String(req.params.key || '').toLowerCase();
  if (!legal.KEY_RE.test(key)) return sendHtml(res, 404, legalViews.legalNotFound());

  const docs = await legal.publishedDocs();
  const doc = docs.find((d) => d.doc_key === key);
  if (!doc || !String(doc.content ?? '').trim()) return sendHtml(res, 404, legalViews.legalNotFound());

  const links = docs
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
