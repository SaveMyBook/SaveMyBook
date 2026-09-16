const assert = require('assert');
const h = require('./harness');

const recommend = h.api('services/ai/recommend');
const moderation = h.api('services/ai/moderation');
const books = h.api('services/books');
const ranking = h.api('services/ranking');
const { prisma, request } = h;

// 候選書單與排行都牽涉大量關聯查詢，這裡以測試自備的書目取代，聚焦在推薦邏輯本身。
let catalogue = [];
let personalIds = [];
let popularIds = [];
let recommendedRows = [];

books.inIdOrder = async (ids) => ids.map((id) => catalogue.find((b) => b.book_id === id)).filter(Boolean);
books.recommended = async (userId, viewed, limit) => recommendedRows.slice(0, limit);
ranking.recommendedIds = async () => personalIds;
ranking.rankedIds = async () => popularIds;

const book = (id) => ({ book_id: id, title: `書 ${id}`, author: '作者', condition_level: 'good', book_categories: { category_name: '文學小說' } });

const setup = ({ favorites = [], ids = [1, 2, 3], granted = true, config = {} } = {}) => {
  catalogue = [1, 2, 3, 4, 5].map(book);
  personalIds = ids;
  popularIds = [4, 5];
  recommendedRows = [];
  h.setSettings({ enabled: true, ...config });
  h.setConsent(7, granted);
  prisma.store.favorites = favorites.map((id) => ({
    user_id: 7, book_id: id, created_at: new Date(), books: { title: `收藏 ${id}`, author: '村上春樹', book_categories: { category_name: '文學小說' } }
  }));
};

module.exports = {
  name: 'AI 推薦與上架審核',
  tests: [
    ['推薦：AI 未啟用時改用一般推薦，不呼叫模型', async () => {
      setup();
      h.setSettings({ enabled: false });
      recommendedRows = [book(4)];
      const { data, meta } = await recommend.recommendations(7, 10);
      assert.strictEqual(meta.source, 'fallback');
      assert.deepStrictEqual(data.map((d) => d.book.book_id), [4]);
      assert.strictEqual(data[0].reason, null);
      assert.strictEqual(h.calls.length, 0);
    }],

    ['推薦：未同意資料處理時改用一般推薦', async () => {
      setup({ favorites: [1], granted: false });
      recommendedRows = [book(4)];
      const { meta } = await recommend.recommendations(7, 10);
      assert.strictEqual(meta.source, 'fallback');
      assert.strictEqual(h.calls.length, 0);
    }],

    ['推薦：一般推薦沒有結果時退回熱門排行', async () => {
      setup();
      h.setSettings({ enabled: false });
      recommendedRows = [];
      const { data, meta } = await recommend.recommendations(7, 10);
      assert.strictEqual(meta.source, 'fallback');
      assert.deepStrictEqual(data.map((d) => d.book.book_id), [4, 5]);
    }],

    ['推薦：沒有收藏也沒有購買紀錄時不呼叫模型', async () => {
      setup({ favorites: [] });
      recommendedRows = [book(4)];
      const { meta } = await recommend.recommendations(7, 10);
      assert.strictEqual(meta.source, 'fallback');
      assert.strictEqual(h.calls.length, 0);
    }],

    ['推薦：依模型挑選排序、清理理由並寫入快取', async () => {
      setup({ favorites: [9] });
      h.queueJson({
        items: [
          { id: 'b2', reason: '  與您收藏的《挪威的森林》同屬<b>文學小說</b>  ' },
          { id: 'b2', reason: '重複的代號會被忽略' },
          { id: 'b99', reason: '不存在的代號會被忽略' },
          { id: 'b1', reason: '理'.repeat(50) }
        ]
      });

      const { data, meta } = await recommend.recommendations(7, 10);
      assert.strictEqual(meta.source, 'ai');
      assert.strictEqual(h.calls.length, 1);
      assert.deepStrictEqual(data.map((d) => d.book.book_id), [2, 1, 3, 4, 5]);
      assert.strictEqual(data[0].reason, '與您收藏的《挪威的森林》同屬文學小說');
      // 理由上限 30 字，超過時以刪節號結尾。
      assert.strictEqual(data[1].reason.length, 30);
      assert.ok(data[1].reason.endsWith('…'));
      // 模型沒挑到的候選書會補在後面，但不附理由。
      assert.strictEqual(data[2].reason, null);

      const cached = JSON.parse(prisma.rows('ai_recommendation_cache')[0].payload);
      assert.deepStrictEqual(cached.items.map((i) => i.book_id), [2, 1, 3, 4, 5]);
    }],

    ['推薦：快取未過期時直接使用，不再呼叫模型', async () => {
      setup({ favorites: [9] });
      prisma.store.ai_recommendation_cache = [{
        user_id: 7,
        payload: JSON.stringify({ items: [{ book_id: 3, reason: '快取的理由' }, { book_id: 1, reason: null }] }),
        created_at: new Date()
      }];
      const { data, meta } = await recommend.recommendations(7, 10);
      assert.strictEqual(meta.source, 'ai');
      assert.strictEqual(h.calls.length, 0);
      assert.deepStrictEqual(data.map((d) => d.book.book_id), [3, 1]);
      assert.strictEqual(data[0].reason, '快取的理由');
    }],

    ['推薦：快取過期或內容損毀時重新產生', async () => {
      setup({ favorites: [9] });
      prisma.store.ai_recommendation_cache = [{
        user_id: 7,
        payload: JSON.stringify({ items: [{ book_id: 3 }] }),
        created_at: new Date(Date.now() - recommend.CACHE_TTL_MS - 1000)
      }];
      h.queueJson({ items: [{ id: 'b1', reason: '重新產生' }] });
      const { data } = await recommend.recommendations(7, 10);
      assert.strictEqual(h.calls.length, 1);
      assert.strictEqual(data[0].book.book_id, 1);
      assert.strictEqual(data[0].reason, '重新產生');
    }],

    ['推薦：模型失敗時安靜退回一般推薦', async () => {
      setup({ favorites: [9] });
      recommendedRows = [book(5)];
      h.queueJson(h.providerError('TIMEOUT'));
      const { data, meta } = await recommend.recommendations(7, 10);
      assert.strictEqual(meta.source, 'fallback');
      assert.deepStrictEqual(data.map((d) => d.book.book_id), [5]);
    }],

    ['推薦：快取中已下架的書會被濾掉，limit 也會生效', async () => {
      setup({ favorites: [9] });
      catalogue = [book(1)];
      const served = await recommend.serve(7, [{ book_id: 1, reason: '理由' }, { book_id: 2, reason: '已下架' }], 10);
      assert.strictEqual(served.length, 1);
      assert.strictEqual(served[0].book.book_id, 1);

      catalogue = [1, 2, 3].map(book);
      const limited = await recommend.serve(7, [{ book_id: 1 }, { book_id: 2 }, { book_id: 3 }], 2);
      assert.strictEqual(limited.length, 2);
    }],

    ['推薦 API：回傳資料與來源標記', async () => {
      const user = h.addUser();
      setup();
      h.setSettings({ enabled: false });
      recommendedRows = [book(4)];
      const res = await request('GET', '/api/ai/recommendations?limit=5', { token: h.tokenFor(user) });
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.body.meta.source, 'fallback');
      assert.strictEqual(res.body.data.length, 1);
    }],

    ['審核判定：未知的判定一律視為需人工審核', () => {
      const out = moderation.sanitizeVerdict({ verdict: 'delete', categories: ['not_book', 'unknown', 'not_book'] });
      assert.strictEqual(out.verdict, 'review');
      assert.deepStrictEqual(out.categories, ['not_book']);
      assert.deepStrictEqual(out.reasons, ['非書籍或無關商品']);
      assert.strictEqual(out.confidence, 0.5);
    }],

    ['審核判定：allow 不附理由，非 allow 但沒理由時給預設說明', () => {
      const allow = moderation.sanitizeVerdict({ verdict: 'allow', reasons: ['看起來正常'], confidence: 0.91234 });
      assert.deepStrictEqual(allow.reasons, []);
      assert.strictEqual(allow.confidence, 0.91);

      const review = moderation.sanitizeVerdict({ verdict: 'review' });
      assert.deepStrictEqual(review.reasons, ['內容需要人工確認']);
      assert.strictEqual(moderation.sanitizeVerdict({ verdict: 'allow' }).confidence, 1);
      assert.strictEqual(moderation.sanitizeVerdict({ verdict: 'reject', confidence: 5 }).confidence, 1);
      assert.strictEqual(moderation.sanitizeVerdict({ verdict: 'reject', confidence: '不知道' }).confidence, 0);
    }],

    ['審核判定：理由最多三點且會清掉控制字元', () => {
      const out = moderation.sanitizeVerdict({
        verdict: 'reject',
        reasons: ['第一點', '第一點', '<script>第二點</script>', '第三點', '第四點']
      });
      assert.deepStrictEqual(out.reasons, ['第一點', '第二點', '第三點']);
    }],

    ['審核處置：只有在阻擋模式且信心足夠時才直接退件', () => {
      assert.strictEqual(moderation.actionFor('allow', 0.1, 'block'), 'allow');
      assert.strictEqual(moderation.actionFor('review', 1, 'block'), 'review');
      assert.strictEqual(moderation.actionFor('reject', 1, 'review'), 'review');
      assert.strictEqual(moderation.actionFor('reject', moderation.BLOCK_CONFIDENCE - 0.01, 'block'), 'review');
      assert.strictEqual(moderation.actionFor('reject', moderation.BLOCK_CONFIDENCE, 'block'), 'reject');
    }],

    ['審核：功能關閉或資料表未建立時一律放行', async () => {
      h.setSettings({ enabled: true, features: { moderation: { enabled: false } } });
      assert.deepStrictEqual(await moderation.screen({ userId: 1, book: { title: '書' } }), moderation.ALLOW);

      h.reset({ schema: h.without(h.DEFAULT_SCHEMA, ['ai_settings']) });
      assert.deepStrictEqual(await moderation.screen({ userId: 1, book: { title: '書' } }), moderation.ALLOW);
      assert.strictEqual(h.calls.length, 0);
    }],

    ['審核：超出預算時放行，但留下 BUDGET_EXCEEDED 的用量紀錄', async () => {
      h.setSettings({ enabled: true, limits: { monthly_budget_usd: 1 } });
      h.addUsageLog({ cost_usd: 2, created_at: new Date() });
      const decision = await moderation.screen({ userId: 1, book: { title: '書' } });
      assert.strictEqual(decision.action, 'allow');
      assert.strictEqual(h.calls.length, 0);
      assert.strictEqual(prisma.rows('ai_usage_logs').at(-1).error_code, 'BUDGET_EXCEEDED');
    }],

    ['審核：阻擋模式下高信心的違規會直接退件', async () => {
      h.setSettings({ enabled: true, features: { moderation: { enabled: true, action: 'block' } } });
      prisma.store.book_categories = [{ category_id: 2, category_name: '電腦資訊' }];
      h.queueJson({ verdict: 'reject', confidence: 0.95, categories: ['not_book'], reasons: ['此商品為電子產品，非書籍'] });

      const decision = await moderation.screen({
        userId: 1,
        book: { title: '二手筆電', author: '', description: '9 成新筆電', price: 15000, category_id: 2 }
      });
      assert.strictEqual(decision.action, 'reject');
      assert.strictEqual(decision.verdict, 'reject');
      assert.deepStrictEqual(decision.categories, ['not_book']);
      assert.strictEqual(decision.provider, 'deepseek');
      assert.ok(h.calls[0].options.prompt.includes('電腦資訊'));
      assert.ok(h.calls[0].options.prompt.includes('<商品資料>'));

      assert.throws(
        () => moderation.assertNotRejected(decision),
        (err) => err.status === 422
          && err.code === 'LISTING_REJECTED'
          && err.message === '此商品未通過上架審核：此商品為電子產品，非書籍'
      );
    }],

    ['審核：審核模式下即使判定違規也只轉人工', async () => {
      h.setSettings({ enabled: true, features: { moderation: { enabled: true, action: 'review' } } });
      h.queueJson({ verdict: 'reject', confidence: 1, categories: ['prohibited'], reasons: [] });
      const decision = await moderation.screen({ userId: 1, book: { title: '盜版影印本' } });
      assert.strictEqual(decision.action, 'review');
      assert.deepStrictEqual(decision.reasons, ['違禁或盜版內容']);
      moderation.assertNotRejected(decision);
    }],

    ['審核：模型失敗時放行，不阻擋上架', async () => {
      h.setSettings({ enabled: true });
      h.queueJson(h.providerError('TIMEOUT'));
      const decision = await moderation.screen({ userId: 1, book: { title: '書' } });
      assert.deepStrictEqual(decision, moderation.ALLOW);
    }]
  ]
};
