const assert = require('assert');
const h = require('./harness');

const support = h.api('services/ai/support');
const knowledge = h.api('services/ai/knowledge');
const { prisma } = h;

const FAQS = [
  { faq_id: 1, category: '帳號', question: '忘記密碼怎麼辦？', answer: '在登入頁點選「忘記密碼」並依信件指示重設。', sort_order: 0, is_visible: true },
  { faq_id: 2, category: '交易', question: '買到的書有破損可以退嗎？', answer: '請在取書後 24 小時內對訂單提出爭議。', sort_order: 0, is_visible: true },
  { faq_id: 3, category: '交易', question: '隱藏的問題', answer: '不應出現在檢索結果', sort_order: 1, is_visible: false }
];

const LEGAL = [{ doc_id: 1, title: '服務條款', content: '第一條 總則\n本平台提供二手書交易服務。\n\n第二條 帳號\n使用者應妥善保管帳號密碼。' }];

// 使用者資料牽涉多層關聯，這裡直接指定各查詢的結果，聚焦在提示詞組裝與檢索。
const stubUserData = ({ bought = [], sold = [], books = [], wallet = { balance: 120 }, tickets = [] } = {}) => {
  h.onModel('orders.findMany', (args) => (args.where.buyer_id ? bought : sold));
  h.onModel('reservations.findMany', () => []);
  h.onModel('books.findMany', () => books);
  h.onModel('wallets.findUnique', () => wallet);
  h.onModel('support_tickets.findMany', () => tickets);
};

const setup = () => {
  knowledge.invalidate();
  prisma.store.faqs = FAQS.map((f) => ({ ...f }));
  prisma.store.legal_documents = LEGAL.map((d) => ({ ...d }));
  h.setSettings({ enabled: true });
  h.setConsent(7, true);
  stubUserData();
};

const titlesOf = (docs) => docs.map((d) => d.title);

module.exports = {
  name: 'AI 客服（檢索增強）',
  tests: [
    ['分詞：中文取單字與雙字，略過疑問用語', () => {
      const tokens = knowledge.tokenize('我要怎麼儲值？');
      assert.ok(tokens.includes('儲值'));
      assert.ok(!tokens.includes('怎麼'));
      assert.ok(!tokens.includes('我'));
      assert.deepStrictEqual(knowledge.tokenize('ISBN 978957'), ['isbn', '978957']);
    }],

    ['同義詞：口語說法補上平台用語', () => {
      assert.match(knowledge.expandQuery('錢可以領出來嗎'), /提領/);
      assert.match(knowledge.expandQuery('可以退錢嗎'), /退款/);
      assert.strictEqual(knowledge.expandQuery('你好'), '你好');
    }],

    ['條款切段：依條文分段且每段帶標題', () => {
      const chunks = knowledge.splitLegal('服務條款', LEGAL[0].content);
      assert.ok(chunks.length >= 1);
      assert.ok(chunks.every((c) => c.title === '《服務條款》' && c.text.length <= 420));
      const long = knowledge.splitLegal('隱私權政策', `${'個人資料將依法處理。'.repeat(80)}`);
      assert.ok(long.length > 1);
      assert.ok(long.every((c) => c.text.length <= 420));
    }],

    ['檢索：依提問找到對應主題，不會整包塞入', async () => {
      setup();
      assert.strictEqual((await knowledge.search('我要怎麼儲值？'))[0].title, '錢包與代幣');
      assert.strictEqual((await knowledge.search('可以先幫我留書嗎'))[0].title, '預約保留');
      assert.strictEqual((await knowledge.search('取件碼是多少'))[0].title, '智慧書櫃存書與取書');
      const docs = await knowledge.search('想刪帳號');
      assert.strictEqual(docs[0].title, '帳號與安全');
      assert.ok(docs.length < knowledge.PLATFORM_TOPICS.length);
    }],

    ['檢索：常見問題與條款都會納入，隱藏的 FAQ 不會', async () => {
      setup();
      const docs = await knowledge.search('買到的書破損可以退嗎');
      assert.ok(docs.some((d) => d.source === 'faq' && d.text.includes('24 小時內')));
      assert.ok(!(await knowledge.search('隱藏的問題')).some((d) => d.text.includes('不應出現')));
      assert.ok((await knowledge.search('帳號密碼保管')).some((d) => d.source === 'legal'));
    }],

    ['檢索：追問時參考前一則提問的主題', async () => {
      setup();
      const alone = await knowledge.search('那要等多久');
      const followUp = await knowledge.search('那要等多久', { context: ['我的書一直在審核中'] });
      assert.strictEqual(followUp[0].title, '上架審核');
      assert.notDeepStrictEqual(titlesOf(alone), titlesOf(followUp));
    }],

    ['檢索：完全無關的內容回傳空陣列', async () => {
      setup();
      assert.deepStrictEqual(await knowledge.search('？？？'), []);
      assert.strictEqual(knowledge.format([]), '（沒有找到相關資料）');
    }],

    ['提示詞：包含檢索結果與本人的訂單、書籍審核狀態與錢包餘額', async () => {
      setup();
      stubUserData({
        bought: [{ order_no: 'SMB001', status: 'pending_deposit', total_amount: 250, created_at: new Date(), order_items: [{ books: { title: '挪威的森林' } }] }],
        sold: [{ order_no: 'SMB002', status: 'completed', total_amount: 90, created_at: new Date(), order_items: [{ books: { title: '人間失格' } }] }],
        books: [{
          title: '高價畫冊', price: 5000, status: 'on_sale', is_approved: false, created_at: new Date(),
          ai_book_reviews: { status: 'pending', reasons: JSON.stringify(['售價明顯高於一般二手書行情']) }
        }],
        wallet: { balance: 321 }
      });
      const system = await support.buildSystem(7, { question: '我的書怎麼還沒上架' });
      assert.match(system, /【參考資料】[\s\S]*上架審核/);
      assert.match(system, /訂單 SMB001：待存書/);
      assert.match(system, /訂單 SMB002：已完成/);
      assert.match(system, /《高價畫冊》：審核中（尚未公開）.*售價明顯高於一般二手書行情/);
      assert.match(system, /錢包餘額：321 代幣/);
      assert.ok(!system.includes('【常見問題】'), '不再整包附上所有 FAQ');
    }],

    ['提示詞：單一使用者資料查詢失敗時略過該區塊', async () => {
      setup();
      h.onModel('wallets.findUnique', () => { throw new Error('Unknown column'); });
      const original = console.error;
      console.error = () => {};
      try {
        const system = await support.buildSystem(7, { question: '餘額' });
        assert.match(system, /錢包餘額：（無資料）/);
      } finally {
        console.error = original;
      }
    }],

    ['送出訊息：以較高推理強度呼叫模型，並依本次提問與前文檢索', async () => {
      setup();
      h.queueJson({ reply: '目前 App 沒有自助儲值功能，需要儲值請轉接客服人員。', suggest_handoff: true });
      const first = await support.sendMessage(7, '我要怎麼儲值？');
      assert.strictEqual(first.suggest_handoff, true);
      assert.strictEqual(h.calls[0].options.reasoning, 'low');
      assert.match(h.calls[0].options.system, /錢包與代幣/);

      h.queueJson({ reply: '可以，請在客服中心查看回覆。', suggest_handoff: false });
      await support.sendMessage(7, '那要多久？');
      const second = h.calls[1].options;
      assert.deepStrictEqual(second.history.map((m) => m.role), ['user', 'assistant']);
      assert.strictEqual(second.prompt, '那要多久？');
      assert.match(second.system, /錢包與代幣/, '追問沿用前一則提問的主題');
    }]
  ]
};
