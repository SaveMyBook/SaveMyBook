const assert = require('assert');
const h = require('./harness');

const { request, tokenFor, addUser, addAdmin, addCabinetAt, buildLayer, status, hits, extra, CENTER } = h;

const nearbyOf = (cabinet, token = tokenFor(addUser())) => request('GET', `/api/cabinets/${cabinet.cabinet_id}/nearby`, { token });

const withClock = async (fn) => {
  const realNow = Date.now;
  const clock = { offset: 0 };
  Date.now = () => realNow() + clock.offset;
  try {
    await fn(clock);
  } finally {
    Date.now = realNow;
  }
};

const tests = [
  ['書櫃附近的捷運、YouBike、停車場與路邊停車一次回傳，並標示資料來源', async () => {
    await buildLayer();
    const res = await nearbyOf(addCabinetAt());
    assert.strictEqual(res.status, 200);
    const { cabinet, mrt, youbike, parking_lots: lots, roadside, attribution, sources } = res.body.data;
    assert.deepStrictEqual(cabinet, { latitude: CENTER.lat, longitude: CENTER.lng });

    // 捷運：最近兩站，各附最近出口與最近的無障礙電梯（Big5 CSV 解碼）
    assert.deepStrictEqual(
      mrt.stations.map((s) => [s.name, s.nearest_exit.exit, s.accessible_exit.exit, s.accessible_exit.facility]),
      [['台電大樓', '3', '5', 'elevator'], ['古亭', '3', '1', 'elevator']]
    );
    assert.strictEqual(mrt.stations[0].distance_m, 382);

    // YouBike：500 公尺內最多 5 站，由近到遠，站名去掉 YouBike2.0_ 前綴，暫停營運的站標示出來
    assert.strictEqual(youbike.stations.length, 5);
    assert.strictEqual(youbike.stations[0].name, '臺灣師範大學(浦城街)');
    assert.deepStrictEqual(youbike.stations.map((s) => s.distance_m), [...youbike.stations.map((s) => s.distance_m)].sort((a, b) => a - b));
    assert.strictEqual(youbike.stations.find((s) => s.name === '臺灣師範大學(圖書館)').is_active, false);
    assert.strictEqual(youbike.updated_at, '2026-10-02T11:50:04.000Z');

    // 停車場：剩餘車位 -9（無此車種）與靜態停車場顯示為 null
    assert.strictEqual(lots.lots.length, 5);
    assert.deepStrictEqual(lots.lots[0].car, { total: 18, available: 0 });
    assert.deepStrictEqual(lots.lots[0].motorcycle, { total: 0, available: null });
    assert.strictEqual(lots.lots.find((p) => p.name === '泰順街停車場').car.available, null);
    assert.strictEqual(lots.updated_at, '2026-10-02T11:47:00.000Z');

    // 路邊汽車格依路段編號對上即時空位；沒有即時空位的路段 available 為 null
    const [first, second, third] = roadside.car;
    assert.deepStrictEqual(
      [first.name, first.segment_id, first.distance_m, first.spaces_nearby, first.accessible_nearby],
      ['師大路C', '30540C0', 28, 13, 4]
    );
    assert.deepStrictEqual(first.live, { total: 3, available: 1, fee: '40元', start: '07:00', end: '20:00', updated_at: '2026-10-02T11:45:10.000Z' });
    assert.strictEqual(second.name, '龍泉街');
    assert.strictEqual(second.live.available, 4);
    assert.strictEqual(third.live.available, null);
    assert.ok(roadside.car.length <= 5 && roadside.motorcycle.length <= 5);
    assert.strictEqual(roadside.layer_updated_at, '2026-08-27T09:32:00.000Z');

    // 機車格依路名分組，同名不重複；沒有路名的格位歸到附近有路名的路段
    const names = roadside.motorcycle.map((m) => m.name);
    assert.strictEqual(new Set(names).size, names.length);
    assert.ok(!names.includes('路名未標示'), names.join('、'));
    assert.ok(roadside.motorcycle.some((m) => m.has_parking_area));

    assert.match(attribution, /臺北市資料大平臺/);
    assert.strictEqual(sources.length, 12);
    assert.ok(sources.every((s) => s.url.startsWith('https://data.taipei/dataset/detail?id=')));
  }],

  ['即時資料在快取期限內不重複抓取，過期後只重新抓即時來源', async () => {
    await buildLayer();
    const cabinet = addCabinetAt();
    await withClock(async (clock) => {
      await nearbyOf(cabinet);
      await nearbyOf(cabinet);
      const keys = ['youbike', 'parkingAvailability', 'roadsideUsage', 'busEstimates', 'roadSpeed', 'parkingLots', 'mrtExits', 'busStops', 'busRoutes', 'taxiStands'];
      assert.deepStrictEqual(keys.map((k) => hits[k]), [1, 1, 1, 1, 1, 1, 1, 1, 1, 1]);

      clock.offset = 6 * 60 * 1000;
      await nearbyOf(cabinet);
      assert.deepStrictEqual(keys.map((k) => hits[k]), [2, 2, 2, 2, 2, 1, 1, 1, 1, 1]);
    });
  }],

  ['單一來源故障只影響該區塊；曾成功過的來源沿用上一份資料', async () => {
    await buildLayer();
    const cabinet = addCabinetAt();

    status.youbike = 500;
    const failed = await nearbyOf(cabinet);
    assert.strictEqual(failed.status, 200);
    assert.deepStrictEqual(failed.body.data.youbike, { status: 'unavailable', stations: [], updated_at: null });
    assert.strictEqual(failed.body.data.mrt.status, 'ok');
    assert.strictEqual(failed.body.data.parking_lots.status, 'ok');

    // 失敗後一分鐘內不再重試，避免每個請求都卡在來源逾時
    await nearbyOf(cabinet);
    assert.strictEqual(hits.youbike, 1);

    await withClock(async (clock) => {
      delete status.youbike;
      clock.offset = 2 * 60 * 1000;
      assert.strictEqual((await nearbyOf(cabinet)).body.data.youbike.stations.length, 5);

      status.youbike = 503;
      clock.offset = 4 * 60 * 1000;
      const stale = await nearbyOf(cabinet);
      assert.strictEqual(stale.body.data.youbike.status, 'ok');
      assert.strictEqual(stale.body.data.youbike.stations.length, 5);
    });
  }],

  ['停車場即時剩餘車位故障時仍列出停車場，剩餘車位為 null', async () => {
    status.parkingAvailability = 500;
    const res = await nearbyOf(addCabinetAt());
    const { parking_lots: lots } = res.body.data;
    assert.strictEqual(lots.status, 'ok');
    assert.strictEqual(lots.realtime_available, false);
    assert.ok(lots.lots.every((p) => p.car.available === null));
  }],

  ['格位索引尚未建立時路邊停車標示為無法取得；建立後寫入檔案，30 天內不重新下載', async () => {
    const cabinet = addCabinetAt();
    const before = await nearbyOf(cabinet);
    assert.strictEqual(before.body.data.roadside.status, 'unavailable');
    assert.strictEqual(hits.roadsideSpaces, undefined);

    assert.ok((await buildLayer()) > 1000);
    assert.ok(require('fs').existsSync(h.indexFile));
    assert.strictEqual(await buildLayer(), 0);
    assert.strictEqual(hits.roadsideSpaces, 1);

    // 伺服器重新啟動後從檔案載入，不必重新下載
    h.transit.reset();
    const after = await nearbyOf(cabinet);
    assert.strictEqual(after.body.data.roadside.status, 'ok');
    assert.strictEqual(after.body.data.roadside.car[0].name, '師大路C');
    assert.strictEqual(hits.roadsideSpaces, 1);
  }],

  ['格位索引超過 30 天時重新下載；下載失敗時保留原本的索引', async () => {
    await buildLayer();
    await withClock(async (clock) => {
      clock.offset = 31 * 24 * 60 * 60 * 1000;
      status.roadsideSpaces = 500;
      await assert.rejects(buildLayer(), /HTTP 500/);
      assert.strictEqual(hits.roadsideSpaces, 2);
      const res = await nearbyOf(addCabinetAt());
      assert.strictEqual(res.body.data.roadside.status, 'ok');

      delete status.roadsideSpaces;
      assert.ok((await buildLayer()) > 1000);
      assert.strictEqual(hits.roadsideSpaces, 3);
    });
  }],

  ['資源編號更換時，依資料集的資源清單改抓新的檔案', async () => {
    const rid = 'new-fares-resource';
    status.mrtFares = 404;
    extra.set(`${h.PORTAL}/api/frontstage/tpeod/dataset.view?id=4acb4911`, () => new Response(JSON.stringify({
      payload: { resources: [{ rid: 'pdf-1', file_format: 'PDF' }, { rid, file_format: 'CSV' }] }
    }), { headers: { 'content-type': 'application/json' } }));
    extra.set(`${h.PORTAL}/api/dataset/4acb4911-0360-4063-808d-fcee629508b3/resource/${rid}/download`, () => new Response(h.fixture('mrt-fares.csv')));

    const res = await request('GET', '/api/cabinets/mrt-fares?from=古亭&to=台電大樓', { token: tokenFor(addUser()) });
    assert.strictEqual(res.status, 200, res.text);
    assert.deepStrictEqual(res.body.data.fares, [{ from: '古亭', to: '台電大樓', fare: 20, concession_fare: 8, distance_km: 0.88 }]);
  }],

  ['捷運車站清單附座標，臺北車站 M1–M8 出口合併為一站', async () => {
    const res = await request('GET', '/api/cabinets/mrt-stations', { token: tokenFor(addUser()) });
    assert.strictEqual(res.status, 200);
    const names = res.body.data.stations.map((s) => s.name);
    assert.deepStrictEqual([...names].sort(), ['古亭', '台北車站', '台電大樓', '忠孝復興', '木柵', '科技大樓'].sort());
    const main = res.body.data.stations.find((s) => s.name === '台北車站');
    assert.ok(Math.abs(main.latitude - 25.0468) < 0.001 && Math.abs(main.longitude - 121.5177) < 0.001);
  }],

  ['票價：多個訖站一次查詢；起站不存在、缺少參數或訖站過多時拒絕', async () => {
    const token = tokenFor(addUser());
    const ok = await request('GET', `/api/cabinets/mrt-fares?from=${encodeURIComponent('台北車站')}&to=${encodeURIComponent('台電大樓,科技大樓')}`, { token });
    assert.strictEqual(ok.status, 200);
    assert.deepStrictEqual(ok.body.data.fares.map((f) => [f.to, f.fare, f.concession_fare]), [['台電大樓', 20, 8], ['科技大樓', 20, 8]]);

    const unknown = await request('GET', '/api/cabinets/mrt-fares?from=不存在&to=古亭', { token });
    assert.deepStrictEqual([unknown.status, unknown.body.message], [400, '查無此捷運站']);
    const missing = await request('GET', '/api/cabinets/mrt-fares?from=古亭', { token });
    assert.deepStrictEqual([missing.status, missing.body.message], [400, '請提供起站與訖站']);
    const many = await request('GET', '/api/cabinets/mrt-fares?from=古亭&to=a,b,c,d', { token });
    assert.deepStrictEqual([many.status, many.body.message], [400, '訖站最多 3 站']);
  }],

  ['捷運資料無法取得時回傳 503', async () => {
    status.mrtExits = 500;
    const res = await request('GET', '/api/cabinets/mrt-stations', { token: tokenFor(addUser()) });
    assert.deepStrictEqual([res.status, res.body.code], [503, 'TRANSIT_UNAVAILABLE']);
  }],

  ['未登入或書櫃不存在時拒絕', async () => {
    const cabinet = addCabinetAt();
    assert.strictEqual((await request('GET', `/api/cabinets/${cabinet.cabinet_id}/nearby`)).status, 401);
    const missing = await request('GET', '/api/cabinets/999/nearby', { token: tokenFor(addUser()) });
    assert.deepStrictEqual([missing.status, missing.body.message], [404, '找不到此書櫃']);
    assert.strictEqual((await request('GET', '/api/cabinets/mrt-stations')).status, 401);
  }],

  ['新增書櫃的附近交通預覽：需書櫃管理權限並檢查座標', async () => {
    await buildLayer();
    const url = `/api/admin/cabinets/nearby-preview?lat=${CENTER.lat}&lng=${CENTER.lng}`;
    const ok = await request('GET', url, { token: tokenFor(addAdmin()) });
    assert.strictEqual(ok.status, 200);
    assert.strictEqual(ok.body.data.roadside.car[0].name, '師大路C');
    assert.strictEqual(ok.body.data.mrt.stations[0].name, '台電大樓');

    const denied = await request('GET', url, { token: tokenFor(addAdmin({ can_manage_cabinets: false })) });
    assert.strictEqual(denied.status, 403);
    const user = await request('GET', url, { token: tokenFor(addUser()) });
    assert.strictEqual(user.status, 403);

    const token = tokenFor(addAdmin());
    const zero = await request('GET', '/api/admin/cabinets/nearby-preview?lat=0&lng=0', { token });
    assert.deepStrictEqual([zero.status, zero.body.message], [400, '座標不正確']);
    const bad = await request('GET', '/api/admin/cabinets/nearby-preview?lat=abc&lng=121.5', { token });
    assert.deepStrictEqual([bad.status, bad.body.message], [400, '緯度格式不正確']);
  }],

  ['公車：300 公尺內的站位依距離排序，路線附名稱、方向與到站狀態', async () => {
    const res = await nearbyOf(addCabinetAt());
    const { bus } = res.body.data;
    assert.strictEqual(bus.status, 'ok');
    assert.strictEqual(bus.realtime_available, true);
    assert.strictEqual(bus.updated_at, '2026-10-02T13:02:00.000Z');
    assert.deepStrictEqual(bus.stops.map((s) => [s.name, s.distance_m]), [['師大路', 162], ['師大', 173], ['師大綜合大樓', 238], ['師大', 242]]);
    assert.strictEqual(bus.stops[2].address, '和平東路一段184號同向(向東)');

    const routes = bus.stops[2].routes;
    assert.deepStrictEqual(routes[0], { name: '復興幹線', direction: '建北站', status: 'minutes', minutes: 1 });
    assert.ok(routes.some((r) => r.name === '235' && r.direction === '交通部觀光署'));
    // 有到站時間的排前面並依分鐘數排序，接著尚未發車，最後是末班已過
    const order = { arriving: 0, minutes: 1, not_departed: 2, unknown: 3, not_stopping: 4, last_passed: 5, no_service: 6 };
    for (let i = 1; i < routes.length; i += 1) {
      const [a, b] = [routes[i - 1], routes[i]];
      assert.ok(order[a.status] < order[b.status] || (order[a.status] === order[b.status] && (a.minutes ?? 0) <= (b.minutes ?? 0)), `${a.name} 應排在 ${b.name} 之前`);
    }
    assert.strictEqual(new Set(routes.map((r) => `${r.name}|${r.direction}`)).size, routes.length, '同一路線同方向只列一次');
  }],

  ['公車到站秒數與狀態碼的換算', async () => {
    const { arrival } = h.api('services/transit/bus');
    assert.deepStrictEqual(arrival(30), { status: 'arriving', minutes: 0 });
    assert.deepStrictEqual(arrival(125), { status: 'minutes', minutes: 2 });
    assert.deepStrictEqual(arrival(-1), { status: 'not_departed', minutes: null });
    assert.deepStrictEqual(arrival(-2), { status: 'not_stopping', minutes: null });
    assert.deepStrictEqual(arrival(-3), { status: 'last_passed', minutes: null });
    assert.deepStrictEqual(arrival(-4), { status: 'no_service', minutes: null });
    assert.deepStrictEqual(arrival(undefined), { status: 'unknown', minutes: null });
  }],

  ['公車預估到站故障時仍列出站牌與路線，狀態為未知；站牌資料故障時公車區塊無法取得', async () => {
    const cabinet = addCabinetAt();
    status.busEstimates = 500;
    const stale = (await nearbyOf(cabinet)).body.data.bus;
    assert.strictEqual(stale.realtime_available, false);
    assert.ok(stale.stops.length > 0);
    assert.ok(stale.stops.every((s) => s.routes.every((r) => r.status === 'unknown')));

    h.transit.reset();
    status.busStops = 500;
    const res = await nearbyOf(cabinet);
    assert.deepStrictEqual(res.body.data.bus, { status: 'unavailable', stops: [], updated_at: null, realtime_available: false });
    assert.strictEqual(res.body.data.mrt.status, 'ok');
  }],

  ['只有一個出口的車站：出口以 null 表示，無障礙設施為坡道', async () => {
    const res = await nearbyOf(addCabinetAt({ lat: 24.9982, lng: 121.5733 }));
    const [station] = res.body.data.mrt.stations;
    assert.strictEqual(station.name, '木柵');
    assert.strictEqual(station.nearest_exit.exit, null);
    assert.deepStrictEqual([station.accessible_exit.facility, station.accessible_exit.exit], ['ramp', null]);
  }],

  ['無障礙設施資料無法取得時，退回出入口資料的無障礙標示', async () => {
    status.mrtAccessibility = 500;
    const [station] = (await nearbyOf(addCabinetAt())).body.data.mrt.stations;
    assert.deepStrictEqual([station.accessible_exit.exit, station.accessible_exit.facility], ['5', null]);
  }],

  ['周邊路況：600 公尺內最多 3 段，壅塞等級對應順暢、車多、壅塞', async () => {
    const { road_speed: speed } = (await nearbyOf(addCabinetAt())).body.data;
    assert.strictEqual(speed.status, 'ok');
    assert.deepStrictEqual(
      speed.sections.map((s) => [s.road, s.between, s.speed_kph, s.level, s.distance_m]),
      [['和平西路', '重慶南路-羅斯福路', 36, 'busy', 290], ['羅斯福路', '和平東路-辛亥路', 56, 'smooth', 367], ['和平東路', '羅斯福路-師大路', 39, 'busy', 430]]
    );
    const { parseSpeeds } = h.api('services/transit/road');
    const xml = (level, speed) => `<vd:SectionData><vd:SectionName>測試路  甲-乙</vd:SectionName><vd:AvgSpd>${speed}</vd:AvgSpd>`
      + `<vd:MOELevel>${level}</vd:MOELevel><vd:StartWgsX>121.5</vd:StartWgsX><vd:StartWgsY>25.0</vd:StartWgsY>`
      + '<vd:EndWgsX>121.51</vd:EndWgsX><vd:EndWgsY>25.01</vd:EndWgsY></vd:SectionData>';
    const parsed = parseSpeeds(xml(2, 12.4) + xml(-1, -1) + xml(0, -1));
    assert.deepStrictEqual(parsed.sections.map((s) => [s.road, s.between, s.speed, s.level]), [['測試路', '甲-乙', 12, 'congested']]);
  }],

  ['計程車招呼站：800 公尺內最多 3 處，附排班格位與時間；範圍內沒有時為空清單', async () => {
    assert.deepStrictEqual((await nearbyOf(addCabinetAt())).body.data.taxi_stands.stands, []);
    const res = await nearbyOf(addCabinetAt({ lat: 25.0335, lng: 121.5355 }));
    assert.deepStrictEqual(
      res.body.data.taxi_stands.stands.map((s) => [s.name, s.street, s.spaces, s.hours, s.distance_m]),
      [['經濟部工業局', '信義路3段41-3號', 2, '0~24', 33], ['大安森林公園北側', '信義路3段', 4, '0~24', 97], ['芙蓉大廈', '仁愛路3段136號', 2, '週一至週五8~19', 730]]
    );
  }],

  ['TWD97 座標換算：中央經線換算為東經 121 度，停車場位置與其入口座標相距在合理範圍', async () => {
    const { toWgs84 } = h.api('lib/twd97');
    const { distanceMeters } = h.api('lib/geo');
    const meridian = toWgs84(250000, 2768000);
    assert.ok(Math.abs(meridian.lng - 121) < 1e-9);
    assert.ok(Math.abs(meridian.lat - 25.02) < 0.01);

    const lot = JSON.parse(h.fixture('parking-lots.json')).data.park.find((p) => p.id === 'TPE0001');
    const pos = toWgs84(Number(lot.tw97x), Number(lot.tw97y));
    const [entrance] = lot.EntranceCoord.EntrancecoordInfo;
    assert.ok(distanceMeters(pos.lat, pos.lng, Number(entrance.Xcod), Number(entrance.Ycod)) < 60);
  }],

  ['臺北市以外的書櫃：YouBike、停車場與路邊停車為空清單，捷運仍列出最近的車站', async () => {
    await buildLayer();
    const res = await nearbyOf(addCabinetAt({ lat: 25.0143, lng: 121.4627 }));
    const { mrt, youbike, parking_lots: lots, roadside } = res.body.data;
    assert.deepStrictEqual([youbike.stations, lots.lots, roadside.car, roadside.motorcycle], [[], [], [], []]);
    assert.strictEqual(mrt.stations.length, 1);
    assert.ok(mrt.stations[0].distance_m > 1500);
  }]
];

module.exports = { name: '書櫃交通資訊', tests };
