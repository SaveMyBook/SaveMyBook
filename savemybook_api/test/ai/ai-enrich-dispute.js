const assert = require('assert');
const h = require('./harness');

const enrich = h.api('services/ai/enrich');
const disputeAssist = h.api('services/ai/dispute-assist');
const isbnLookup = h.api('services/isbn-lookup');

let rows = [];
const setupEnrich = (bookRow, found) => {
  h.reset({ tables: { books: [bookRow] } });
  h.installDefaults();
  rows = [];
  h.onSql(/INSERT INTO ai_book_enrichments/, ([bookId, status, fields, aiWritten]) => {
    rows = rows.filter((r) => r.book_id !== bookId);
    rows.push({ book_id: bookId, status, fields, ai_written: aiWritten });
    return 1;
  });
  h.onSql(/SELECT fields, ai_written FROM ai_book_enrichments/, ([bookId]) => rows.filter((r) => r.book_id === bookId));
  isbnLookup.lookupWithSources = async () => {
    if (!found) {
      const err = new Error('找不到此 ISBN 的書籍資訊');
      err.status = 404;
      throw err;
    }
    return { fields: found, sources: [] };
  };
};

const baseBook = (overrides = {}) => ({
  book_id: 1, seller_id: 9, title: '憲法解題書', isbn: '9786264112437', description: null, author: null,
  publisher: null, publish_date: null, status: 'on_sale', is_approved: true, price: 650, ...overrides
});

module.exports = {
  name: 'AI 書籍資料補齊與爭議分析',
  tests: [
    ['補齊：依 ISBN 補上空白的作者與出版社，簡介由 AI 依書目整理', async () => {
      setupEnrich(baseBook(), { author: '歐律師', publisher: '高點文化', publish_date: '2024-02-01', description: '本書收錄歷年憲法考題與解析。' });
      h.queueJson({ description: '本書整理歷年憲法考題並逐題解析，適合準備國家考試的讀者。' });

      const result = await enrich.enrich(1);
      const saved = h.prisma.rows('books')[0];
      assert.strictEqual(result.status, 'done');
      assert.strictEqual(saved.author, '歐律師');
      assert.strictEqual(saved.publisher, '高點文化');
      assert.strictEqual(saved.publish_date, '2024-02-01');
      assert.strictEqual(saved.description, '本書整理歷年憲法考題並逐題解析，適合準備國家考試的讀者。');
      assert.match(h.calls[0].options.system, /只能使用【書目來源】提供的內容/);
      assert.strictEqual(rows[0].status, 'done');
      assert.strictEqual(rows[0].ai_written, 1);
      assert.deepStrictEqual(rows[0].fields.split(',').sort(), ['author', 'description', 'publish_date', 'publisher']);
    }],

    ['補齊：賣家已填的欄位不覆蓋；AI 關閉時簡介改用書目原文', async () => {
      setupEnrich(baseBook({ author: '賣家填的作者' }), { author: '別的作者', description: '書目提供的簡介內容。' });
      h.reset({ tables: { books: [baseBook({ author: '賣家填的作者' })] } });
      h.installDefaults({ enabled: false });
      h.onSql(/INSERT INTO ai_book_enrichments/, ([bookId, status, fields, aiWritten]) => {
        rows = [{ book_id: bookId, status, fields, ai_written: aiWritten }];
        return 1;
      });

      await enrich.enrich(1);
      const saved = h.prisma.rows('books')[0];
      assert.strictEqual(saved.author, '賣家填的作者');
      assert.strictEqual(saved.description, '書目提供的簡介內容。');
      assert.strictEqual(h.calls.length, 0);
      assert.strictEqual(rows[0].ai_written, 0);
    }],

    ['補齊：沒有 ISBN、查無書目或欄位都已填寫時只記錄一次，不再重試', async () => {
      setupEnrich(baseBook({ isbn: null }), null);
      assert.strictEqual((await enrich.enrich(1)).status, 'none');
      setupEnrich(baseBook(), null);
      assert.strictEqual((await enrich.enrich(1)).status, 'none');
      assert.strictEqual(rows[0].status, 'none');
      setupEnrich(baseBook({ description: '有', author: '有', publisher: '有', publish_date: '2020' }), { author: 'x' });
      assert.strictEqual((await enrich.enrich(1)).status, 'none');
    }],

    ['補齊：賣家修改過的欄位從紀錄移除，書籍頁不再標示', async () => {
      setupEnrich(baseBook(), null);
      rows = [{ book_id: 1, status: 'done', fields: 'description,author', ai_written: 1 }];
      await enrich.forget(1, ['description', 'price']);
      assert.strictEqual(rows[0].fields, 'author');
      assert.strictEqual(rows[0].ai_written, 0);
    }],

    ['爭議分析：比對上架資料與申訴內容，回傳摘要與清理過的建議', async () => {
      h.reset();
      h.installDefaults();
      h.onModel('transaction_disputes.findUnique', () => ({
        dispute_id: 3,
        applicant_id: 1,
        reason: '書中有大量螢光筆劃記，與近全新不符',
        evidence_urls: '/uploads/evidence/a.jpg',
        created_at: new Date(),
        orders: {
          buyer_id: 1, seller_id: 2, status: 'refunding', created_at: new Date(), deposited_at: new Date(), picked_up_at: new Date(),
          order_items: [{ unit_price: 200, books: { title: '小王子', author: '聖修伯里', condition_level: 'like_new', description: '幾乎沒翻過', book_images: [] } }]
        }
      }));
      h.queueJson({
        summary: '買家表示書中有大量劃記，賣家標示為近全新。',
        findings: ['申訴描述有大量螢光筆劃記', '上架照片未拍攝內頁'],
        suggestion: 'something_else',
        confidence: 3,
        rationale: '需要內頁照片才能確認。'
      });

      const result = await disputeAssist.analyze(3, 99);
      assert.strictEqual(result.suggestion, 'need_more_info', '未知建議一律視為需要更多資訊');
      assert.strictEqual(result.confidence, 1);
      assert.strictEqual(result.findings.length, 2);
      const call = h.calls[0];
      assert.match(call.options.prompt, /賣家標示書況：近全新/);
      assert.match(call.options.prompt, /提出者：買家/);
      assert.ok(!/聊天/.test(call.options.prompt), '不使用聊天內容');
    }],

    ['爭議分析：AI 關閉時回 503，找不到案件回 404', async () => {
      h.reset();
      h.installDefaults({ enabled: false });
      h.onModel('transaction_disputes.findUnique', () => ({ dispute_id: 1, orders: { order_items: [] } }));
      await assert.rejects(() => disputeAssist.analyze(1, 9), (err) => err.status === 503);
      h.onModel('transaction_disputes.findUnique', () => null);
      await assert.rejects(() => disputeAssist.analyze(1, 9), (err) => err.status === 404);
    }]
  ]
};
