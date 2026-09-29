const assert = require('assert');
const fs = require('fs');
const path = require('path');
const h = require('./harness');

const { titleMatches } = h.api('lib/book-match');
const isbnCodes = h.api('lib/isbn');
const { simplifiedShare, toSimplified } = h.api('lib/hanzi');
const googleBooks = h.api('lib/google-books');
const openLibrary = h.api('lib/open-library');
const isbnLookup = h.api('services/isbn-lookup');

const bank = JSON.parse(fs.readFileSync(path.join(__dirname, 'golden', 'bibliography.json'), 'utf8'));

// 其他測試檔會永久換掉這些函式；本檔依檔名排序先載入，先留下原本的實作，每個測試前再裝回。
const originals = {
  fetchVolumeByIsbn: googleBooks.fetchVolumeByIsbn,
  fetchEditionByIsbn: openLibrary.fetchEditionByIsbn,
  fetchEditionDetailByIsbn: openLibrary.fetchEditionDetailByIsbn,
  lookupWithSources: isbnLookup.lookupWithSources
};

const stubSources = ({ google = null, library = null, detail = null } = {}) => {
  const calls = { detail: 0 };
  googleBooks.fetchVolumeByIsbn = async () => google;
  openLibrary.fetchEditionByIsbn = async () => library;
  openLibrary.fetchEditionDetailByIsbn = async () => {
    calls.detail += 1;
    return detail;
  };
  return calls;
};

const ISBN = '9789573317241';
const WRONG = { title: '1Q84', authors: ['村上春樹'], publisher: '時報出版', description: '另一本書的簡介' };
const RIGHT = { title: '挪威的森林', authors: [{ name: '村上春樹' }], publishers: [{ name: '時報出版' }], publish_date: '2003', isbn: ISBN, isbns: [ISBN] };

module.exports = {
  name: '書目比對（ISBN 與書名）',
  before: () => {
    h.reset();
    Object.assign(googleBooks, { fetchVolumeByIsbn: originals.fetchVolumeByIsbn });
    Object.assign(openLibrary, { fetchEditionByIsbn: originals.fetchEditionByIsbn, fetchEditionDetailByIsbn: originals.fetchEditionDetailByIsbn });
    isbnLookup.lookupWithSources = originals.lookupWithSources;
  },
  tests: [
    ['評測集：副標、版次、套書與簡繁差異判定相符，ISBN 屬於另一本書的案例全部判定不符', () => {
      const wrong = bank.titles.filter((c) => titleMatches(c.listed, c.source, { subtitle: c.subtitle ?? '' }) !== c.same);
      const different = bank.titles.filter((c) => !c.same).length;
      console.log(`     相符 ${bank.titles.length - different} 題、不符 ${different} 題`);
      assert.deepStrictEqual(wrong.map((c) => `${c.id} ${c.listed}｜${c.source}`), []);
    }],

    ['評測集：錯誤 ISBN 的案例經過書目補齊後誤寫率為 0，相符的案例照常補齊', async () => {
      const enrichment = h.api('services/ai/enrich');
      const written = [];
      for (const c of bank.titles) {
        h.reset({ tables: { books: [{ book_id: 1, title: c.listed, isbn: ISBN, status: 'on_sale', is_approved: true, author: null, publisher: null, description: null, publish_date: null }] } });
        h.installDefaults({ enabled: false });
        stubSources({ google: { title: c.source, subtitle: c.subtitle, industryIdentifiers: [{ type: 'ISBN_13', identifier: ISBN }], authors: ['書目作者'] } });
        const result = await enrichment.enrich(1);
        if ((h.prisma.rows('books')[0].author === '書目作者') !== c.same) written.push(`${c.id} ${result?.status}`);
      }
      assert.deepStrictEqual(written, []);
    }],

    ['ISBN：驗證檢查碼，10 碼與 13 碼互通，登錄的任一 ISBN 屬於同一本書即相符', () => {
      assert.strictEqual(isbnCodes.normalize('978-957-33-1724-1'), ISBN);
      assert.strictEqual(isbnCodes.normalize('９７８９５７３３１７２４１'), ISBN);
      assert.strictEqual(isbnCodes.normalize('9789573317249'), '');
      assert.strictEqual(isbnCodes.normalize('957331724X'), '');
      assert.strictEqual(isbnCodes.normalize('080442957X'), '080442957X');
      assert.ok(isbnCodes.sameBook(ISBN, ['9573317249']));
      assert.ok(isbnCodes.sameBook('9573317249', ['9789999999999', ISBN]));
      assert.ok(!isbnCodes.sameBook(ISBN, ['9789861371955', 'UOM:39015']));
      assert.ok(!isbnCodes.sameBook(ISBN, []));
    }],

    ['簡體字：比對書名時統一字形，只有簡體中文才有的字才計入簡體比例', () => {
      assert.strictEqual(toSimplified('三體'), '三体');
      assert.deepStrictEqual(simplifiedShare('皇后與里程'), { count: 0, ratio: 0 });
      const share = simplifiedShare('这本书讲述青春与成长');
      assert.strictEqual(share.count, 5);
      assert.ok(share.ratio > 0.4);
    }],

    ['書目查詢：帶書名時只採用書名相符的來源，Open Library 不符時也不查它的版本頁', async () => {
      const calls = stubSources({
        google: { title: '挪威的森林', industryIdentifiers: [{ type: 'ISBN_13', identifier: ISBN }], authors: ['村上春樹'], description: '青春小說的簡介內容' },
        library: { ...RIGHT, title: '1Q84', publishers: [{ name: '別的出版社' }] }
      });
      const found = await isbnLookup.lookupWithSources(ISBN, { title: '挪威的森林' });
      assert.strictEqual(found.fields.title, '挪威的森林');
      assert.strictEqual(found.fields.publisher, '');
      assert.deepStrictEqual(found.sources.map((s) => s.title), ['Google Books']);
      assert.strictEqual(calls.detail, 0);
    }],

    ['書目查詢：所有來源的書名都不符時回傳 ISBN_TITLE_MISMATCH；不帶書名時照常合併', async () => {
      stubSources({ google: WRONG, library: { ...RIGHT, title: '1Q84' } });
      await assert.rejects(isbnLookup.lookupWithSources(ISBN, { title: '挪威的森林' }), (err) => err.code === 'ISBN_TITLE_MISMATCH' && err.status === 409);

      stubSources({ google: WRONG, library: RIGHT });
      const found = await isbnLookup.lookupWithSources(ISBN);
      assert.strictEqual(found.fields.title, '1Q84');
      assert.strictEqual(found.sources.length, 2);
    }],

    ['書目查詢：Open Library 登錄的 ISBN 都不屬於這本書時略過', async () => {
      stubSources({ library: { ...RIGHT, isbns: ['9789861371955'] } });
      await assert.rejects(isbnLookup.lookupWithSources(ISBN), (err) => err.status === 404);
    }]
  ]
};
