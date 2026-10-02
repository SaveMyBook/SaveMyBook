const { DATASETS, fetchBuffer, decodeText, parseCsv } = require('./opendata');
const { createSource } = require('./source');
const { distanceMeters } = require('../../lib/geo');

const DAY = 24 * 60 * 60 * 1000;

// 出入口名稱為「科技大樓站出口2」，臺北車站則是「台北車站M1」；票價檔的站名不帶「站」（臺北車站為「台北車站」）。
const stationOf = (name, exitNo) => {
  let s = name;
  if (exitNo && s.endsWith(exitNo)) s = s.slice(0, -exitNo.length);
  s = s.replace(/出口$/, '');
  if (s.endsWith('站') && !s.endsWith('車站')) s = s.slice(0, -1);
  return s;
};

const parseExits = (text) => {
  const [header, ...rows] = parseCsv(text);
  const col = (label) => header.findIndex((h) => h.includes(label));
  const [iName, iNo, iLng, iLat, iAccess] = ['出入口名稱', '出入口編號', '經度', '緯度', '無障礙'].map(col);
  if ([iName, iNo, iLng, iLat].some((i) => i < 0)) throw new Error('捷運出入口欄位不符');

  const exits = [];
  for (const r of rows) {
    const lat = Number(r[iLat]);
    const lng = Number(r[iLng]);
    if (!Number.isFinite(lat) || !Number.isFinite(lng) || !r[iName]) continue;
    // 只有一個出口的車站（如木柵站）名稱為「木柵站出口」、編號為 0，以 null 表示單一出口。
    exits.push({
      station: stationOf(r[iName], r[iNo]),
      exit: r[iNo] === '0' ? null : r[iNo] || r[iName],
      lat,
      lng,
      accessible: iAccess >= 0 && r[iAccess] === '是'
    });
  }
  if (!exits.length) throw new Error('捷運出入口資料為空');

  const byStation = new Map();
  for (const e of exits) {
    if (!byStation.has(e.station)) byStation.set(e.station, []);
    byStation.get(e.station).push(e);
  }
  const stations = [...byStation].map(([name, list]) => ({
    name,
    lat: list.reduce((s, e) => s + e.lat, 0) / list.length,
    lng: list.reduce((s, e) => s + e.lng, 0) / list.length,
    exits: list
  }));
  return { exits, stations };
};

// 名稱為「大安站出口電梯」「台北車站出口電梯1」「木柵站出口無障礙坡道」，編號為「出口3」「M2」或「單一出口」。
const parseAccessibility = (text) => {
  const [header, ...rows] = parseCsv(text);
  const col = (label) => header.findIndex((h) => h.includes(label));
  const [iName, iNo, iLng, iLat] = ['名稱', '編號', '經度', '緯度'].map(col);
  if ([iName, iNo, iLng, iLat].some((i) => i < 0)) throw new Error('捷運無障礙設施欄位不符');
  const byStation = new Map();
  for (const r of rows) {
    const m = r[iName]?.match(/^(.+)出口(電梯|無障礙坡道)\d*$/);
    const lat = Number(r[iLat]);
    const lng = Number(r[iLng]);
    if (!m || !Number.isFinite(lat) || !Number.isFinite(lng)) continue;
    const station = stationOf(m[1], '');
    const exit = r[iNo] === '單一出口' ? null : r[iNo].replace(/^出口/, '');
    if (!byStation.has(station)) byStation.set(station, []);
    byStation.get(station).push({ facility: m[2] === '電梯' ? 'elevator' : 'ramp', exit, lat, lng });
  }
  if (!byStation.size) throw new Error('捷運無障礙設施資料為空');
  return byStation;
};

const parseFares = (text) => {
  const [, ...rows] = parseCsv(text);
  const pairs = new Map();
  const names = new Set();
  for (const [from, to, fare, concession, km] of rows) {
    const full = Number(fare);
    if (!from || !to || !Number.isFinite(full)) continue;
    pairs.set(`${from}|${to}`, { fare: full, concession_fare: Number(concession) || null, distance_km: Number(km) || 0 });
    names.add(from);
  }
  if (!pairs.size) throw new Error('捷運票價資料為空');
  return { pairs, names };
};

const exitsSource = createSource({
  name: DATASETS.mrtExits.title,
  ttlMs: DAY,
  retryMs: 10 * 60 * 1000,
  load: async () => ({ data: parseExits(decodeText(await fetchBuffer(DATASETS.mrtExits))) })
});

const accessibilitySource = createSource({
  name: DATASETS.mrtAccessibility.title,
  ttlMs: DAY,
  retryMs: 10 * 60 * 1000,
  load: async () => ({ data: parseAccessibility(decodeText(await fetchBuffer(DATASETS.mrtAccessibility))) })
});

const faresSource = createSource({
  name: DATASETS.mrtFares.title,
  ttlMs: DAY,
  retryMs: 10 * 60 * 1000,
  load: async () => ({ data: parseFares(decodeText(await fetchBuffer(DATASETS.mrtFares))) })
});

const round6 = (n) => Math.round(n * 1e6) / 1e6;

const exitView = (e, lat, lng) => ({
  exit: e.exit,
  accessible: e.accessible,
  latitude: e.lat,
  longitude: e.lng,
  distance_m: distanceMeters(lat, lng, e.lat, e.lng)
});

const STATION_RADIUS_M = 1500;

// 無障礙出口優先用電梯、其次坡道（無障礙設施資料），取不到時退回出入口資料的「是否為無障礙用」。
const accessibleExit = (station, exits, facilities, lat, lng) => {
  const list = facilities?.get(station) ?? [];
  const pick = (kind) => list
    .filter((f) => f.facility === kind)
    .map((f) => ({
      exit: f.exit ?? (exits.length === 1 ? exits[0].exit : null),
      facility: kind,
      latitude: f.lat,
      longitude: f.lng,
      distance_m: distanceMeters(lat, lng, f.lat, f.lng)
    }))
    .sort((a, b) => a.distance_m - b.distance_m)[0];
  const found = pick('elevator') ?? pick('ramp');
  if (found) return found;
  const flagged = exits.find((e) => e.accessible);
  return flagged ? { ...flagged, facility: null } : null;
};

// 最近的兩個車站，各附最近的出口與最近的無障礙出口；1.5 公里內沒有車站時仍列出最近的一站。
const nearby = async (lat, lng) => {
  const [{ data, updatedAt }, facilities] = await Promise.all([exitsSource.get(), accessibilitySource.get()]);
  if (!data) return { status: 'unavailable', stations: [], updated_at: null };

  const ranked = data.stations
    .map((s) => {
      const exits = s.exits.map((e) => exitView(e, lat, lng)).sort((a, b) => a.distance_m - b.distance_m);
      return { name: s.name, distance_m: exits[0].distance_m, exits };
    })
    .sort((a, b) => a.distance_m - b.distance_m);
  const close = ranked.filter((s) => s.distance_m <= STATION_RADIUS_M).slice(0, 2);
  const picked = close.length ? close : ranked.slice(0, 1);

  return {
    status: 'ok',
    updated_at: updatedAt,
    stations: picked.map((s) => ({
      name: s.name,
      distance_m: s.distance_m,
      nearest_exit: s.exits[0],
      accessible_exit: accessibleExit(s.name, s.exits, facilities.data, lat, lng)
    }))
  };
};

const stations = async () => {
  const { data, updatedAt } = await exitsSource.get();
  if (!data) return null;
  return {
    updated_at: updatedAt,
    stations: data.stations
      .map((s) => ({ name: s.name, latitude: round6(s.lat), longitude: round6(s.lng) }))
      .sort((a, b) => a.name.localeCompare(b.name, 'zh-Hant'))
  };
};

const fares = async (from, toList) => {
  const { data, updatedAt } = await faresSource.get();
  if (!data) return null;
  if (!data.names.has(from)) return { unknown_station: true };
  return {
    updated_at: updatedAt,
    fares: toList.map((to) => {
      const found = data.pairs.get(`${from}|${to}`);
      return { from, to, ...(found ?? { fare: null, concession_fare: null, distance_km: null }) };
    })
  };
};

const warm = () => Promise.all([exitsSource.get(), faresSource.get(), accessibilitySource.get()]);

module.exports = { nearby, stations, fares, warm, parseExits, parseFares, parseAccessibility };
