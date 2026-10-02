const fs = require('fs');
const os = require('os');
const path = require('path');

process.env.TRANSIT_DATA_DIR = fs.mkdtempSync(path.join(os.tmpdir(), 'smb-transit-'));

const h = require('../commerce/harness');
const { onFetch, onReset, api } = require('../lib/server');

const transit = api('services/transit');
const { DATASETS } = api('services/transit/opendata');

// 測資為 2026-10-02 自 data.taipei 下載後裁切的真實資料：以師大路（25.0245, 121.5288）為中心，
// 捷運、票價與無障礙設施為 Big5 編碼，路邊即時空位只把師大路C、龍泉街改成固定值；
// 公車、道路速率為交通局檔案伺服器的 gzip 原檔裁切；計程車招呼站離中心最近約 1.1 公里。
const FIXTURES = path.join(__dirname, 'fixtures');
const fixture = (name) => fs.readFileSync(path.join(FIXTURES, name));

const PORTAL = 'https://data.taipei';
const downloadUrl = (key) => `${PORTAL}/api/dataset/${DATASETS[key].dataset}/resource/${DATASETS[key].resource}/download`;

const ROUTES = {
  mrtExits: { url: downloadUrl('mrtExits'), file: 'mrt-exits.csv', type: 'text/csv' },
  mrtFares: { url: downloadUrl('mrtFares'), file: 'mrt-fares.csv', type: 'text/csv' },
  mrtAccessibility: { url: downloadUrl('mrtAccessibility'), file: 'mrt-accessibility.csv', type: 'text/csv' },
  busStops: { url: DATASETS.busStops.url, file: 'bus-stops.gz', type: 'application/x-gzip' },
  busEstimates: { url: DATASETS.busEstimates.url, file: 'bus-estimates.gz', type: 'application/x-gzip' },
  busRoutes: { url: DATASETS.busRoutes.url, file: 'bus-routes.gz', type: 'application/x-gzip' },
  roadSpeed: { url: DATASETS.roadSpeed.url, file: 'road-speed.xml.gz', type: 'application/x-gzip' },
  taxiStands: { url: downloadUrl('taxiStands'), file: 'taxi-stands.csv', type: 'text/csv' },
  youbike: { url: DATASETS.youbike.url, file: 'youbike.json', type: 'application/json' },
  parkingLots: { url: DATASETS.parkingLots.url, file: 'parking-lots.json', type: 'application/octet-stream' },
  parkingAvailability: { url: DATASETS.parkingAvailability.url, file: 'parking-availability.json', type: 'application/octet-stream' },
  roadsideUsage: { url: DATASETS.roadsideUsage.url, file: 'roadside-usage.xml', type: 'application/octet-stream' },
  roadsideSpaces: { url: downloadUrl('roadsideSpaces'), file: 'roadside-spaces.zip', type: 'application/zip' }
};

// 各來源的回應狀態，測試可改成 500 或 404 模擬來源故障或資源編號更換。
const status = {};
const hits = {};
const extra = new Map();

for (const [key, route] of Object.entries(ROUTES)) {
  onFetch(route.url, () => {
    hits[key] = (hits[key] ?? 0) + 1;
    const code = status[key] ?? 200;
    if (code !== 200) return new Response('error', { status: code });
    return new Response(fixture(route.file), { status: 200, headers: { 'content-type': route.type } });
  });
}
onFetch(`${PORTAL}/api/`, (url) => {
  const handler = [...extra].find(([prefix]) => url.startsWith(prefix))?.[1];
  if (!handler) return new Response('not found', { status: 404 });
  return handler(url);
});

const indexFile = path.join(process.env.TRANSIT_DATA_DIR, 'roadside-spaces.json');

onReset(() => {
  transit.reset();
  for (const key of Object.keys(status)) delete status[key];
  for (const key of Object.keys(hits)) delete hits[key];
  extra.clear();
  fs.rmSync(indexFile, { force: true });
});

const CENTER = { lat: 25.0245, lng: 121.5288 };

const addCabinetAt = ({ lat = CENTER.lat, lng = CENTER.lng, ...rest } = {}) => {
  const cabinet = h.addCabinet(rest);
  cabinet.latitude = lat;
  cabinet.longitude = lng;
  return cabinet;
};

// 先建好格位索引，模擬排程已執行過。
const buildLayer = () => transit.refreshRoadsideLayer();

module.exports = { ...h, transit, status, hits, extra, indexFile, CENTER, addCabinetAt, buildLayer, fixture, downloadUrl, PORTAL };
