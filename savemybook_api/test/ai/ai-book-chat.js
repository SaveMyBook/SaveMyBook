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
