const assert = require('assert');
const h = require('./harness');

const semantic = h.api('services/ai/semantic');
const catalog = h.api('services/ai/catalog-search');
const knowledge = h.api('services/ai/knowledge');
const embeddings = h.api('lib/ai/embeddings');
const bookChat = h.api('services/ai/book-chat');
const books = h.api('services/books');

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

const setup = ({ books = [], embeddings: withEmbeddings = true } = {}) => {
  h.reset();
  h.installDefaults({ embeddings: withEmbeddings });
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

    ['未設定嵌入金鑰時只用關鍵字檢索，不呼叫嵌入 API', async () => {
      setup({ books: shelf(), embeddings: false });
      const ranked = await catalog.search([{ text: 'AI', weight: 1 }], { query: '有沒有推薦的 AI 書籍' });
      assert.deepStrictEqual(ranked, []);
      assert.strictEqual(embedRequests.length, 0);
      assert.deepStrictEqual(await semantic.status(), {
        ready: false,
        provider: null,
        model: null,
        counts: {},
        cooldown_until: { sync: null, query: null },
        last_sync_at: null,
        last_error: null,
        coverage: {}
      });
    }],

    ['嵌入 API 系統性失敗時退回關鍵字檢索，同步與查詢各自暫停重試', async () => {
      setup({ books: shelf() });
      const original = embeddings.embed;
      const tasks = [];
      embeddings.embed = async (p, key, texts, options = {}) => {
        tasks.push(options.task ?? 'document');
        throw new h.ai.AiProviderError('AUTH', { provider: 'gemini' });
      };
      try {
        const ranked = await catalog.search([{ text: '推理', weight: 1 }], { query: '推理小說' });
        assert.deepStrictEqual(ranked.map((r) => r.book_id), [1]);
        assert.deepStrictEqual(tasks, ['document', 'query'], '同步失敗不影響查詢，查詢仍會嘗試一次');
        catalog.clear();
        await catalog.search([{ text: '推理', weight: 1 }], { query: '推理小說' });
        assert.strictEqual(tasks.length, 2, '冷卻期間不再呼叫');
        const status = await semantic.status();
        assert.ok(status.cooldown_until.sync > new Date());
        assert.ok(status.cooldown_until.query > new Date());
        assert.strictEqual(status.last_error.code, 'AUTH');
        assert.strictEqual(status.last_error.purpose, 'query');
        assert.strictEqual(status.last_sync_at, null);
      } finally {
        embeddings.embed = original;
      }
    }],

    ['查詢端個別請求錯誤（例如 BAD_REQUEST）不觸發冷卻，下次查詢照常使用語意檢索', async () => {
      setup({ books: shelf() });
      const original = embeddings.embed;
      let failNext = true;
      embeddings.embed = async (p, key, texts, options = {}) => {
        if (failNext && options.task === 'query') {
          failNext = false;
          throw new h.ai.AiProviderError('BAD_REQUEST', { provider: 'gemini' });
        }
        return original(p, key, texts, options);
      };
      try {
        await catalog.search([], { query: 'AI 書' });
        const status = await semantic.status();
        assert.deepStrictEqual(status.cooldown_until, { sync: null, query: null });
        assert.strictEqual(status.last_error.code, 'BAD_REQUEST');

        catalog.clear();
        const ranked = await catalog.search([{ text: 'AI 人工智慧', weight: 1 }], { query: '有沒有推薦的 AI 書籍' });
        assert.strictEqual(ranked[0].book_id, 2, '語意檢索恢復');
      } finally {
        embeddings.embed = original;
      }
    }],

    ['同步端同一批文件固定失敗（BAD_REQUEST 或零向量）時，之後的搜尋不再重送這批文件', async () => {
      for (const failure of ['BAD_REQUEST', 'ZERO_VECTOR']) {
        setup({ books: shelf() });
        const original = embeddings.embed;
        const originalLog = h.usageService.log;
        const tasks = [];
        const errorLogs = [];
        h.usageService.log = async (entry) => {
          if (entry.feature === 'embedding' && entry.status === 'error') errorLogs.push(entry);
          return originalLog(entry);
        };
        embeddings.embed = async (p, key, texts, options = {}) => {
          tasks.push(options.task ?? 'document');
          if (options.task === 'query') return original(p, key, texts, options);
          if (failure === 'BAD_REQUEST') throw new h.ai.AiProviderError('BAD_REQUEST', { provider: 'gemini' });
          const err = new h.ai.AiProviderError('INVALID_OUTPUT', { provider: 'gemini', providerMessage: '第 2 筆為零向量' });
          err.systemic = false;
          err.cost_usd = 0.0001;
          throw err;
        };
        try {
          for (let i = 0; i < 4; i += 1) {
            catalog.clear();
            await catalog.search([{ text: '推理', weight: 1 }], { query: `推理小說 ${i}` });
          }
          assert.strictEqual(tasks.filter((t) => t === 'document').length, 1, `${failure}：失敗的文件只送一次`);
          assert.strictEqual(tasks.filter((t) => t === 'query').length, 4, `${failure}：查詢照常使用語意檢索`);
          assert.strictEqual(errorLogs.length, 1, `${failure}：錯誤只記錄一次`);
          const status = await semantic.status();
          assert.deepStrictEqual(status.cooldown_until, { sync: null, query: null });
          assert.deepStrictEqual(status.coverage.book, { indexed: 0, total: 3 });
        } finally {
          embeddings.embed = original;
          h.usageService.log = originalLog;
        }
      }
    }],

    ['查詢端連續 3 次非系統性錯誤（例如金鑰過期回 400）後暫停呼叫', async () => {
      setup({ books: shelf() });
      await catalog.search([], { query: 'AI 書' });
      const original = embeddings.embed;
      let queries = 0;
      embeddings.embed = async () => {
        queries += 1;
        throw new h.ai.AiProviderError('BAD_REQUEST', { provider: 'gemini', providerMessage: 'API key expired' });
      };
      try {
        for (let i = 0; i < 5; i += 1) {
          catalog.clear();
          const ranked = await catalog.search([{ text: '推理', weight: 1 }], { query: `推理小說 ${i}` });
          assert.deepStrictEqual(ranked.map((r) => r.book_id), [1], '退回關鍵字檢索');
        }
        assert.strictEqual(queries, 3);
        const status = await semantic.status();
        assert.ok(status.cooldown_until.query > new Date());
        assert.strictEqual(status.cooldown_until.sync, null);
      } finally {
        embeddings.embed = original;
      }
    }],

    ['查詢冷卻中仍會在背景同步書籍向量；向量維度不符屬系統性錯誤，會觸發冷卻', async () => {
      setup({ books: shelf() });
      const original = embeddings.embed;
      embeddings.embed = async (p, key, texts, options = {}) => {
        if (options.task === 'query') {
          const err = new h.ai.AiProviderError('INVALID_OUTPUT', { provider: 'gemini', providerMessage: '向量維度 3072，預期 768' });
          err.systemic = true;
          throw err;
        }
        return original(p, key, texts, options);
      };
      try {
        const ranked = await catalog.search([{ text: '推理', weight: 1 }], { query: '推理小說' });
        assert.deepStrictEqual(ranked.map((r) => r.book_id), [1]);
        let status = await semantic.status();
        assert.ok(status.cooldown_until.query > new Date());
        assert.strictEqual(status.cooldown_until.sync, null);
        assert.strictEqual(status.last_error.detail, '回應格式不正確（向量維度 3072，預期 768）');

        const changed = shelf();
        changed[2].title = '生成式 AI 料理食譜';
        h.onModel('books.findMany', () => changed);
        catalog.clear();
        const before = embedRequests.length;
        assert.strictEqual(await catalog.warm(), 1);
        assert.strictEqual(embedRequests.length, before + 1);
        status = await semantic.status();
        assert.ok(status.last_sync_at instanceof Date);
        assert.deepStrictEqual(status.coverage.book, { indexed: 3, total: 3 });
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

    ['搜尋：相關度排序先放語意與關鍵字的結果，再補上字面相符的書', async () => {
      setup({ books: shelf() });
      const { total, books: page } = await books.list({
        skip: 0, limit: 10, sort: 'relevance', viewerId: null, status: 'on_sale', keyword: 'AI', categoryIds: []
      });
      assert.strictEqual(page[0].book_id, 2, '書名只寫 Gemini 的 AI 書排第一');
      assert.strictEqual(total, 3);
    }],

    ['相似的書：用已存的向量找內容相近的書，不含自己，也不再呼叫嵌入 API', async () => {
      const list = [...shelf(), book(5, { title: 'ChatGPT 提示工程實務' })];
      setup({ books: list });
      h.onModel('books.findUnique', () => ({ ...list[1], book_categories: { category_name: '一般' } }));
      await catalog.search([], { query: 'AI 書' });
      const before = embedRequests.length;

      const similar = await books.similar(2, null);
      assert.strictEqual(similar[0].book_id, 5);
      assert.ok(!similar.some((b) => b.book_id === 2));
      assert.strictEqual(embedRequests.length, before, '沿用已存向量');
    }],

    ['狀態：回報使用的模型、已建立的向量數、涵蓋率與最近同步時間', async () => {
      setup({ books: shelf() });
      await catalog.search([], { query: 'AI 書' });
      const status = await semantic.status();
      assert.strictEqual(status.ready, true);
      assert.strictEqual(status.provider, 'gemini');
      assert.strictEqual(status.counts.book, 3);
      assert.deepStrictEqual(status.coverage.book, { indexed: 3, total: 3 });
      assert.ok(status.last_sync_at instanceof Date);
      assert.deepStrictEqual(status.cooldown_until, { sync: null, query: null });
      assert.strictEqual(status.last_error, null);
    }]
  ]
};
