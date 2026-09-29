const assert = require('assert');
const h = require('./harness');

const feedback = h.api('services/ai/feedback');
const events = h.api('services/recommendation-events');
const recommend = h.api('services/ai/recommend');
const books = h.api('services/books');
const ranking = h.api('services/ranking');
const adoption = h.api('services/ai/listing-adoption');
const quality = h.api('services/ai/quality');
const analyses = h.api('services/ai/dispute-analyses');
const harvest = h.api('services/ai/golden-harvest');
const faqs = h.api('services/faqs');
const publicId = h.api('lib/public-id');
const { prisma, request } = h;

const HOUR = 60 * 60 * 1000;
const DAY = 24 * HOUR;
const ago = (ms) => new Date(Date.now() - ms);

const supportSession = (userId, { sessionId = 1, ticketId = null, status = 'open' } = {}) => {
  prisma.rows('ai_support_sessions').push({
    session_id: sessionId, user_id: userId, status, ticket_id: ticketId, created_at: ago(HOUR), updated_at: ago(HOUR / 2)
  });
};

const supportMessage = (sessionId, messageId, role, content, extra = {}) => {
  prisma.rows('ai_support_messages').push({
    message_id: messageId, session_id: sessionId, role, content, created_at: ago(HOUR - messageId * 1000), ...extra
  });
};

const bookRow = (id, extra = {}) => ({
  book_id: id, seller_id: 99, title: `書 ${id}`, author: '作者', price: 200, status: 'on_sale', is_approved: true, cabinet_id: null,
  condition_level: 'good', created_at: new Date(), ...extra
});

const put = (user, path, body) => request('PUT', path, { token: h.tokenFor(user), body });

module.exports = {
  name: 'AI 回饋與品質紀錄',
  tests: [
    ['客服評價：助理訊息附加密編號，本人可評價與取消，他人與使用者訊息回 404', async () => {
      h.setSettings({ enabled: true });
      const user = h.addUser();
      const other = h.addUser();
      h.setConsent(user.user_id, true);
      supportSession(user.user_id);
      supportMessage(1, 1, 'user', '取書期限是幾天');
      supportMessage(1, 2, 'assistant', '取書期限為三天。');

      const session = await request('GET', '/api/ai/support/session', { token: h.tokenFor(user) });
      const [asked, reply] = session.body.data.messages;
      assert.strictEqual(asked.message_no, undefined);
      assert.strictEqual(reply.message_no, publicId.encode('ai_support_message', 2));
      assert.ok(!/^\d+$/.test(reply.message_no));
      assert.strictEqual(reply.feedback, null);

      const path = `/api/ai/support/messages/${reply.message_no}/feedback`;
      const rated = await put(user, path, { rating: 'unhelpful', reason: 'inaccurate' });
      assert.strictEqual(rated.status, 200);
      assert.deepStrictEqual(rated.body.data.feedback, { rating: 'unhelpful', reason: 'inaccurate' });
      const stored = prisma.rows('ai_support_messages')[1];
      assert.strictEqual(stored.feedback, 'unhelpful');
      assert.ok(stored.feedback_at instanceof Date);

      const reopened = await request('GET', '/api/ai/support/session', { token: h.tokenFor(user) });
      assert.deepStrictEqual(reopened.body.data.messages[1].feedback, { rating: 'unhelpful', reason: 'inaccurate' });

      assert.strictEqual((await put(user, path, { rating: 'helpful', reason: 'inaccurate' })).status, 400);
      assert.strictEqual((await put(user, path, { rating: 'unhelpful', reason: 'books_mismatch' })).status, 400);
      assert.strictEqual((await put(other, path, { rating: 'helpful' })).status, 404);
      const ownQuestion = publicId.encode('ai_support_message', 1);
      assert.strictEqual((await put(user, `/api/ai/support/messages/${ownQuestion}/feedback`, { rating: 'helpful' })).status, 404);
      assert.strictEqual((await put(user, '/api/ai/support/messages/2/feedback', { rating: 'helpful' })).status, 404);

      const cleared = await put(user, path, { rating: null });
      assert.strictEqual(cleared.body.data.feedback, null);
      assert.strictEqual(prisma.rows('ai_support_messages')[1].feedback, null);
      assert.strictEqual(prisma.rows('ai_support_messages')[1].feedback_reason, null);
    }],

    ['書籍顧問評價：編號前綴與客服不同，互不通用', async () => {
      const user = h.addUser();
      prisma.rows('ai_chat_sessions').push({ session_id: 5, user_id: user.user_id, status: 'open', created_at: new Date(), updated_at: new Date() });
      prisma.rows('ai_chat_messages').push({
        message_id: 9, session_id: 5, role: 'assistant', content: '以下是推薦的書。', book_ids: null, created_at: new Date()
      });
      const no = feedback.messageNo('book_chat', 9);
      assert.ok(no.startsWith('AC'));
      const res = await put(user, `/api/ai/book-chat/messages/${no}/feedback`, { rating: 'unhelpful', reason: 'books_mismatch' });
      assert.strictEqual(res.status, 200);
      assert.strictEqual(prisma.rows('ai_chat_messages')[0].feedback_reason, 'books_mismatch');
      assert.strictEqual((await put(user, `/api/ai/support/messages/${no}/feedback`, { rating: 'helpful' })).status, 404);
    }],

    ['推薦曝光：同一來源 6 小時內只記一次，點擊記在最近一次曝光', async () => {
      const now = new Date();
      assert.strictEqual(await events.logImpressions(7, [1, 2, 2, 3], 'ai', now), 3);
      assert.strictEqual(await events.logImpressions(7, [1, 2, 4], 'ai', now), 1);
      assert.strictEqual(await events.logImpressions(7, [1], 'rules', now), 1);
      assert.strictEqual(await events.logImpressions(7, [5], 'other', now), 0);
      const rows = prisma.rows('recommendation_logs');
      assert.strictEqual(rows.length, 5);
      assert.ok(rows.every((r) => r.rec_type === 'personalized'));

      assert.strictEqual(await events.click(7, 2, now), true);
      assert.strictEqual(await events.click(7, 2, now), false, '同一次曝光只記一次點擊');
      assert.strictEqual(await events.click(7, 8, now), false, '沒有曝光的書不記錄');
      const clicked = rows.filter((r) => r.is_clicked);
      assert.strictEqual(clicked.length, 1);
      assert.strictEqual(clicked[0].book_id, 2);

      prisma.rows('recommendation_logs').push({ rec_id: 99, user_id: 7, book_id: 1, source: 'ai', is_clicked: false, created_at: ago(91 * DAY) });
      assert.strictEqual(await events.purgeExpired(), 1);
    }],

    ['推薦路由：回傳的書記為曝光並區分 AI 與規則式；點擊與不感興趣的驗證', async () => {
      const user = h.addUser();
      const original = recommend.recommendations;
      prisma.store.books = [bookRow(31), bookRow(32)];
      try {
        recommend.recommendations = async () => ({
          data: [{ book: bookRow(31), reason: null, basis: null }, { book: bookRow(32), reason: null, basis: null }],
          groups: [],
          meta: { source: 'fallback', generated_at: new Date() }
        });
        const res = await request('GET', '/api/ai/recommendations', { token: h.tokenFor(user) });
        assert.strictEqual(res.status, 200);
      } finally {
        recommend.recommendations = original;
      }
      await new Promise((resolve) => setImmediate(resolve));
      const rows = prisma.rows('recommendation_logs');
      assert.deepStrictEqual(rows.map((r) => [r.book_id, r.source]), [[31, 'rules'], [32, 'rules']]);

      const click = await request('POST', '/api/ai/recommendations/clicks', { token: h.tokenFor(user), body: { book_id: 31 } });
      assert.deepStrictEqual(click.body.data, { recorded: true });
      const missing = await request('POST', '/api/ai/recommendations/dismissals', { token: h.tokenFor(user), body: { book_id: 404 } });
      assert.strictEqual(missing.status, 404);
      const dismissed = await request('POST', '/api/ai/recommendations/dismissals', { token: h.tokenFor(user), body: { book_id: 32 } });
      assert.strictEqual(dismissed.status, 200);
      const again = await request('POST', '/api/ai/recommendations/dismissals', { token: h.tokenFor(user), body: { book_id: 32 } });
      assert.strictEqual(again.status, 200);
      assert.strictEqual(prisma.rows('recommendation_dismissals').length, 1);
    }],

    ['推薦路由：AI 推薦只有附理由或依據的書記為 AI，補在後面的候選書記為規則式，最近瀏覽的書不記曝光', async () => {
      const user = h.addUser();
      const original = recommend.recommendations;
      const basis = { kind: 'category', name: '推理小說' };
      try {
        recommend.recommendations = async () => ({
          data: [
            { book: bookRow(41), reason: '同為東野圭吾的推理作品', basis: null },
            { book: bookRow(42), reason: null, basis },
            { book: bookRow(43), reason: null, basis: null },
            { book: bookRow(44), reason: '延伸主題', basis }
          ],
          groups: [],
          meta: { source: 'ai', generated_at: new Date() }
        });
        const res = await request('GET', '/api/ai/recommendations?viewed_ids=44', { token: h.tokenFor(user) });
        assert.strictEqual(res.status, 200);
        assert.strictEqual(res.body.data.length, 4);
      } finally {
        recommend.recommendations = original;
      }
      await new Promise((resolve) => setImmediate(resolve));
      const logged = prisma.rows('recommendation_logs').map((r) => [r.book_id, r.source]).sort((x, y) => x[0] - y[0]);
      assert.deepStrictEqual(logged, [[41, 'ai'], [42, 'ai'], [43, 'rules']]);
    }],

    ['不感興趣：規則式推薦、AI 推薦快取與熱門補位都排除', async () => {
      const saved = { rankedIds: ranking.rankedIds, recommendedIds: ranking.recommendedIds, inIdOrder: books.inIdOrder };
      prisma.store.books = [1, 2, 3, 4].map((id) => bookRow(id));
      h.setSettings({ enabled: false });
      await events.dismiss(7, 2);
      await events.dismiss(7, 4);
      try {
        ranking.recommendedIds = async () => [1, 2, 3];
        ranking.rankedIds = async () => [4, 3];
        const rules = await books.recommended(7, [], 10);
        assert.deepStrictEqual(rules.map((b) => b.book_id), [1, 3]);

        books.inIdOrder = async (ids) => ids.map((id) => bookRow(id));
        const served = await recommend.serve(7, [1, 2, 3].map((id) => ({ book_id: id, reason: '理由' })), 10);
        assert.deepStrictEqual(served.map((d) => d.book.book_id), [1, 3]);

        ranking.recommendedIds = async () => [2];
        const { data } = await recommend.fallback(7, 10);
        assert.deepStrictEqual(data.map((d) => d.book.book_id), [3], '熱門補位也不列入不感興趣的書');
      } finally {
        Object.assign(ranking, { rankedIds: saved.rankedIds, recommendedIds: saved.recommendedIds });
        books.inIdOrder = saved.inIdOrder;
      }
    }],

    ['上架輔助採用率：權杖只屬於本人、只能用一次，兩步驟合併計算', async () => {
      const step1 = await adoption.issue(7, {
        fields: { title: '挪威的森林', author: '村上春樹', publisher: '時報出版', publish_date: '2003-08-01', isbn: '9789571333427', description: '簡介\n內容' },
        category: { category_id: 3 }
      });
      const step2 = await adoption.issue(7, { fields: { title: '挪威的森林' }, condition: { level: 'good' }, price: { suggested: 180 } });
      assert.match(step1, /^[0-9a-f]{32}$/);
      assert.strictEqual(await adoption.issue(7, { fields: {}, category: null, condition: null, price: null }), null);

      const book = {
        title: '挪威的森林', author: '村上 春樹', publisher: '時報', publish_date: '2003/08/01', isbn: '978-957-13-3342-7',
        description: '簡介 內容', category_id: 3, condition_level: 'fair', price: 180
      };
      assert.strictEqual(await adoption.record(8, [step1], book), null, '他人的權杖不採用');
      const adopted = await adoption.record(7, `${step1},${step2},not-a-token`, book);
      assert.deepStrictEqual(adopted, {
        title: 1, author: 0, publisher: 0, publish_date: 1, isbn: 1, description: 1, category_id: 1, condition_level: 0, price: 1
      });
      assert.strictEqual(await adoption.record(7, [step1], book), null, '權杖只能使用一次');
      const rows = prisma.rows('ai_listing_suggestions');
      assert.strictEqual(rows.filter((r) => r.adopted).length, 1);
      assert.ok(rows.every((r) => r.used_at));
      assert.ok(rows.every((r) => r.fields === '{}'), '算出採用結果後清除建議值');
    }],

    ['上架輔助採用率：簡介只存雜湊；賣家改選書況後帶入價格表中該書況的建議價也算採用售價', async () => {
      const table = { like_new: { suggested: 230 }, good: { suggested: 170 }, fair: { suggested: 110 }, poor: { suggested: 60 } };
      const step1 = await adoption.issue(7, { fields: { author: '村上春樹', description: '簡介\n內容' }, price: { suggested: 170, by_condition: table } });
      const stored = JSON.parse(prisma.rows('ai_listing_suggestions').at(-1).fields);
      assert.ok(!JSON.stringify(stored).includes('簡介'), '簡介只存雜湊');
      assert.deepStrictEqual(stored.price_by_condition, { like_new: '230', good: '170', fair: '110', poor: '60' });
      assert.deepStrictEqual(await adoption.record(7, [step1], { author: '村上春樹', condition_level: 'fair', price: 110 }), { author: 1, description: 0, price: 1 });

      const step2 = await adoption.issue(7, { condition: { level: 'good' }, price: { suggested: 170, by_condition: table } });
      const other = await adoption.issue(7, { price: { suggested: 170, by_condition: table } });
      assert.deepStrictEqual(await adoption.record(7, [step2], { condition_level: 'like_new', price: 230 }), { condition_level: 0, price: 1 },
        '維持自己選的書況並套用該書況的建議價');
      assert.deepStrictEqual(await adoption.record(7, [other], { condition_level: 'fair', price: 120 }), { price: 0 });
    }],

    ['上架輔助路由：回應附上權杖', async () => {
      h.setSettings({ enabled: true });
      const user = h.addUser();
      h.setConsent(user.user_id, true);
      prisma.store.book_categories = [{ category_id: 1, category_name: '文學小說', sort_order: 0 }];
      h.queueJson({ fields: { title: '小王子', author: '聖修伯里' }, category_id: 1, category_confidence: 0.8, price: { suggested: 150 }, warnings: [] });
      const res = await request('POST', '/api/ai/listing-assist', { token: h.tokenFor(user), body: { title: '小王子' } });
      assert.strictEqual(res.status, 200);
      assert.match(res.body.data.suggestion_token, /^[0-9a-f]{32}$/);
      const stored = prisma.rows('ai_listing_suggestions')[0];
      assert.strictEqual(stored.user_id, user.user_id);
      assert.deepStrictEqual(JSON.parse(stored.fields), { author: '聖修伯里', category_id: '1', price: '150' }, '賣家自己輸入的書名不算建議');
    }],

    ['上架輔助採用率：與賣家輸入相同的 ISBN、書名不列為建議，只剩輸入值時不發權杖', async () => {
      const inputs = { isbn: '978-957-13-3342-7', title: '挪威的森林' };
      assert.deepStrictEqual(adoption.suggestionOf({ fields: { isbn: '9789571333427', title: ' 挪威的森林 ', author: '村上春樹' } }, inputs), { author: '村上春樹' });
      assert.deepStrictEqual(adoption.suggestionOf({ fields: { title: '挪威的森林（新版）' } }, inputs), { title: '挪威的森林（新版）' });
      assert.strictEqual(await adoption.issue(7, { fields: { isbn: '9789571333427', title: '挪威的森林' } }, inputs), null);

      const token = await adoption.issue(7, { fields: { title: '挪威的森林', author: '村上春樹' }, price: { suggested: 180 } }, inputs);
      await adoption.record(7, [token], { title: '挪威的森林', author: '村上春樹', price: 200 });
      const exported = await adoption.exportUser(7);
      assert.strictEqual(exported.length, 1);
      assert.deepStrictEqual(exported[0].adopted, { author: 1, price: 0 });
      assert.ok(exported[0].used_at instanceof Date);
      assert.ok(!('fields' in exported[0]) && !('token' in exported[0]));
      assert.strictEqual(exported[0].suggested, null, '建立書籍後只保留採用結果');

      await adoption.issue(7, { fields: { author: '村上春樹' } }, inputs);
      const pending = (await adoption.exportUser(7)).at(-1);
      assert.deepStrictEqual([pending.used_at, pending.suggested, pending.adopted], [null, { author: '村上春樹' }, null], '尚未使用的建議值列入匯出');

      h.setConsent(7, true);
      await h.api('services/ai/consent').setGranted(7, false);
      assert.strictEqual(prisma.rows('ai_listing_suggestions').filter((r) => r.user_id === 7).length, 0, '撤回同意時一併刪除');
    }],

    ['爭議分析：保存結果與提示詞版本，開啟面板讀取最新一次，裁決時記錄是否一致', async () => {
      h.installDefaults();
      prisma.store.transaction_disputes = [{ dispute_id: 3 }];
      h.onModel('transaction_disputes.findUnique', () => ({
        dispute_id: 3, applicant_id: 1, reason: '書況不符', evidence_urls: '', created_at: new Date(),
        orders: {
          buyer_id: 1, seller_id: 2, status: 'refunding', created_at: new Date(), deposited_at: new Date(), picked_up_at: new Date(),
          order_items: [{ unit_price: 200, books: { title: '小王子', author: '聖修伯里', condition_level: 'like_new', description: '', book_images: [] } }]
        }
      }));
      assert.strictEqual(await analyses.latest(3), null);
      await assert.rejects(() => analyses.latest(4), (err) => err.status === 404);

      h.queueJson({ summary: '第一次', findings: [], suggestion: 'dismiss', confidence: 0.4, rationale: '理由' });
      await analyses.run(3, 99);
      h.queueJson({ summary: '第二次', findings: ['劃記'], suggestion: 'refund', confidence: 0.8, rationale: '理由' });
      const second = await analyses.run(3, 99);
      assert.strictEqual(second.summary, '第二次');
      assert.strictEqual(h.calls.length, 2);

      const latest = await analyses.latest(3);
      assert.strictEqual(latest.summary, '第二次');
      assert.strictEqual(latest.suggestion, 'refund');
      assert.deepStrictEqual(latest.images, { listing: 0, evidence: 0, skipped: 0 });
      assert.strictEqual(latest.helpful, null);
      assert.strictEqual(h.calls.length, 2, '讀取最新結果不呼叫模型');
      const row = prisma.rows('ai_dispute_analyses')[1];
      assert.match(row.prompt_version, /^[0-9a-f]{12}$/);
      assert.ok(!('provider' in JSON.parse(row.result)));

      const first = prisma.rows('ai_dispute_analyses')[0];
      assert.match(latest.analysis_no, /^DA[0-9A-Z]{7}$/);
      const firstNo = publicId.encode('ai_dispute_analysis', first.analysis_id);
      assert.strictEqual((await analyses.rate(3, firstNo, false)).helpful, false, '評價管理員看到的那一次分析');
      assert.strictEqual(prisma.rows('ai_dispute_analyses')[1].helpful, undefined, '較新的分析不受影響');
      assert.strictEqual((await analyses.rate(3, latest.analysis_no, true)).helpful, true);
      await assert.rejects(() => analyses.rate(3, 'DA0000000', true), (err) => err.status === 404);
      prisma.store.transaction_disputes.push({ dispute_id: 4 });
      await assert.rejects(() => analyses.rate(4, latest.analysis_no, true), (err) => err.status === 404, '不可評價其他爭議的分析');

      const admin = h.addAdmin({ can_manage_transactions: true });
      const missingNo = await request('PATCH', '/api/admin/disputes/3/ai-analysis', { token: h.tokenFor(admin), body: { helpful: true } });
      assert.strictEqual(missingNo.status, 400);
      const viaRoute = await request('PATCH', '/api/admin/disputes/3/ai-analysis', {
        token: h.tokenFor(admin), body: { helpful: false, analysis_no: firstNo }
      });
      assert.strictEqual(viaRoute.status, 200);
      assert.strictEqual(viaRoute.body.data.analysis_no, firstNo);
      await analyses.recordResolution(prisma, 3, 'refund_auto');
      assert.strictEqual(prisma.rows('ai_dispute_analyses')[1].agreed, true);
      assert.strictEqual(prisma.rows('ai_dispute_analyses')[0].agreed, undefined, '只比對最後一次分析');
      assert.strictEqual(analyses.agreementOf('dismiss', 'refund_manual'), false);
      assert.strictEqual(analyses.agreementOf('need_more_info', 'dismissed'), null);
    }],

    ['品質報表：只計管理員決定（含恢復背景審核駁回的書）的推翻比例，各比例沒有樣本時為 null', async () => {
      const admin = h.addAdmin({ can_view_stats: true });
      const now = new Date();
      const event = (extra) => ({ book_id: 1, prior: 'pending', status: 'approved', verdict: 'review', origin: 'ai', categories: '[]', created_at: now, ...extra });
      prisma.store.ai_review_events = [
        event({ actor: 'admin', categories: '["source","price"]', misjudged: true }),
        event({ actor: 'admin', categories: '["source"]', misjudged: false, status: 'rejected' }),
        event({ actor: 'admin', origin: 'rules', misjudged: false }),
        event({ actor: 'relist', misjudged: null }),
        event({ actor: 'relist', prior: 'rejected', verdict: 'reject', categories: '["not_book"]', misjudged: true }),
        event({ actor: 'seller_edit', misjudged: null })
      ];
      prisma.store.ai_support_sessions = [
        { session_id: 1, user_id: 1, status: 'escalated', created_at: now },
        { session_id: 2, user_id: 1, status: 'closed', created_at: now }
      ];
      prisma.store.ai_support_messages = [
        { message_id: 1, session_id: 1, role: 'assistant', feedback: 'unhelpful', feedback_reason: 'inaccurate', feedback_at: now },
        { message_id: 2, session_id: 2, role: 'assistant', feedback: 'helpful', feedback_reason: null, feedback_at: now }
      ];
      prisma.store.ai_chat_messages = [
        { message_id: 1, session_id: 1, role: 'assistant', book_ids: null, created_at: now },
        { message_id: 2, session_id: 1, role: 'assistant', book_ids: '1,2', created_at: now },
        { message_id: 3, session_id: 1, role: 'user', book_ids: null, created_at: now }
      ];
      prisma.store.recommendation_logs = [
        { rec_id: 1, user_id: 1, book_id: 1, source: 'ai', is_clicked: true, created_at: now },
        { rec_id: 2, user_id: 1, book_id: 2, source: 'ai', is_clicked: false, created_at: now },
        { rec_id: 3, user_id: 1, book_id: 3, source: 'rules', is_clicked: false, created_at: now }
      ];
      prisma.store.ai_dispute_analyses = [
        { analysis_id: 1, dispute_id: 1, agreed: true, helpful: true, resolved_at: now, created_at: now },
        { analysis_id: 2, dispute_id: 2, agreed: false, helpful: null, resolved_at: now, created_at: now }
      ];
      prisma.store.ai_listing_suggestions = [
        { token: 'a', user_id: 1, adopted: JSON.stringify({ title: 1, price: 0 }), used_at: now },
        { token: 'b', user_id: 1, adopted: JSON.stringify({ title: 1 }), used_at: now },
        { token: 'c', user_id: 1, adopted: null, used_at: now }
      ];
      prisma.store.faqs = [{ faq_id: 1, source_ticket_id: 5, created_at: now }, { faq_id: 2, source_ticket_id: null, created_at: now }];

      const res = await request('GET', '/api/admin/ai/quality?period=today', { token: h.tokenFor(admin) });
      assert.strictEqual(res.status, 200);
      const q = res.body.data;
      assert.deepStrictEqual([q.moderation.decisions, q.moderation.overturned], [4, 2], '恢復背景審核駁回的書計入推翻');
      assert.deepStrictEqual(q.moderation.by_category.find((c) => c.category === 'source'), { category: 'source', decisions: 2, overturned: 1, rate: 0.5 });
      assert.deepStrictEqual(q.moderation.by_origin.find((o) => o.origin === 'rules'), { origin: 'rules', decisions: 1, overturned: 0, rate: 0 });
      assert.strictEqual(q.support.handoff_rate, 0.5);
      assert.strictEqual(q.support.negative_rate, 0.5);
      assert.deepStrictEqual(q.support.reasons, { inaccurate: 1 });
      assert.strictEqual(q.book_chat.no_books_rate, 0.5);
      assert.strictEqual(q.book_chat.negative_rate, null);
      assert.deepStrictEqual(q.recommendations.ai, { impressions: 2, clicks: 1, ctr: 0.5 });
      assert.deepStrictEqual(q.recommendations.rules, { impressions: 1, clicks: 0, ctr: 0 });
      assert.strictEqual(q.dispute_assist.agreement_rate, 0.5);
      assert.strictEqual(q.dispute_assist.helpful_rate, 1);
      assert.strictEqual(q.listing_assist.listings, 2);
      assert.deepStrictEqual(q.listing_assist.fields, [
        { field: 'title', suggested: 2, adopted: 2, rate: 1 },
        { field: 'price', suggested: 1, adopted: 0, rate: 0 }
      ]);
      assert.strictEqual(q.faqs_from_tickets, 1);
      assert.ok(!JSON.stringify(q).includes('content'), '品質報表不含對話內容');

      const member = h.addUser();
      assert.strictEqual((await request('GET', '/api/admin/ai/quality', { token: h.tokenFor(member) })).status, 403);
      assert.strictEqual(quality.ratio(0, 0), null);
    }],

    ['評測集候選：只收推翻的審核（含恢復背景駁回的書）並去識別化；負評只有原因統計，不含使用者提問與回覆', async () => {
      const month = '2026-08';
      const inMonth = new Date(2026, 7, 15);
      prisma.store.books = [bookRow(1, {
        title: '小王子', description: '館藏書，請加 LINE：@seller123 或打 0912345678 詢問。書況良好。', condition_note: null, isbn: '9789571333427'
      })];
      prisma.store.ai_review_events = [
        { book_id: 1, actor: 'admin', prior: 'pending', status: 'approved', verdict: 'review', origin: 'ai', categories: '["source"]', confidence: 0.7, misjudged: true, created_at: inMonth },
        { book_id: 1, actor: 'admin', prior: 'pending', status: 'rejected', verdict: 'review', origin: 'ai', categories: '[]', misjudged: false, created_at: inMonth },
        { book_id: 1, actor: 'relist', prior: 'rejected', status: 'approved', verdict: 'reject', origin: 'ai', categories: '["not_book"]', confidence: 0.95, misjudged: true, created_at: inMonth }
      ];
      prisma.store.ai_support_messages = [
        { message_id: 1, session_id: 1, role: 'user', content: '訂單 SMB20260801100000000001 的錢什麼時候撥款？我的電話 0912345678' },
        { message_id: 2, session_id: 1, role: 'assistant', content: '模型回覆', feedback: 'unhelpful', feedback_reason: 'inaccurate', feedback_at: inMonth },
        { message_id: 3, session_id: 1, role: 'user', content: '另一題' },
        { message_id: 4, session_id: 1, role: 'assistant', content: '回覆', feedback: 'unhelpful', feedback_at: new Date(2026, 8, 2) }
      ];
      prisma.store.ai_chat_messages = [];

      const result = await harvest.collect(month);
      assert.strictEqual(result.moderation.length, 2);
      assert.deepStrictEqual(result.moderation[0].flagged, { verdict: 'review', origin: 'ai', categories: ['source'], confidence: 0.7 });
      assert.deepStrictEqual(result.moderation[1].admin, { decision: 'approved', prior: 'rejected' });
      assert.ok(!/0912345678|seller123/.test(result.moderation[0].listing.description));
      assert.match(result.moderation[0].listing.description, /書況良好/);
      assert.strictEqual(result.moderation[0].listing.isbn, '9789571333427');
      assert.deepStrictEqual(result.support_feedback, { unhelpful: 1, reasons: { inaccurate: 1 } });
      assert.deepStrictEqual(result.book_chat_feedback, { unhelpful: 0, reasons: {} });
      assert.ok(!/取書|撥款|另一題|模型回覆/.test(JSON.stringify(result)), '不輸出使用者提問與回覆');
      assert.ok(!/user_id|seller_id|book_id/.test(JSON.stringify(result)));
      assert.strictEqual(harvest.previousMonth(new Date(2026, 0, 10)), '2025-12');
    }],

    ['常見問題回流：由轉接工單預填問題與客服回覆，並去識別化', async () => {
      prisma.store.support_tickets = [
        { ticket_id: 7, user_id: 1, subject: 'AI 客服轉接：取書期限過了怎麼辦', category: 'trade' },
        { ticket_id: 8, user_id: 1, subject: '一般提問', category: 'other' }
      ];
      prisma.store.support_ticket_messages = [
        { message_id: 1, ticket_id: 7, is_staff: false, content: '以下為 AI 客服對話紀錄', created_at: ago(3 * HOUR) },
        { message_id: 2, ticket_id: 7, is_staff: true, content: '逾期未取書時訂單會自動取消並退款。如有疑問請洽 0912345678。', created_at: ago(2 * HOUR) },
        { message_id: 3, ticket_id: 7, is_staff: true, content: '', created_at: ago(HOUR) }
      ];
      supportSession(1, { sessionId: 4, ticketId: 7, status: 'escalated' });
      supportMessage(4, 1, 'user', '訂單 SMB20260801100000000001 取書期限過了怎麼辦');
      supportMessage(4, 2, 'user', '謝謝');

      const draft = await faqs.draftFromTicket(7);
      assert.deepStrictEqual(draft, {
        category: 'trade',
        question: '訂單 取書期限過了怎麼辦',
        answer: '逾期未取書時訂單會自動取消並退款。',
        source_ticket_id: 7
      });
      await assert.rejects(() => faqs.draftFromTicket(8), (err) => err.code === 'TICKET_NOT_FROM_AI');
      await assert.rejects(() => faqs.draftFromTicket(9), (err) => err.status === 404);

      const admin = h.addAdmin({ can_manage_support: true, can_manage_announcements: true });
      const viaRoute = await request('GET', '/api/admin/tickets/7/faq-draft', { token: h.tokenFor(admin) });
      assert.strictEqual(viaRoute.status, 200);
      const created = await request('POST', '/api/admin/faqs', {
        token: h.tokenFor(admin), body: { question: '取書期限過了怎麼辦？', answer: '訂單會自動取消並退款。', source_ticket_id: 7 }
      });
      assert.strictEqual(created.status, 201);
      assert.strictEqual(prisma.rows('faqs').at(-1).source_ticket_id, 7);
      const listed = await request('GET', '/api/support/faqs');
      assert.strictEqual(listed.status, 200);
      assert.ok(listed.body.data.some((f) => f.question === '取書期限過了怎麼辦？'));
      assert.ok(listed.body.data.every((f) => !('source_ticket_id' in f)), '前台不公開來源工單');
      const unknown = await request('POST', '/api/admin/faqs', {
        token: h.tokenFor(admin), body: { question: '問題', answer: '答案', source_ticket_id: 99 }
      });
      assert.strictEqual(unknown.status, 400);
      const ordinary = await request('POST', '/api/admin/faqs', {
        token: h.tokenFor(admin), body: { question: '問題', answer: '答案', source_ticket_id: 8 }
      });
      assert.strictEqual(ordinary.status, 400);
      assert.strictEqual(ordinary.body.code, 'TICKET_NOT_FROM_AI');
    }],

    ['常見問題回流：AI 對話過期或撤回同意而刪除後，仍依工單標記預填，問題改用工單主旨', async () => {
      prisma.store.support_tickets = [
        { ticket_id: 7, user_id: 1, subject: 'AI 客服轉接：取書期限過了怎麼辦', category: 'trade', from_ai_support: true }
      ];
      prisma.store.support_ticket_messages = [
        { message_id: 1, ticket_id: 7, is_staff: false, content: '以下為 AI 客服對話紀錄', created_at: ago(3 * HOUR) },
        { message_id: 2, ticket_id: 7, is_staff: true, content: '逾期未取書時訂單會自動取消並退款。', created_at: ago(2 * HOUR) }
      ];
      prisma.store.ai_support_sessions = [];
      prisma.store.ai_support_messages = [];

      assert.deepStrictEqual(await faqs.draftFromTicket(7), {
        category: 'trade',
        question: '取書期限過了怎麼辦',
        answer: '逾期未取書時訂單會自動取消並退款。',
        source_ticket_id: 7
      });
    }]
  ]
};
