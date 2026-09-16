const assert = require('assert');
const zlib = require('node:zlib');
const h = require('./harness');
const { addUser, setDns, site, html, connections, previewOf, linkPreview } = h;

const HOST = 'https://news.example.com';
const setup = () => setDns('news.example.com', ['93.184.216.34']);

const tests = [
  ['HTML 超過 1 MB 時只讀取前 1 MB，之後的內容不採用並中止下載', async () => {
    const { token } = addUser();
    setup();
    const head = '<html><head><meta property="og:title" content="前段標題">';
    const filler = 'x'.repeat(64 * 1024);
    const chunks = [head, ...Array(40).fill(filler), '<meta property="og:description" content="超過上限的描述"></head>'];
    site(`${HOST}/big`, html(chunks));

    const data = await previewOf(token, `${HOST}/big`);
    assert.strictEqual(data.title, '前段標題');
    assert.strictEqual(data.description, null, '超過 1 MB 之後的內容不可採用');
    assert.ok(connections[0].bytesSent < 1.2 * 1024 * 1024, `應提前中止下載，實際送出 ${connections[0].bytesSent} bytes`);
  }],

  ['非 HTML 內容不預覽', async () => {
    const { token } = addUser();
    setup();
    site(`${HOST}/json`, { headers: { 'content-type': 'application/json' }, body: '{"title":"x"}' });
    site(`${HOST}/pdf`, { headers: { 'content-type': 'application/pdf' }, body: '%PDF-1.7' });
    site(`${HOST}/none`, { headers: {}, body: '<title>沒有內容類型</title>' });
    site(`${HOST}/xhtmlish`, { headers: { 'content-type': 'text/htmlx' }, body: '<title>x</title>' });
    for (const path of ['json', 'pdf', 'none', 'xhtmlish']) assert.strictEqual(await previewOf(token, `${HOST}/${path}`), null, path);
  }],

  ['逾時回傳 null（等待回應與下載主體兩種情境）', async () => {
    const { token } = addUser();
    setup();
    linkPreview.LIMITS.timeoutMs = 150;
    site(`${HOST}/slow`, { ...html('<title>太慢</title>'), delayMs: 600 });
    site(`${HOST}/drip`, { ...html(['<html><head>', '<title>', '滴', '漏</title></head>']), chunkDelayMs: 120 });

    const started = Date.now();
    assert.strictEqual(await previewOf(token, `${HOST}/slow`), null);
    assert.strictEqual(await previewOf(token, `${HOST}/drip`), null);
    assert.ok(Date.now() - started < 1000, '應於逾時後立即結束');
  }],

  ['逾時預設為 5 秒，大小上限為 1 MB 與 3 MB', async () => {
    assert.strictEqual(linkPreview.LIMITS.timeoutMs, 5000);
    assert.strictEqual(linkPreview.LIMITS.htmlMaxBytes, 1024 * 1024);
    assert.strictEqual(linkPreview.LIMITS.imageMaxBytes, 3 * 1024 * 1024);
  }],

  ['非 2xx 狀態碼與缺少 Location 的轉址不預覽', async () => {
    const { token } = addUser();
    setup();
    site(`${HOST}/404`, html('<title>找不到</title>', { status: 404 }));
    site(`${HOST}/500`, html('<title>錯誤</title>', { status: 500 }));
    site(`${HOST}/redirect`, { status: 302, headers: {} });
    for (const path of ['404', '500', 'redirect']) assert.strictEqual(await previewOf(token, `${HOST}/${path}`), null, path);
  }],

  ['支援 gzip 與 br 壓縮，解壓縮後同樣受 1 MB 限制', async () => {
    const { token } = addUser();
    setup();
    const page = '<html><head><title>壓縮頁面</title><meta name="description" content="已解壓縮"></head></html>';
    site(`${HOST}/gzip`, html(zlib.gzipSync(page), { headers: { 'content-encoding': 'gzip' } }));
    site(`${HOST}/br`, html(zlib.brotliCompressSync(page), { headers: { 'content-encoding': 'br' } }));
    const bomb = zlib.gzipSync(Buffer.concat([Buffer.from('<title>炸彈</title>'), Buffer.alloc(20 * 1024 * 1024, 0x20), Buffer.from('<meta name="description" content="不應讀到">')]));
    site(`${HOST}/bomb`, html(bomb, { headers: { 'content-encoding': 'gzip' } }));
    site(`${HOST}/weird`, html('<title>x</title>', { headers: { 'content-encoding': 'compress' } }));

    assert.strictEqual((await previewOf(token, `${HOST}/gzip`)).description, '已解壓縮');
    assert.strictEqual((await previewOf(token, `${HOST}/br`)).title, '壓縮頁面');
    const bombData = await previewOf(token, `${HOST}/bomb`);
    assert.strictEqual(bombData.title, '炸彈');
    assert.strictEqual(bombData.description, null);
    assert.strictEqual(await previewOf(token, `${HOST}/weird`), null);
  }],

  ['依 Content-Type 或 meta 宣告的編碼解碼（Big5）', async () => {
    const { token } = addUser();
    setup();
    const big5Title = Buffer.from([0xa4, 0xa4, 0xb5, 0xd8, 0xa5, 0xc1, 0xb0, 0xea]);
    const body = Buffer.concat([Buffer.from('<html><head><meta charset="big5"><title>'), big5Title, Buffer.from('</title></head>')]);
    site(`${HOST}/big5`, { headers: { 'content-type': 'text/html' }, body });
    assert.strictEqual((await previewOf(token, `${HOST}/big5`)).title, '中華民國');
  }],

  ['網址欄位缺漏或過長時回傳 400', async () => {
    const { token } = addUser();
    const missing = await h.request('GET', '/api/chat/link-preview', { token });
    assert.strictEqual(missing.status, 400);
    const long = await h.request('GET', `/api/chat/link-preview?url=${encodeURIComponent(`https://a.example.com/${'a'.repeat(2100)}`)}`, { token });
    assert.strictEqual(long.status, 400);
    assert.strictEqual(connections.length, 0);
  }]
];

module.exports = { name: '抓取限制', tests };
