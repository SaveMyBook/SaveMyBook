const assert = require('assert');
const h = require('./harness');

const { request } = h;

const patch = (token, cabinetId, body) =>
  request('PATCH', `/api/admin/cabinets/${cabinetId}/device/settings`, { token, body });

module.exports = {
  name: '書櫃螢幕設定',
  tests: [
    ['管理員調整亮度：裝置下一次 GET /state 取得，後台摘要同步，並記錄管理員操作', async () => {
      const admin = h.addAdmin();
      const token = h.tokenFor(admin);
      const cabinet = h.addCabinet({ name: '公館書櫃' });
      const { token: deviceToken, bootId } = h.addDevice({ cabinetId: cabinet.cabinet_id });

      const before = await h.deviceState(deviceToken, bootId);
      assert.strictEqual(before.status, 200, before.text);
      assert.deepStrictEqual(before.body.data.settings, { screen_brightness: 100 }, '未設定時為 100%');

      const res = await patch(token, cabinet.cabinet_id, { screen_brightness: 60 });
      assert.strictEqual(res.status, 200, res.text);
      assert.deepStrictEqual(res.body.data, { screen_brightness: 60 });
      assert.strictEqual(h.cabinetRow(cabinet.cabinet_id).screen_brightness, 60);
      assert.match(JSON.parse(h.logs().at(-1).detail).summary, /公館書櫃.*100% 調整為 60%/);

      const after = await h.deviceState(deviceToken, bootId);
      assert.deepStrictEqual(after.body.data.settings, { screen_brightness: 60 });
      const summary = await request('GET', `/api/admin/cabinets/${cabinet.cabinet_id}/device`, { token });
      assert.strictEqual(summary.body.data.cabinet.screen_brightness, 60);

      const logCount = h.logs().length;
      assert.strictEqual((await patch(token, cabinet.cabinet_id, { screen_brightness: 60 })).status, 200);
      assert.strictEqual(h.logs().length, logCount, '數值沒變時不重複記錄');
    }],

    ['亮度須為 10 至 100 的整數；設定存於書櫃，尚未配對裝置也能先設定', async () => {
      const token = h.tokenFor(h.addAdmin());
      const cabinet = h.addCabinet();
      for (const bad of [9, 101, 55.5, 'abc', null]) {
        const res = await patch(token, cabinet.cabinet_id, { screen_brightness: bad });
        assert.strictEqual(res.status, 400, `${bad} 應被拒絕`);
      }
      assert.strictEqual(h.cabinetRow(cabinet.cabinet_id).screen_brightness ?? 100, 100, '被拒絕時不改變');
      const res = await patch(token, cabinet.cabinet_id, { screen_brightness: 10 });
      assert.strictEqual(res.status, 200, res.text);
      assert.strictEqual(h.cabinetRow(cabinet.cabinet_id).screen_brightness, 10);
    }],

    ['一般使用者不能調整；書櫃不存在時回 404', async () => {
      const cabinet = h.addCabinet();
      const denied = await patch(h.tokenFor(h.addUser()), cabinet.cabinet_id, { screen_brightness: 50 });
      assert.strictEqual(denied.status, 403);
      const missing = await patch(h.tokenFor(h.addAdmin()), 999999, { screen_brightness: 50 });
      assert.strictEqual(missing.status, 404);
    }]
  ]
};
