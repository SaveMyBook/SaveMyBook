const assert = require('assert');
const h = require('./harness');

const semantic = h.api('services/ai/semantic');
const catalog = h.api('services/ai/catalog-search');
const knowledge = h.api('services/ai/knowledge');
const embeddings = h.api('lib/ai/embeddings');
const bookChat = h.api('services/ai/book-chat');

const DIMS = embeddings.PROFILES.gemini.dimensions;
const EMBED_URL = /generativelanguage\.googleapis\.com\/v1beta\/models\/gemini-embedding-001:batchEmbedContents/;

// 以主題決定向量方向，模擬「意思相近的文字向量相近」；與字面是否相同無關。
const TOPICS = [
  /AI|Gemini|ChatGPT|人工智慧|提示工程|生成式/i,
  /推理|偵探|東野/,
  /退款|退費|申訴|爭議|拿回錢/
];
const vectorOf = (text) => {
  const v = new Array(DIMS).fill(0);
  const topic = TOPICS.findIndex((re) => re.test(text));
  v[topic < 0 ? 10 : topic] = 1;
  v[20] = 0.3;
  return v;
};

let embedRequests = [];
h.onFetch(EMBED_URL, (url, init) => {
  const body = JSON.parse(init.body);
  embedRequests.push(body.requests);
  return h.jsonResponse({ embeddings: body.requests.map((r) => ({ values: vectorOf(r.content.parts[0].text) })) });
});

let store = [];

const setup = ({ books = [], embeddingsTable = true } = {}) => {
  h.reset();
  h.installDefaults({ embeddings: embeddingsTable });
  embedRequests = [];
  store = [];
  h.onSql(/SELECT ref_id, content_hash, vector FROM ai_embeddings/, ([kind, model]) =>
    store.filter((r) => r.kind === kind && r.model === model));
  h.onSql(/INSERT INTO ai_embeddings/, (values) => {
    for (let i = 0; i < values.length; i += 6) {
      const [kind, ref, model, hash, vector] = values.slice(i, i + 6);
      store = store.filter((r) => !(r.kind === kind && r.ref_id === ref));
      store.push({ kind, ref_id: ref, model, content_hash: hash, vector });
    }
    return values.length / 6;
  });
  h.onSql(/SELECT kind, COUNT\(\*\) AS n FROM ai_embeddings/, ([model]) => {
    const counts = new Map();
    for (const r of store.filter((x) => x.model === model)) counts.set(r.kind, (counts.get(r.kind) ?? 0) + 1);
    return [...counts].map(([kind, n]) => ({ kind, n: BigInt(n) }));
  });
  h.onModel('books.findMany', () => books);
  h.onModel('book_categories.findMany', () => []);
};

const book = (id, overrides = {}) => ({
  book_id: id,
  seller_id: 9,
  title: `書籍 ${id}`,
  author: null,
  publisher: null,
  description: null,
  price: 200,
  status: 'on_sale',
  is_approved: true,
  condition_level: 'good',
  category_id: 1,
  cabinet_id: null,
  view_count: 0,
  book_categories: { category_name: '一般' },
  book_images: [],
  users: { user_id: 9, nickname: '賣家', avatar_url: null },
  ...overrides
});

const shelf = () => [
  book(1, { title: '東野圭吾推理精選', author: '東野圭吾', view_count: 999 }),
  book(2, { title: 'Gemini 應用開發實戰', author: '王小明', view_count: 3 }),
  book(3, { title: '家常料理一百道', view_count: 50 })
];

module.exports = {
  name: 'AI 語意檢索',
  tests: [
    ['向量：正規化、編碼與解碼可還原', () => {
      const v = embeddings.normalize([3, 4]);
      assert.ok(Math.abs(embeddings.dot(v, v) - 1) < 1e-6);
      assert.deepStrictEqual(Array.from(embeddings.decode(embeddings.encode(v), 2)), Array.from(v));
      assert.strictEqual(embeddings.decode('短', 2), null);
      assert.strictEqual(embeddings.normalize([0, 0]), null);
    }],

    ['RRF：兩份排名都靠前的項目分數最高', () => {
      const scores = semantic.fuse([{ ids: ['a', 'b', 'c'] }, { ids: ['b', 'd'] }]);
      const order = [...scores].sort((x, y) => y[1] - x[1]).map(([id]) => id);
      assert.strictEqual(order[0], 'b');
      assert.ok(order.includes('d'), '只出現在語意排名的項目也會納入');
    }],

    ['書名沒有關鍵字的 AI 書也能以語意找到，並排在最前面', async () => {
      setup({ books: shelf() });
      const ranked = await catalog.search([{ text: 'AI 人工智慧', weight: 1 }], { query: '有沒有推薦的 AI 書籍' });
      assert.strictEqual(ranked[0].book_id, 2);
      assert.strictEqual(ranked[0].lexical, false);
      assert.ok(ranked[0].similarity > 0.9);
      assert.ok(!ranked.some((r) => r.book_id === 3), '主題無關的書不列入');
    }],

    ['向量只計算一次：內容未變更時直接沿用，變更後只重算該本', async () => {
      setup({ books: shelf() });
      await catalog.search([], { query: 'AI 書' });
      const firstDocs = embedRequests.flat().filter((r) => r.taskType === 'RETRIEVAL_DOCUMENT').length;
      assert.strictEqual(firstDocs, 3);

      catalog.clear();
      await catalog.search([], { query: 'AI 書' });
      assert.strictEqual(embedRequests.flat().filter((r) => r.taskType === 'RETRIEVAL_DOCUMENT').length, 3, '沒有重算');
      assert.strictEqual(embedRequests.flat().filter((r) => r.taskType === 'RETRIEVAL_QUERY').length, 1, '相同查詢沿用快取');

      const changed = shelf();
      changed[2].title = '生成式 AI 料理食譜';
      h.onModel('books.findMany', () => changed);
      catalog.clear();
      const ranked = await catalog.search([], { query: 'AI 書' });
      const docs = embedRequests.flat().filter((r) => r.taskType === 'RETRIEVAL_DOCUMENT');
      assert.strictEqual(docs.length, 4);
      assert.match(docs[3].content.parts[0].text, /生成式 AI 料理食譜/);
      assert.ok(ranked.some((r) => r.book_id === 3));
    }],

    ['嵌入費用記入用量，功能名稱為 embedding', async () => {
      setup({ books: shelf() });
      const logged = [];
      h.state.sql.unshift({
        match: /INSERT INTO ai_usage_logs/,
        run: (values) => {
          logged.push(values);
          return 1;
        }
      });
      await catalog.search([], { query: 'AI 書' });
      assert.ok(logged.length >= 2);
      assert.ok(logged.every((v) => v[0] === 'embedding' && v[1] === 'gemini' && v[2] === 'gemini-embedding-001'));
    }],

    ['尚未執行 020 時只用關鍵字檢索，不呼叫嵌入 API', async () => {
      setup({ books: shelf(), embeddingsTable: false });
      const ranked = await catalog.search([{ text: 'AI', weight: 1 }], { query: '有沒有推薦的 AI 書籍' });
      assert.deepStrictEqual(ranked, []);
      assert.strictEqual(embedRequests.length, 0);
      assert.deepStrictEqual(await semantic.status(), { ready: false, provider: 'gemini', model: 'gemini-embedding-001', counts: {} });
    }],

    ['嵌入 API 失敗時退回關鍵字檢索且暫停重試', async () => {
      setup({ books: shelf() });
      const original = embeddings.embed;
      let attempts = 0;
      embeddings.embed = async () => {
        attempts += 1;
        throw new h.ai.AiProviderError('AUTH', { provider: 'gemini' });
      };
      try {
        const ranked = await catalog.search([{ text: '推理', weight: 1 }], { query: '推理小說' });
        assert.deepStrictEqual(ranked.map((r) => r.book_id), [1]);
        catalog.clear();
        await catalog.search([{ text: '推理', weight: 1 }], { query: '推理小說' });
        assert.strictEqual(attempts, 1, '冷卻期間不再呼叫');
      } finally {
        embeddings.embed = original;
      }
    }],

    ['書籍顧問：語意找到的書會進入候選並標示為檢索結果', async () => {
      setup({ books: shelf() });
      const search = bookChat.sanitizeSearch({ keywords: ['人工智慧', 'AI'] }, new Set());
      const { rows, matched, extraIds } = await bookChat.candidates(5, search, '有沒有推薦的 AI 書籍');
      assert.strictEqual(matched, true);
      assert.strictEqual(rows[0].book_id, 2);
      assert.ok(!extraIds.has(2));
    }],

    ['客服知識：換句話說的問題也能找到對應段落', async () => {
      setup();
      const docs = await knowledge.search('東西有問題想拿回錢');
      assert.ok(docs.length > 0);
      assert.ok(docs.some((d) => /退款|爭議|申訴/.test(d.text)), '語意比對到退款相關說明');
    }],

    ['狀態：回報使用的模型與已建立的向量數', async () => {
      setup({ books: shelf() });
      await catalog.search([], { query: 'AI 書' });
      const status = await semantic.status();
      assert.strictEqual(status.ready, true);
      assert.strictEqual(status.provider, 'gemini');
      assert.strictEqual(status.counts.book, 3);
    }]
  ]
};
