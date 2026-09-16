const assert = require('assert');
const h = require('./harness');
const { addUser, setDns, site, connections, linkPreview } = h;

const PNG = Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), Buffer.alloc(64, 1)]);
const JPEG = Buffer.concat([Buffer.from([0xff, 0xd8, 0xff, 0xe0]), Buffer.alloc(64, 2)]);
const CDN = 'https://cdn.example.com';

const setup = () => {
  setDns('cdn.example.com', ['93.184.216.34']);
  setDns('evil.example.com', ['10.0.0.1']);
};

const imagePath = (url) => `/api/chat/link-preview/image?u=${linkPreview.signImage(url)}`;

const tests = [
  ['簽章正確時以伺服器代為取得圖片，回應帶快取與安全標頭', async () => {
    const { token } = addUser();
    setup();
    site(`${CDN}/a.png`, { headers: { 'content-type': 'image/png' }, body: PNG });

    const res = await h.request('GET', imagePath(`${CDN}/a.png`), { token });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.headers.get('content-type'), 'image/png');
    assert.match(res.headers.get('cache-control'), /max-age=86400/);
    assert.strictEqual(res.headers.get('x-content-type-options'), 'nosniff');
    assert.match(res.headers.get('content-security-policy'), /sandbox/);
    assert.strictEqual(connections[0].headers['user-agent'].startsWith('SaveMyBookLinkPreview/'), true);
  }],

  ['簽章錯誤、遭竄改或缺少時拒絕，且不連線', async () => {
    const { token } = addUser();
    setup();
    site(`${CDN}/a.png`, { headers: { 'content-type': 'image/png' }, body: PNG });
    const valid = linkPreview.signImage(`${CDN}/a.png`);
    const [payload, mac] = valid.split('.');
    const otherPayload = Buffer.from('http://169.254.169.254/latest/meta-data/').toString('base64url');
    const flipped = `${mac.slice(0, -1)}${mac.endsWith('A') ? 'B' : 'A'}`;

    const bad = [
      '', 'abc', `${payload}`, `${payload}.`, `.${mac}`, `${payload}.${flipped}`, `${otherPayload}.${mac}`,
      `${payload}.${mac}.extra`, `${payload}.${mac.slice(0, 10)}`
    ];
    for (const u of bad) {
      const res = await h.request('GET', `/api/chat/link-preview/image?u=${encodeURIComponent(u)}`, { token });
      assert.strictEqual(res.status, 403, `u=${u}`);
    }
    const missing = await h.request('GET', '/api/chat/link-preview/image', { token });
    assert.strictEqual(missing.status, 403);
    assert.strictEqual(connections.length, 0);
  }],

  ['以其他金鑰簽章的網址無效', async () => {
    const crypto = require('crypto');
    const { token } = addUser();
    const payload = Buffer.from(`${CDN}/a.png`).toString('base64url');
    const forged = crypto.createHmac('sha256', 'another-secret').update(payload).digest('base64url');
    const res = await h.request('GET', `/api/chat/link-preview/image?u=${payload}.${forged}`, { token });
    assert.strictEqual(res.status, 403);
  }],

  ['圖片代理同樣套用 SSRF 防護', async () => {
    const { token } = addUser();
    setup();
    site(`${CDN}/redirect.png`, { status: 302, headers: { location: 'http://169.254.169.254/latest/meta-data/' } });
    for (const url of ['http://127.0.0.1/a.png', 'http://[::1]/a.png', 'https://evil.example.com/a.png', `${CDN}/redirect.png`, 'http://cdn.example.com:8080/a.png']) {
      const res = await h.request('GET', imagePath(url), { token });
      assert.strictEqual(res.status, 404, url);
    }
    assert.deepStrictEqual(connections.map((c) => c.address), ['93.184.216.34']);
  }],

  ['只接受 image/*（不含 SVG），並以檔頭判斷實際格式', async () => {
    const { token } = addUser();
    setup();
    site(`${CDN}/page.html`, { headers: { 'content-type': 'text/html' }, body: '<html></html>' });
    site(`${CDN}/vector.svg`, { headers: { 'content-type': 'image/svg+xml' }, body: '<svg onload="alert(1)"></svg>' });
    site(`${CDN}/fake.png`, { headers: { 'content-type': 'image/png' }, body: '<html><script>alert(1)</script></html>' });
    site(`${CDN}/photo`, { headers: { 'content-type': 'image/png' }, body: JPEG });

    for (const name of ['page.html', 'vector.svg', 'fake.png']) {
      const res = await h.request('GET', imagePath(`${CDN}/${name}`), { token });
      assert.strictEqual(res.status, 404, name);
    }
    const photo = await h.request('GET', imagePath(`${CDN}/photo`), { token });
    assert.strictEqual(photo.status, 200);
    assert.strictEqual(photo.headers.get('content-type'), 'image/jpeg');
  }],

  ['圖片超過 3 MB 時拒絕（宣告長度與實際串流兩種情境）', async () => {
    const { token } = addUser();
    setup();
    const big = Buffer.concat([JPEG, Buffer.alloc(3 * 1024 * 1024)]);
    site(`${CDN}/declared.jpg`, { headers: { 'content-type': 'image/jpeg', 'content-length': String(big.length) }, body: big });
    const chunks = [JPEG, ...Array(64).fill(Buffer.alloc(64 * 1024))];
    site(`${CDN}/stream.jpg`, { headers: { 'content-type': 'image/jpeg' }, body: chunks });

    const declared = await h.request('GET', imagePath(`${CDN}/declared.jpg`), { token });
    assert.strictEqual(declared.status, 404);
    assert.strictEqual(connections[0].bytesSent <= big.length, true);

    const stream = await h.request('GET', imagePath(`${CDN}/stream.jpg`), { token });
    assert.strictEqual(stream.status, 404);
    assert.ok(connections[1].bytesSent < 3.2 * 1024 * 1024, `應提前中止下載，實際送出 ${connections[1].bytesSent} bytes`);
  }],

  ['圖片逾時回傳 404', async () => {
    const { token } = addUser();
    setup();
    linkPreview.LIMITS.timeoutMs = 150;
    site(`${CDN}/slow.png`, { headers: { 'content-type': 'image/png' }, body: PNG, delayMs: 600 });
    const res = await h.request('GET', imagePath(`${CDN}/slow.png`), { token });
    assert.strictEqual(res.status, 404);
  }]
];

module.exports = { name: '預覽圖片代理', tests };
