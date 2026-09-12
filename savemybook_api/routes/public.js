const express = require('express');
const prisma = require('../lib/prisma');
const { TOKEN_RE } = require('../lib/share');

const router = express.Router();

const escapeHtml = (value) =>
  String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');

const page = ({ title, body, status = 200 }) => ({
  status,
  html: `<!doctype html>
<html lang="zh-Hant">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escapeHtml(title)}｜SaveMyBook</title>
<style>
  :root { color-scheme: light dark; }
  * { box-sizing: border-box; }
  body {
    margin: 0; min-height: 100vh; display: flex; align-items: center; justify-content: center;
    background: #f3f5f7; color: #151e27; padding: 24px;
    font-family: -apple-system, BlinkMacSystemFont, "PingFang TC", "Noto Sans TC", sans-serif;
  }
  .card {
    background: #fff; border-radius: 20px; padding: 32px 28px; width: 100%; max-width: 360px;
    text-align: center; box-shadow: 0 8px 32px rgba(0,0,0,.08);
  }
  .avatar {
    width: 96px; height: 96px; border-radius: 50%; object-fit: cover; margin: 0 auto 16px;
    display: block; background: #e8ecef;
  }
  .avatar-fallback {
    width: 96px; height: 96px; border-radius: 50%; margin: 0 auto 16px; background: #e8ecef;
    display: flex; align-items: center; justify-content: center; font-size: 40px; color: #90a4ae;
  }
  h1 { font-size: 22px; margin: 0 0 6px; }
  .bio { color: #5b6770; font-size: 14px; line-height: 1.6; margin: 0 0 20px; white-space: pre-wrap; }
  .meta { color: #90a4ae; font-size: 12px; margin: 0 0 24px; }
  .brand { color: #627d8d; font-weight: 700; letter-spacing: .5px; font-size: 13px; margin-bottom: 20px; }
  a.btn {
    display: block; background: #627d8d; color: #fff; text-decoration: none;
    padding: 14px; border-radius: 14px; font-weight: 700; border: 0; width: 100%;
    font-size: 15px; font-family: inherit; cursor: pointer;
  }
  .hint { color: #90a4ae; font-size: 12px; line-height: 1.6; margin: 14px 0 0; }
  .cover {
    width: 150px; height: 210px; object-fit: cover; border-radius: 12px; display: block;
    margin: 0 auto 18px; background: #e8ecef; box-shadow: 0 4px 16px rgba(0,0,0,.12);
  }
  .cover-fallback {
    width: 150px; height: 210px; border-radius: 12px; margin: 0 auto 18px; background: #e8ecef;
    display: flex; align-items: center; justify-content: center; font-size: 44px; color: #90a4ae;
  }
  .price { font-size: 28px; font-weight: 800; color: #627d8d; margin: 0 0 4px; }
  .tags { display: flex; gap: 6px; justify-content: center; flex-wrap: wrap; margin: 0 0 16px; }
  .tag {
    font-size: 11px; font-weight: 700; padding: 4px 10px; border-radius: 999px;
    background: #eef1f3; color: #5b6770;
  }
  .tag.sold { background: #fbe9e7; color: #c0392b; }
  .seller { display: flex; align-items: center; justify-content: center; gap: 8px; margin: 0 0 20px; }
  .seller img, .seller div.ph {
    width: 26px; height: 26px; border-radius: 50%; object-fit: cover; background: #e8ecef;
    display: flex; align-items: center; justify-content: center; font-size: 12px; color: #90a4ae;
  }
  .seller span { color: #5b6770; font-size: 13px; }
  .hint[hidden] { display: none; }
  @media (prefers-color-scheme: dark) {
    body { background: #121212; color: #e8e8e8; }
    .card { background: #1e1e1e; box-shadow: none; }
    .bio { color: #9e9e9e; }
    .avatar, .avatar-fallback, .cover, .cover-fallback, .seller img, .seller div.ph { background: #2a2a2a; }
    .tag { background: #2a2a2a; color: #b0b0b0; }
    .seller span { color: #9e9e9e; }
  }
</style>
</head>
<body><div class="card">${body}</div></body>
</html>`,
});

router.get('/u/:token', async (req, res) => {
  const token = String(req.params.token || '');

  const notFound = page({
    title: '找不到使用者',
    status: 404,
    body: `
      <div class="brand">SaveMyBook</div>
      <div class="avatar-fallback">?</div>
      <h1>找不到這位使用者</h1>
      <p class="bio">這個連結可能已經失效，或帳號已被停用。</p>`,
  });

  if (!TOKEN_RE.test(token)) {
    return res.status(notFound.status).type('html').send(notFound.html);
  }

  try {
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
        _count: { select: { books: true } },
      },
    });

    if (!user || !user.is_active || user.is_blacklisted || user.anonymized_at) {
      return res.status(notFound.status).type('html').send(notFound.html);
    }

    const origin = `${req.protocol}://${req.get('host')}`;
    const avatar = user.avatar_url
      ? `<img class="avatar" src="${escapeHtml(
          user.avatar_url.startsWith('http') ? user.avatar_url : origin + user.avatar_url
        )}" alt="">`
      : `<div class="avatar-fallback">${escapeHtml(user.nickname.slice(0, 1))}</div>`;

    const joined = new Date(user.created_at).toLocaleDateString('zh-TW');

    const result = page({
      title: user.nickname,
      body: `
        <div class="brand">SaveMyBook</div>
        ${avatar}
        <h1>${escapeHtml(user.nickname)}</h1>
        <p class="bio">${escapeHtml(user.bio || '這個人很懶，什麼都沒留下')}</p>
        <p class="meta">上架 ${user._count.books} 本書 ・ ${escapeHtml(joined)} 加入</p>
        <button class="btn" id="open-app">在 App 中開啟</button>
        <p class="hint" id="hint" hidden>
          沒有反應嗎？請先安裝 SaveMyBook App，<br>或在 App 的「分享檔案」裡直接掃描這個 QR Code。
        </p>
        <script>
          (function () {
            var scheme = 'savemybook://user/${user.user_id}';
            document.getElementById('open-app').addEventListener('click', function () {
              var hint = document.getElementById('hint');
              var left = false;
              function onHide() { if (document.hidden) left = true; }
              document.addEventListener('visibilitychange', onHide);
              window.location.href = scheme;
              setTimeout(function () {
                document.removeEventListener('visibilitychange', onHide);
                if (!left) hint.hidden = false;
              }, 1500);
            });
          })();
        </script>`,
    });

    res.status(200).type('html').send(result.html);
  } catch (err) {
    console.error('[公開個人頁失敗]:', err);
    const error = page({
      title: '發生錯誤',
      status: 500,
      body: `
        <div class="brand">SaveMyBook</div>
        <h1>暫時無法載入</h1>
        <p class="bio">請稍後再試一次。</p>`,
    });
    res.status(error.status).type('html').send(error.html);
  }
});

const CONDITION_TEXT = {
  like_new: '近全新',
  good: '良好',
  fair: '普通',
  poor: '待修補'
};

router.get('/b/:token', async (req, res) => {
  const token = String(req.params.token || '');

  const notFound = page({
    title: '找不到書籍',
    status: 404,
    body: `
      <div class="brand">SaveMyBook</div>
      <div class="cover-fallback">?</div>
      <h1>找不到這本書</h1>
      <p class="bio">這個連結可能已經失效，或書籍已經下架。</p>`,
  });

  if (!TOKEN_RE.test(token)) {
    return res.status(notFound.status).type('html').send(notFound.html);
  }

  try {
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

    const seller = book?.users;
    if (!book || book.status === 'removed' || !seller || !seller.is_active ||
        seller.is_blacklisted || seller.anonymized_at) {
      return res.status(notFound.status).type('html').send(notFound.html);
    }

    const origin = `${req.protocol}://${req.get('host')}`;
    const absolute = (url) => (url.startsWith('http') ? url : origin + url);

    const image = book.book_images[0]?.image_url;
    const cover = image
      ? `<img class="cover" src="${escapeHtml(absolute(image))}" alt="">`
      : '<div class="cover-fallback">📚</div>';

    const avatar = seller.avatar_url
      ? `<img src="${escapeHtml(absolute(seller.avatar_url))}" alt="">`
      : `<div class="ph">${escapeHtml(seller.nickname.slice(0, 1))}</div>`;

    const sold = book.status !== 'on_sale';
    const tags = [
      book.book_categories?.category_name
        ? `<span class="tag">${escapeHtml(book.book_categories.category_name)}</span>`
        : '',
      `<span class="tag">${escapeHtml(CONDITION_TEXT[book.condition_level] || book.condition_level)}</span>`,
      sold ? '<span class="tag sold">已售出／保留中</span>' : '',
    ].join('');

    const result = page({
      title: book.title,
      body: `
        <div class="brand">SaveMyBook</div>
        ${cover}
        <h1>${escapeHtml(book.title)}</h1>
        <p class="bio">${escapeHtml(book.author || '')}</p>
        <p class="price">$${escapeHtml(Number(book.price).toFixed(0))}</p>
        <div class="tags">${tags}</div>
        <div class="seller">${avatar}<span>${escapeHtml(seller.nickname)}</span></div>
        <button class="btn" id="open-app">在 App 中開啟</button>
        <p class="hint" id="hint" hidden>
          沒有反應嗎？請先安裝 SaveMyBook App，再重新點一次這個連結。
        </p>
        <script>
          (function () {
            var scheme = 'savemybook://book/${book.book_id}';
            document.getElementById('open-app').addEventListener('click', function () {
              var hint = document.getElementById('hint');
              var left = false;
              function onHide() { if (document.hidden) left = true; }
              document.addEventListener('visibilitychange', onHide);
              window.location.href = scheme;
              setTimeout(function () {
                document.removeEventListener('visibilitychange', onHide);
                if (!left) hint.hidden = false;
              }, 1500);
            });
          })();
        </script>`,
    });

    res.status(200).type('html').send(result.html);
  } catch (err) {
    console.error('[公開書籍頁失敗]:', err);
    const error = page({
      title: '發生錯誤',
      status: 500,
      body: `
        <div class="brand">SaveMyBook</div>
        <h1>暫時無法載入</h1>
        <p class="bio">請稍後再試一次。</p>`,
    });
    res.status(error.status).type('html').send(error.html);
  }
});

module.exports = router;
