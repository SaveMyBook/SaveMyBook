const assert = require('assert');
const h = require('./harness');

const listingAssist = h.api('services/ai/listing-assist');

const { parsePublishDate, cleanDescription, sanitizeFields, mergeFields, normalizeLanguage, toPageCount } = listingAssist;

const categories = [{ category_id: 3, category_name: '文學小說' }];
const isbnLookup = h.api('services/isbn-lookup');
const googleBooks = h.api('lib/google-books');
const openLibrary = h.api('lib/open-library');

// 測試不得連外：書目來源一律以假資料取代，預設查無資料。
const setup = ({ lookup = null } = {}) => {
  h.reset();
  h.installDefaults();
  h.onModel('book_categories.findMany', () => categories);
  googleBooks.searchVolumesByTitle = async () => [];
  openLibrary.searchByTitle = async () => [];
  isbnLookup.lookupWithSources = async () => {
    if (!lookup) throw new Error('查無資料');
    return lookup;
  };
};

module.exports = {
  name: 'AI 上架輔助',
  tests: [
    ['書況：接受中文標籤、大小寫與字串格式，無法辨識或無依據時為 null', () => {
      const { sanitizeCondition } = listingAssist;
      assert.strictEqual(sanitizeCondition({ level: 'good', confidence: 0.8 }, true).level, 'good');
      assert.strictEqual(sanitizeCondition({ level: 'Like New', confidence: 0.8 }, true).level, 'like_new');
      assert.strictEqual(sanitizeCondition({ level: 'like-new' }, true).level, 'like_new');
      assert.strictEqual(sanitizeCondition({ level: '良好（有輕微摺痕）' }, true).level, 'good');
      assert.strictEqual(sanitizeCondition({ level: '待修補' }, true).level, 'poor');
      assert.strictEqual(sanitizeCondition('fair', true).level, 'fair');
      assert.strictEqual(sanitizeCondition({ level: '很棒' }, true), null);
      assert.strictEqual(sanitizeCondition({ level: 'good' }, false), null);
    }],

    ['出版日期：ISO 日期保留到日', () => {
      assert.deepStrictEqual(parsePublishDate('2003-08-01'), { date: '2003-08-01', precision: 'day' });
      assert.deepStrictEqual(parsePublishDate('2003/8/1'), { date: '2003-08-01', precision: 'day' });
      assert.deepStrictEqual(parsePublishDate('2003-08-01T00:00:00Z'), { date: '2003-08-01', precision: 'day' });
    }],

    ['出版日期：英文月份只到月時精度為 month', () => {
      assert.deepStrictEqual(parsePublishDate('August 2003'), { date: '2003-08', precision: 'month' });
      assert.deepStrictEqual(parsePublishDate('Sept 2003'), { date: '2003-09', precision: 'month' });
    }],

    ['出版日期：英文月日年與日月年都解析到日', () => {
      assert.deepStrictEqual(parsePublishDate('Aug 1, 2003'), { date: '2003-08-01', precision: 'day' });
      assert.deepStrictEqual(parsePublishDate('1 August 2003'), { date: '2003-08-01', precision: 'day' });
    }],

    ['出版日期：中文年月日', () => {
      assert.deepStrictEqual(parsePublishDate('2003年8月'), { date: '2003-08', precision: 'month' });
      assert.deepStrictEqual(parsePublishDate('2003年8月1日'), { date: '2003-08-01', precision: 'day' });
    }],

    ['出版日期：民國年換算為西元年', () => {
      assert.deepStrictEqual(parsePublishDate('民國92年8月'), { date: '2003-08', precision: 'month' });
      assert.deepStrictEqual(parsePublishDate('民國 92 年 8 月 15 日'), { date: '2003-08-15', precision: 'day' });
    }],

    ['出版日期：只有年份或無法解析時降級', () => {
      assert.deepStrictEqual(parsePublishDate('2003'), { date: '2003', precision: 'year' });
      assert.deepStrictEqual(parsePublishDate('c2003'), { date: '2003', precision: 'year' });
      assert.deepStrictEqual(parsePublishDate(''), { date: '', precision: '' });
      assert.deepStrictEqual(parsePublishDate('近期出版'), { date: '', precision: '' });
    }],

    ['出版日期：不存在的日期降級為月，不存在的月降級為年', () => {
      assert.deepStrictEqual(parsePublishDate('2003-02-30'), { date: '2003-02', precision: 'month' });
      assert.deepStrictEqual(parsePublishDate('2003-13-05'), { date: '2003', precision: 'year' });
    }],

    ['精度旗標：模型宣告的精度較低時截掉多餘的日', () => {
      const fields = sanitizeFields({ publish_date: '2003-08-01', publish_date_precision: 'month' });
      assert.strictEqual(fields.publish_date, '2003-08');
      assert.strictEqual(fields.publish_date_precision, 'month');
    }],

    ['精度旗標：模型宣告的精度較高時不採信，以實際解析結果為準', () => {
      const fields = sanitizeFields({ publish_date: '2003-08', publish_date_precision: 'day' });
      assert.strictEqual(fields.publish_date, '2003-08');
      assert.strictEqual(fields.publish_date_precision, 'month');
    }],

    ['精度旗標：沒有日期時精度為空字串', () => {
      const fields = sanitizeFields({ publish_date: '', publish_date_precision: 'day' });
      assert.strictEqual(fields.publish_date, '');
      assert.strictEqual(fields.publish_date_precision, '');
    }],

    ['精度旗標：書目來源較精確時優先採用來源日期', () => {
      const merged = mergeFields({ publish_date: '2003-08-01' }, sanitizeFields({ publish_date: '2003年8月', publish_date_precision: 'month' }));
      assert.strictEqual(merged.publish_date, '2003-08-01');
      assert.strictEqual(merged.publish_date_precision, 'day');
    }],

    ['精度旗標：模型較精確時保留模型日期', () => {
      const merged = mergeFields({ publish_date: 'August 2003' }, sanitizeFields({ publish_date: '2003-08-12', publish_date_precision: 'day' }));
      assert.strictEqual(merged.publish_date, '2003-08-12');
      assert.strictEqual(merged.publish_date_precision, 'day');
    }],

    ['簡介整理：清掉 HTML 標籤與 HTML 實體', () => {
      const out = cleanDescription('<p>本書<b>描述</b>一段&nbsp;青春故事。</p>');
      assert.strictEqual(out, '本書描述一段 青春故事。');
    }],

    ['簡介整理：清掉促銷、贈品與活動訊息', () => {
      const out = cleanDescription('本書描述一段青春故事。\n★限時特價 79 折\n購買即贈品書籤一組\n適合喜歡村上春樹的讀者。');
      assert.strictEqual(out, '本書描述一段青春故事。\n適合喜歡村上春樹的讀者。');
    }],

    ['簡介整理：清掉外部網址、電話與電子郵件', () => {
      const out = cleanDescription('本書描述一段青春故事，訂購請洽 02-23456789 或 service@example.com。\n詳見 https://example.com/book');
      assert.ok(!out.includes('example.com'));
      assert.ok(!out.includes('23456789'));
      assert.ok(out.includes('本書描述一段青春故事'));
    }],

    ['簡介整理：清掉重複的書名與重複的段落', () => {
      const out = cleanDescription('挪威的森林\n本書描述一段青春故事。\n本書描述一段青春故事。', { title: '挪威的森林' });
      assert.strictEqual(out, '本書描述一段青春故事。');
    }],

    ['簡介整理：清掉「內容簡介」這類標題行', () => {
      assert.strictEqual(cleanDescription('【內容簡介】\n本書描述一段青春故事。'), '本書描述一段青春故事。');
    }],

    ['簡介整理：沒有內容時回傳空字串', () => {
      assert.strictEqual(cleanDescription(''), '');
      assert.strictEqual(cleanDescription(null), '');
      assert.strictEqual(cleanDescription('<p></p>'), '');
    }],

    ['新增欄位：副標題、頁數與語言都會清理', () => {
      const fields = sanitizeFields({ subtitle: '  村上春樹經典  ', page_count: '384', language: 'zh-TW' });
      assert.strictEqual(fields.subtitle, '村上春樹經典');
      assert.strictEqual(fields.page_count, 384);
      assert.strictEqual(fields.language, 'zh-Hant');
    }],

    ['新增欄位：不合理的頁數與語言標記一律捨棄', () => {
      assert.strictEqual(toPageCount(0), null);
      assert.strictEqual(toPageCount(-3), null);
      assert.strictEqual(toPageCount(999999), null);
      assert.strictEqual(normalizeLanguage('繁體中文'), '');
      assert.strictEqual(normalizeLanguage('/languages/chi'), 'zh');
    }],

    ['新增欄位：書目來源的頁數與語言會覆蓋模型輸出', () => {
      const merged = mergeFields({ page_count: '512', language: 'zh-CN' }, sanitizeFields({ page_count: 100, language: 'en' }));
      assert.strictEqual(merged.page_count, 512);
      assert.strictEqual(merged.language, 'zh-Hans');
    }],

    ['整體流程：回傳整理後的簡介、精度旗標與來源標記', async () => {
      setup();
      h.queueJson({
        fields: {
          title: '挪威的森林',
          subtitle: '村上春樹經典',
          author: '村上春樹',
          publisher: '時報出版',
          publish_date: '2003-08-01',
          publish_date_precision: 'day',
          isbn: '9789573317241',
          description: '<p>本書描述一段青春故事。</p>\n★限時特價 79 折',
          page_count: 384,
          language: 'zh-TW'
        },
        category_id: 3,
        category_confidence: 0.9,
        condition: null,
        price: { original_price: 380, suggested: 180, min: 150, max: 220, reasons: [] },
        sources: [],
        warnings: []
      });

      const data = await listingAssist.assist({ userId: 1, isbn: '', title: '挪威的森林', conditionNote: '', files: [] });
      assert.strictEqual(data.fields.publish_date, '2003-08-01');
      assert.strictEqual(data.fields.publish_date_precision, 'day');
      assert.strictEqual(data.fields.subtitle, '村上春樹經典');
      assert.strictEqual(data.fields.page_count, 384);
      assert.strictEqual(data.fields.language, 'zh-Hant');
      assert.strictEqual(data.fields.description, '本書描述一段青春故事。');
      assert.strictEqual(data.description_source, 'ai');
      assert.strictEqual(data.category.category_id, 3);
    }],

    ['整體流程：精度不到日時加上提醒', async () => {
      setup();
      h.queueJson({
        fields: { title: '挪威的森林', publish_date: '2003年8月', publish_date_precision: 'month', description: '本書描述一段青春故事。' },
        category_id: null,
        condition: null,
        price: null,
        sources: [],
        warnings: []
      });

      const data = await listingAssist.assist({ userId: 1, isbn: '', title: '挪威的森林', conditionNote: '', files: [] });
      assert.strictEqual(data.fields.publish_date, '2003-08');
      assert.strictEqual(data.fields.publish_date_precision, 'month');
      assert.ok(data.warnings.some((w) => w.includes('僅能確認到月或年')));
    }],

    ['整體流程：模型沒給簡介時退回清理過的來源文字', async () => {
      setup({
        lookup: {
          fields: { title: '挪威的森林', description: '<p>來源簡介內容，描述青春故事。</p>', publish_date: 'August 2003' },
          sources: [{ title: 'Open Library', url: 'https://openlibrary.org/isbn/9789573317241' }]
        }
      });
      h.queueJson({
        fields: { title: '挪威的森林', description: '' },
        category_id: null,
        condition: null,
        price: null,
        sources: [],
        warnings: []
      });
      const data = await listingAssist.assist({ userId: 1, isbn: '9789573317241', title: '', conditionNote: '', files: [] });
      assert.strictEqual(data.fields.description, '來源簡介內容，描述青春故事。');
      assert.strictEqual(data.description_source, 'sources');
      assert.strictEqual(data.fields.publish_date_precision, 'month');
    }],

    ['整體流程：來源與模型都有簡介時標記為 mixed', async () => {
      setup({ lookup: { fields: { title: '挪威的森林', description: '書店文案：本書描述青春故事。' }, sources: [] } });
      h.queueJson({
        fields: { title: '挪威的森林', description: '模型整理後的簡介，涵蓋主題與適合的讀者。' },
        category_id: null,
        condition: null,
        price: null,
        sources: [],
        warnings: []
      });
      const data = await listingAssist.assist({ userId: 1, isbn: '9789573317241', title: '', conditionNote: '', files: [] });
      assert.strictEqual(data.fields.description, '模型整理後的簡介，涵蓋主題與適合的讀者。');
      assert.strictEqual(data.description_source, 'mixed');
    }]
  ]
};
