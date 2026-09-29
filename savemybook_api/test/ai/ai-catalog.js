const assert = require('assert');
const h = require('./harness');

const catalog = h.api('services/ai/catalog-search');
const reservations = h.api('services/reservations');
const ranking = h.api('services/ranking');

// ai-recommend.js 載入時會替換 ranking.recommendedIds，這裡先保留原本的實作。
const { recommendedIds } = ranking;

const soon = () => new Date(Date.now() + 60 * 60 * 1000);

const listed = (id, overrides = {}) => ({
  book_id: id,
  seller_id: 9,
  title: `書 ${id}`,
  author: '作者',
  publisher: '',
  description: '',
  isbn: null,
  category_id: 1,
  price: 200,
  condition_level: 'good',
  view_count: 1,
  cabinet_id: null,
  status: 'on_sale',
  is_approved: true,
  created_at: new Date(),
  book_categories: { category_name: '文學小說' },
  ...overrides
});

module.exports = {
  name: 'AI 選書共用檢索與可購買判斷',
  tests: [
    ['他人保留中：只算其他買家的有效保留，不含本人、已到期與待回覆的預約', async () => {
      h.prisma.store.reservations = [
        { reservation_id: 1, book_id: 1, buyer_id: 99, status: 'confirmed', pickup_deadline: soon() },
        { reservation_id: 2, book_id: 2, buyer_id: 7, status: 'confirmed', pickup_deadline: soon() },
        { reservation_id: 3, book_id: 3, buyer_id: 99, status: 'confirmed', pickup_deadline: new Date(Date.now() - 1000) },
        { reservation_id: 4, book_id: 4, buyer_id: 99, status: 'pending', pickup_deadline: null }
      ];
      assert.deepStrictEqual([...(await reservations.heldByOthers(7))], [1]);
      assert.deepStrictEqual([...(await reservations.heldByOthers(null))].sort(), [1, 2]);
    }],

    ['可購買判斷：排除書櫃維修中與他人保留中的書', async () => {
      h.prisma.store.smart_cabinets = [{ cabinet_id: 6, is_maintenance: 1 }, { cabinet_id: 8, is_maintenance: 0 }];
      h.prisma.store.reservations = [{ reservation_id: 1, book_id: 3, buyer_id: 99, status: 'confirmed', pickup_deadline: soon() }];
      const rows = [
        { book_id: 1, cabinet_id: 6 },
        { book_id: 2, cabinet_id: 8 },
        { book_id: 3, cabinet_id: null },
        { book_id: 4, cabinet_id: null }
      ];
      assert.deepStrictEqual((await catalog.available(rows, 7)).map((b) => b.book_id), [2, 4]);
      assert.deepStrictEqual(await catalog.available([], 7), []);
    }],

    ['ISBN：辨識含連字號的 10 碼與 13 碼，其他長度的數字不視為 ISBN', () => {
      assert.strictEqual(catalog.isbnOf('978-957-33-1724-1'), '9789573317241');
      assert.strictEqual(catalog.isbnOf('957 33 1724 x'), '957331724X');
      assert.strictEqual(catalog.isbnOf('123456789012'), null);
      assert.strictEqual(catalog.isbnOf('機器學習'), null);
      assert.deepStrictEqual(catalog.isbnForms('9573317249'), ['9573317249', '9789573317241']);
      assert.deepStrictEqual(catalog.isbnForms('9789573317241'), ['9789573317241', '9573317249']);
    }],

    ['ISBN：全形數字、各式破折號與 ISBN 前綴都能辨識，站內檢索同樣找得到', async () => {
      assert.strictEqual(catalog.isbnOf('９７８－９５７－３３－１７２４－１'), '9789573317241');
      assert.strictEqual(catalog.isbnOf('978–957–33–1724–1'), '9789573317241');
      assert.strictEqual(catalog.isbnOf('978‐957‐33‐1724‐1'), '9789573317241');
      assert.strictEqual(catalog.isbnOf('ISBN 9789573317241'), '9789573317241');
      assert.strictEqual(catalog.isbnOf('isbn:957-33-1724-9'), '9573317249');
      assert.strictEqual(catalog.isbnOf('2020–2021 學年'), null);

      h.prisma.store.books = [
        listed(1, { title: '978 推理全集', view_count: 99 }),
        listed(2, { title: '挪威的森林', isbn: '9789573317241' })
      ];
      catalog.clear();
      for (const text of ['９７８－９５７－３３－１７２４－１', '978–957–33–1724–1', 'ISBN：957-33-1724-9']) {
        const found = await catalog.search([{ text, weight: 1 }], { query: text });
        assert.strictEqual(found[0]?.book_id, 2, text);
      }
    }],

    ['ISBN：站內檢索可依含連字號或 10 碼的 ISBN 找到書，並排在最前面', async () => {
      h.prisma.store.books = [
        listed(1, { title: '978 推理全集', view_count: 99 }),
        listed(2, { title: '挪威的森林', isbn: '9789573317241' }),
        listed(3, { title: '舊版散文集', isbn: '986-123-456-X' })
      ];
      const hyphenated = await catalog.search([{ text: '978-957-33-1724-1', weight: 1 }], { query: '978-957-33-1724-1' });
      assert.deepStrictEqual(hyphenated.map((r) => r.book_id), [2]);
      assert.strictEqual(hyphenated[0].lexical, true);

      const isbn10 = await catalog.search([{ text: '957-33-1724-9', weight: 1 }], { query: '957-33-1724-9' });
      assert.deepStrictEqual(isbn10.map((r) => r.book_id), [2]);

      const legacy = await catalog.search([{ text: '請問有 9789861234564 嗎', weight: 1 }]);
      assert.strictEqual(legacy[0].book_id, 3);

      const filtered = await catalog.search([{ text: '9789573317241', weight: 1 }], { filter: (doc) => doc.book_id !== 2 });
      assert.ok(!filtered.some((r) => r.book_id === 2), 'ISBN 直接比對同樣套用篩選條件');
    }],

    ['規則式推薦：已取消或已退款的訂單不算購買紀錄但不推薦回給買家，最近瀏覽只採用已核准且未下架的書', async () => {
      h.prisma.store.books = [
        listed(14, { category_id: 1, author: '甲' }),
        listed(21, { category_id: 1, author: '甲' }),
        listed(22, { category_id: 2, author: '乙' }),
        listed(23, { category_id: 3, author: '丙' }),
        listed(24, { category_id: 4, author: '丁' }),
        listed(31, { category_id: 3, author: '丙', status: 'removed' }),
        listed(32, { category_id: 4, author: '丁', is_approved: false })
      ];
      const purchases = [
        { book_id: 11, status: 'cancelled', books: { category_id: 2, author: '乙' } },
        { book_id: 12, status: 'refunded', books: { category_id: 2, author: '乙' } },
        { book_id: 13, status: 'completed', books: { category_id: 1, author: '甲' } },
        { book_id: 14, status: 'cancelled', books: { category_id: 1, author: '甲' } }
      ];
      h.onModel('order_items.findMany', (args) => {
        const { notIn = [], in: only } = args.where.orders.status ?? {};
        return purchases.filter((p) => !notIn.includes(p.status) && (!only || only.includes(p.status)));
      });
      assert.deepStrictEqual(await recommendedIds(7, [31, 32]), [21]);
    }]
  ]
};
