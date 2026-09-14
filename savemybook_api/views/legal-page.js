const { escapeHtml } = require('../lib/html');

const HEADING_PATTERNS = [
  /^\s*第\s*[0-9零〇一二三四五六七八九十百兩]+\s*[條条章節节]\s*[、.．:：]?\s*\S.*$/,
  /^\s*[一二三四五六七八九十]+\s*、\s*\S.*$/,
  /^\s*\d{1,3}\s*(?:[.．](?!\d)|[、)）])\s*\S.*$/
];

const headingPatternFor = (lines) => HEADING_PATTERNS.find((re) => lines.some((line) => line.length <= 80 && re.test(line))) ?? null;

const isHeading = (line, pattern = null) =>
  line.length <= 80 && (pattern ? pattern.test(line) : HEADING_PATTERNS.some((re) => re.test(line)));

const dateFormat = new Intl.DateTimeFormat('zh-TW', { timeZone: 'Asia/Taipei', year: 'numeric', month: 'long', day: 'numeric' });

const STYLE = `
  :root {
    color-scheme: light dark;
    --bg: #f3f5f7; --card: #ffffff; --text: #151e27; --muted: #5b6770; --soft: #8a969e;
    --accent: #627d8d; --accent-ink: #ffffff; --line: #e4e9ed; --chip: rgba(255,255,255,.16); --hero: #627d8d;
  }
  @media (prefers-color-scheme: dark) {
    :root { --bg: #121212; --card: #1c1c1c; --text: #e8e8e8; --muted: #a3a3a3; --soft: #7a7a7a; --accent: #8fa9b8; --accent-ink: #10171b; --line: #2b2b2b; --chip: rgba(255,255,255,.1); --hero: #1a2f38; }
  }
  *, *::before, *::after { box-sizing: border-box; }
  html { -webkit-text-size-adjust: 100%; scroll-behavior: smooth; }
  body {
    margin: 0; background: var(--bg); color: var(--text);
    font-family: -apple-system, BlinkMacSystemFont, "PingFang TC", "Noto Sans TC", "Microsoft JhengHei", sans-serif;
    font-size: 16px; line-height: 1.85;
  }
  .container { width: 100%; max-width: 820px; margin: 0 auto; padding: 0 clamp(16px, 4vw, 32px); }
  .hero { background: var(--hero); color: #fff; padding: clamp(28px, 6vw, 56px) 0 clamp(64px, 9vw, 88px); }
  .brand { display: inline-block; font-size: 13px; font-weight: 700; letter-spacing: .06em; opacity: .9; }
  .hero h1 { font-size: clamp(24px, 4.6vw, 36px); line-height: 1.3; margin: 10px 0 8px; font-weight: 800; }
  .meta { font-size: 13.5px; opacity: .88; display: flex; flex-wrap: wrap; gap: 4px 16px; }
  .tabs {
    display: flex; gap: 8px; margin-top: 22px; overflow-x: auto; scrollbar-width: none;
    -webkit-overflow-scrolling: touch; padding-bottom: 2px;
  }
  .tabs::-webkit-scrollbar { display: none; }
  .tabs a {
    flex: none; color: #fff; text-decoration: none; font-size: 14px; font-weight: 600;
    padding: 7px 14px; border-radius: 999px; background: var(--chip); white-space: nowrap;
    transition: background .15s ease;
  }
  .tabs a:hover { background: rgba(255,255,255,.26); }
  .tabs a[aria-current="page"] { background: #fff; color: #33434c; }
  .sheet { margin-top: calc(-1 * clamp(40px, 6vw, 56px)); }
  .doc {
    background: var(--card); border-radius: clamp(16px, 3vw, 24px);
    padding: clamp(22px, 5vw, 48px); box-shadow: 0 10px 40px rgba(15, 30, 40, .08);
  }
  .toc { border: 1px solid var(--line); border-radius: 14px; padding: 14px 18px; margin: 0 0 28px; }
  .toc strong { display: block; font-size: 13px; color: var(--muted); margin-bottom: 6px; letter-spacing: .04em; }
  .toc ol { margin: 0; padding-left: 0; list-style: none; columns: 2 240px; column-gap: 24px; }
  .toc li { break-inside: avoid; padding: 2px 0; }
  .toc a { color: var(--accent); text-decoration: none; font-size: 14.5px; line-height: 1.6; }
  .toc a:hover { text-decoration: underline; }
  .doc h2 {
    font-size: clamp(17px, 2.4vw, 20px); line-height: 1.45; margin: 36px 0 10px; padding-top: 18px;
    border-top: 1px solid var(--line); scroll-margin-top: 16px;
  }
  .doc h2:first-of-type { border-top: 0; padding-top: 0; }
  .toc + h2 { margin-top: 0; }
  .doc p { margin: 0 0 14px; white-space: pre-wrap; overflow-wrap: anywhere; color: var(--text); }
  .doc > :last-child { margin-bottom: 0; }
  footer.container { color: var(--soft); font-size: 12.5px; padding-top: 28px; padding-bottom: 48px; text-align: center; }
  @media (max-width: 480px) {
    body { font-size: 15px; line-height: 1.8; }
    .toc ol { columns: 1; }
  }
  @media print {
    body { background: #fff; color: #000; }
    .hero { background: none; color: #000; padding: 0 0 12px; }
    .tabs, .toc { display: none; }
    .sheet { margin: 0; }
    .doc { box-shadow: none; padding: 0; }
  }
`;

const renderContent = (content) => {
  const normalized = String(content ?? '').replace(/\r\n?/g, '\n');
  const pattern = headingPatternFor(normalized.split('\n'));
  const blocks = normalized.split(/\n{2,}/);
  const parts = [];
  const headings = [];
  for (const block of blocks) {
    let buffer = [];
    const flush = () => {
      if (buffer.length) parts.push(`<p>${escapeHtml(buffer.join('\n'))}</p>`);
      buffer = [];
    };
    for (const line of block.split('\n')) {
      if (!line.trim()) continue;
      if (pattern && isHeading(line, pattern)) {
        flush();
        const id = `section-${headings.length + 1}`;
        headings.push({ id, text: line.trim() });
        parts.push(`<h2 id="${id}">${escapeHtml(line.trim())}</h2>`);
      } else {
        buffer.push(line);
      }
    }
    flush();
  }

  const toc = headings.length >= 3
    ? `<nav class="toc" aria-label="目錄"><strong>目錄</strong><ol>${headings
      .map((h) => `<li><a href="#${h.id}">${escapeHtml(h.text)}</a></li>`)
      .join('')}</ol></nav>`
    : '';
  return toc + parts.join('\n');
};

const page = ({ title, meta, tabs, body }) => `<!doctype html>
<html lang="zh-Hant">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="theme-color" content="#627d8d">
<title>${escapeHtml(title)}｜救「舊」我的書</title>
<meta name="description" content="救「舊」我的書${escapeHtml(title)}">
<style>${STYLE}</style>
</head>
<body>
<header class="hero">
  <div class="container">
    <span class="brand">救「舊」我的書</span>
    <h1>${escapeHtml(title)}</h1>
    ${meta}
    ${tabs}
  </div>
</header>
<main class="container sheet">
  <article class="doc">
${body}
  </article>
</main>
<footer class="container">© ${new Date().getFullYear()} 救「舊」我的書</footer>
</body>
</html>`;

const legalPage = ({ doc, version, links }) => page({
  title: doc.title,
  meta: `<div class="meta"><span>最後更新：${escapeHtml(dateFormat.format(new Date(doc.updated_at)))}</span>${version ? `<span>版本 ${Number(version)}</span>` : ''}</div>`,
  tabs: links.length > 1
    ? `<nav class="tabs" aria-label="文件">${links
      .map((l) => `<a href="${escapeHtml(l.href)}"${l.current ? ' aria-current="page"' : ''}>${escapeHtml(l.title)}</a>`)
      .join('')}</nav>`
    : '',
  body: renderContent(doc.content)
});

const legalNotFound = () => page({
  title: '找不到此文件',
  meta: '',
  tabs: '',
  body: '<p>此文件不存在或尚未發布。</p>'
});

module.exports = { legalPage, legalNotFound, renderContent, isHeading };
