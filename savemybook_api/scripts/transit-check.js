#!/usr/bin/env node
// 實際連線 data.taipei，確認各資料集仍能下載與解析，並印出指定座標附近的交通資訊摘要。
// 用法：node scripts/transit-check.js [緯度 經度]
//       加上 --layer 會重新下載路邊停車格位圖層（約 56MB）並重建索引。
const transit = require('../services/transit');
const roadside = require('../services/transit/roadside');

const args = process.argv.slice(2);
const coords = args.filter((a) => !a.startsWith('--')).map(Number);
const [lat, lng] = coords.length === 2 ? coords : [25.0245, 121.5288];

(async () => {
  if (args.includes('--layer')) {
    const started = Date.now();
    const spaces = await roadside.rebuildLayer();
    console.log(`格位索引：${spaces} 格，耗時 ${((Date.now() - started) / 1000).toFixed(1)} 秒`);
  }

  const stations = await transit.stations();
  console.log(`捷運車站：${stations ? stations.stations.length : '無法取得'}`);

  const data = await transit.nearby(lat, lng);
  console.log(`\n座標 ${lat}, ${lng}`);
  for (const s of data.mrt.stations) {
    console.log(`  捷運 ${s.name}：${s.distance_m} 公尺，最近出口 ${s.nearest_exit.exit}${s.accessible_exit ? `，無障礙出口 ${s.accessible_exit.exit}` : ''}`);
  }
  if (stations && data.mrt.stations[0]) {
    const fare = await transit.fares('台北車站', [data.mrt.stations[0].name]);
    const f = fare?.fares?.[0];
    if (f) console.log(`  票價 台北車站→${f.to}：${f.fare} 元，敬老愛心兒童 ${f.concession_fare} 元，${f.distance_km} 公里`);
  }
  for (const s of data.bus.stops) {
    console.log(`  公車 ${s.name}（${s.distance_m} 公尺）：${s.routes.slice(0, 4).map((r) => `${r.name} 往${r.direction} ${r.status === 'minutes' ? `${r.minutes} 分` : r.status}`).join('、')}`);
  }
  console.log(`  路況：${data.road_speed.sections.map((s) => `${s.road}（${s.between}）${s.speed_kph} 公里 ${s.level}`).join('、') || '無'}`);
  console.log(`  計程車招呼站：${data.taxi_stands.stands.map((s) => `${s.name} ${s.distance_m}m`).join('、') || '無'}`);
  console.log(`  YouBike（${data.youbike.status}）：${data.youbike.stations.map((s) => `${s.name} 借${s.available_rent}/還${s.available_return}`).join('、') || '無'}`);
  console.log(`  停車場（${data.parking_lots.status}）：${data.parking_lots.lots.map((p) => `${p.name} ${p.distance_m}m 汽車${p.car.available ?? '-'}/${p.car.total}`).join('、') || '無'}`);
  console.log(`  路邊汽車（${data.roadside.status}）：${data.roadside.car.map((s) => `${s.name} ${s.distance_m}m ${s.spaces_nearby}格${s.live?.available != null ? ` 空${s.live.available}` : ''}`).join('、') || '無'}`);
  console.log(`  路邊機車：${data.roadside.motorcycle.map((s) => `${s.name} ${s.distance_m}m ${s.spaces_nearby}格`).join('、') || '無'}`);
  process.exit(0);
})().catch((err) => {
  console.error(err);
  process.exit(1);
});
