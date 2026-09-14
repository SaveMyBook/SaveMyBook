const express = require('express');
const prisma = require('../lib/prisma');
const { TOKEN_RE } = require('../services/share');
const views = require('../views/public-page');

const router = express.Router();

const sendHtml = (res, status, html) => res.status(status).type('html').send(html);

const isVisibleUser = (user) => user && user.is_active && !user.is_blacklisted && !user.anonymized_at;

/// 公開頁是給瀏覽器看的，錯誤也要回 HTML，不能丟給 JSON 錯誤處理器。
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
  sendHtml(res, 200, views.userProfile({ origin, user }));
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
  sendHtml(res, 200, views.bookDetail({ origin, book }));
}));

module.exports = router;
