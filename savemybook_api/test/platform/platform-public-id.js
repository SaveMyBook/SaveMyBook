const assert = require('assert');
const h = require('./harness');

const publicId = h.api('lib/public-id');

const TYPES = ['transaction', 'log', 'user', 'book', 'order', 'category', 'cabinet', 'report', 'dispute', 'ticket', 'backup'];

// 解碼會把 O 正規化成 0、I／L 正規化成 1，因此前綴含有這些字母的類型無法還原（見測試報告）。
const DECODABLE = TYPES.filter((type) => !/[OIL]/.test(publicId.prefixOf(type)));

module.exports = {
  name: '平台：加密編號',
  tests: [
    ['前綴含 O／I／L 的類型也能解碼（含小寫與易混淆字元）', () => {
      // LG、OD、LD、LV、SL 的前綴本身就有 O／I／L，若把正規化套用到整串會讓前綴永遠比對不到。
      for (const type of ['log', 'order', 'legal', 'level', 'cabinet_slot']) {
        const code = publicId.encode(type, 1234);
        assert.strictEqual(publicId.decode(type, code), 1234, `${type} 原樣解碼`);
        assert.strictEqual(publicId.decode(type, code.toLowerCase()), 1234, `${type} 小寫解碼`);
        assert.strictEqual(publicId.decodeAny(code)?.id, 1234, `${type} decodeAny`);
      }
    }],

    ['編號主體的 O／I／L 會被視為 0／1', () => {
      const code = publicId.encode('order', 777);
      const body = code.slice(2).replace(/0/g, 'O').replace(/1/g, 'I');
      assert.strictEqual(publicId.decode('order', `OD${body}`), 777);
    }],

    ['每個類型都有兩碼前綴，編號固定 9 碼', () => {
      for (const type of TYPES) {
        const code = publicId.encode(type, 1234);
        assert.strictEqual(code.length, 9, `${type} 的編號長度`);
        assert.strictEqual(code.slice(0, 2), publicId.prefixOf(type));
      }
      assert.strictEqual(publicId.prefixOf('沒有這個類型'), 'ID');
    }],

    ['編碼後可以還原回原本的編號', () => {
      for (const type of DECODABLE) {
        for (const id of [0, 1, 2, 42, 65535, 65536, 999999, 4294967295]) {
          assert.strictEqual(publicId.decode(type, publicId.encode(type, id)), id, `${type}/${id}`);
        }
      }
    }],

    ['超出範圍或非整數的編號不會產生代碼', () => {
      assert.strictEqual(publicId.encode('log', -1), null);
      assert.strictEqual(publicId.encode('log', 1.5), null);
      assert.strictEqual(publicId.encode('log', 4294967296), null);
      assert.strictEqual(publicId.encode('log', 'abc'), null);
      assert.strictEqual(publicId.encode('log', undefined), null);
    }],

    ['連號的資料不會產生連號的代碼', () => {
      const codes = [1, 2, 3, 4, 5].map((id) => publicId.encode('log', id));
      assert.strictEqual(new Set(codes).size, 5);
      for (let i = 1; i < codes.length; i += 1) {
        // 相鄰編號的代碼不得只差一個字元，否則等同暴露流水號。
        const differing = [...codes[i]].filter((ch, index) => ch !== codes[i - 1][index]).length;
        assert.ok(differing > 1, `${codes[i - 1]} 與 ${codes[i]} 太相近`);
      }
      assert.ok(!codes.some((code) => /^LG0{5}\d$/.test(code)));
    }],

    ['同一個編號在不同類型下代碼不同，共用前綴的類型才會相同', () => {
      assert.notStrictEqual(publicId.encode('log', 7), publicId.encode('book', 7));
      assert.strictEqual(publicId.encode('user', 7), publicId.encode('member', 7));
      assert.strictEqual(publicId.encode('user', 7), publicId.encode('wallet', 7));
    }],

    ['解碼會忽略大小寫、空白與連字號，並修正易混淆的字元', () => {
      const code = publicId.encode('book', 8888);
      assert.strictEqual(publicId.decode('book', code.toLowerCase()), 8888);
      assert.strictEqual(publicId.decode('book', ` ${code.slice(0, 4)}-${code.slice(4)} `), 8888);

      // 字母表不含 I、L、O、U，輸入時一律視為 1 與 0。
      const confusing = publicId.encode('book', 8888).replace(/0/g, 'O').replace(/1/g, 'L');
      assert.strictEqual(publicId.decode('book', confusing), 8888);
    }],

    ['前綴或長度不符時解不出編號', () => {
      const code = publicId.encode('book', 5);
      assert.strictEqual(publicId.decode('category', code), null);
      assert.strictEqual(publicId.decode('book', `${code}0`), null);
      assert.strictEqual(publicId.decode('book', code.slice(0, -1)), null);
      assert.strictEqual(publicId.decode('book', ''), null);
      assert.strictEqual(publicId.decode('book', null), null);
      assert.strictEqual(publicId.decode('book', 'BK!!!!!!!'), null);
    }],

    ['可由代碼本身判斷類型', () => {
      const code = publicId.encode('dispute', 321);
      assert.deepStrictEqual(publicId.decodeAny(code), { type: 'dispute', prefix: 'DP', id: 321 });
      assert.strictEqual(publicId.decodeAny('ZZ1234567'), null);
      assert.strictEqual(publicId.decodeAny(''), null);
      assert.strictEqual(publicId.decodeAny('BK123'), null);
    }]
  ]
};
