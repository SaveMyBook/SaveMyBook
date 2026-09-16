const assert = require('assert');
const h = require('./harness');
const { addUser, setDns, site, html, previewOf, signedTarget } = h;
const htmlMeta = h.api('lib/html-meta');

const HOST = 'https://blog.example.com';
const setup = () => setDns('blog.example.com', ['93.184.216.34']);
const BELL = String.fromCharCode(7);
const NEWLINE_TAB = `${String.fromCharCode(10)}${String.fromCharCode(9)}`;

const tests = [
  ['解析 Open Graph 標籤', async () => {
    const { token } = addUser();
    setup();
    site(`${HOST}/og`, html(`<!doctype html><html><head>
      <title>文件標題</title>
      <meta property="og:title" content="二手書交易指南">
      <meta property="og:description" content="如何為舊書訂出合理價格">
      <meta property="og:image" content="https://cdn.example.com/cover.jpg">
      <meta property="og:site_name" content="書店部落格">
      <meta name="twitter:title" content="不應採用">
    </head><body></body></html>`));

    const data = await previewOf(token, `${HOST}/og#section`);
    assert.deepStrictEqual({ ...data, image_url: undefined }, {
      url: `${HOST}/og`, site_name: '書店部落格', title: '二手書交易指南', description: '如何為舊書訂出合理價格', image_url: undefined, kind: 'web'
    });
    assert.ok(data.image_url.startsWith('/api/chat/link-preview/image?u='));
    assert.strictEqual(signedTarget(data.image_url), 'https://cdn.example.com/cover.jpg');
  }],

  ['缺少 Open Graph 時依序採用 twitter:*、<title> 與 meta description，網站名稱改用主機名稱', async () => {
    const { token } = addUser();
    setup();
    setDns('www.plain.example.org', ['93.184.216.34']);
    site(`${HOST}/twitter`, html(`<head><meta name="twitter:title" content="推特標題"><meta name="twitter:description" content="推特描述">
      <meta name="twitter:image" content="https://cdn.example.com/t.png"></head>`));
    site('https://www.plain.example.org/', html('<HTML><HEAD><TITLE>純文字標題</TITLE><META NAME="Description" CONTENT="頁面描述"></HEAD></HTML>'));
    site(`${HOST}/untitled`, html('<head><meta name="description" content="只有描述"></head>'));

    const twitter = await previewOf(token, `${HOST}/twitter`);
    assert.strictEqual(twitter.title, '推特標題');
    assert.strictEqual(twitter.description, '推特描述');
    assert.strictEqual(signedTarget(twitter.image_url), 'https://cdn.example.com/t.png');

    const plain = await previewOf(token, 'https://www.plain.example.org/');
    assert.deepStrictEqual([plain.title, plain.description, plain.site_name, plain.image_url], ['純文字標題', '頁面描述', 'plain.example.org', null]);

    assert.strictEqual(await previewOf(token, `${HOST}/untitled`), null, '沒有標題時不預覽');
  }],

  ['相對圖片網址以最終網址為基準轉為絕對網址，非 http(s) 圖片忽略', async () => {
    const { token } = addUser();
    setup();
    setDns('m.example.com', ['93.184.216.35']);
    site(`${HOST}/rel`, html('<head><title>a</title><meta property="og:image" content="/images/a.png?size=large&amp;v=2"></head>'));
    site(`${HOST}/proto`, html('<head><title>b</title><meta property="og:image" content="//static.example.net/b.jpg"></head>'));
    site(`${HOST}/moved`, { status: 301, headers: { location: 'https://m.example.com/articles/1' } });
    site('https://m.example.com/articles/1', html('<head><title>c</title><meta property="og:image" content="../img/c.webp"></head>'));
    site(`${HOST}/js`, html('<head><title>d</title><meta property="og:image" content="javascript:alert(1)"></head>'));
    site(`${HOST}/data`, html('<head><title>e</title><meta property="og:image" content="data:image/png;base64,AAAA"></head>'));

    assert.strictEqual(signedTarget((await previewOf(token, `${HOST}/rel`)).image_url), `${HOST}/images/a.png?size=large&v=2`);
    assert.strictEqual(signedTarget((await previewOf(token, `${HOST}/proto`)).image_url), 'https://static.example.net/b.jpg');
    const moved = await previewOf(token, `${HOST}/moved`);
    assert.strictEqual(moved.url, `${HOST}/moved`);
    assert.strictEqual(moved.site_name, 'm.example.com');
    assert.strictEqual(signedTarget(moved.image_url), 'https://m.example.com/img/c.webp');
    assert.strictEqual((await previewOf(token, `${HOST}/js`)).image_url, null);
    assert.strictEqual((await previewOf(token, `${HOST}/data`)).image_url, null);
  }],

  ['清除 HTML、實體與控制字元，標題截為 120 字、描述截為 200 字', async () => {
    const { token } = addUser();
    setup();
    const longTitle = '書'.repeat(150);
    const longDescription = '📚'.repeat(250);
    site(`${HOST}/dirty`, html(`<head>
      <meta property="og:title" content="&lt;b&gt;粗體&lt;/b&gt; 標題&#x200B;&#8203;${BELL} &amp; 更多&nbsp;&#128218;">
      <meta property="og:description" content="第一行${NEWLINE_TAB}第二行<script>alert(1)</script>">
    </head>`));
    site(`${HOST}/long`, html(`<head><title>${longTitle}</title><meta name="description" content="${longDescription}"></head>`));

    const dirty = await previewOf(token, `${HOST}/dirty`);
    assert.strictEqual(dirty.title, '粗體 標題 & 更多 📚');
    assert.strictEqual(dirty.description, '第一行 第二行 alert(1)');

    const long = await previewOf(token, `${HOST}/long`);
    assert.strictEqual(Array.from(long.title).length, 120);
    assert.ok(long.title.endsWith('…'));
    assert.strictEqual(Array.from(long.description).length, 200);
    const beforeEllipsis = long.description.charCodeAt(long.description.length - 2);
    assert.ok(!(beforeEllipsis >= 0xd800 && beforeEllipsis <= 0xdbff), '不可切斷代理字元');
  }],

  ['忽略註解、script、style 與 body 內的標籤，屬性值可含 >', async () => {
    const { token } = addUser();
    setup();
    site(`${HOST}/tricky`, html(`<head>
      <!-- <meta property="og:title" content="註解中的標題"> -->
      <script>document.write('<meta property="og:title" content="腳本中的標題">')</script>
      <style>/* <title>樣式中的標題</title> */</style>
      <meta content="價格 > 100 元的好書" property='og:title'>
      <title>備用</title>
    </head><body><meta property="og:description" content="body 內不採用"></body>`));

    const data = await previewOf(token, `${HOST}/tricky`);
    assert.strictEqual(data.title, '價格 > 100 元的好書');
    assert.strictEqual(data.description, null);
  }],

  ['解析器對惡意輸入維持線性時間', async () => {
    const inputs = [
      '<meta '.repeat(200000),
      `<meta content="${'a'.repeat(1000000)}`,
      '<script>'.repeat(150000),
      '<!--'.repeat(250000),
      '<'.repeat(1000000),
      `<title>${'&amp;'.repeat(200000)}`,
      '<meta content=a '.repeat(80000)
    ];
    for (const input of inputs) {
      const started = Date.now();
      htmlMeta.extract(input);
      assert.ok(Date.now() - started < 1500, `解析耗時過久：${input.slice(0, 20)}`);
    }
  }]
];

module.exports = { name: '內容解析', tests };
