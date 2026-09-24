const assert = require('assert');
const h = require('./harness');

const bookChat = h.api('services/ai/book-chat');
const books = h.api('services/books');
const ranking = h.api('services/ranking');
const runner = h.api('services/ai/runner');

const categories = [
  { category_id: 1, category_name: '文學小說' },
  { category_id: 2, category_name: '電腦資訊' }
];

const book = (id, overrides = {}) => ({
  book_id: id,
  seller_id: 9,
  title: `推理小說 ${id}`,
  author: '東野圭吾',
  price: 100 + id,
  status: 'on_sale',
  is_approved: true,
  condition_level: 'good',
  category_id: 1,
  view_count: 100 - id,
  book_categories: { category_name: '文學小說' },
  book_images: [],
  users: { user_id: 9, nickname: '賣家', avatar_url: null },
  ...overrides
});

let insertedSessions = 0;
let messageSeq = 0;
let storedMessages = [];

const setup = ({ sessionRow = null, existing = [], candidateRows = [] } = {}) => {
  h.reset();
  h.installDefaults();
  insertedSessions = 0;
  messageSeq = 100;
  storedMessages = [];

  h.onSql(/SELECT session_id, created_at, updated_at FROM ai_chat_sessions/, () => (sessionRow ? [sessionRow] : []));
  h.onSql(/FROM ai_chat_messages WHERE session_id/, () => [...existing].reverse());
  h.onSql(/INSERT INTO ai_chat_sessions/, () => {
    insertedSessions += 1;
    return 1;
  });
  h.onSql(/INSERT INTO ai_chat_messages/, (values) => {
    messageSeq += 1;
    storedMessages.push({ role: values[1], content: values[2], book_ids: values[3] });
    return 1;
  });
  h.onSql(/UPDATE ai_chat_sessions/, () => 1);
  h.onSql(/LAST_INSERT_ID/, () => [{ id: messageSeq }]);
  h.onModel('book_categories.findMany', () => categories);
  h.onModel('books.findMany', () => candidateRows);
};

const ids = new Set([1, 2]);

module.exports = {
  name: 'AI 書籍顧問',
  tests: [
    ['搜尋條件清理：只接受分類清單內的 category_id', () => {
      const out = bookChat.sanitizeSearch({ keyword: '推理', category_ids: [1, 9, 2, 1], condition_levels: [] }, ids);
      assert.deepStrictEqual(out.category_ids, [1, 2]);
    }],

    ['搜尋條件清理：價格顛倒時自動對調，超出範圍視為未設定', () => {
      const out = bookChat.sanitizeSearch({ min_price: 500, max_price: 300 }, ids);
      assert.strictEqual(out.min_price, 300);
      assert.strictEqual(out.max_price, 500);
      assert.strictEqual(bookChat.sanitizeSearch({ max_price: 999999 }, ids).max_price, null);
      assert.strictEqual(bookChat.sanitizeSearch({ max_price: '不限' }, ids).max_price, null);
    }],

    ['搜尋條件清理：只接受合法的書況代碼', () => {
      const out = bookChat.sanitizeSearch({ condition_levels: ['good', 'perfect', 'good'] }, ids);
      assert.deepStrictEqual(out.condition_levels, ['good']);
    }],

    ['搜尋條件清理：非物件時回傳 null', () => {
      assert.strictEqual(bookChat.sanitizeSearch(null, ids), null);
      assert.strictEqual(bookChat.sanitizeSearch('推理', ids), null);
    }],

    ['book_ids 解析：過濾非正整數並限制數量', () => {
      assert.deepStrictEqual(bookChat.parseBookIds('3,7,x,-1,0,11,12,13,14,15'), [3, 7, 11, 12, 13, 14]);
      assert.deepStrictEqual(bookChat.parseBookIds(null), []);
    }],

    ['送出訊息：兩次呼叫模型並回傳驗證過的書卡與追問建議', async () => {
      const rows = [book(1), book(2), book(3)];
      setup({ candidateRows: rows });
      h.queueJson(
        { reply: '為您搜尋推理小說。', search: { keyword: '推理', category_ids: [1], max_price: 300, min_price: null, condition_levels: [] }, need_more_info: false },
        { reply: '以下是適合通勤閱讀的推理小說。', book_ids: ['b2', 'b1', 'b9'], reasons: { b2: '節奏明快，適合通勤', b1: '經典入門作' }, suggestions: ['還有其他作者嗎', '有沒有更便宜的'] }
      );

      const data = await bookChat.sendMessage(5, '想找適合通勤看的推理小說，300 元以內');
      assert.strictEqual(h.calls.length, 2);
      assert.strictEqual(data.reply.books.length, 2);
      assert.deepStrictEqual(data.reply.books.map((b) => b.book.book_id), [2, 1]);
      assert.strictEqual(data.reply.books[0].reason, '節奏明快，適合通勤');
      assert.deepStrictEqual(data.reply.suggestions, ['還有其他作者嗎', '有沒有更便宜的']);
      assert.strictEqual(insertedSessions, 1);
      assert.deepStrictEqual(storedMessages.map((m) => m.role), ['user', 'assistant']);
      assert.strictEqual(storedMessages[1].book_ids, '2,1');
    }],

    ['送出訊息：候選集合外的代號一律忽略', async () => {
      setup({ candidateRows: [book(1)] });
      h.queueJson(
        { reply: '好的。', search: { keyword: '推理', category_ids: [], max_price: null, min_price: null, condition_levels: [] }, need_more_info: false },
        { reply: '推薦如下。', book_ids: ['b7', 'b8'], reasons: {}, suggestions: [] }
      );

      const data = await bookChat.sendMessage(5, '推薦推理小說');
      assert.strictEqual(data.reply.books.length, 1);
      assert.strictEqual(data.reply.books[0].book.book_id, 1);
    }],

    ['送出訊息：需求不明確時只呼叫一次模型且不附書卡', async () => {
      setup();
      h.queueJson({ reply: '請問您想看哪一類主題的書？', search: null, need_more_info: true });

      const data = await bookChat.sendMessage(5, '推薦書');
      assert.strictEqual(h.calls.length, 1);
      assert.strictEqual(data.reply.books.length, 0);
      assert.strictEqual(data.reply.content, '請問您想看哪一類主題的書？');
      assert.strictEqual(storedMessages[1].book_ids, null);
    }],

    ['送出訊息：查無符合條件的書時改推熱門書，不回錯誤', async () => {
      setup({ candidateRows: [] });
      h.queueJson({ reply: '好的。', search: { keyword: '不存在的書', category_ids: [], max_price: null, min_price: null, condition_levels: [] }, need_more_info: false });
      const rankedOriginal = ranking.rankedIds;
      const orderOriginal = books.inIdOrder;
      ranking.rankedIds = async () => [4, 5];
      books.inIdOrder = async () => [book(4), book(5)];
      try {
        const data = await bookChat.sendMessage(5, '想找不存在的書');
        assert.strictEqual(data.reply.books.length, 2);
        assert.strictEqual(h.calls.length, 1);
      } finally {
        ranking.rankedIds = rankedOriginal;
        books.inIdOrder = orderOriginal;
      }
    }],

    ['送出訊息：第二次模型呼叫失敗時退回候選書單，不丟出 502', async () => {
      const rows = [book(1), book(2)];
      setup({ candidateRows: rows });
      h.queueJson(
        { reply: '為您搜尋推理小說。', search: { keyword: '推理', category_ids: [], max_price: null, min_price: null, condition_levels: [] }, need_more_info: false },
        h.providerError('TIMEOUT')
      );

      const data = await bookChat.sendMessage(5, '推薦推理小說');
      assert.strictEqual(data.reply.books.length, 2);
      assert.strictEqual(data.reply.content, '為您搜尋推理小說。');
    }],

    ['搜尋條件清理：關鍵字支援多個同義詞並相容舊的單一 keyword', () => {
      const out = bookChat.sanitizeSearch({ keywords: ['人工智慧', 'AI', 'AI', '', '機器學習', '深度學習', '神經網路', '資料科學'], keyword: 'AI' }, ids);
      assert.deepStrictEqual(out.keywords, ['人工智慧', 'AI', '機器學習', '深度學習', '神經網路']);
      assert.deepStrictEqual(bookChat.sanitizeSearch({ keyword: '推理' }, ids).keywords, ['推理']);
    }],

    ['回覆含欄位名稱或英文代碼時不直接顯示給使用者', () => {
      assert.strictEqual(bookChat.cleanReply('請提供預算（min_price, max_price）與書況（like_new、good）', 500), '');
      assert.strictEqual(bookChat.cleanReply('為您挑選 b2 與 b3', 500), '');
      assert.strictEqual(bookChat.cleanReply('這幾本適合想入門 AI 的讀者。', 500), '這幾本適合想入門 AI 的讀者。');
    }],

    ['送出訊息：需求不明確且模型回覆夾帶欄位名稱時，改用預設問句並提供示範需求', async () => {
      setup();
      h.queueJson({ reply: '請提供 keywords 與 min_price', search: null, need_more_info: true, suggestions: [] });

      const data = await bookChat.sendMessage(5, '推薦書');
      assert.strictEqual(data.reply.content, bookChat.CLARIFY_REPLY);
      assert.strictEqual(data.reply.suggestions.length, 3);
    }],

    ['送出訊息：關鍵字查無結果時告知模型候選書只是熱門書', async () => {
      setup();
      let call = 0;
      // 第 1 次：站內索引、第 2 次：資料庫關鍵字比對，兩者都查無結果才退回熱門書。
      h.onModel('books.findMany', () => {
        call += 1;
        return call <= 2 ? [] : [book(1), book(2)];
      });
      h.queueJson(
        { reply: '為您尋找 AI 相關書籍。', search: { keywords: ['人工智慧', 'AI'], category_ids: [], max_price: null, min_price: null, condition_levels: [] }, need_more_info: false },
        { reply: '站上目前沒有直接相關的 AI 書籍。', book_ids: [], reasons: {}, suggestions: [] }
      );

      const data = await bookChat.sendMessage(5, '我最近想研究 AI，推薦我什麼書');
      assert.match(h.calls[1].options.prompt, /【比對結果】\n未找到直接相關的書/);
      assert.strictEqual(data.reply.content, '站上目前沒有直接相關的 AI 書籍。');
    }],

    ['候選書：依關鍵字相關度排序，而不是瀏覽數', async () => {
      const catalogue = [
        book(1, { title: '東野圭吾推理精選', author: '東野圭吾', view_count: 999 }),
        book(2, { title: '機器學習導論', author: '周志華', view_count: 3, category_id: 2, book_categories: { category_name: '電腦資訊' }, description: '從線性模型到神經網路的機器學習入門教材' }),
        book(3, { title: '深度學習實戰', author: '某作者', view_count: 5, category_id: 2, book_categories: { category_name: '電腦資訊' } })
      ];
      setup({ candidateRows: catalogue });
      const search = bookChat.sanitizeSearch({ keywords: ['機器學習', '人工智慧'], category_ids: [2] }, ids);
      const { rows, matched, extraIds } = await bookChat.candidates(5, search, '想入門機器學習');
      assert.strictEqual(matched, true);
      assert.strictEqual(rows[0].book_id, 2);
      const retrieved = rows.filter((b) => !extraIds.has(b.book_id));
      assert.ok(!retrieved.some((b) => b.book_id === 1), '與主題無關的熱門書不列入檢索結果');
      assert.deepStrictEqual([...extraIds], [1], '只作為後段的其他在售書供模型判斷');
    }],

    ['候選書：價格與書況條件在站內索引也會套用', async () => {
      const catalogue = [
        book(1, { title: '機器學習導論', price: 800 }),
        book(2, { title: '機器學習入門', price: 200, condition_level: 'fair' }),
        book(3, { title: '機器學習實務', price: 250, condition_level: 'good' })
      ];
      setup({ candidateRows: catalogue });
      const search = bookChat.sanitizeSearch({ keywords: ['機器學習'], max_price: 300, condition_levels: ['good'] }, ids);
      const { rows, extraIds } = await bookChat.candidates(5, search);
      assert.deepStrictEqual(rows.filter((b) => !extraIds.has(b.book_id)).map((b) => b.book_id), [3]);
    }],

    ['送出訊息：追問時附上先前推薦的書名並標示已推薦過，兩次呼叫都提高推理強度', async () => {
      const rows = [book(1, { description: '經典本格推理' }), book(2)];
      setup({
        sessionRow: { session_id: 3, created_at: new Date(), updated_at: new Date() },
        existing: [
          { message_id: 1, role: 'user', content: '推薦推理小說', book_ids: null, created_at: new Date() },
          { message_id: 2, role: 'assistant', content: '為您挑選以下推理小說。', book_ids: '1', created_at: new Date() }
        ],
        candidateRows: rows
      });
      h.queueJson(
        { reply: '為您再找其他推理小說。', search: { keywords: ['推理'], category_ids: [], max_price: null, min_price: null, condition_levels: [] }, need_more_info: false },
        { reply: '這本也很適合您。', book_ids: ['b2'], reasons: { b2: '同樣是節奏明快的推理作品' }, suggestions: [] }
      );

      await bookChat.sendMessage(5, '還有別的嗎');
      const [plan, pickCall] = h.calls.map((c) => c.options);
      assert.match(plan.history[1].content, /當時推薦的書：《推理小說 1》/);
      assert.strictEqual(plan.reasoning, 'low');
      assert.strictEqual(pickCall.reasoning, 'low');
      assert.match(pickCall.prompt, /b1｜《推理小說 1》.*簡介：經典本格推理｜先前已推薦/);
      assert.ok(!/b2｜[^\n]*先前已推薦/.test(pickCall.prompt));
    }],

    ['送出訊息：未同意 AI 資料處理時回 403 AI_CONSENT_REQUIRED', async () => {
      setup();
      h.reset();
      h.installDefaults({ consented: false });
      h.onModel('book_categories.findMany', () => categories);
      await assert.rejects(() => bookChat.sendMessage(5, '推薦推理小說'), (err) => err.code === 'AI_CONSENT_REQUIRED' && err.status === 403);
    }],

    ['送出訊息：功能關閉時回 503 AI_DISABLED', async () => {
      h.reset();
      h.installDefaults({ config: { features: { book_chat: { enabled: false } } } });
      await assert.rejects(() => bookChat.sendMessage(5, '推薦推理小說'), (err) => err.code === 'AI_DISABLED');
    }],

    ['讀取對話：沒有進行中的對話時回傳 null', async () => {
      setup();
      assert.strictEqual(await bookChat.currentSession(5), null);
    }],

    ['讀取對話：重新查書，已下架的書卡會被濾掉', async () => {
      setup({
        sessionRow: { session_id: 12, created_at: new Date(), updated_at: new Date() },
        existing: [
          { message_id: 1, role: 'user', content: '推薦推理小說', book_ids: null, created_at: new Date() },
          { message_id: 2, role: 'assistant', content: '推薦如下。', book_ids: '1,2', created_at: new Date() }
        ]
      });
      const orderOriginal = books.inIdOrder;
      books.inIdOrder = async (list) => list.filter((id) => id === 1).map((id) => book(id));
      try {
        const data = await bookChat.currentSession(5);
        assert.strictEqual(data.session_id, 12);
        assert.strictEqual(data.messages.length, 2);
        assert.strictEqual(data.messages[1].books.length, 1);
        assert.strictEqual(data.messages[0].books.length, 0);
      } finally {
        books.inIdOrder = orderOriginal;
      }
    }],

    ['結束對話會把狀態改為 closed', async () => {
      setup();
      await bookChat.close(5);
      assert.ok(h.prisma.sqlLog.some((sql) => /UPDATE ai_chat_sessions SET status = 'closed'/.test(sql)));
    }],

    ['尚未執行 013 時回 503 AI_UNAVAILABLE', async () => {
      h.reset();
      h.onSql(/information_schema\.TABLES/, (values) => [{ n: values.includes('ai_chat_sessions') ? 0 : values.length }]);
      h.onSql(/information_schema\.COLUMNS/, () => [{ n: 1 }]);
      h.onSql(/FROM ai_settings/, () => []);
      await assert.rejects(() => bookChat.currentSession(5), (err) => err.code === 'AI_UNAVAILABLE' && err.status === 503);
    }],

    ['狀態：尚未執行 013 時 status 的 book_chat 為 false', async () => {
      h.reset();
      h.installDefaults();
      h.state.sql.unshift({
        match: /information_schema\.TABLES/,
        run: (values) => [{ n: values.includes('ai_chat_sessions') ? 0 : values.length }]
      });
      const status = await runner.status(5);
      assert.strictEqual(status.book_chat, false);
      assert.strictEqual(status.support, true);
    }],

    ['狀態：資料表齊備時 status 的 book_chat 為 true', async () => {
      h.reset();
      h.installDefaults();
      const status = await runner.status(5);
      assert.strictEqual(status.book_chat, true);
    }]
  ]
};
