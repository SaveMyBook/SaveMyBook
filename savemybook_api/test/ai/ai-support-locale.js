const assert = require('assert');
const fs = require('fs');
const path = require('path');
const h = require('./harness');

const locale = h.api('services/ai/locale');
const support = h.api('services/ai/support');

const ARB_DIR = path.join(h.API_ROOT, '..', 'savemybook_app', 'lib', 'i18n');
const ARB_FILES = { 'zh-Hant': 'app_zh_Hant.arb', 'zh-Hans': 'app_zh_Hans.arb', en: 'app_en.arb', ja: 'app_ja.arb', ko: 'app_ko.arb' };

module.exports = {
  name: 'AI 客服語系',
  tests: [
    ['語系白名單：只接受 App 支援的五種介面語系', () => {
      const cases = [
        ['zh-Hant', 'zh-Hant'], ['zh_Hant', 'zh-Hant'], ['ZH-HANT', 'zh-Hant'], [' zh_hans ', 'zh-Hans'],
        ['en', 'en'], ['EN', 'en'], ['ja', 'ja'], ['ko', 'ko'],
        ['zh', null], ['zh-TW', null], ['en-US', null], ['fr', null], ['', null], [null, null], [undefined, null], [3, null], [['en'], null]
      ];
      for (const [input, expected] of cases) assert.strictEqual(locale.normalize(input), expected, String(input));
      assert.strictEqual(locale.resolve('fr'), 'zh-Hant');
    }],

    ['提示詞：非繁體中文介面附上 App 的功能名稱對照，繁體中文不附', () => {
      assert.strictEqual(locale.promptSection(null), '【回覆語言】繁體中文');
      const ko = locale.promptSection('ko');
      assert.ok(ko.startsWith('【回覆語言】한국어\n\n【介面用語】\n'));
      assert.strictEqual(ko.split('\n').filter((l) => l.includes(' → ')).length, locale.APP_TERMS.length);
      assert.match(ko, /^轉接客服人員 → 상담원 연결$/m);
      for (const tag of Object.keys(locale.LANGUAGES)) assert.ok(locale.GUARDED_REPLIES[tag], tag);
    }],

    ['簡體中文回覆：建議轉接的句型強制附上轉接卡，參考資料字樣一併清理', () => {
      for (const reply of ['建议您联系客服人员确认。', '请联系客服人员协助处理。', '可由客服人员协助处理。', locale.GUARDED_REPLIES['zh-Hans']]) {
        assert.deepStrictEqual(support.handoffReasons({ question: '订单问题', reply }), ['reply'], reply);
      }
      assert.deepStrictEqual(support.handoffReasons({ question: '订单问题', reply: '客服人员回复后会通知您。' }), []);
      assert.deepStrictEqual(support.handoffReasons({ question: '订单问题', reply: '无需联系客服即可完成。' }), []);
      assert.strictEqual(support.stripReferences('根据参考资料，取书期限为 3 天（详见参考资料）。另请参阅参考资料。'), '取书期限为 3 天。另请参阅平台说明。');
      assert.deepStrictEqual(support.followUpsOf(['参考资料里怎么说？', '取书期限是几天？']), ['取书期限是几天？']);
    }],

    ['提問端：簡體中文、日文與韓文的轉接要求與儲值、提領問題同樣強制轉接', () => {
      const reasons = (question) => support.handoffReasons({ question, reply: '好的' });
      for (const q of ['我要转人工', '客服人员在吗', 'オペレーターと話したい', 'サポート担当者につないでください', '상담원 연결해주세요']) {
        assert.deepStrictEqual(reasons(q), ['agent'], q);
      }
      for (const q of ['怎么提现？', '储值方式', 'チャージ方法を教えて', '出金したい', '충전 방법', '출금하고 싶어요']) {
        assert.deepStrictEqual(reasons(q), ['wallet'], q);
      }
      assert.deepStrictEqual(reasons('从书柜领出书'), []);
      assert.strictEqual(support.ticketCategoryOf(['App 一直闪退']), 'bug');
    }],

    ['功能名稱對照與 App 的翻譯檔一致', () => {
      if (!fs.existsSync(ARB_DIR)) return;
      const arb = Object.fromEntries(Object.entries(ARB_FILES).map(([tag, file]) => [tag, JSON.parse(fs.readFileSync(path.join(ARB_DIR, file), 'utf8'))]));
      for (const [key, zh, names] of locale.APP_TERMS) {
        assert.strictEqual(arb['zh-Hant'][key], zh, key);
        for (const tag of ['zh-Hans', 'en', 'ja', 'ko']) assert.strictEqual(names[tag], arb[tag][key], `${key}（${tag}）`);
      }
    }]
  ]
};
