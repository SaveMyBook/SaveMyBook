const assert = require('assert');
const {
  request, addUser, tokenFor, stubGoogleBooks, stubOpenLibrary, jsonResponse
} = require('./harness');

const ISBN = '9789573317249';

const googleVolume = (info) => jsonResponse({ items: [{ volumeInfo: info }] });

const openLibraryData = (isbn, book) => jsonResponse({ [`ISBN:${isbn}`]: book });

const lookup = (isbn = ISBN) => {
  const user = addUser();
  return request('GET', `/api/books/isbn/${isbn}`, { token: tokenFor(user) });
};

const tests = [
  ['ISBN 格式不正確時回 400', async () => {
    const res = await lookup('12345');
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.message, 'ISBN 必須是 10 或 13 碼');
  }],

  ['未登入無法查詢 ISBN', async () => {
    const res = await request('GET', `/api/books/isbn/${ISBN}`);
    assert.strictEqual(res.status, 401);
  }],

  ['兩個來源都查無資料時回 404', async () => {
    stubGoogleBooks(() => jsonResponse({ items: [] }));
    stubOpenLibrary(() => jsonResponse({}));

    const res = await lookup();
    assert.strictEqual(res.status, 404);
    assert.strictEqual(res.body.message, '找不到此 ISBN 的書籍資訊');
  }],

  ['兩個來源都發生錯誤時回 502', async () => {
    stubGoogleBooks(() => jsonResponse({ error: 'boom' }, { status: 500 }));
    stubOpenLibrary(() => jsonResponse({ error: 'boom' }, { status: 500 }));

    const res = await lookup();
    assert.strictEqual(res.status, 502);
    assert.strictEqual(res.body.message, '查詢外部書籍資訊發生錯誤');
  }],

  ['只有 Google Books 有資料時仍可回傳', async () => {
    stubGoogleBooks(() => googleVolume({
      title: '射鵰英雄傳',
      subtitle: '新修版',
      authors: ['金庸'],
      publisher: '遠流',
      publishedDate: '2003',
      description: '武俠小說',
      pageCount: 480,
      language: 'zh-TW'
    }));
    stubOpenLibrary(() => jsonResponse({}));

    const res = await lookup();
    assert.strictEqual(res.status, 200);
    assert.deepStrictEqual(res.body.data, {
      title: '射鵰英雄傳',
      subtitle: '新修版',
      author: '金庸',
      publisher: '遠流',
      publish_date: '2003',
      description: '武俠小說',
      page_count: '480',
      language: 'zh-TW'
    });
  }],

  ['Google Books 失敗時仍可由 Open Library 取得資料', async () => {
    stubGoogleBooks(() => jsonResponse({ error: 'boom' }, { status: 500 }));
    stubOpenLibrary((url) => (url.includes('/api/books')
      ? openLibraryData(ISBN, {
          title: '射鵰英雄傳',
          authors: [{ name: '金庸' }],
          publishers: [{ name: '遠流' }],
          publish_date: '2003'
        })
      : jsonResponse({ description: '武俠小說', publish_date: '2003' })));

    const res = await lookup();
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.data.title, '射鵰英雄傳');
    assert.strictEqual(res.body.data.author, '金庸');
    assert.strictEqual(res.body.data.publisher, '遠流');
    assert.strictEqual(res.body.data.description, '武俠小說');
  }],

  ['逐欄位合併兩個來源：Google 缺的欄位改用 Open Library', async () => {
    stubGoogleBooks(() => googleVolume({ title: '射鵰英雄傳', authors: ['金庸'] }));
    stubOpenLibrary((url) => (url.includes('/api/books')
      ? openLibraryData(ISBN, {
          title: '射鵰英雄傳（Open Library）',
          authors: [{ name: '金庸' }],
          publishers: [{ name: '遠流' }],
          publish_date: '2003'
        })
      : jsonResponse({ number_of_pages: 480 })));

    const res = await lookup();
    assert.strictEqual(res.status, 200);
    // 書名以 Google Books 為先，缺少的出版社與頁數改由 Open Library 補上。
    assert.strictEqual(res.body.data.title, '射鵰英雄傳');
    assert.strictEqual(res.body.data.publisher, '遠流');
    assert.strictEqual(res.body.data.page_count, '480');
  }],

  ['出版日期取精度最高的來源', async () => {
    stubGoogleBooks(() => googleVolume({ title: '射鵰英雄傳', publishedDate: '2003' }));
    stubOpenLibrary((url) => (url.includes('/api/books')
      ? openLibraryData(ISBN, { title: '射鵰英雄傳', authors: [], publishers: [], publish_date: 'Aug 2003' })
      : jsonResponse({ publish_date: '2003-08-01' })));

    const res = await lookup();
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.data.publish_date, '2003-08-01');
  }],

  ['10 碼 ISBN 會同時以 13 碼向 Open Library 查詢', async () => {
    const isbn10 = '9573317249';
    let bibkeys = '';
    stubGoogleBooks(() => jsonResponse({ items: [] }));
    stubOpenLibrary((url) => {
      if (url.includes('/api/books')) {
        bibkeys = decodeURIComponent(new URL(url).searchParams.get('bibkeys'));
        return openLibraryData(isbn10, { title: '射鵰英雄傳', authors: [], publishers: [], publish_date: '2003' });
      }
      return jsonResponse({});
    });

    const res = await lookup(isbn10);
    assert.strictEqual(res.status, 200);
    assert.ok(bibkeys.includes(`ISBN:${isbn10}`));
    assert.ok(/ISBN:978\d{10}/.test(bibkeys), `應補上 13 碼變體，實際為 ${bibkeys}`);
  }]
];

module.exports = { name: 'ISBN 外部書庫查詢', tests };
