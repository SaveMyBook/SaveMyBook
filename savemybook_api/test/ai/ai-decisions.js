const assert = require('assert');
const h = require('./harness');

const traces = h.api('services/ai/trace');
const decisions = h.api('services/ai/decisions');
const consent = h.api('services/ai/consent');
const support = h.api('services/ai/support');
const bookChat = h.api('services/ai/book-chat');
const recommend = h.api('services/ai/recommend');
const listingAssist = h.api('services/ai/listing-assist');
const semantic = h.api('services/ai/semantic');
const catalog = h.api('services/ai/catalog-search');
const embeddings = h.api('lib/ai/embeddings');
const knowledge = h.api('services/ai/knowledge');
const books = h.api('services/books');
const ranking = h.api('services/ranking');
const isbnLookup = h.api('services/isbn-lookup');
const googleBooks = h.api('lib/google-books');
const openLibrary = h.api('lib/open-library');
const { prisma, runner, settingsService } = h;

const DAY = 24 * 60 * 60 * 1000;
const USER = 1;

const reply = (json, extra = {}) => ({ text: JSON.stringify(json), json, usage: {}, latency_ms: 1, sources: [], ...extra });

const enable = (config = {}) => {
  h.setSettings({ enabled: true, ...config });
  h.setConsent(USER, true);
};

const usageRows = (feature) => prisma.rows('ai_usage_logs').filter((r) => !feature || r.feature === feature);
const decisionRows = (feature) => prisma.rows('ai_decision_logs').filter((r) => !feature || r.feature === feature);
const statsOf = (row) => JSON.parse(row.stats);
const assistantRows = (table) => prisma.rows(table).filter((r) => r.role === 'assistant');
const metaOf = (row) => JSON.parse(row.meta);

const categories = [{ category_id: 1, category_name: '文學小說' }];

const book = (id, overrides = {}) => ({
  book_id: id,
  seller_id: 9,
  title: `推理小說 ${id}`,
  author: '東野圭吾',
  publisher: null,
  description: null,
  isbn: null,
  price: 100 + id,
  status: 'on_sale',
  is_approved: true,
  condition_level: 'good',
  category_id: 1,
  cabinet_id: null,
  view_count: 100 - id,
  book_categories: { category_name: '文學小說' },
  book_images: [],
  users: { user_id: 9, nickname: '賣家', avatar_url: null },
  ...overrides
});

const shelf = (count = 6) => {
  const rows = Array.from({ length: count }, (_, i) => book(i + 1));
  h.onModel('books.findMany', () => rows);
  h.onModel('book_categories.findMany', () => categories);
  return rows;
};

// 暫時替換模組上的函式，測試結束後還原，不影響其他測試檔。
const withStubs = async (stubs, run) => {
  const saved = stubs.map(([target, key]) => [target, key, target[key]]);
  for (const [target, key, value] of stubs) target[key] = value;
  try {
    return await run();
  } finally {
    for (const [target, key, value] of saved) target[key] = value;
  }
};

const withBibliography = (lookup, run) => withStubs([
  [isbnLookup, 'lookupWithSources', async () => {
    if (!lookup) throw new Error('查無資料');
    return lookup;
  }],
  [googleBooks, 'searchVolumesByTitle', async () => []],
  [openLibrary, 'searchByTitle', async () => []]
], () => {
  h.onModel('book_categories.findMany', () => categories);
  return run();
});

const PHONE = '0912345678';
const ISBN = '9789573317241';

module.exports = {
  name: 'AI 決策追蹤紀錄',
  tests: [
    ['提示詞版本只由固定規則文字決定，各功能的版本互不相同', () => {
      assert.strictEqual(traces.promptVersion('規則'), traces.promptVersion('規則'));
      assert.notStrictEqual(traces.promptVersion('規則'), traces.promptVersion('規則二'));
      assert.match(support.PROMPT_VERSION, /^[0-9a-f]{12}$/);
      const versions = [support.PROMPT_VERSION, bookChat.PLAN_VERSION, bookChat.PICK_VERSION, recommend.PROMPT_VERSION, listingAssist.PROMPT_VERSION];
      assert.strictEqual(new Set(versions).size, versions.length);
      assert.notStrictEqual(bookChat.PICK_VERSION, traces.promptVersion(bookChat.PICK_SYSTEM), '使用者提示詞中的固定指示也列入版本');
      assert.notStrictEqual(listingAssist.PROMPT_VERSION, traces.promptVersion(listingAssist.SYSTEM), '網路搜尋等固定指示也列入版本');
    }],

    ['決策紀錄只保留代號、計數與布林值，自由文字一律丟棄', () => {
      const out = decisions.codesOnly({
        path: 'picked',
        title: '推理小說 1',
        note: `電話 ${PHONE}`,
        flags: { handoff: true, '中文鍵': true },
        counts: { docs: 3, bad: Number.NaN },
        list: ['faq', '常見問題'],
        deep: { a: { b: { c: 1 } } }
      });
      assert.deepStrictEqual(out, { path: 'picked', flags: { handoff: true }, counts: { docs: 3 }, list: ['faq'], deep: { a: {} } });

      const ids = decisions.codesOnly({
        phone: PHONE, isbn: ISBN, prefixed: `isbn${ISBN}`, title: 'Dune', book: 'Norwegian Wood', long: 'a'.repeat(31),
        codes: ['INVALID_OUTPUT', 'like_new', 'gemini'], counts: { phone: 912345678, ms: 25000 }
      });
      assert.deepStrictEqual(ids, { codes: ['INVALID_OUTPUT', 'like_new', 'gemini'], counts: { ms: 25000 } });
    }],

    ['處理路徑超過欄位長度時不寫入路徑，決策紀錄照常保存', async () => {
      await decisions.record({ feature: 'support', outcome: 'ok', path: 'a'.repeat(31) });
      await decisions.record({ feature: 'support', outcome: 'ok', path: 'a'.repeat(30) });
      assert.deepStrictEqual(decisionRows('support').map((r) => r.path), [null, 'a'.repeat(30)]);
    }],

    ['runner：用量紀錄帶請求識別碼、提示詞版本與處理結果；備援呼叫沿用同一個識別碼', async () => {
      enable({ features: { support: { provider: 'deepseek', fallback_provider: 'gemini' } } });
      const settings = await settingsService.load();
      const trace = traces.start('support', { userId: USER });
      const base = { settings, provider: 'deepseek', userId: USER, prompt: 'x', json: true, trace, promptVersion: 'abc123abc123' };

      h.queueJson(h.providerError('SERVER'), { reply: '好' });
      await runner.call('support', base);
      assert.deepStrictEqual(usageRows().map((r) => [r.provider, r.outcome, r.request_id, r.prompt_version]), [
        ['deepseek', 'failed', trace.id, 'abc123abc123'],
        ['gemini', 'ok', trace.id, 'abc123abc123']
      ]);

      h.queueJson(() => reply({ reply: '' }));
      await assert.rejects(() => runner.call('support', { ...base, validate: () => ({ detail: '回覆清理後為空', outcome: 'empty' }) }));
      assert.strictEqual(usageRows().at(-1).outcome, 'empty');

      h.queueJson(h.providerError('BLOCKED'));
      await assert.rejects(() => runner.call('support', base), (err) => err.reason === 'BLOCKED');
      assert.strictEqual(usageRows().at(-1).outcome, 'refused');

      h.queueJson(() => reply({ reply: '好' }, { repaired: true }));
      await runner.call('support', base);
      assert.strictEqual(usageRows().at(-1).outcome, 'repaired');

      h.queueJson({ reply: '好' });
      const result = await runner.call('support', { ...base, assess: () => ({ outcome: 'degraded' }) });
      assert.strictEqual(result.outcome, 'degraded');
      assert.strictEqual(usageRows().at(-1).outcome, 'degraded');
      assert.strictEqual(usageRows().at(-1).status, 'ok', '降級只影響處理結果，仍計入每日次數');

      h.queueJson({ reply: '好' });
      await runner.call('support', { settings, provider: 'deepseek', userId: USER, prompt: 'x', json: true });
      assert.match(usageRows().at(-1).request_id, /^[0-9a-f]{16}$/, '沒有 trace 時仍產生識別碼');
    }],

    ['JSON 前後夾帶文字時標記為修復；只有程式碼區塊標記時不算', async () => {
      const ai = h.ai;
      assert.deepStrictEqual(ai.extractJson('好的，結果如下：{"a":1} 以上'), { a: 1 });
      const adapter = ai.PROVIDERS.deepseek.adapter;
      const run = (text) => withStubs([[adapter, 'generate', async () => ({ text, usage: {}, sources: [] })]],
        () => h.realGenerate('deepseek', { prompt: 'x', json: true, apiKey: 'k' }));
      assert.strictEqual((await run('說明文字 {"a":1} 結尾')).repaired, true);
      assert.strictEqual((await run('```json\n{"a":1}\n```')).repaired, undefined);
    }],

    ['AI 客服：助理訊息保存檢索段落與處理路徑，不含使用者原文；重新讀取對話時還原轉接建議', async () => {
      enable();
      h.queueJson({ reply: '請至書櫃掃描機台上的 QR Code 取書。', answer_type: 'answer', sources: [1], suggest_handoff: false });
      const first = await support.sendMessage(USER, `我的電話是 ${PHONE}，買到的書要怎麼取書？`);
      assert.strictEqual(first.reply.suggest_handoff, false);

      const [row] = assistantRows('ai_support_messages');
      const meta = metaOf(row);
      assert.strictEqual(meta.answer_type, 'answer');
      assert.strictEqual(meta.prompt_version, support.PROMPT_VERSION);
      assert.strictEqual(meta.provider, 'deepseek');
      assert.ok(meta.retrieval.length > 0 && meta.retrieval.every((d) => d.id && d.source && typeof d.score === 'number'));
      assert.strictEqual(meta.insufficient, false);
      assert.ok(Number.isFinite(meta.ms.retrieve) && Number.isFinite(meta.ms.model));
      assert.ok(!row.meta.includes(PHONE), 'meta 不得含使用者原文');

      const [decision] = decisionRows('support');
      assert.strictEqual(decision.request_id, meta.request_id);
      assert.strictEqual(decision.user_id, USER);
      assert.strictEqual(decision.outcome, 'ok');
      assert.strictEqual(decision.path, 'answer');
      assert.deepStrictEqual(statsOf(decision).flags, { handoff: false, handoff_forced: false, insufficient: false, degraded: false, follow_ups: false });
      assert.strictEqual(statsOf(decision).counts.cited, 1);
      assert.ok(!decision.stats.includes(PHONE));
      const [call] = usageRows('support');
      assert.strictEqual(call.request_id, meta.request_id, '同一個動作的用量與決策紀錄可以串起來');
      assert.strictEqual(call.prompt_version, support.PROMPT_VERSION);

      h.queueJson({ reply: '款項異常需要由客服人員確認，建議轉接客服人員。', suggest_handoff: true });
      await support.sendMessage(USER, '我的錢包餘額不對');
      const session = await support.currentSession(USER);
      const assistants = session.messages.filter((m) => m.role === 'assistant');
      assert.deepStrictEqual(assistants.map((m) => m.suggest_handoff), [false, true]);
      assert.deepStrictEqual(assistants.map((m) => m.degraded), [false, false]);
      assert.ok(session.messages.filter((m) => m.role === 'user').every((m) => !('suggest_handoff' in m)));
    }],

    ['AI 客服：改用說明原文或安全替換時記為降級；內容遭阻擋時記為遭拒絕', async () => {
      enable();
      h.queueJson(h.providerError('SERVER'));
      const fallback = await support.sendMessage(USER, '要怎麼取書？');
      assert.strictEqual(fallback.degraded, true);
      assert.strictEqual(metaOf(assistantRows('ai_support_messages')[0]).answer_type, 'passage');
      assert.strictEqual(metaOf(assistantRows('ai_support_messages')[0]).error, 'SERVER');
      assert.deepStrictEqual([decisionRows()[0].outcome, decisionRows()[0].path], ['degraded', 'passage']);

      h.queueJson({ reply: '請加 LINE：abc12345 與我聯絡，或撥 0912345678。', suggest_handoff: false });
      const guarded = await support.sendMessage(USER, '要怎麼取書？');
      assert.strictEqual(guarded.reply.content, support.GUARDED_REPLY);
      assert.deepStrictEqual([decisionRows()[1].outcome, decisionRows()[1].path], ['degraded', 'guarded']);
      assert.strictEqual(usageRows('support').at(-1).outcome, 'degraded');

      h.queueJson(h.providerError('BLOCKED'));
      await assert.rejects(() => support.sendMessage(USER, '要怎麼取書？'), (err) => err.reason === 'BLOCKED');
      assert.strictEqual(decisionRows()[2].outcome, 'refused');
      assert.strictEqual(assistantRows('ai_support_messages').length, 2, '遭拒絕時不寫入對話');
    }],

    ['AI 客服：依介面語系放寬英文追問建議的長度，降級回覆以該語系標示相關說明，決策紀錄只記語系代碼', async () => {
      enable();
      const english = 'How long do I have to pick up my book?';
      h.queueJson({ reply: 'You can pick it up at the locker.', answer_type: 'answer', sources: [1], follow_ups: [english] });
      const first = await support.sendMessage(USER, 'How do I pick up my book?', { locale: 'en' });
      assert.deepStrictEqual(first.reply.suggestions, [english]);
      assert.strictEqual(statsOf(decisionRows('support')[0]).locale, 'en');

      h.queueJson(h.providerError('SERVER'));
      const fallback = await support.sendMessage(USER, '受け取り方法を教えてください', { locale: 'ja' });
      assert.strictEqual(fallback.degraded, true);
      assert.ok(fallback.reply.content.startsWith('関連する説明は以下のとおりです：'));
      assert.ok(!decisionRows('support')[1].stats.includes('受け取り'), '決策紀錄不含使用者原文');
    }],

    ['AI 客服：回覆清理後為空、又沒有檢索段落可改用時，決策紀錄為清理後為空', async () => {
      enable();
      h.queueJson({ reply: '   ', suggest_handoff: false }, { reply: '<p></p>', suggest_handoff: false });
      await withStubs([[knowledge, 'search', async () => []]], () =>
        assert.rejects(() => support.sendMessage(USER, '要怎麼取書？'), (err) => err.reason === 'INVALID_OUTPUT'));
      const [decision] = decisionRows('support');
      assert.deepStrictEqual([decision.outcome, decision.path], ['empty', null]);
      assert.strictEqual(usageRows('support')[0].outcome, 'empty');
    }],

    ['書籍顧問：重新讀取對話時還原推薦理由與追問建議；追問時提示詞帶入前一輪條件與書價', async () => {
      enable();
      shelf();
      h.queueJson(
        { reply: '為您搜尋推理小說。', topic: 'new', search: { keywords: ['推理'], max_price: 300 }, need_more_info: false },
        { reply: '以下是推理小說。', book_ids: ['b2', 'b1'], reasons: { b2: '節奏明快，適合通勤' }, suggestions: ['有沒有更便宜的'] }
      );
      await bookChat.sendMessage(USER, `推理小說，我的電話 ${PHONE}`);

      const [row] = assistantRows('ai_chat_messages');
      const meta = metaOf(row);
      assert.strictEqual(meta.path, 'picked');
      assert.strictEqual(meta.topic, 'new');
      assert.deepStrictEqual(meta.search.keywords, ['推理']);
      assert.strictEqual(meta.search.max_price, 300);
      assert.deepStrictEqual(meta.reasons, { 2: '節奏明快，適合通勤' });
      assert.deepStrictEqual(meta.prices, { 1: 101, 2: 102 });
      assert.deepStrictEqual(meta.prompt_versions, { plan: bookChat.PLAN_VERSION, pick: bookChat.PICK_VERSION });
      assert.ok(meta.counts.candidates > 0);
      assert.ok(!row.meta.includes(PHONE));

      const session = await bookChat.currentSession(USER);
      const assistant = session.messages.find((m) => m.role === 'assistant');
      assert.deepStrictEqual(assistant.books.map((b) => [b.book.book_id, b.reason]), [[2, '節奏明快，適合通勤'], [1, null]]);
      assert.deepStrictEqual(assistant.suggestions, ['有沒有更便宜的']);
      assert.strictEqual(assistant.degraded, false);

      h.queueJson(
        { reply: '為您找更便宜的推理小說。', topic: 'continue', search: { keywords: [], max_price: 101 }, need_more_info: false },
        { reply: '以下是較便宜的推理小說。', book_ids: ['b1'], reasons: {}, suggestions: [] }
      );
      await bookChat.sendMessage(USER, '有沒有更便宜的');
      const planPrompt = h.calls[2].options.prompt;
      assert.match(planPrompt, /【前一輪搜尋條件】\n\{"keywords":\["推理"\]/);
      assert.match(planPrompt, /【前一輪展示的書】\n《推理小說 2》102 代幣\n《推理小說 1》101 代幣/);
      assert.match(bookChat.PLAN_SYSTEM, /topic 輸出 continue 或 new/);

      const second = metaOf(assistantRows('ai_chat_messages')[1]);
      assert.strictEqual(second.topic, 'continue');
      assert.strictEqual(second.inherited, true, '模型判斷延續卻漏了主題時沿用前一輪的關鍵字');
      assert.deepStrictEqual(second.search.keywords, ['推理']);
      assert.strictEqual(second.search.max_price, 101);
      const decision = decisionRows('book_chat')[1];
      assert.strictEqual(statsOf(decision).flags.continued, true);
      assert.strictEqual(statsOf(decision).flags.inherited, true);
    }],

    ['書籍顧問：任一段輸出經修復後採用時，決策紀錄為修復後採用', async () => {
      enable();
      shelf();
      h.queueJson(
        () => reply({ reply: '為您搜尋推理小說。', topic: 'new', search: { keywords: ['推理'] }, need_more_info: false }, { repaired: true }),
        { reply: '推薦如下。', book_ids: ['b1'], reasons: {}, suggestions: [] },
        { reply: '為您搜尋推理小說。', topic: 'new', search: { keywords: ['推理'] }, need_more_info: false },
        () => reply({ reply: '推薦如下。', book_ids: ['b1'], reasons: {}, suggestions: [] }, { repaired: true }),
        { reply: '為您搜尋推理小說。', topic: 'new', search: { keywords: ['推理'] }, need_more_info: false },
        { reply: '推薦如下。', book_ids: ['b1'], reasons: {}, suggestions: [] }
      );
      await bookChat.sendMessage(USER, '推理小說');
      await bookChat.sendMessage(USER, '推理小說');
      await bookChat.sendMessage(USER, '推理小說');
      assert.deepStrictEqual(decisionRows('book_chat').map((r) => r.outcome), ['repaired', 'repaired', 'ok']);
    }],

    ['書籍顧問：主要與備援服務商都失敗時，附加資料記錄最後失敗的備援服務商', async () => {
      enable({ features: { book_chat: { provider: 'deepseek', fallback_provider: 'gemini' } } });
      shelf();
      const settings = await settingsService.load();
      h.queueJson(new h.ai.AiProviderError('SERVER', { provider: 'deepseek' }), new h.ai.AiProviderError('SERVER', { provider: 'gemini' }));
      const data = await bookChat.sendMessage(USER, '推理小說');
      assert.strictEqual(data.reply.degraded, true);
      const meta = metaOf(assistantRows('ai_chat_messages')[0]);
      assert.deepStrictEqual(meta.plan, { provider: 'gemini', model: settings.providers.gemini.model, error: 'SERVER' });
      assert.strictEqual(meta.pick, null, '服務中斷時不呼叫第二段');
    }],

    ['書籍顧問：換新主題時不沿用前一輪條件；價格不自動補回', async () => {
      enable();
      shelf();
      h.queueJson(
        { reply: '為您搜尋。', topic: 'new', search: { keywords: ['推理'], max_price: 150 }, need_more_info: false },
        { reply: '推薦如下。', book_ids: ['b1'], reasons: {}, suggestions: [] },
        { reply: '為您搜尋。', topic: 'continue', search: { keywords: ['東野圭吾'], max_price: null }, need_more_info: false },
        { reply: '推薦如下。', book_ids: ['b1'], reasons: {}, suggestions: [] },
        { reply: '為您搜尋。', topic: 'new', search: { keywords: [], category_ids: [] }, need_more_info: false },
        { reply: '推薦如下。', book_ids: ['b1'], reasons: {}, suggestions: [] }
      );
      await bookChat.sendMessage(USER, '推理小說 150 元以內');
      await bookChat.sendMessage(USER, '不限預算，想看東野圭吾');
      await bookChat.sendMessage(USER, '隨便推薦');
      const [, unlimited, fresh] = assistantRows('ai_chat_messages').map(metaOf);
      assert.strictEqual(unlimited.search.max_price, null, '「不限預算」不補回前一輪的價格上限');
      assert.strictEqual(unlimited.inherited, false);
      assert.deepStrictEqual(fresh.search.keywords, []);
      assert.strictEqual(fresh.inherited, false);
    }],

    ['書籍顧問：書單代號全部無效時，選書呼叫記為降級，處理路徑為檢索排序', async () => {
      enable();
      shelf();
      h.queueJson(
        { reply: '為您搜尋推理小說。', topic: 'new', search: { keywords: ['推理'] }, need_more_info: false },
        { reply: '推薦如下。', book_ids: ['b99'], reasons: {}, suggestions: [] }
      );
      const data = await bookChat.sendMessage(USER, '推理小說');
      assert.strictEqual(data.reply.degraded, true);
      assert.strictEqual(usageRows('book_chat_pick')[0].outcome, 'degraded');
      assert.strictEqual(usageRows('book_chat_pick')[0].prompt_version, bookChat.PICK_VERSION);
      const [decision] = decisionRows('book_chat');
      assert.deepStrictEqual([decision.outcome, decision.path], ['degraded', 'retrieval']);
      assert.strictEqual(statsOf(decision).flags.invalid_picks, true);
      const plan = usageRows('book_chat')[0];
      assert.strictEqual(plan.request_id, decision.request_id);
    }],

    ['推薦：每次產生寫入一筆決策紀錄，記錄候選數、無效代號與被丟棄的理由', async () => {
      enable();
      const catalogue = [1, 2, 3, 4].map((id) => ({ book_id: id, title: `書 ${id}`, condition_level: 'good', book_categories: { category_name: '文學小說' } }));
      const favorite = { book_id: 9, books: { title: '收藏', is_approved: true, status: 'on_sale', book_categories: { category_name: '文學小說' } } };
      const signals = { purchases: [], favorites: [favorite], cart: [], viewed: [], seen: new Set([9]), fingerprint: 'fp', empty: false };
      h.queueJson({
        items: [
          { id: 'b2', basis: 'k1', reason: '' },
          { id: 'b2', reason: '重複' },
          { id: 'b77', reason: '不存在' },
          { id: 'b1', basis: 'x9', reason: `請洽 ${PHONE}` }
        ]
      });
      await withStubs([
        [books, 'inIdOrder', async (ids) => ids.map((id) => catalogue.find((b) => b.book_id === id)).filter(Boolean)],
        [ranking, 'recommendedIds', async () => [1, 2, 3]],
        [ranking, 'rankedIds', async () => [4]],
        [catalog, 'search', async () => []]
      ], async () => {
        const access = await runner.access('recommend');
        await recommend.refresh(USER, access, signals, [], null);
      });
      const [decision] = decisionRows('recommend');
      assert.deepStrictEqual([decision.outcome, decision.path, decision.user_id], ['ok', 'generated', USER]);
      const { counts } = statsOf(decision);
      assert.strictEqual(counts.candidates, 4);
      assert.strictEqual(counts.fillers, 1);
      assert.strictEqual(counts.returned, 4);
      assert.strictEqual(counts.picked, 2);
      assert.strictEqual(counts.invalid, 1);
      assert.strictEqual(counts.duplicate, 1);
      assert.strictEqual(counts.reasons_dropped, 1);
      assert.strictEqual(counts.basis_dropped, 1);
      assert.strictEqual(counts.related, 4, '同分類的候選書都列出分類關聯');
      assert.strictEqual(counts.templated, 1);
      assert.strictEqual(counts.favorites, 1);
      assert.ok(!decision.stats.includes(PHONE));
      assert.strictEqual(usageRows('recommend')[0].request_id, decision.request_id);
      assert.strictEqual(usageRows('recommend')[0].prompt_version, recommend.PROMPT_VERSION);
    }],

    ['上架輔助：記錄處理路徑、描述來源與被丟棄的欄位；模型失敗時記為降級並帶入書目', async () => {
      enable({ features: { listing_assist: { provider: 'gemini', web_search: false } } });
      h.queueJson({
        fields: { title: '挪威的森林', isbn: '123', description: '一段簡介。'.repeat(20) },
        category_id: 999,
        condition: { level: 'perfect' },
        price: { suggested: 250, original_price: 380 },
        sources: [{ title: '捏造', url: 'https://made-up.example.com' }],
        warnings: []
      });
      await withBibliography(null, () => listingAssist.assist({ userId: USER, isbn: '', title: '挪威的森林', files: [] }));
      const [decision] = decisionRows('listing_assist');
      assert.deepStrictEqual([decision.outcome, decision.path], ['ok', 'model']);
      const stats = statsOf(decision);
      // 沒有書目、搜尋或照片可依據的簡介不採用（P11），計入被丟棄的欄位。
      assert.deepStrictEqual(stats.dropped, { isbn: 1, description: 1, category: 1, condition: 1, price: 0, sources: 1 });
      assert.strictEqual(stats.description, 'none');
      assert.strictEqual(stats.flags.title, true);
      assert.strictEqual(usageRows('listing_assist')[0].prompt_version, listingAssist.PROMPT_VERSION);
      assert.strictEqual(stats.flags.used_search, false);

      h.queueJson(h.providerError('SERVER'));
      const lookup = { fields: { title: '挪威的森林', author: '村上春樹' }, sources: [] };
      await withBibliography(lookup, () => listingAssist.assist({ userId: USER, isbn: '9789573317241', title: '', files: [] }));
      const fallback = decisionRows('listing_assist')[1];
      assert.deepStrictEqual([fallback.outcome, fallback.path], ['degraded', 'bibliographic']);
      assert.strictEqual(statsOf(fallback).flags.structured, true);
    }],

    ['上架輔助：「使用網路搜尋」依服務商回報的實際搜尋次數判斷，不是依設定', async () => {
      enable({ features: { listing_assist: { provider: 'gemini', web_search: true } } });
      const fields = { fields: { title: '挪威的森林' }, sources: [], warnings: [] };
      h.queueJson(() => reply(fields, { usage: { search_calls: 0 } }), () => reply(fields, { usage: { search_calls: 2 } }));
      await withBibliography(null, () => listingAssist.assist({ userId: USER, isbn: '', title: '挪威的森林', files: [] }));
      await withBibliography(null, () => listingAssist.assist({ userId: USER, isbn: '', title: '挪威的森林', files: [] }));
      const flags = decisionRows('listing_assist').map((r) => statsOf(r).flags);
      assert.deepStrictEqual(flags.map((f) => [f.search_requested, f.used_search]), [[true, false], [true, true]]);
    }],

    ['查詢向量的費用記在發起的功能與請求識別碼之下，文件向量記為索引更新', async () => {
      enable();
      const saved = embeddings.ORDER;
      embeddings.ORDER = ['gemini'];
      const docs = [{ ref: 'a', text: '推理小說', hash: 'h1' }];
      const unit = () => embeddings.normalize(Array.from({ length: embeddings.PROFILES.gemini.dimensions }, (_, i) => (i === 0 ? 1 : 0)));
      h.onSql(/SELECT ref_id, content_hash, vector FROM ai_embeddings/, () => []);
      h.onSql(/INSERT INTO ai_embeddings/, () => 1);
      try {
        await withStubs([[embeddings, 'embed', async (p, key, texts) => ({
          vectors: texts.map(unit), tokens: texts.length, cost_usd: 0.00001, latency_ms: 1
        })]], async () => {
          const trace = traces.start('book_chat', { userId: USER });
          await semantic.rank('book', docs, '推理', { userId: USER, trace, inlineSync: true });
          const rows = usageRows('embedding');
          const query = rows.find((r) => r.request_id === trace.id);
          assert.ok(query, '查詢向量帶有請求識別碼');
          assert.strictEqual(query.origin, 'book_chat');
          assert.ok(rows.some((r) => r.origin === 'index' && r.request_id == null), '請求中當場補算的文件向量也記為索引更新');
          assert.ok(rows.every((r) => r.origin != null));
          await semantic.rank('book', docs, '偵探', { trace: traces.origin('book_search') });
          assert.strictEqual(usageRows('embedding').at(-1).origin, 'book_search');
        });
      } finally {
        embeddings.ORDER = saved;
        semantic.reset();
      }
    }],

    ['保存期限：決策紀錄與訊息的附加資料滿 90 天刪除；撤回同意時刪除本人的決策紀錄', async () => {
      const now = new Date();
      const old = new Date(now.getTime() - 91 * DAY);
      const recent = new Date(now.getTime() - 10 * DAY);
      prisma.store.ai_decision_logs = [
        { log_id: 1, request_id: 'a', feature: 'support', user_id: USER, outcome: 'ok', path: 'answer', stats: '{}', created_at: old },
        { log_id: 2, request_id: 'b', feature: 'support', user_id: USER, outcome: 'ok', path: 'answer', stats: '{}', created_at: recent },
        { log_id: 3, request_id: 'c', feature: 'recommend', user_id: 2, outcome: 'ok', path: 'generated', stats: '{}', created_at: recent }
      ];
      prisma.store.ai_support_messages = [
        { message_id: 1, session_id: 1, role: 'assistant', content: '舊', meta: '{"path":"answer"}', created_at: old },
        { message_id: 2, session_id: 1, role: 'assistant', content: '新', meta: '{"path":"answer"}', created_at: recent }
      ];
      prisma.store.ai_chat_messages = [{ message_id: 1, session_id: 1, role: 'assistant', content: '舊', meta: '{}', created_at: old }];

      assert.deepStrictEqual(await decisions.purgeExpired(now), { logs: 1, meta: 2 });
      assert.deepStrictEqual(prisma.rows('ai_decision_logs').map((r) => r.log_id), [2, 3]);
      assert.deepStrictEqual(prisma.rows('ai_support_messages').map((r) => r.meta), [null, '{"path":"answer"}']);
      assert.strictEqual(prisma.rows('ai_chat_messages')[0].meta, null);

      await consent.setGranted(USER, false);
      assert.deepStrictEqual(prisma.rows('ai_decision_logs').map((r) => r.user_id), [2]);
    }],

    ['個資匯出包含本人的決策紀錄與助理訊息的附加資料', async () => {
      prisma.store.ai_decision_logs = [
        { log_id: 1, request_id: 'a', feature: 'recommend', user_id: USER, outcome: 'ok', path: 'generated', stats: '{"counts":{"picked":2}}', created_at: new Date() },
        { log_id: 2, request_id: 'b', feature: 'recommend', user_id: 2, outcome: 'ok', path: 'generated', stats: '{}', created_at: new Date() }
      ];
      const data = await consent.exportUser(USER);
      assert.deepStrictEqual(data.decision_logs.map((r) => [r.feature, r.path, r.stats]), [['recommend', 'generated', { counts: { picked: 2 } }]]);
      assert.ok(Array.isArray(data.support_sessions) && Array.isArray(data.book_chat_sessions));
    }],

    ['後台處理結果統計：只提供彙總數字，依功能統計處理結果、路徑、旗標與提示詞版本', async () => {
      h.setSettings({ enabled: true });
      const admin = h.addAdmin({ can_view_stats: true });
      const statsAdmin = h.addAdmin({});
      const at = new Date();
      prisma.store.ai_decision_logs = [
        { log_id: 1, request_id: 'r1', feature: 'support', user_id: 5, outcome: 'ok', path: 'answer', stats: '{"flags":{"handoff":true,"insufficient":false},"counts":{"docs":4}}', created_at: at },
        { log_id: 2, request_id: 'r2', feature: 'support', user_id: 5, outcome: 'degraded', path: 'passage', stats: '{"flags":{"handoff":true,"insufficient":true},"counts":{"docs":2}}', created_at: at },
        { log_id: 3, request_id: 'r3', feature: 'book_chat', user_id: 6, outcome: 'ok', path: 'declined', stats: '{"flags":{"continued":true}}', created_at: at },
        { log_id: 4, request_id: 'r4', feature: 'support', user_id: 5, outcome: 'ok', path: 'answer', stats: '{}', created_at: new Date(at.getTime() - 60 * DAY) }
      ];
      h.addUsageLog({ feature: 'support', prompt_version: 'v1v1v1v1v1v1', outcome: 'ok', request_id: 'r1' });
      h.addUsageLog({ feature: 'support', prompt_version: 'v1v1v1v1v1v1', outcome: 'failed', status: 'error', request_id: 'r2' });
      h.addUsageLog({ feature: 'embedding', origin: 'book_chat', cost_usd: 0.0002 });
      h.addUsageLog({ feature: 'embedding', origin: null, cost_usd: 0.001 });
      h.addUsageLog({ feature: 'embedding', origin: 'index', cost_usd: 0.0005 });
      h.addUsageLog({ feature: 'book_chat', provider: 'deepseek', status: 'error', error_code: 'INVALID_OUTPUT' });
      h.addUsageLog({ feature: 'book_chat', provider: 'deepseek', outcome: 'repaired', format_dropped: 2 });
      h.addUsageLog({ feature: 'book_chat', provider: 'deepseek', status: 'error', error_code: 'INVALID_OUTPUT', outcome: 'empty', format_defaulted: 1 });
      h.addUsageLog({ feature: 'book_chat', provider: 'deepseek', status: 'error', error_code: 'TIMEOUT', outcome: 'not_sent' });
      h.addUsageLog({ feature: 'book_chat', provider: 'openai', status: 'error', error_code: 'INCOMPLETE' });
      h.addUsageLog({ feature: 'test', provider: 'openai', status: 'error', error_code: 'INVALID_OUTPUT' });

      const res = await h.request('GET', '/api/admin/ai/decisions?period=7d', { token: h.tokenFor(admin) });
      assert.strictEqual(res.status, 200);
      const data = res.body.data;
      const supportRow = data.features.find((f) => f.feature === 'support');
      assert.strictEqual(supportRow.total, 2);
      assert.deepStrictEqual(supportRow.outcomes, { ok: 1, repaired: 0, degraded: 1, empty: 0, refused: 0, failed: 0 });
      assert.deepStrictEqual(supportRow.paths, { answer: 1, passage: 1 });
      assert.deepStrictEqual(supportRow.flags, { handoff: 2, insufficient: 1 });
      assert.deepStrictEqual(supportRow.averages, { docs: 3 });
      assert.deepStrictEqual(data.features.map((f) => f.feature), ['support', 'book_chat', 'recommend', 'listing_assist']);
      assert.deepStrictEqual(data.prompt_versions.map((v) => [v.feature, v.prompt_version, v.requests, v.errors]), [['support', 'v1v1v1v1v1v1', 2, 1]]);
      assert.deepStrictEqual(data.embedding_by_origin.map((e) => e.origin), ['unknown', 'index', 'book_chat'], '上線前沒有來源的用量不算成索引更新');
      // 格式錯誤依功能與服務商分開統計，不含嵌入、連線測試與沒有送出的紀錄；清理後為空不算格式錯誤。
      assert.deepStrictEqual(data.format_errors.filter((r) => r.feature === 'book_chat'), [
        { feature: 'book_chat', provider: 'deepseek', requests: 3, invalid_output: 1, incomplete: 0, repaired: 1, dropped: 1, defaulted: 1 },
        { feature: 'book_chat', provider: 'openai', requests: 1, invalid_output: 0, incomplete: 1, repaired: 0, dropped: 0, defaulted: 0 }
      ]);
      assert.ok(!data.format_errors.some((r) => ['embedding', 'test'].includes(r.feature)));
      assert.ok(!JSON.stringify(data).includes('"user_id"'), '不提供任何使用者明細');
      assert.ok(!JSON.stringify(data).includes('r1'), '不提供請求識別碼');

      const denied = await h.request('GET', '/api/admin/ai/decisions', { token: h.tokenFor(statsAdmin) });
      assert.strictEqual(denied.status, 403);
      const bad = await h.request('GET', '/api/admin/ai/decisions?period=year', { token: h.tokenFor(admin) });
      assert.strictEqual(bad.status, 400);
    }]
  ]
};
