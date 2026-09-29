const assert = require('assert');
const h = require('./harness');

const deadlines = h.api('services/ai/deadline');
const breaker = h.api('services/ai/breaker');
const requests = h.api('services/ai/requests');
const consent = h.api('services/ai/consent');
const support = h.api('services/ai/support');
const knowledge = h.api('services/ai/knowledge');
const bookChat = h.api('services/ai/book-chat');
const catalogSearch = h.api('services/ai/catalog-search');
const listingAssist = h.api('services/ai/listing-assist');
const isbnLookup = h.api('services/isbn-lookup');
const googleBooks = h.api('lib/google-books');
const openLibrary = h.api('lib/open-library');
const { prisma, runner, settingsService, usageService } = h;

const reply = (json, usage = {}) => ({ text: JSON.stringify(json), json, usage, latency_ms: 1, sources: [] });

const lastLog = () => prisma.rows('ai_usage_logs').at(-1);

// 以較短的整體時限取代 25 秒，模擬前面的步驟已用掉大部分時間。
const withDeadline = async (totalMs, run) => {
  const original = deadlines.start;
  deadlines.start = () => original(totalMs);
  try {
    return await run();
  } finally {
    deadlines.start = original;
  }
};

const enable = (config = {}) => {
  h.setSettings({ enabled: true, ...config });
  h.setConsent(1, true);
};

const categories = [{ category_id: 1, category_name: '文學小說' }];

const book = (id) => ({
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
  users: { user_id: 9, nickname: '賣家', avatar_url: null }
});

const shelf = (count = 8) => {
  const rows = Array.from({ length: count }, (_, i) => book(i + 1));
  h.onModel('books.findMany', () => rows);
  h.onModel('book_categories.findMany', () => categories);
  return rows;
};

const plan = { reply: '為您搜尋推理小說。', search: { keywords: ['推理'] }, need_more_info: false };

// 上架輔助的書目來源一律以假資料取代，測試不得連外。
const withBibliography = async (lookup, run) => {
  const saved = [isbnLookup.lookupWithSources, googleBooks.searchVolumesByTitle, openLibrary.searchByTitle];
  isbnLookup.lookupWithSources = async () => {
    if (!lookup) throw new Error('查無資料');
    return lookup;
  };
  googleBooks.searchVolumesByTitle = async () => [];
  openLibrary.searchByTitle = async () => [];
  h.onModel('book_categories.findMany', () => categories);
  try {
    return await run();
  } finally {
    [isbnLookup.lookupWithSources, googleBooks.searchVolumesByTitle, openLibrary.searchByTitle] = saved;
  }
};

// 讓 Date.now 往後跳，模擬呼叫耗掉的時間。
const withClock = async (run) => {
  const realNow = Date.now;
  let offset = 0;
  Date.now = () => realNow() + offset;
  try {
    return await run((ms) => { offset += ms; });
  } finally {
    Date.now = realNow;
  }
};

const assistAnswer = {
  fields: { title: '地方志研究', description: '' },
  category_id: null,
  condition: null,
  price: null,
  sources: [{ title: '參考網頁', url: 'https://made-up.example.com/book' }],
  warnings: []
};

module.exports = {
  name: 'AI 時限、降級與防止重複',
  tests: [
    ['整體時限：扣除保留時間且不超過上限，不足最低時間時為 0', () => {
      const d = deadlines.start(10000);
      const budget = d.budget({ reserve: 1500, cap: 20000 });
      assert.ok(budget > 8400 && budget <= 8500, String(budget));
      assert.strictEqual(d.budget({ cap: 5000 }), 5000);
      assert.strictEqual(deadlines.start(4000).budget(), 0);
      assert.ok(deadlines.INTERACTIVE_MS < 30000, '須短於 App 的 30 秒請求逾時');
    }],

    ['runner：以剩餘時間作為逾時；時間不足時不送出請求，記一筆零費用的逾時錯誤', async () => {
      enable();
      const settings = await settingsService.load();
      h.queueJson({ reply: '好' });
      await runner.call('support', { settings, provider: 'deepseek', userId: 1, deadline: deadlines.start(8000), prompt: 'x', json: true });
      const { timeoutMs } = h.calls[0].options;
      assert.ok(timeoutMs > 6000 && timeoutMs <= 6500, String(timeoutMs));

      await assert.rejects(
        () => runner.call('support', { settings, provider: 'deepseek', userId: 1, deadline: deadlines.start(4000), prompt: 'x' }),
        (err) => err.reason === 'TIMEOUT' && err.notSent === true
      );
      assert.strictEqual(h.calls.length, 1);
      const log = lastLog();
      assert.strictEqual(log.status, 'error');
      assert.strictEqual(log.error_code, 'TIMEOUT');
      assert.strictEqual(log.error_detail, '剩餘時間不足，未送出請求');
      assert.strictEqual(Number(log.cost_usd), 0);
    }],

    ['runner：驗證不通過的回應記為格式錯誤並計費，但不計入每日次數', async () => {
      enable();
      const settings = await settingsService.load();
      h.queueJson(() => reply({ reply: '' }, { input_tokens: 1000, output_tokens: 100 }));
      await assert.rejects(
        () => runner.call('support', {
          settings, provider: 'deepseek', userId: 1, prompt: 'x', json: true, validate: (r) => (r.json.reply ? null : '回覆清理後為空')
        }),
        (err) => err.reason === 'INVALID_OUTPUT'
      );
      const log = lastLog();
      assert.strictEqual(log.error_code, 'INVALID_OUTPUT');
      assert.strictEqual(log.error_detail, '回覆清理後為空');
      assert.ok(Number(log.cost_usd) > 0);
      assert.strictEqual(await usageService.dailyCount(1, 'support'), 0);
      assert.strictEqual(await usageService.billedFailureCount(1, 'support'), 1);
    }],

    ['備援服務商：主要服務商服務中斷時改用備援；內容遭阻擋或格式錯誤時不改用', async () => {
      enable({ features: { support: { provider: 'deepseek', fallback_provider: 'gemini' } } });
      const settings = await settingsService.load();
      const request = { settings, provider: 'deepseek', userId: 1, prompt: 'x', json: true };

      h.queueJson(h.providerError('SERVER'), { reply: '備援回覆' });
      const result = await runner.call('support', request);
      assert.deepStrictEqual(h.calls.map((c) => c.provider), ['deepseek', 'gemini']);
      assert.strictEqual(result.provider, 'gemini');
      assert.deepStrictEqual(prisma.rows('ai_usage_logs').map((r) => [r.provider, r.status]), [['deepseek', 'error'], ['gemini', 'ok']]);

      for (const reason of ['BLOCKED', 'INVALID_OUTPUT']) {
        const before = h.calls.length;
        h.queueJson(h.providerError(reason));
        await assert.rejects(() => runner.call('support', request), (err) => err.reason === reason);
        assert.strictEqual(h.calls.length, before + 1, reason);
      }

      assert.strictEqual(runner.fallbackFor(settings, 'book_chat_pick', 'deepseek'), null);
      const withBackup = settingsService.normalize({ enabled: true, features: { book_chat: { fallback_provider: 'gemini' } } });
      assert.strictEqual(runner.fallbackFor(withBackup, 'book_chat_pick', 'deepseek'), 'gemini', '第二段沿用書籍顧問的設定');
      const visionless = settingsService.normalize({ enabled: true, features: { moderation: { fallback_provider: 'deepseek' } } });
      assert.strictEqual(runner.fallbackFor(visionless, 'moderation', 'gemini', { needsVision: true }), null, '備援不支援影像時不改用');
      const searchless = settingsService.normalize({ enabled: true, features: { listing_assist: { fallback_provider: 'deepseek' } } });
      assert.strictEqual(runner.fallbackFor(searchless, 'listing_assist', 'gemini', { needsSearch: true }), null, '備援不支援搜尋時不改用');
      assert.strictEqual(runner.fallbackFor(searchless, 'listing_assist', 'gemini'), 'deepseek');
    }],

    ['上架輔助：主要服務商可搜尋而備援不行時，搜尋請求不改用備援；不搜尋的重試才改用，且不採用模型列出的網址', async () => {
      enable({ features: { listing_assist: { provider: 'gemini', web_search: true, fallback_provider: 'deepseek' } } });
      h.queueJson(h.providerError('SERVER'), h.providerError('SERVER'), assistAnswer);
      const data = await withBibliography(null, () => listingAssist.assist({ userId: 1, isbn: '', title: '地方志研究', files: [] }));
      assert.deepStrictEqual(h.calls.map((c) => [c.provider, c.options.search]), [['gemini', true], ['gemini', false], ['deepseek', false]]);
      assert.match(h.calls[2].options.prompt, /【網路搜尋】未開放/);
      assert.strictEqual(data.provider, 'deepseek');
      assert.deepStrictEqual(data.sources, []);
      assert.strictEqual(data.fields.description, '');
      assert.strictEqual(data.description_source, '');
    }],

    ['上架輔助：備援與不搜尋的重試共用整體時限，時間不足時不再重試，直接回傳書目資料', async () => {
      assert.ok(listingAssist.ASSIST_MS < 90000, '須短於 App 上傳請求的 90 秒逾時');
      enable({ features: { listing_assist: { provider: 'gemini', web_search: true, fallback_provider: 'deepseek' } } });
      const lookup = { fields: { title: '地方志研究', author: '王小明' }, sources: [{ title: 'Open Library', url: 'https://openlibrary.org/isbn/9789573317241' }] };
      const data = await withClock((elapse) => {
        const timeout = (ms) => async () => {
          elapse(ms);
          throw h.providerError('TIMEOUT');
        };
        h.queueJson(timeout(55000), timeout(13000));
        return withBibliography(lookup, () => listingAssist.assist({ userId: 1, isbn: '9789573317241', title: '', files: [] }));
      });
      assert.deepStrictEqual(h.calls.map((c) => [c.provider, c.options.search]), [['gemini', true], ['gemini', false]]);
      assert.strictEqual(h.calls[0].options.timeoutMs, 50000);
      const retryTimeout = h.calls[1].options.timeoutMs;
      assert.ok(retryTimeout <= listingAssist.ASSIST_MS - 55000 - listingAssist.LOOKUP_RESERVE_MS, String(retryTimeout));
      assert.strictEqual(data.fields.title, '地方志研究');
      assert.ok(data.warnings.includes('AI 建議暫時無法取得，已帶入書籍資訊'));
    }],

    ['斷路器：連續 3 次服務中斷後暫停呼叫；有備援時直接改用備援；期滿後放行一次', async () => {
      enable();
      const settings = await settingsService.load();
      const request = { settings, provider: 'deepseek', userId: 1, prompt: 'x', json: true };
      for (let i = 0; i < breaker.FAILURE_LIMIT; i += 1) {
        h.queueJson(h.providerError('SERVER'));
        await assert.rejects(() => runner.call('support', request));
      }
      await assert.rejects(() => runner.call('support', request), (err) => err.reason === 'SERVER' && err.notSent === true);
      assert.strictEqual(h.calls.length, breaker.FAILURE_LIMIT);
      assert.strictEqual(lastLog().error_detail, '服務商連續失敗，暫停呼叫');

      enable({ features: { support: { fallback_provider: 'gemini' } } });
      const backup = await settingsService.load();
      h.queueJson({ reply: '備援回覆' });
      await runner.call('support', { ...request, settings: backup });
      assert.strictEqual(h.calls.at(-1).provider, 'gemini');
      assert.strictEqual(h.calls.length, breaker.FAILURE_LIMIT + 1, '不先等主要服務商失敗');

      const realNow = Date.now;
      Date.now = () => realNow() + breaker.OPEN_MS + 1000;
      try {
        h.queueJson(h.providerError('SERVER'));
        await assert.rejects(() => runner.call('support', request), (err) => !err.notSent);
        await assert.rejects(() => runner.call('support', request), (err) => err.notSent === true);
        h.queueJson({ reply: '管理員連線測試不受暫停影響' });
        await runner.call('test', request);
      } finally {
        Date.now = realNow;
      }
    }],

    ['斷路器：暫停期滿後只放行一個探測請求，同時進來的請求改用備援；探測成功才恢復', async () => {
      enable();
      const settings = await settingsService.load();
      for (let i = 0; i < breaker.FAILURE_LIMIT; i += 1) {
        h.queueJson(h.providerError('SERVER'));
        await assert.rejects(() => runner.call('support', { settings, provider: 'deepseek', userId: 1, prompt: 'x' }));
      }
      enable({ features: { support: { fallback_provider: 'gemini' } } });
      const request = { settings: await settingsService.load(), provider: 'deepseek', userId: 1, prompt: 'x' };
      await withClock(async (elapse) => {
        elapse(breaker.OPEN_MS + 1000);
        let respond;
        const gate = new Promise((resolve) => { respond = resolve; });
        h.queueJson(async () => {
          await gate;
          return reply({ reply: '探測成功' });
        }, { reply: '備援回覆' });
        const probe = runner.call('support', request);
        const other = await runner.call('support', request);
        assert.strictEqual(other.provider, 'gemini');
        respond();
        assert.strictEqual((await probe).provider, 'deepseek');
        h.queueJson({ reply: '已恢復' });
        assert.strictEqual((await runner.call('support', request)).provider, 'deepseek');
      });
      assert.deepStrictEqual(h.calls.slice(breaker.FAILURE_LIMIT).map((c) => c.provider), ['deepseek', 'gemini', 'deepseek']);
    }],

    ['斷路器：管理員連線測試的失敗與成功都不影響正式流量', async () => {
      enable();
      const settings = await settingsService.load();
      const request = { settings, provider: 'deepseek', userId: 1, prompt: 'x' };
      for (let i = 0; i < breaker.FAILURE_LIMIT; i += 1) {
        h.queueJson(h.providerError('SERVER'));
        await assert.rejects(() => runner.call('test', request));
      }
      assert.strictEqual(breaker.isOpen('deepseek'), false);
      h.queueJson({ reply: '正常' });
      await runner.call('support', request);

      for (let i = 0; i < breaker.FAILURE_LIMIT - 1; i += 1) {
        h.queueJson(h.providerError('SERVER'));
        await assert.rejects(() => runner.call('support', request));
      }
      h.queueJson({ reply: '連線測試成功' });
      await runner.call('test', request);
      h.queueJson(h.providerError('SERVER'));
      await assert.rejects(() => runner.call('support', request));
      assert.strictEqual(breaker.isOpen('deepseek'), true, '連線測試成功不會清除正式流量的連續失敗');
    }],

    ['斷路器：依剩餘時間縮短的逾時不計入連續失敗', async () => {
      enable();
      const settings = await settingsService.load();
      for (let i = 0; i < breaker.FAILURE_LIMIT + 1; i += 1) {
        h.queueJson(h.providerError('TIMEOUT'));
        await assert.rejects(() => runner.call('support', { settings, provider: 'deepseek', userId: 1, deadline: deadlines.start(6000), prompt: 'x' }));
      }
      assert.strictEqual(breaker.isOpen('deepseek'), false);
    }],

    ['備援服務商：列入 AI 狀態的 providers_in_use，同意畫面據此揭露接收者', async () => {
      const user = h.addUser();
      enable({ features: { listing_assist: { enabled: false } } });
      assert.deepStrictEqual((await runner.status(user.user_id)).providers_in_use, ['DeepSeek']);
      enable({ features: { listing_assist: { enabled: false }, support: { fallback_provider: 'gemini' } } });
      assert.deepStrictEqual((await runner.status(user.user_id)).providers_in_use, ['DeepSeek', 'Google Gemini']);
    }],

    ['設定：備援服務商預設為不使用，只接受已知的服務商，並列入變更紀錄', () => {
      assert.strictEqual(settingsService.normalize({}).features.book_chat.fallback_provider, null);
      const next = settingsService.normalize({ features: { support: { fallback_provider: 'gemini' } } });
      assert.strictEqual(next.features.support.fallback_provider, 'gemini');
      assert.throws(
        () => settingsService.normalize({ features: { support: { fallback_provider: 'claude' } } }, { strict: true }),
        /AI 客服的備援服務商/
      );
      const [change] = settingsService.diffSettings(settingsService.normalize({}), next);
      assert.strictEqual(change.label, 'AI 客服備援服務商');
    }],

    ['客服：服務中斷時改附檢索第一名的說明，標示為相關說明並建議轉接，不計入次數', async () => {
      enable();
      h.queueJson(h.providerError('TIMEOUT'));
      const [top] = await knowledge.search('要怎麼取書');
      const data = await support.sendMessage(1, '要怎麼取書');
      assert.strictEqual(data.degraded, true);
      assert.strictEqual(data.suggest_handoff, true);
      assert.strictEqual(data.reply.content, `${support.FALLBACK_LEAD}\n\n${top.title}\n${top.text}`);
      assert.deepStrictEqual(prisma.rows('ai_support_messages').map((m) => m.role), ['user', 'assistant']);
      assert.strictEqual(await usageService.dailyCount(1, 'support'), 0);
    }],

    ['客服：以整體時限的剩餘時間呼叫模型；時間不足時不呼叫，直接改附相關說明', async () => {
      enable();
      h.queueJson({ reply: '好的', suggest_handoff: false });
      const normal = await withDeadline(6000, () => support.sendMessage(1, '要怎麼取書'));
      assert.strictEqual(normal.degraded, false);
      assert.ok(h.calls[0].options.timeoutMs <= 4500, String(h.calls[0].options.timeoutMs));

      const late = await withDeadline(4000, () => support.sendMessage(1, '要怎麼取書'));
      assert.strictEqual(h.calls.length, 1);
      assert.strictEqual(late.degraded, true);
      assert.ok(late.reply.content.startsWith(support.FALLBACK_LEAD));
    }],

    ['防止重複：同一個 client_id 重送時回傳第一次的結果，不再呼叫模型或寫入對話', async () => {
      enable();
      h.queueJson({ reply: '第一次的回覆', suggest_handoff: true });
      const first = await support.sendMessage(1, '問題', { clientId: 'client-0001' });
      const again = await support.sendMessage(1, '問題', { clientId: 'client-0001' });
      assert.strictEqual(h.calls.length, 1);
      assert.deepStrictEqual(again, first);
      assert.strictEqual(first.user_message.client_id, 'client-0001');
      assert.strictEqual(prisma.rows('ai_support_messages').length, 2);
      assert.strictEqual(prisma.rows('ai_usage_logs').length, 1);

      const session = await support.currentSession(1);
      assert.deepStrictEqual(session.messages.map((m) => m.client_id), ['client-0001', undefined]);
      assert.ok(!JSON.stringify(prisma.rows('ai_message_requests')).includes('問題'), '登記不存訊息內容');
    }],

    ['防止重複：同時送達的相同訊息只處理一次', async () => {
      enable();
      let open;
      const gate = new Promise((resolve) => { open = resolve; });
      h.queueJson(async () => {
        await gate;
        return reply({ reply: '只處理一次', suggest_handoff: false });
      });
      const a = support.sendMessage(1, '問題', { clientId: 'client-0002' });
      const b = support.sendMessage(1, '問題', { clientId: 'client-0002' });
      open();
      const [ra, rb] = await Promise.all([a, b]);
      assert.strictEqual(h.calls.length, 1);
      assert.deepStrictEqual(ra, rb);
      assert.strictEqual(prisma.rows('ai_support_messages').length, 2);
    }],

    ['防止重複：其他行程處理中時回 409；處理中斷超過時限後重新處理', async () => {
      enable();
      const row = { request_id: 50, user_id: 1, feature: 'support', client_id: 'client-0003', status: 'processing', created_at: new Date(), updated_at: new Date() };
      prisma.rows('ai_message_requests').push(row);
      await assert.rejects(
        () => support.sendMessage(1, '問題', { clientId: 'client-0003' }),
        (err) => err.status === 409 && err.code === 'AI_REQUEST_IN_PROGRESS'
      );
      assert.strictEqual(h.calls.length, 0);

      row.updated_at = new Date(Date.now() - requests.STALE_MS - 1000);
      h.queueJson({ reply: '重新處理', suggest_handoff: false });
      const data = await support.sendMessage(1, '問題', { clientId: 'client-0003' });
      assert.strictEqual(data.reply.content, '重新處理');
      assert.strictEqual(prisma.rows('ai_message_requests')[0].status, 'done');
    }],

    ['防止重複：處理失敗時取消登記，重送會重新處理', async () => {
      enable();
      h.queueJson(h.providerError('BLOCKED'));
      await assert.rejects(() => support.sendMessage(1, '問題', { clientId: 'client-0004' }), (err) => err.code === 'AI_CONTENT_BLOCKED');
      assert.strictEqual(prisma.rows('ai_message_requests').length, 0);
      h.queueJson({ reply: '第二次成功', suggest_handoff: false });
      assert.strictEqual((await support.sendMessage(1, '問題', { clientId: 'client-0004' })).reply.content, '第二次成功');
    }],

    ['防止重複 API：client_id 格式錯誤回 400；重送回傳相同結果，讀取對話帶回 client_id', async () => {
      const user = h.addUser();
      h.setSettings({ enabled: true });
      h.setConsent(user.user_id, true);
      const token = h.tokenFor(user);
      const bad = await h.request('POST', '/api/ai/support/messages', { token, body: { content: '問題', client_id: '含空白 的識別碼' } });
      assert.strictEqual(bad.status, 400);

      h.queueJson({ reply: '回覆', suggest_handoff: false });
      const body = { content: '問題', client_id: 'Ab_12-cd34ef' };
      const first = await h.request('POST', '/api/ai/support/messages', { token, body });
      const second = await h.request('POST', '/api/ai/support/messages', { token, body });
      assert.strictEqual(first.status, 201);
      assert.deepStrictEqual(second.body, first.body);
      const session = await h.request('GET', '/api/ai/support/session', { token });
      assert.strictEqual(session.body.data.messages[0].client_id, 'Ab_12-cd34ef');
    }],

    ['防止重複：撤回同意時刪除登記；登記保留 24 小時', async () => {
      const old = new Date(Date.now() - requests.RETENTION_MS - 1000);
      prisma.store.ai_message_requests = [
        { request_id: 1, user_id: 1, feature: 'support', client_id: 'client-a', status: 'done', created_at: new Date(), updated_at: new Date() },
        { request_id: 2, user_id: 2, feature: 'support', client_id: 'client-b', status: 'done', created_at: new Date(), updated_at: new Date() },
        { request_id: 3, user_id: 2, feature: 'book_chat', client_id: 'client-c', status: 'done', created_at: old, updated_at: old }
      ];
      await consent.setGranted(1, false);
      assert.deepStrictEqual(prisma.rows('ai_message_requests').map((r) => r.request_id), [2, 3]);
      assert.strictEqual(await requests.purgeExpired(), 1);
      assert.deepStrictEqual(prisma.rows('ai_message_requests').map((r) => r.request_id), [2]);
    }],

    ['書籍顧問：第一段服務中斷時改用使用者原話檢索，略過第二段，以相關度前 6 本回覆', async () => {
      enable();
      shelf();
      h.queueJson(h.providerError('SERVER'));
      const data = await bookChat.sendMessage(1, '推理小說');
      assert.strictEqual(h.calls.length, 1);
      assert.strictEqual(data.reply.degraded, true);
      assert.strictEqual(data.reply.content, bookChat.RELATED_REPLY);
      assert.strictEqual(data.reply.books.length, bookChat.PICK_LIMIT);
      assert.strictEqual(await usageService.dailyCount(1, 'book_chat'), 0);
    }],

    ['書籍顧問：第一段格式錯誤時仍以原話檢索的結果請模型挑書', async () => {
      enable();
      shelf();
      h.queueJson(
        h.providerError('INVALID_OUTPUT'),
        h.providerError('INVALID_OUTPUT'),
        { reply: '推薦這兩本。', book_ids: ['b2', 'b1'], reasons: { b2: '節奏明快' }, suggestions: [] }
      );
      const data = await bookChat.sendMessage(1, '推理小說');
      assert.deepStrictEqual(h.calls.map((c) => c.options.system === bookChat.PICK_SYSTEM), [false, false, true]);
      assert.match(h.calls[1].options.prompt, /【格式修正】上一次的輸出不符合規定的格式，不是有效的 JSON 物件。/);
      assert.deepStrictEqual(data.reply.books.map((b) => b.reason), ['節奏明快', null]);
      assert.strictEqual(data.reply.degraded, true);
    }],

    ['書籍顧問：第一段保留後段所需時間；剩餘時間不足時不送出，直接以檢索結果回覆', async () => {
      enable();
      shelf();
      h.queueJson(plan, { reply: '推薦如下。', book_ids: ['b1'], reasons: {}, suggestions: [] });
      await bookChat.sendMessage(1, '推理小說');
      const planTimeout = h.calls[0].options.timeoutMs;
      assert.ok(planTimeout <= deadlines.INTERACTIVE_MS - bookChat.PLAN_RESERVE_MS, String(planTimeout));

      const skipped = await withDeadline(bookChat.PLAN_RESERVE_MS + 2000, () => bookChat.sendMessage(1, '推理小說'));
      assert.strictEqual(h.calls.length, 2, '兩段都沒有送出');
      assert.strictEqual(skipped.reply.degraded, true);
      assert.strictEqual(skipped.reply.books.length, bookChat.PICK_LIMIT);

      // 檢索耗時過久，第二段剩餘的時間不足。
      const realNow = Date.now;
      const availability = catalogSearch.availability;
      let offset = 0;
      Date.now = () => realNow() + offset;
      catalogSearch.availability = async (...args) => {
        offset += 9000;
        return availability(...args);
      };
      try {
        h.queueJson(plan);
        const late = await withDeadline(bookChat.PLAN_RESERVE_MS + 3500, () => bookChat.sendMessage(1, '推理小說'));
        assert.strictEqual(h.calls.length, 3, '第二段沒有送出');
        assert.strictEqual(late.reply.degraded, true);
        assert.strictEqual(late.reply.content, plan.reply);
        assert.strictEqual(lastLog().error_detail, '剩餘時間不足，未送出請求');
      } finally {
        Date.now = realNow;
        catalogSearch.availability = availability;
      }
    }],

    ['書籍顧問：重送時回傳第一次的書卡、推薦理由與追問建議', async () => {
      enable();
      shelf();
      h.queueJson(plan, { reply: '推薦如下。', book_ids: ['b2'], reasons: { b2: '節奏明快' }, suggestions: ['有沒有更便宜的'] });
      const first = await bookChat.sendMessage(1, '推理小說', { clientId: 'chat-00001' });
      const again = await bookChat.sendMessage(1, '推理小說', { clientId: 'chat-00001' });
      assert.strictEqual(h.calls.length, 2);
      assert.strictEqual(again.reply.books[0].reason, '節奏明快');
      assert.deepStrictEqual(again.reply.suggestions, ['有沒有更便宜的']);
      assert.deepStrictEqual(again.reply.books.map((b) => b.book.book_id), first.reply.books.map((b) => b.book.book_id));
      assert.deepStrictEqual(again.user_message, first.user_message);
      const session = await bookChat.currentSession(1);
      assert.strictEqual(session.messages[0].client_id, 'chat-00001');
    }],

    ['書籍顧問：內容遭阻擋時照舊回 422，不寫入對話', async () => {
      enable();
      shelf();
      h.queueJson(h.providerError('BLOCKED'));
      await assert.rejects(() => bookChat.sendMessage(1, '推理小說'), (err) => err.code === 'AI_CONTENT_BLOCKED');
      assert.strictEqual(prisma.rows('ai_chat_messages').length, 0);
    }]
  ]
};
