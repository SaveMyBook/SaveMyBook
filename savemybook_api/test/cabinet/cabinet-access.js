const assert = require('assert');
const h = require('./harness');

const { prisma, api, request } = h;
const access = api('services/cabinet-access');

const SECOND = 1000;

const modeOf = async (cabinetId, now = new Date()) => {
  const a = (await access.accessFor([cabinetId], now)).get(cabinetId);
  return [a.mode, a.reason];
};

const rejects = async (promise, status, code) => {
  await assert.rejects(promise, (err) => {
    assert.strictEqual(err.status, status);
    assert.strictEqual(err.code, code);
    return true;
  });
};

module.exports = {
  name: '書櫃存取模式',
  tests: [
    ['沒有裝置為手動；自行解除配對或疑似複製的 120 秒內仍為掃碼', async () => {
      const cabinet = h.addCabinet();
      assert.deepStrictEqual(await modeOf(cabinet.cabinet_id), ['manual', 'no_device']);

      const { device } = h.addDevice({ cabinetId: cabinet.cabinet_id, status: 'revoked' });
      device.revoke_reason = 'cloned';
      device.revoked_at = new Date(Date.now() - 30 * SECOND);
      assert.deepStrictEqual(await modeOf(cabinet.cabinet_id), ['scan', 'no_device']);
      device.revoked_at = new Date(Date.now() - 121 * SECOND);
      assert.deepStrictEqual(await modeOf(cabinet.cabinet_id), ['manual', 'no_device']);

      device.revoke_reason = 'admin';
      device.revoked_at = new Date();
      assert.deepStrictEqual(await modeOf(cabinet.cabinet_id), ['manual', 'no_device'], '管理員撤銷立即回到手動');

      const a = (await access.accessFor([cabinet.cabinet_id])).get(cabinet.cabinet_id);
      assert.strictEqual(a.available_doors, null);
      assert.strictEqual(a.pre_deposit_doors, null);
      assert.strictEqual(a.online, false);
    }],

    ['離線 15 至 120 秒仍為掃碼（不在線），超過 120 秒轉為手動', async () => {
      const cabinet = h.addCabinet();
      const { device } = h.addDevice({ cabinetId: cabinet.cabinet_id });
      let a = (await access.accessFor([cabinet.cabinet_id])).get(cabinet.cabinet_id);
      assert.deepStrictEqual([a.mode, a.reason, a.online], ['scan', null, true]);

      device.last_seen_at = new Date(Date.now() - 20 * SECOND);
      a = (await access.accessFor([cabinet.cabinet_id])).get(cabinet.cabinet_id);
      assert.deepStrictEqual([a.mode, a.reason, a.online], ['scan', null, false]);

      device.last_seen_at = new Date(Date.now() - 121 * SECOND);
      assert.deepStrictEqual(await modeOf(cabinet.cabinet_id), ['manual', 'offline']);
    }],

    ['裝置故障超過 120 秒轉為手動；有裝置時維修中與停用為 unavailable，沒有裝置時維持手動', async () => {
      const cabinet = h.addCabinet();
      const { device } = h.addDevice({ cabinetId: cabinet.cabinet_id });
      device.fault_code = 'POWER';
      device.fault_since = new Date(Date.now() - 60 * SECOND);
      assert.deepStrictEqual(await modeOf(cabinet.cabinet_id), ['scan', null]);
      device.fault_since = new Date(Date.now() - 121 * SECOND);
      assert.deepStrictEqual(await modeOf(cabinet.cabinet_id), ['manual', 'fault']);

      cabinet.is_maintenance = 1;
      assert.deepStrictEqual(await modeOf(cabinet.cabinet_id), ['unavailable', 'maintenance']);
      cabinet.is_maintenance = 0;
      cabinet.is_active = false;
      assert.deepStrictEqual(await modeOf(cabinet.cabinet_id), ['unavailable', 'inactive']);

      const bare = h.addCabinet({ isMaintenance: true });
      assert.deepStrictEqual(await modeOf(bare.cabinet_id), ['manual', 'no_device']);
      const inactive = h.addCabinet({ isActive: false });
      assert.deepStrictEqual(await modeOf(inactive.cabinet_id), ['manual', 'no_device']);
    }],

    ['模擬器關閉時模擬書櫃不算有效裝置', async () => {
      const cabinet = h.addCabinet();
      h.addDevice({ cabinetId: cabinet.cabinet_id, kind: 'simulator' });
      assert.deepStrictEqual(await modeOf(cabinet.cabinet_id), ['scan', null]);
      h.env.cabinetSimulator = false;
      assert.deepStrictEqual(await modeOf(cabinet.cabinet_id), ['manual', 'no_device']);
    }],

    ['可用櫃門數與可先行存書的櫃門數', async () => {
      const cabinet = h.addCabinet({ openTime: '08:00', closeTime: '22:00' });
      h.addDevice({ cabinetId: cabinet.cabinet_id });
      let a = (await access.accessFor([cabinet.cabinet_id])).get(cabinet.cabinet_id);
      assert.strictEqual(a.available_doors, 4);
      assert.strictEqual(a.pre_deposit_doors, 3);
      assert.strictEqual(a.open_time, '08:00');
      assert.strictEqual(a.close_time, '22:00');

      cabinet.available_slots = 1;
      a = (await access.accessFor([cabinet.cabinet_id])).get(cabinet.cabinet_id);
      assert.strictEqual(a.available_doors, 1);
      assert.strictEqual(a.pre_deposit_doors, 0, '只剩 1 扇門時保留給依訂單存書');
    }],

    ['訂單列表與詳情附上 cabinet_access 與 doors（只計訂單的書櫃，依通道排序）', async () => {
      const seller = h.addUser();
      const buyer = h.addUser();
      const cabinet = h.addCabinet();
      const other = h.addCabinet();
      h.addDevice({ cabinetId: cabinet.cabinet_id });
      h.addDevice({ cabinetId: other.cabinet_id });
      const books = [1, 2, 3].map((i) => h.addBook({ sellerId: seller.user_id, title: `書 ${i}`, status: 'sold', cabinet_id: cabinet.cabinet_id }));
      const order = h.addOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: books[0].book_id, cabinetId: cabinet.cabinet_id, status: 'deposited' });
      for (const book of books.slice(1)) {
        prisma.rows('order_items').push({ item_id: prisma.nextId('order_items'), order_id: order.order_id, book_id: book.book_id, quantity: 1, unit_price: 100, subtotal: 100 });
      }
      h.addPlaced(books[0].book_id, h.doorOf(cabinet.cabinet_id, 3).slot_id);
      h.addPlaced(books[1].book_id, h.doorOf(cabinet.cabinet_id, 2).slot_id);
      h.addPlaced(books[2].book_id, h.doorOf(other.cabinet_id, 1).slot_id);
      const plain = h.addOrder({ buyerId: buyer.user_id, sellerId: seller.user_id, bookId: h.addBook({ sellerId: seller.user_id }).book_id });

      const token = h.tokenFor(buyer);
      const list = await request('GET', '/api/orders', { token });
      assert.strictEqual(list.status, 200);
      const byId = new Map(list.body.data.map((o) => [o.order_id, o]));
      const shaped = byId.get(order.order_id);
      assert.deepStrictEqual(shaped.doors, ['A02', 'A03']);
      assert.deepStrictEqual(shaped.cabinet_access, {
        mode: 'scan', reason: null, open_now: true, open_time: null, close_time: null, available_doors: 2, pre_deposit_doors: 1
      });
      assert.strictEqual(byId.get(plain.order_id).cabinet_access, null);
      assert.deepStrictEqual(byId.get(plain.order_id).doors, []);
      assert.strictEqual(list.body.data[0].pickup_code, undefined);

      const detail = await request('GET', `/api/orders/${order.order_id}`, { token });
      assert.deepStrictEqual(detail.body.data.doors, ['A02', 'A03']);
      assert.strictEqual(detail.body.data.cabinet_access.mode, 'scan');
      assert.strictEqual('online' in detail.body.data.cabinet_access, false);

      const queries = prisma.sqlLog.filter((sql) => /smart_cabinets/.test(sql)).length;
      assert.ok(queries <= 2, '存取模式不逐筆查詢');
    }],

    ['手動回報的許可：具書櫃權限且非當事人的管理員永遠放行，其餘依存取模式', async () => {
      const cabinet = h.addCabinet();
      const { device } = h.addDevice({ cabinetId: cabinet.cabinet_id });
      const buyer = h.addUser();
      const seller = h.addUser();
      const staff = h.addAdmin();
      const staffUser = { userId: staff.user_id, role: 'admin' };
      const parties = { buyerId: buyer.user_id, sellerId: seller.user_id };

      assert.deepStrictEqual(await access.assertManualAllowed(null, { userId: buyer.user_id, role: 'buyer_seller' }, parties),
        { reason: null, audited: false });
      assert.deepStrictEqual(await access.assertManualAllowed(cabinet.cabinet_id, staffUser, parties), { reason: null, audited: false });

      await assert.rejects(access.assertManualAllowed(cabinet.cabinet_id, { userId: buyer.user_id, role: 'buyer_seller' }, parties), (err) => {
        assert.strictEqual(err.code, 'CABINET_SCAN_REQUIRED');
        assert.strictEqual(err.status, 409);
        assert.strictEqual(err.message, '此書櫃已啟用掃碼存取，請至書櫃以 App 掃描 QR Code 辦理');
        assert.deepStrictEqual(err.extra, { cabinet_id: cabinet.cabinet_id });
        return true;
      });
      const partyAdmin = h.addAdmin();
      await rejects(access.assertManualAllowed(cabinet.cabinet_id, { userId: partyAdmin.user_id, role: 'admin' },
        { buyerId: partyAdmin.user_id, sellerId: seller.user_id }), 409, 'CABINET_SCAN_REQUIRED');
      const limited = h.addAdmin({ can_manage_cabinets: false });
      await rejects(access.assertManualAllowed(cabinet.cabinet_id, { userId: limited.user_id, role: 'admin' }, parties), 409, 'CABINET_SCAN_REQUIRED');

      device.last_seen_at = new Date(Date.now() - 121 * SECOND);
      assert.deepStrictEqual(await access.assertManualAllowed(cabinet.cabinet_id, { userId: buyer.user_id, role: 'buyer_seller' }, parties),
        { reason: 'offline', audited: true });

      device.last_seen_at = new Date();
      cabinet.is_maintenance = 1;
      await rejects(access.assertManualAllowed(cabinet.cabinet_id, { userId: buyer.user_id }, parties), 409, 'CABINET_MAINTENANCE');
      cabinet.is_maintenance = 0;
      cabinet.is_active = false;
      await rejects(access.assertManualAllowed(cabinet.cabinet_id, { userId: buyer.user_id }, parties), 409, 'CABINET_UNAVAILABLE');

      const fresh = h.addCabinet();
      assert.deepStrictEqual(await access.assertManualAllowed(fresh.cabinet_id, { userId: buyer.user_id }, parties),
        { reason: 'no_device', audited: true }, '從未配對過裝置的書櫃同樣須待客服確認（業主決策）');
      const { device: old } = h.addDevice({ cabinetId: fresh.cabinet_id, status: 'revoked' });
      old.revoked_at = new Date(Date.now() - 3600 * SECOND);
      assert.deepStrictEqual(await access.assertManualAllowed(fresh.cabinet_id, { userId: buyer.user_id }, parties),
        { reason: 'no_device', audited: true }, '曾配對過裝置時同樣待客服確認');
      assert.deepStrictEqual(await access.assertManualAllowed(fresh.cabinet_id, staffUser, parties), { reason: null, audited: false },
        '具書櫃權限且非當事人的管理員不受影響');
    }],

    ['定位距離檢查：門檻、精度與時效、格式錯誤', () => {
      const cabinet = { latitude: 25.0421, longitude: 121.5254 };
      const at = (lat, lng, accuracy = 20, age = 1000) => ({ location_status: 'granted', location: { lat, lng, accuracy_m: accuracy, age_ms: age } });

      const near = access.checkDistance(cabinet, at(25.0425, 121.5254));
      assert.strictEqual(near.ok, true);
      assert.strictEqual(near.status, 'granted');
      assert.ok(near.distance_m > 40 && near.distance_m < 50);
      assert.strictEqual(near.accuracy_m, 20);

      const edge = access.checkDistance(cabinet, at(25.0445, 121.5254, 100));
      assert.strictEqual(edge.ok, true, '距離扣除精度（最多 100 公尺）後未超過 200 公尺');
      const far = access.checkDistance(cabinet, at(25.0521, 121.5254, 30));
      assert.strictEqual(far.ok, false);
      assert.ok(far.distance_m > 1000);

      const coarse = access.checkDistance(cabinet, at(25.0521, 121.5254, 800));
      assert.deepStrictEqual([coarse.ok, coarse.status, coarse.accuracy_m], [true, 'unavailable', 800]);
      assert.ok(coarse.distance_m > 1000, '改記為無法取得定位時仍保存距離');
      const stale = access.checkDistance(cabinet, at(25.0521, 121.5254, 20, 61000));
      assert.deepStrictEqual([stale.ok, stale.status], [true, 'unavailable']);

      assert.deepStrictEqual(access.checkDistance(cabinet, { location_status: 'denied' }),
        { ok: true, status: 'denied', distance_m: null, accuracy_m: null });
      assert.strictEqual(access.checkDistance(cabinet, { location_status: 'unavailable' }).ok, true);

      for (const bad of [
        { location_status: 'granted' },
        at(91, 121),
        at(25, 181),
        at(0, 0),
        at(25, 121, -1),
        at(25, 121, 10, 'soon'),
        { location_status: 'maybe' }
      ]) {
        assert.throws(() => access.checkDistance(cabinet, bad), (err) => err.status === 400 && err.message === '定位資料格式不正確');
      }
    }]
  ]
};
