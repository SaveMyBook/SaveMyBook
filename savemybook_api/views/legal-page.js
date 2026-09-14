const { escapeHtml } = require('../lib/html');

const HEADING_PATTERNS = [
  /^\s*\d{1,3}\s*(?:[.．](?!\d)|[、)）])\s*\S.*$/,
  /^\s*第\s*[0-9零〇一二三四五六七八九十百兩]+\s*[條条章節节]\s*[、.．:：]?\s*\S.*$/,
  /^\s*[一二三四五六七八九十]+\s*、\s*\S.*$/
];

const isHeading = (line) => line.length <= 80 && HEADING_PATTERNS.some((re) => re.test(line));

const dateFormat = new Intl.DateTimeFormat('zh-TW', { timeZone: 'Asia/Taipei', year: 'numeric', month: 'long', day: 'numeric' });

const STYLE = `
  :root { color-scheme: light dark; --bg: #f3f5f7; --card: #fff; --text: #151e27; --muted: #5b6770; --accent: #627d8d; --line: #e3e8ec; }
  @media (prefers-color-scheme: dark) {
    :root { --bg: #121212; --card: #1e1e1e; --text: #e8e8e8; --muted: #9e9e9e; --accent: #8fa9b8; --line: #2c2c2c; }
  }
  * { box-sizing: border-box; }
  body {
    margin: 0; background: var(--bg); color: var(--text);
    font-family: -apple-system, BlinkMacSystemFont, "PingFang TC", "Noto Sans TC", "Microsoft JhengHei", sans-serif;
    line-height: 1.8; -webkit-text-size-adjust: 100%;
  }
  header { background: var(--accent); color: #fff; padding: 28px 20px 36px; }
  header .inner, main, footer { max-width: 760px; margin: 0 auto; }
  .brand { font-size: 13px; font-weight: 700; letter-spacing: .5px; opacity: .85; }
  h1 { font-size: 26px; line-height: 1.35; margin: 8px 0 6px; }
  .meta { font-size: 13px; opacity: .85; }
  main { background: var(--card); margin-top: -18px; border-radius: 20px; padding: 28px 24px; box-shadow: 0 8px 32px rgba(0,0,0,.06); }
  h2 { font-size: 17px; margin: 28px 0 8px; padding-top: 4px; }
  h2:first-child { margin-top: 0; }
  p { margin: 0 0 12px; white-space: pre-wrap; word-break: break-word; }
  nav { display: flex; flex-wrap: wrap; gap: 8px 16px; margin: 20px auto 0; padding: 0 24px; max-width: 760px; }
  nav a { color: var(--accent); text-decoration: none; font-size: 14px; font-weight: 600; }
  nav a[aria-current="page"] { color: var(--muted); pointer-events: none; }
  footer { color: var(--muted); font-size: 12px; padding: 16px 24px 40px; }
  @media print {
    header { background: none; color: #000; padding: 0 0 12px; }
    main { box-shadow: none; margin: 0; padding: 0; }
    nav { display: none; }
  }
`;

const renderContent = (content) => {
  const blocks = String(content ?? '').replace(/\r\n?/g, '\n').split(/\n{2,}/);
  const html = [];
  for (const block of blocks) {
    const lines = block.split('\n');
    let buffer = [];
    const flush = () => {
      if (buffer.length) html.push(`<p>${escapeHtml(buffer.join('\n'))}</p>`);
      buffer = [];
    };
    for (const line of lines) {
      if (!line.trim()) continue;
      if (isHeading(line)) {
        flush();
        html.push(`<h2>${escapeHtml(line.trim())}</h2>`);
      } else {
        buffer.push(line);
      }
    }
    flush();
  }
  return html.join('\n');
};

const legalPage = ({ doc, version, links }) => `<!doctype html>
<html lang="zh-Hant">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escapeHtml(doc.title)}｜救「舊」我的書</title>
<meta name="description" content="救「舊」我的書${escapeHtml(doc.title)}">
<style>${STYLE}</style>
</head>
<body>
<header><div class="inner">
  <div class="brand">救「舊」我的書</div>
  <h1>${escapeHtml(doc.title)}</h1>
  <div class="meta">最後更新：${escapeHtml(dateFormat.format(new Date(doc.updated_at)))}${version ? `　版本 ${Number(version)}` : ''}</div>
</div></header>
<nav>${links.map((l) => `<a href="${escapeHtml(l.href)}"${l.current ? ' aria-current="page"' : ''}>${escapeHtml(l.title)}</a>`).join('')}</nav>
<main>
${renderContent(doc.content)}
</main>
<footer>© ${new Date().getFullYear()} 救「舊」我的書</footer>
</body>
</html>`;

const legalNotFound = () => `<!doctype html>
<html lang="zh-Hant"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>找不到文件｜救「舊」我的書</title><style>${STYLE}</style></head>
<body><header><div class="inner"><div class="brand">救「舊」我的書</div><h1>找不到此文件</h1></div></header>
<main><p>此文件不存在或尚未發布。</p></main></body></html>`;

module.exports = { legalPage, legalNotFound, renderContent, isHeading };
