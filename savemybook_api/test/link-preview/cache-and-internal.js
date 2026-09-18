const assert = require('assert');
const h = require('./harness');
const { addUser, addBook, setDns, site, html, connections, dnsLog, previewOf, linkPreview } = h;

const HOST = 'https://shop.example.com';
const setup = () => setDns('shop.example.com', ['93.184.216.34']);

const tests = [
  ['站內書籍分享連結直接查資料庫，不對外連線', async () => {
    const { token } = addUser();
    const book = addBook();
    const data = await previewOf(token, `https://example.test/b/${book.share_token}`);
    assert.deepStrictEqual(data, {
      url: `https://example.test/b/${book.share_token}`,
      site_name: '救「舊」我的書',
      title: '深入淺出統計學',
      description: '王大明',
      image_url: '/uploads/books/cover.jpg',
      kind: 'book',
      price: 350
    });
    const upper = await previewOf(token, `http://EXAMPLE.test/b/${book.share_token.toUpperCase()}/`);
    assert.strictEqual(upper.kind, 'book');
    assert.strictEqual(connections.length, 0);
    assert.strictEqual(dnsLog.length, 0);
  }],

  ['已下架、違規、賣家停權或不存在的書回傳 null；其他站內路徑不對外抓取', async () => {
    const { token } = addUser();
    const removed = addBook({ status: 'removed' });
    const rejected = addBook({ is_approved: false });
    const banned = addBook({ users: { nickname: 'x', avatar_url: null, is_active: true, is_blacklisted: true, anonymized_at: null } });
    const unknown = 'f'.repeat(32);
    for (const t of [removed.share_token, rejected.share_token, banned.share_token, unknown]) {
      assert.strictEqual(await previewOf(token, `https://example.test/b/${t}`), null, t);
    }
    for (const path of [`/u/${unknown}`, '/terms', '/b/123', '/api/books/1']) {
      assert.strictEqual(await previewOf(token, `https://example.test${path}`), null, path);
    }
    assert.strictEqual(connections.length, 0);
    assert.strictEqual(dnsLog.length, 0);
  }],

  ['API 本身的網域產生的分享連結同樣視為站內，不對外連線', async () => {
    const { token } = addUser();
    const book = addBook();
    const data = await previewOf(token, `https://127.0.0.1/b/${book.share_token}`);
    assert.strictEqual(data?.kind, 'book');
    assert.strictEqual(connections.length, 0);
  }],

  ['書籍狀態變更後立即反映，不受快取影響', async () => {
    const { token } = addUser();
    const book = addBook();
    const url = `https://example.test/b/${book.share_token}`;
    assert.strictEqual((await previewOf(token, url)).kind, 'book');
    book.status = 'removed';
    assert.strictEqual(await previewOf(token, url), null);
  }],

  ['成功結果快取 24 小時，失敗結果快取 10 分鐘', async () => {
    const { token } = addUser();
    setup();
    site(`${HOST}/ok`, html('<title>快取</title>'));
    site(`${HOST}/fail`, html('<title>x</title>', { status: 503 }));

    const realNow = Date.now;
    let offset = 0;
    Date.now = () => realNow() + offset;
    try {
      await previewOf(token, `${HOST}/ok`);
      await previewOf(token, `${HOST}/ok#another-fragment`);
      await previewOf(token, `${HOST}/fail`);
      await previewOf(token, `${HOST}/fail`);
      assert.strictEqual(connections.length, 2, '快取命中時不應再次連線');

      offset = 11 * 60 * 1000;
      await previewOf(token, `${HOST}/ok`);
      await previewOf(token, `${HOST}/fail`);
      assert.strictEqual(connections.length, 3, '失敗結果 10 分鐘後重新抓取，成功結果仍在快取');

      offset = 25 * 60 * 60 * 1000;
      await previewOf(addUser().token, `${HOST}/ok`);
      assert.strictEqual(connections.length, 4, '成功結果 24 小時後重新抓取');
    } finally {
      Date.now = realNow;
    }
  }],

  ['快取預設上限 500 筆，超過時淘汰最久未使用的項目', async () => {
    assert.strictEqual(linkPreview.LIMITS.cacheSize, 500);
    const { token } = addUser();
    setup();
    linkPreview.LIMITS.cacheSize = 2;
    for (const p of ['a', 'b', 'c']) site(`${HOST}/${p}`, html(`<title>${p}</title>`));

    await previewOf(token, `${HOST}/a`);
    await previewOf(token, `${HOST}/b`);
    await previewOf(token, `${HOST}/a`);
    await previewOf(token, `${HOST}/c`);
    assert.strictEqual(connections.length, 3);
    await previewOf(token, `${HOST}/a`);
    assert.strictEqual(connections.length, 3, '最近使用的 a 應保留');
    await previewOf(token, `${HOST}/b`);
    assert.strictEqual(connections.length, 4, 'b 應已被淘汰');
  }],

  ['同一網址同時多個請求只抓取一次', async () => {
    const { token } = addUser();
    const other = addUser();
    setup();
    site(`${HOST}/slow`, { ...html('<title>合併請求</title>'), delayMs: 150 });

    const results = await Promise.all([
      previewOf(token, `${HOST}/slow`),
      previewOf(other.token, `${HOST}/slow`),
      previewOf(token, `${HOST}/slow#x`)
    ]);
    assert.strictEqual(connections.length, 1);
    assert.ok(results.every((r) => r.title === '合併請求'));
  }],

  ['每位使用者每分鐘最多 30 次，不影響其他使用者', async () => {
    const { token } = addUser();
    const other = addUser();
    setup();
    site(`${HOST}/limit`, html('<title>限流</title>'));
    for (let i = 0; i < 30; i += 1) await previewOf(token, `${HOST}/limit`);
    const blocked = await h.request('GET', `/api/chat/link-preview?url=${encodeURIComponent(`${HOST}/limit`)}`, { token });
    assert.strictEqual(blocked.status, 429);
    assert.strictEqual(blocked.body.code, 'RATE_LIMITED');
    assert.ok(blocked.headers.get('retry-after'));
    assert.strictEqual((await previewOf(other.token, `${HOST}/limit`)).title, '限流');
  }]
];

module.exports = { name: '站內連結、快取與限流', tests };
