const assert = require('assert');
const h = require('./harness');

const schema = h.api('lib/ai/schema');
const deadlines = h.api('services/ai/deadline');
const support = h.api('services/ai/support');
const knowledge = h.api('services/ai/knowledge');
const bookChat = h.api('services/ai/book-chat');
const { prisma, runner, settingsService, realGenerate } = h;

h.aiHttp.options.backoffMs = 5;

const fetched = [];
const replies = [];

// 其他測試組已先登記同一批服務商網址的攔截，這裡在測試期間直接換掉 fetch。
const withFetch = async (run) => {
  const saved = global.fetch;
  global.fetch = async (url, init) => {
    fetched.push(JSON.parse(init.body));
    const next = replies.shift();
    if (!next) throw new Error(`測試未預期的服務商請求：${url}`);
    return h.jsonResponse(next);
  };
  try {
    return await run();
  } finally {
    global.fetch = saved;
  }
};

const reply = (json) => ({ text: JSON.stringify(json), json, usage: {}, latency_ms: 1, sources: [] });

// 記下各功能交給 runner 的規格與 repair 設定；預設服務商不支援嚴格模式，送給服務商的參數看不出規格。
const withCallSpy = async (run) => {
  const seen = [];
  const { call } = runner;
  runner.call = (feature, args) => {
    seen.push({ feature, schema: args.schema, repair: args.repair });
    return call(feature, args);
  };
  try {
    await run();
  } finally {
    runner.call = call;
  }
  return seen;
};

const SAMPLE = schema.define('sample_output', schema.object({
  reply: schema.string({ max: 10 }),
  kind: schema.enumOf(['a', 'b'], { default: 'a' }),
  tags: schema.array(schema.string(), { max: 2, default: [] }),
  note: schema.string({ nullable: true, default: null }),
  items: schema.array(schema.object({ id: schema.string(), score: schema.number({ default: 0 }) }), { default: [] }),
  meta: schema.object({ n: schema.integer() }, { nullable: true, default: null })
}));

const enable = (config = {}) => {
  h.setSettings({ enabled: true, ...config });
  h.setConsent(1, true);
};

const FAQS = [
  { faq_id: 1, category: '帳號', question: '忘記密碼怎麼辦？', answer: '在登入頁點選「忘記密碼」並依信件指示重設。', sort_order: 0, is_visible: true }
];

const supportSetup = () => {
  knowledge.invalidate();
  prisma.store.faqs = FAQS.map((f) => ({ ...f }));
  prisma.store.legal_documents = [];
  enable();
  h.onModel('orders.findMany', () => []);
  h.onModel('reservations.findMany', () => []);
  h.onModel('books.findMany', () => []);
  h.onModel('wallets.findUnique', () => ({ balance: 100 }));
  h.onModel('support_tickets.findMany', () => []);
};

const supportStats = () => JSON.parse(prisma.rows('ai_decision_logs').filter((r) => r.feature === 'support').at(-1).stats);
const supportMeta = () => JSON.parse(prisma.rows('ai_support_messages').filter((r) => r.role === 'assistant').at(-1).meta);

module.exports = {
  name: 'AI 結構化輸出與伺服器端查證',
  before: () => {
    fetched.length = 0;
    replies.length = 0;
  },
  tests: [
    ['規格驗證：缺少必要欄位時列出路徑；有預設值的欄位缺少或型別不符時改用預設值', () => {
      const missing = schema.check(SAMPLE, { kind: 'a' });
      assert.deepStrictEqual(missing.problems, ['缺少 reply']);
      assert.deepStrictEqual(schema.check(SAMPLE, 'x').problems, ['輸出 應為物件']);
      assert.deepStrictEqual(schema.check(SAMPLE, { reply: ['x'] }).problems, ['reply 應為字串']);

      const { value, problems, stats } = schema.check(SAMPLE, { reply: 12, kind: 'z', tags: 'x', extra: 1, meta: { n: '3' } });
      assert.deepStrictEqual(problems, []);
      assert.deepStrictEqual(value, { reply: '12', kind: 'a', tags: [], note: null, items: [], meta: { n: 3 } });
      assert.strictEqual(stats.defaulted, 2);
    }],

    ['規格驗證：超過長度與筆數上限時截短；陣列中不合格的項目只捨棄該項', () => {
      const { value, stats } = schema.check(SAMPLE, {
        reply: '一二三四五六七八九十十一',
        tags: ['a', 'b', 'c'],
        items: [{ id: 'x', score: '0.5' }, { score: 1 }, 'y', { id: 'z' }],
        meta: null
      });
      assert.strictEqual(value.reply, '一二三四五六七八九…');
      assert.deepStrictEqual(value.tags, ['a', 'b']);
      assert.deepStrictEqual(value.items, [{ id: 'x', score: 0.5 }, { id: 'z', score: 0 }]);
      assert.strictEqual(value.meta, null);
      assert.deepStrictEqual([stats.dropped, stats.truncated], [2, 1]);
      assert.deepStrictEqual(stats.dropped_in, { items: 2 }, '捨棄的項目依陣列路徑分計');
    }],

    ['規格轉換：OpenAI 嚴格模式要求所有欄位必填、不得有額外欄位，可為 null 的欄位以型別聯集表示', () => {
      const strict = SAMPLE.strict;
      assert.strictEqual(strict.name, 'sample_output');
      assert.deepStrictEqual(strict.schema.required, ['reply', 'kind', 'tags', 'note', 'items', 'meta']);
      assert.strictEqual(strict.schema.additionalProperties, false);
      assert.deepStrictEqual(strict.schema.properties.kind, { type: 'string', enum: ['a', 'b'] });
      assert.deepStrictEqual(strict.schema.properties.note, { type: ['string', 'null'] });
      assert.deepStrictEqual(strict.schema.properties.items.items.required, ['id', 'score']);
      assert.strictEqual(strict.schema.properties.meta.anyOf[1].type, 'null');
      assert.ok(!JSON.stringify(strict.schema).includes('max'), '長度上限交給伺服器驗證，不送給服務商');
      assert.throws(() => schema.define('含空白 的名稱', schema.object({})));
    }],

    ['截斷救回：只保留完整的陣列項目，未寫完的欄位與項目捨棄', () => {
      const partial = '{"items":[{"id":"b1","reason":"含\\"引號\\"與 ] 符號"},{"id":"b2","reason":"x"},{"id":"b3","rea';
      assert.deepStrictEqual(h.ai.salvageJson(partial), {
        items: [{ id: 'b1', reason: '含"引號"與 ] 符號' }, { id: 'b2', reason: 'x' }]
      });
      assert.strictEqual(h.ai.salvageJson('{"reply":"寫到一半'), null);
      assert.strictEqual(h.ai.salvageJson('完全不是 JSON'), null);
      // 項目內的陣列寫完不代表項目寫完：截斷在第二項的標籤中時，整個第二項都要捨棄。
      assert.deepStrictEqual(h.ai.salvageJson('{"items":[{"id":"b1","tags":["a","b"],"reason":"x"},{"id":"b2","tags":["c","d'), {
        items: [{ id: 'b1', tags: ['a', 'b'], reason: 'x' }]
      });
      assert.deepStrictEqual(h.ai.salvageJson('{"data":{"ids":["a","b","c'), { data: { ids: ['a', 'b'] } });
    }],

    ['截斷救回：呼叫端要求 salvage 時，輸出被截斷仍採用完整的項目並標示為修復；未要求時照舊回 INCOMPLETE', async () => {
      const truncated = {
        choices: [{ message: { content: '{"items":[{"id":"b1","basis":"","reason":""},{"id":"b2","ba' }, finish_reason: 'length' }],
        usage: { prompt_tokens: 10, completion_tokens: 20 }
      };
      replies.push(truncated);
      const result = await withFetch(() => realGenerate('deepseek', { model: 'deepseek-flash', prompt: '推薦 json', json: true, salvage: true }));
      assert.deepStrictEqual(result.json, { items: [{ id: 'b1', basis: '', reason: '' }] });
      assert.strictEqual(result.salvaged, true);
      assert.strictEqual(result.repaired, true);

      replies.push(truncated);
      await assert.rejects(
        () => withFetch(() => realGenerate('deepseek', { model: 'deepseek-flash', prompt: '推薦 json', json: true })),
        (err) => err.reason === 'INCOMPLETE'
      );
    }],

    ['照片格式：依服務商能接受的格式分組，不支援的格式不送出', async () => {
      const images = [{ mimeType: 'image/jpeg', data: 'a' }, { mimeType: 'image/gif', data: 'b' }, { mimeType: 'image/heic', data: 'c' }];
      assert.deepStrictEqual(h.ai.imagesFor('openai', images).sent.map((i) => i.data), ['a', 'b']);
      assert.deepStrictEqual(h.ai.imagesFor('gemini', images).sent.map((i) => i.data), ['a', 'c']);
      assert.deepStrictEqual(h.ai.imagesFor('deepseek', images).skipped.length, 3);

      replies.push({ candidates: [{ content: { parts: [{ text: '{"ok":true}' }] }, finishReason: 'STOP' }], usageMetadata: {} });
      await withFetch(() => realGenerate('gemini', { model: 'gemini-3.1-flash-lite', prompt: '看圖', images }));
      const parts = fetched[0].contents.at(-1).parts;
      assert.deepStrictEqual(parts.filter((p) => p.inlineData).map((p) => p.inlineData.mimeType), ['image/jpeg', 'image/heic']);
    }],

    ['備援：主要服務商送出的照片格式備援不支援時不改用備援', () => {
      const settings = { features: { admin_assist: { fallback_provider: 'openai' } } };
      const { env } = h.api('config/env');
      const key = env.openaiApiKey;
      env.openaiApiKey = 'sk-test';
      try {
        assert.strictEqual(runner.fallbackFor(settings, 'admin_assist', 'gemini', { needsVision: true, imageTypes: ['image/jpeg'] }), 'openai');
        assert.strictEqual(runner.fallbackFor(settings, 'admin_assist', 'gemini', { needsVision: true, imageTypes: ['image/heic'] }), null);
      } finally {
        env.openaiApiKey = key;
      }
    }],

    ['備援：改用備援時送出與主要服務商相同的照片，備援能接受更多格式也不多送', async () => {
      enable({ features: { moderation: { provider: 'gemini', fallback_provider: 'openai' } } });
      const settings = await settingsService.load();
      const { env } = h.api('config/env');
      const key = env.openaiApiKey;
      env.openaiApiKey = 'sk-test';
      try {
        const images = [{ mimeType: 'image/jpeg', data: 'a' }, { mimeType: 'image/gif', data: 'b' }];
        h.queueJson(h.providerError('SERVER'), { ok: true });
        const result = await runner.call('moderation', { settings, provider: 'gemini', prompt: '照片共 1 張', images });
        assert.strictEqual(result.provider, 'openai');
        assert.deepStrictEqual(h.calls.map((c) => [c.provider, c.options.images.map((i) => i.data)]), [['gemini', ['a']], ['openai', ['a']]]);
      } finally {
        env.openaiApiKey = key;
      }
    }],

    ['runner：用量紀錄記下捨棄的清單項目與改用預設值的欄位數，validate 可讀到依路徑分計的捨棄數；沒有送出的呼叫記為 not_sent', async () => {
      enable();
      const settings = await settingsService.load();
      let seen = null;
      h.queueJson({ reply: '好', kind: 'z', items: [{ id: 'x' }, { score: 1 }, 'y'] });
      await runner.call('support', {
        settings, provider: 'deepseek', prompt: 'x', schema: SAMPLE, validate: (r) => { seen = r.format; return null; }
      });
      assert.deepStrictEqual(seen, { dropped: 2, defaulted: 1, truncated: 0, dropped_in: { items: 2 } });
      const log = prisma.rows('ai_usage_logs').at(-1);
      assert.deepStrictEqual([log.format_dropped, log.format_defaulted], [2, 1]);

      const deadline = deadlines.start(0);
      await assert.rejects(() => runner.call('support', { settings, provider: 'deepseek', prompt: 'x', deadline }), (err) => err.notSent === true);
      assert.deepStrictEqual([prisma.rows('ai_usage_logs').at(-1).error_code, prisma.rows('ai_usage_logs').at(-1).outcome], ['TIMEOUT', 'not_sent']);
    }],

    ['runner：支援嚴格模式的服務商附上規格，其他服務商與搜尋時只要求 JSON；輸出一律經規格驗證', async () => {
      enable();
      const settings = await settingsService.load();
      h.queueJson({ reply: '好', extra: 'x' }, { reply: '好' }, { reply: '好' });
      const first = await runner.call('support', { settings, provider: 'openai', prompt: 'x', schema: SAMPLE });
      assert.deepStrictEqual(h.calls[0].options.schema, SAMPLE.strict);
      assert.strictEqual(h.calls[0].options.json, true);
      assert.deepStrictEqual(first.json, { reply: '好', kind: 'a', tags: [], note: null, items: [], meta: null });

      await runner.call('support', { settings, provider: 'deepseek', prompt: 'x', schema: SAMPLE });
      assert.strictEqual(h.calls[1].options.schema, undefined);
      assert.strictEqual(h.calls[1].options.json, true);

      await runner.call('support', { settings, provider: 'openai', prompt: 'x', schema: SAMPLE, search: true });
      assert.strictEqual(h.calls[2].options.schema, undefined, '搜尋時不能同時要求 JSON 格式');
    }],

    ['runner：規格不符記為格式錯誤，細節只列欄位路徑；repair 時附上說明向同一服務商重試一次，成功記為修復', async () => {
      enable();
      const settings = await settingsService.load();
      h.queueJson({ kind: 'b', secret: '模型輸出的內容' }, { reply: '修正後' });
      const result = await runner.call('support', { settings, provider: 'deepseek', userId: 1, prompt: '原提問', schema: SAMPLE, repair: true });
      assert.strictEqual(result.json.reply, '修正後');
      assert.strictEqual(result.outcome, 'repaired');
      assert.deepStrictEqual(h.calls.map((c) => c.provider), ['deepseek', 'deepseek']);
      assert.strictEqual(h.calls[1].options.prompt, `原提問\n\n${runner.REPAIR_NOTE}：缺少 reply。請依規定的欄位與型別，重新輸出一個完整的 JSON 物件，不要加入其他文字。`);
      const logs = prisma.rows('ai_usage_logs');
      assert.deepStrictEqual(logs.map((r) => [r.status, r.error_code, r.outcome]), [['error', 'INVALID_OUTPUT', 'failed'], ['ok', null, 'repaired']]);
      assert.strictEqual(logs[0].error_detail, '格式不符：缺少 reply');
      assert.ok(!logs.some((r) => String(r.error_detail ?? '').includes('模型輸出的內容')));
    }],

    ['runner：未要求 repair、剩餘時間不足或不是格式錯誤時不重試', async () => {
      enable();
      const settings = await settingsService.load();
      h.queueJson({ kind: 'a' });
      await assert.rejects(() => runner.call('support', { settings, provider: 'deepseek', prompt: 'x', schema: SAMPLE }), (err) => err.reason === 'INVALID_OUTPUT');
      assert.strictEqual(h.calls.length, 1);

      h.queueJson(async () => {
        await new Promise((resolve) => setTimeout(resolve, 200));
        return reply({ kind: 'a' });
      });
      const deadline = deadlines.start(3100);
      await assert.rejects(
        () => runner.call('support', { settings, provider: 'deepseek', prompt: 'x', schema: SAMPLE, repair: true, deadline, reserve: 0 }),
        (err) => err.reason === 'INVALID_OUTPUT'
      );
      assert.strictEqual(h.calls.length, 2, '剩餘時間不足一次呼叫時不重試');

      h.queueJson(h.providerError('TIMEOUT'));
      await assert.rejects(() => runner.call('support', { settings, provider: 'deepseek', prompt: 'x', schema: SAMPLE, repair: true }), (err) => err.reason === 'TIMEOUT');
      assert.strictEqual(h.calls.length, 3);
    }],

    ['客服：移除回覆中的參考編號與「參考資料」字樣', () => {
      assert.strictEqual(support.stripReferences('根據參考資料，訂單成立後 3 天內須存書[1]。'), '訂單成立後 3 天內須存書。');
      assert.strictEqual(support.stripReferences('依【參考資料】[2][3]，取消後全額退款【1】。'), '取消後全額退款。');
      assert.strictEqual(support.stripReferences('參考資料中沒有提到運費（參見參考資料）。'), '平台說明中沒有提到運費。');
      assert.strictEqual(support.stripReferences('第 1 步：開啟 App [1, 2]。'), '第 1 步：開啟 App。');
    }],

    ['客服：以規格呼叫並保存回答類型、實際引用的來源與追問建議；追問建議隨助理訊息回傳', async () => {
      supportSetup();
      h.queueJson({
        reply: '忘記密碼時，請在登入頁點選「忘記密碼」[1]。',
        answer_type: 'answer',
        sources: [1, 7],
        account_data: false,
        suggest_handoff: false,
        handoff_category: null,
        follow_ups: ['收不到重設信怎麼辦？', '收不到重設信怎麼辦？', '請加 LINE ID：abc123 詢問', '這是一個超過三十個字的追問建議內容，應該要被捨棄而不是被截短才對']
      });
      let data;
      const seen = await withCallSpy(async () => {
        data = await support.sendMessage(1, '忘記密碼怎麼辦');
      });
      assert.deepStrictEqual(seen, [{ feature: 'support', schema: support.OUTPUT, repair: true }]);
      assert.strictEqual(h.calls[0].options.json, true);
      assert.strictEqual(h.calls[0].options.repair, undefined, 'repair 由 runner 處理，不傳給服務商');
      assert.strictEqual(data.reply.content, '忘記密碼時，請在登入頁點選「忘記密碼」。');
      assert.deepStrictEqual(data.reply.suggestions, ['收不到重設信怎麼辦？']);
      assert.strictEqual(data.suggest_handoff, false);

      const meta = supportMeta();
      assert.strictEqual(meta.reply_type, 'answer');
      assert.strictEqual(meta.insufficient, false);
      assert.deepStrictEqual(meta.cited, ['faq:1']);
      const stats = supportStats();
      assert.deepStrictEqual([stats.counts.cited, stats.counts.invalid_sources], [1, 1]);

      const session = await support.currentSession(1);
      assert.deepStrictEqual(session.messages.at(-1).suggestions, ['收不到重設信怎麼辦？']);
    }],

    ['客服：沒有引用任何資料的回答標記為依據不足；澄清問題與依平台概要回答不算', async () => {
      supportSetup();
      h.queueJson(
        { reply: '手續費為 10 元。', answer_type: 'answer', sources: [], account_data: false },
        { reply: '請問您指的是哪一筆訂單？', answer_type: 'clarify', sources: [] },
        { reply: '您的錢包餘額為 100 代幣。', answer_type: 'answer', sources: [], account_data: true },
        { reply: 'App 目前沒有自助提領功能。', answer_type: 'answer', sources: [], platform_data: true }
      );
      await support.sendMessage(1, '手續費多少');
      assert.strictEqual(supportMeta().insufficient, true);
      assert.strictEqual(supportStats().flags.insufficient, true);
      await support.sendMessage(1, '那筆訂單呢');
      assert.strictEqual(supportMeta().insufficient, false);
      await support.sendMessage(1, '我還有多少代幣');
      assert.strictEqual(supportMeta().insufficient, false);
      await support.sendMessage(1, '可以把代幣換成現金嗎');
      assert.strictEqual(supportMeta().insufficient, false);
      assert.match(support.SYSTEM_RULES, /platform_data：reply 是否依據【平台概要】/);
      assert.strictEqual(support.OUTPUT.strict.schema.properties.platform_data.type, 'boolean');
    }],

    ['客服：模型表示無法確認、訊息提到客服人員或問到儲值提領、回覆已提到轉接時，由伺服器強制轉接', async () => {
      supportSetup();
      const cases = [
        [{ reply: '目前資料無法確認這項規定。', answer_type: 'unknown', sources: [] }, '有沒有會員折扣', ['unknown'], 'other'],
        [{ reply: '好的，請稍候。', answer_type: 'answer', sources: [1] }, '我要找客服人員', ['agent'], 'other'],
        [{ reply: '目前 App 沒有自助儲值功能。', answer_type: 'answer', sources: [1] }, '要怎麼儲值代幣？', ['wallet'], 'wallet'],
        [{ reply: '此情況建議轉接客服人員協助。', answer_type: 'answer', sources: [1], handoff_category: 'cabinet' }, '書櫃打不開', ['reply'], 'cabinet'],
        [{ reply: '可在設定頁變更密碼。', answer_type: 'answer', sources: [1], suggest_handoff: true, handoff_category: 'account' }, '怎麼改密碼', ['model'], 'account']
      ];
      for (const [json, question, reasons, category] of cases) {
        h.queueJson(json);
        const data = await support.sendMessage(1, question);
        assert.strictEqual(data.suggest_handoff, true, question);
        const meta = supportMeta();
        assert.deepStrictEqual(meta.handoff_reasons, reasons, question);
        assert.strictEqual(meta.handoff_category, category, question);
        assert.strictEqual(supportStats().flags.handoff_forced, !reasons.includes('model'), question);
      }

      h.queueJson({ reply: '可在設定頁變更密碼。', answer_type: 'answer', sources: [1] });
      const plain = await support.sendMessage(1, '怎麼改密碼');
      assert.strictEqual(plain.suggest_handoff, false);
      assert.strictEqual(supportMeta().handoff_category, null);
    }],

    ['客服：從書櫃領出書、說明客服人員回覆流程等一般回答不強制轉接', () => {
      const reasons = (question, reply) => support.handoffReasons({ question, reply });
      assert.deepStrictEqual(reasons('買到的書要怎麼從書櫃領出來？', '請在取書期限內到書櫃掃描 QR Code 取書。'), []);
      assert.deepStrictEqual(reasons('我的提問處理到哪了', '您的提問目前為待處理，客服人員回覆後會通知您。'), []);
      assert.deepStrictEqual(reasons('可以直接取消訂單嗎', '您不需要聯絡客服，可在訂單頁自行取消。'), []);
      assert.deepStrictEqual(reasons('代幣可以領出來嗎', '目前沒有提領功能。'), ['wallet']);
      assert.deepStrictEqual(reasons('書櫃打不開', '建議您聯絡客服人員協助處理。'), ['reply']);
      assert.deepStrictEqual(reasons('書櫃打不開', '您可以透過 App 的「聯絡客服」功能提出問題。'), ['reply']);
    }],

    ['書籍顧問：以規格呼叫兩段；理由陣列與舊版的代號物件都能對應到書卡', async () => {
      enable();
      const rows = [1, 2].map((id) => ({
        book_id: id, seller_id: 9, title: `推理小說 ${id}`, author: '東野圭吾', price: 100 + id, status: 'on_sale', is_approved: true,
        condition_level: 'good', category_id: 1, cabinet_id: null, view_count: 10, book_categories: { category_name: '文學小說' }, book_images: [],
        users: { user_id: 9, nickname: '賣家', avatar_url: null }
      }));
      h.onModel('books.findMany', () => rows);
      h.onModel('book_categories.findMany', () => [{ category_id: 1, category_name: '文學小說' }]);
      h.queueJson(
        { reply: '為您搜尋推理小說。', topic: 'new', search: { keyword: '推理' }, need_more_info: false },
        { reply: '《推理小說 2》節奏明快。', book_ids: ['b2', 'b1'], reasons: [{ id: 'b2', reason: '節奏明快' }, { id: 'b1', reason: '經典作品' }], suggestions: [] }
      );
      let data;
      const seen = await withCallSpy(async () => {
        data = await bookChat.sendMessage(1, '推理小說');
      });
      assert.deepStrictEqual(seen, [
        { feature: 'book_chat', schema: bookChat.PLAN_OUTPUT, repair: true },
        { feature: 'book_chat_pick', schema: bookChat.PICK_OUTPUT, repair: true }
      ]);
      assert.deepStrictEqual(data.reply.books.map((b) => [b.book.book_id, b.reason]), [[2, '節奏明快'], [1, '經典作品']]);
      assert.match(h.calls[1].options.prompt, /推理/, '舊寫法的單數 keyword 仍用於檢索');
      assert.deepStrictEqual(bookChat.PICK_OUTPUT.strict.schema.properties.reasons.items.required, ['id', 'reason']);
    }],

    ['書籍顧問：只問釐清問題時可省略搜尋條件；要搜尋卻缺少條件時附上說明重試一次', async () => {
      enable();
      h.onModel('books.findMany', () => []);
      h.onModel('book_categories.findMany', () => [{ category_id: 1, category_name: '文學小說' }]);
      h.queueJson({ reply: '請問您偏好哪一類主題？', need_more_info: true, suggestions: ['推薦推理小說'] });
      const clarify = await bookChat.sendMessage(1, '推薦書');
      assert.strictEqual(clarify.reply.content, '請問您偏好哪一類主題？');
      assert.strictEqual(h.calls.length, 1);

      h.queueJson({ reply: '為您搜尋。', need_more_info: false }, { reply: '請問您偏好哪一類主題？', need_more_info: true });
      await bookChat.sendMessage(1, '推薦書');
      assert.strictEqual(h.calls.length, 3);
      assert.match(h.calls[2].options.prompt, /【格式修正】上一次的輸出不符合規定的格式：缺少 search。/);

      // 嚴格模式允許 search 為 null；不需要釐清卻沒有條件時同樣要重試，不能改走釐清問題。
      h.queueJson({ reply: '為您搜尋 AI 入門書。', topic: 'new', search: null, need_more_info: false }, { reply: '請問您偏好哪一類主題？', need_more_info: true });
      await bookChat.sendMessage(1, '想找 AI 入門書');
      assert.strictEqual(h.calls.length, 5);
      assert.match(h.calls[4].options.prompt, /缺少 search/);
    }],

    ['書籍顧問：書單項目全部格式不符時附上說明重試；重試仍不符改附檢索結果，不當成沒有合適的書', async () => {
      enable();
      const rows = [1, 2].map((id) => ({
        book_id: id, seller_id: 9, title: `推理小說 ${id}`, author: '東野圭吾', price: 100 + id, status: 'on_sale', is_approved: true,
        condition_level: 'good', category_id: 1, cabinet_id: null, view_count: 10, book_categories: { category_name: '文學小說' }, book_images: [],
        users: { user_id: 9, nickname: '賣家', avatar_url: null }
      }));
      h.onModel('books.findMany', () => rows);
      h.onModel('book_categories.findMany', () => [{ category_id: 1, category_name: '文學小說' }]);
      const plan = { reply: '為您搜尋推理小說。', topic: 'new', search: { keywords: ['推理'] }, need_more_info: false };
      const malformed = { reply: '推薦《推理小說 1》。', book_ids: [{ id: 'b1' }, { id: 'b2' }], reasons: [], suggestions: [] };

      h.queueJson(plan, malformed, { reply: '推薦《推理小說 1》。', book_ids: ['b1'], reasons: [], suggestions: [] });
      const repaired = await bookChat.sendMessage(1, '推理小說');
      assert.deepStrictEqual(repaired.reply.books.map((b) => b.book.book_id), [1]);
      assert.match(h.calls[2].options.prompt, /book_ids 項目格式不符/);

      h.queueJson(plan, malformed, { ...malformed, book_ids: [null] });
      const fallback = await bookChat.sendMessage(1, '推理小說');
      assert.deepStrictEqual(fallback.reply.books.map((b) => b.book.book_id), [1, 2], '改附檢索結果');
      assert.strictEqual(fallback.reply.content, '為您搜尋推理小說。');
      const decision = prisma.rows('ai_decision_logs').filter((r) => r.feature === 'book_chat').at(-1);
      assert.strictEqual(decision.path, 'retrieval');

      h.queueJson(plan, { reply: '站上目前沒有相關的書。', book_ids: [], reasons: [], suggestions: [] });
      const declined = await bookChat.sendMessage(1, '推理小說');
      assert.deepStrictEqual(declined.reply.books, [], '模型明確回傳空書單時才視為沒有合適的書');
    }],

    ['書籍顧問：回覆查證書名、價格與「沒有相關」的說法', () => {
      const items = [{ book: { title: '哈利波特：神秘的魔法石' } }, { book: { title: 'Python 入門（第二版）' } }];
      assert.deepStrictEqual(bookChat.replyIssues('推薦《哈利波特》與《Python入門》。', items), { titles: 2, unmatched: 0, price: false, denies: false });
      assert.deepStrictEqual(bookChat.replyIssues('《魔戒》只要 150 元，但站上沒有相關的書。', items), { titles: 1, unmatched: 1, price: true, denies: true });
      assert.strictEqual(bookChat.replyIssues('站上目前沒有相關的書。', []).denies, false, '沒有書卡時說沒有相關是正確的');
      assert.strictEqual(bookChat.replyIssues('售價合理，適合入門。', items).price, false, '沒有金額的「售價」字樣不算');
      assert.strictEqual(bookChat.replyIssues('這本書無需相關背景即可閱讀。', items).denies, false);
      assert.strictEqual(bookChat.replyIssues('即使沒有相關基礎也能讀懂這本書。', items).denies, false);
      assert.strictEqual(bookChat.replyIssues('目前沒有符合您需求的書籍。', items).denies, true);
      assert.strictEqual(bookChat.replyIssues('以下是符合您 500 元以內預算的書。', items).price, false, '複述使用者的預算不算寫價格');
      assert.strictEqual(bookChat.replyIssues('預算 300 元的話，《哈利波特》很適合。', items).price, false);
      assert.strictEqual(bookChat.replyIssues('價格介於 300～500 元的書。', items).price, false);
      assert.strictEqual(bookChat.replyIssues('《哈利波特》售價 NT$250。', items).price, true);
    }],

    ['書籍顧問：第一階段只記錄回覆查證的違規，不替換回覆', async () => {
      enable();
      const rows = [1, 2].map((id) => ({
        book_id: id, seller_id: 9, title: `推理小說 ${id}`, author: '東野圭吾', price: 100 + id, status: 'on_sale', is_approved: true,
        condition_level: 'good', category_id: 1, cabinet_id: null, view_count: 10, book_categories: { category_name: '文學小說' }, book_images: [],
        users: { user_id: 9, nickname: '賣家', avatar_url: null }
      }));
      h.onModel('books.findMany', () => rows);
      h.onModel('book_categories.findMany', () => [{ category_id: 1, category_name: '文學小說' }]);
      h.queueJson(
        { reply: '為您搜尋推理小說。', topic: 'new', search: { keywords: ['推理'] }, need_more_info: false },
        { reply: '推薦《白夜行》，只要 99 元。', book_ids: ['b1'], reasons: [], suggestions: [] }
      );
      const data = await bookChat.sendMessage(1, '推理小說');
      assert.strictEqual(bookChat.REPLY_CHECK_ENFORCED, false);
      assert.strictEqual(data.reply.content, '推薦《白夜行》，只要 99 元。');
      const decision = prisma.rows('ai_decision_logs').filter((r) => r.feature === 'book_chat').at(-1);
      const { flags, counts } = JSON.parse(decision.stats);
      assert.deepStrictEqual(
        [flags.reply_unknown_title, flags.reply_price, flags.reply_denies_books, flags.reply_replaced, counts.reply_titles],
        [true, true, false, false, 1]
      );
    }]
  ]
};
