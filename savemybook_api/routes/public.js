const express = require('express');
const prisma = require('../lib/prisma');

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
  .hint[hidden] { display: none; }
  @media (prefers-color-scheme: dark) {
    body { background: #121212; color: #e8e8e8; }
    .card { background: #1e1e1e; box-shadow: none; }
    .bio { color: #9e9e9e; }
    .avatar, .avatar-fallback { background: #2a2a2a; }
  }
</style>
</head>
<body><div class="card">${body}</div></body>
</html>`,
});

router.get('/u/:id', async (req, res) => {
  const userId = parseInt(req.params.id, 10);

  const notFound = page({
    title: '找不到使用者',
    status: 404,
    body: `
      <div class="brand">SaveMyBook</div>
      <div class="avatar-fallback">?</div>
      <h1>找不到這位使用者</h1>
      <p class="bio">這個連結可能已經失效，或帳號已被停用。</p>`,
  });

  if (!userId) {
    return res.status(notFound.status).type('html').send(notFound.html);
  }

  try {
    const user = await prisma.users.findUnique({
      where: { user_id: userId },
      select: {
        user_id: true,
        nickname: true,
        avatar_url: true,
        bio: true,
        created_at: true,
        is_active: true,
        is_blacklisted: true,
        _count: { select: { books: true } },
      },
    });

    if (!user || !user.is_active || user.is_blacklisted) {
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

module.exports = router;
