const assert = require('assert');
const h = require('./harness');

const v = h.api('lib/validate');
const password = h.api('lib/password');
const { clip } = h.api('lib/text');
const { escapeHtml } = h.api('lib/html');

const badRequest = (message) => (err) => err.status === 400 && err.message === message;

module.exports = {
  name: '平台：輸入驗證',
  tests: [
    ['編號必須是 1 到 32 位元正整數', () => {
      assert.strictEqual(v.id('42'), 42);
      assert.strictEqual(v.id(42), 42);
      for (const value of [0, -1, '1.5', 'abc', '', null, undefined, 2147483648]) {
        assert.throws(() => v.id(value, '會員編號'), badRequest('會員編號不正確'), String(value));
      }
    }],

    ['選填編號允許空值', () => {
      assert.strictEqual(v.optionalId(undefined, '分類編號'), null);
      assert.strictEqual(v.optionalId('', '分類編號'), null);
      assert.strictEqual(v.optionalId('null', '分類編號'), null);
      assert.strictEqual(v.optionalId('7', '分類編號'), 7);
      assert.throws(() => v.optionalId('0', '分類編號'), badRequest('分類編號不正確'));
    }],

    ['整數與數值的範圍檢查各有訊息', () => {
      assert.strictEqual(v.int('5', { min: 0, max: 10 }), 5);
      assert.throws(() => v.int('11', { label: '排序', min: 0, max: 10 }), badRequest('排序必須是 0 ~ 10 之間的整數'));
      assert.throws(() => v.int('2.5', { label: '排序', min: 0, max: 10 }), badRequest('排序必須是 0 ~ 10 之間的整數'));

      assert.strictEqual(v.number('12.5', { min: 0 }), 12.5);
      assert.throws(() => v.number('abc', { label: '金額' }), badRequest('金額格式不正確'));
      assert.throws(() => v.number(Infinity, { label: '金額' }), badRequest('金額格式不正確'));
      assert.throws(() => v.number(-1, { label: '金額', min: 0 }), badRequest('金額格式不正確'));
    }],

    ['文字會去除前後空白並限制長度', () => {
      assert.strictEqual(v.text('  你好  '), '你好');
      assert.strictEqual(v.text(123), '123');
      assert.strictEqual(v.text(undefined), '');
      assert.strictEqual(v.text(null), '');
      assert.throws(() => v.text('12345', { label: '暱稱', max: 4 }), badRequest('暱稱不可超過 4 個字'));

      assert.strictEqual(v.optionalText(undefined, {}), undefined);
      assert.strictEqual(v.optionalText('   ', {}), null);
      assert.strictEqual(v.optionalText(' 內容 ', {}), '內容');
    }],

    ['列舉值與布林值', () => {
      assert.strictEqual(v.oneOf('ios', ['ios', 'android']), 'ios');
      assert.throws(() => v.oneOf('web', ['ios', 'android']), badRequest('僅接受：ios, android'));
      assert.throws(() => v.oneOf('web', ['ios'], '不支援的平台'), badRequest('不支援的平台'));

      assert.strictEqual(v.bool(true), true);
      assert.strictEqual(v.bool('true'), true);
      assert.strictEqual(v.bool(1), true);
      assert.strictEqual(v.bool('1'), true);
      assert.strictEqual(v.bool('yes'), false);
      assert.strictEqual(v.bool(undefined), false);
    }],

    ['日期允許空值，格式錯誤時回報欄位名稱', () => {
      assert.strictEqual(v.date(''), null);
      assert.strictEqual(v.date('null'), null);
      assert.strictEqual(v.date('2003-08-01').toISOString().slice(0, 10), '2003-08-01');
      assert.throws(() => v.date('不是日期', '生日'), badRequest('生日格式不正確'));
    }],

    ['分頁參數會被夾在合理範圍內', () => {
      assert.deepStrictEqual(v.pagination({}), { page: 1, limit: 20, skip: 0 });
      assert.deepStrictEqual(v.pagination({ page: '3', limit: '10' }), { page: 3, limit: 10, skip: 20 });
      assert.deepStrictEqual(v.pagination({ page: '0', limit: '0' }), { page: 1, limit: 20, skip: 0 });
      assert.deepStrictEqual(v.pagination({ limit: '500' }), { page: 1, limit: 100, skip: 0 });
      assert.deepStrictEqual(v.pagination({ limit: '500' }, { max: 30, limit: 5 }), { page: 1, limit: 30, skip: 0 });
      assert.deepStrictEqual(v.pagination({ page: '999999' }).page, 100000);
      assert.deepStrictEqual(v.pageMeta(45, { page: 2, limit: 20 }), { total: 45, page: 2, limit: 20, total_pages: 3 });
    }],

    ['佐證連結只接受站內上傳或 http(s) 網址', () => {
      assert.strictEqual(v.evidenceUrls(''), null);
      assert.strictEqual(v.evidenceUrls(['/uploads/a.jpg', 'https://example.test/b.png']), '/uploads/a.jpg,https://example.test/b.png');
      assert.strictEqual(v.evidenceUrls('/uploads/a.jpg, /uploads/b.jpg'), '/uploads/a.jpg,/uploads/b.jpg');
      assert.throws(() => v.evidenceUrls(['/uploads/../../etc/passwd']), badRequest('佐證連結格式不正確'));
      assert.throws(() => v.evidenceUrls(['javascript:alert(1)']), badRequest('佐證連結格式不正確'));
      assert.throws(() => v.evidenceUrls([`https://example.test/${'a'.repeat(500)}`]), badRequest('佐證連結格式不正確'));
      assert.throws(() => v.evidenceUrls(new Array(11).fill('/uploads/a.jpg')), badRequest('佐證資料最多 10 筆'));
    }],

    ['排序清單必須是不重複的正整數', () => {
      assert.deepStrictEqual(v.sortOrder([3, '1', 2], '請提供順序'), [3, 1, 2]);
      assert.throws(() => v.sortOrder([], '請提供順序'), badRequest('請提供順序'));
      assert.throws(() => v.sortOrder('3,1', '請提供順序'), badRequest('請提供順序'));
      assert.throws(() => v.sortOrder([1, 1], '請提供順序'), badRequest('排序資料格式不正確'));
      assert.throws(() => v.sortOrder([1, 'x'], '請提供順序'), badRequest('排序資料格式不正確'));
      assert.throws(() => v.sortOrder(new Array(1001).fill(1), '請提供順序'), badRequest('排序資料過多'));
    }],

    ['密碼規則：長度、字元集與組成', () => {
      password.assertPolicy('Passw0rd');
      assert.throws(() => password.assertPolicy('Pw0rd', '新密碼'), badRequest('新密碼長度至少 8 個字元'));
      assert.throws(() => password.assertPolicy(12345678), badRequest('密碼長度至少 8 個字元'));
      assert.throws(() => password.assertPolicy('密碼密碼密碼密碼'), badRequest('密碼僅可使用英文字母、數字及半形符號'));
      assert.throws(() => password.assertPolicy('abcdefgh'), badRequest('密碼必須包含數字'));
      assert.throws(() => password.assertPolicy('12345678'), badRequest('密碼必須包含英文字母'));
      assert.throws(() => password.assertPolicy(`${'a1'.repeat(37)}`), badRequest('密碼長度過長'));
    }],

    ['臨時密碼一定符合密碼規則且每次不同', () => {
      const first = password.temporary();
      password.assertPolicy(first);
      assert.strictEqual(first.length, 14);
      assert.notStrictEqual(first, password.temporary());
    }],

    ['密碼比對不會因為非字串而拋錯', async () => {
      const hashed = await password.hash('Passw0rd123');
      assert.strictEqual(await password.verify('Passw0rd123', hashed), true);
      assert.strictEqual(await password.verify('wrong', hashed), false);
      assert.strictEqual(await password.verify(null, hashed), false);
      assert.strictEqual(await password.verify('Passw0rd123', null), false);
      assert.strictEqual(await password.verify('Passw0rd123', '不是雜湊'), false);
    }],

    ['文字截斷與 HTML 逸出', () => {
      assert.strictEqual(clip('一二三四五', 3), '一二…');
      assert.strictEqual(clip('一二三', 3), '一二三');
      assert.strictEqual(escapeHtml('<script>"x" & \'y\'</script>'), '&lt;script&gt;&quot;x&quot; &amp; &#39;y&#39;&lt;/script&gt;');
      assert.strictEqual(escapeHtml(null), '');
    }]
  ]
};
