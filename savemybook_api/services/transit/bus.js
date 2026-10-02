const { DATASETS, fetchBuffer, decodeText, parseJson, taipeiTime } = require('./opendata');
const { createSource } = require('./source');
const { createGridIndex } = require('../../lib/geo');

const RADIUS_M = 300;
const STOP_LIMIT = 4;
const DAY = 24 * 60 * 60 * 1000;

// 同一個站位（stopLocationId）有多條路線的站牌，合併成一個站點顯示；路線的方向以該方向最後一站為終點。
const parseStops = (body) => {
  const list = body?.BusInfo;
  if (!Array.isArray(list)) throw new Error('公車站牌資料格式不符');
  const locations = new Map();
  const last = new Map();
  for (const s of list) {
    const lat = Number(s.latitude);
    const lng = Number(s.longitude);
    if (!Number.isFinite(lat) || !Number.isFinite(lng) || !s.nameZh) continue;
    const routeKey = `${s.routeId}|${s.goBack}`;
    const seq = Number(s.seqNo);
    if (!last.has(routeKey) || seq > last.get(routeKey).seq) last.set(routeKey, { seq, name: s.nameZh });

    const id = String(s.stopLocationId ?? s.Id);
    let loc = locations.get(id);
    if (!loc) {
      loc = { name: s.nameZh, address: String(s.address ?? '').trim(), lat, lng, entries: [] };
      locations.set(id, loc);
    }
    loc.entries.push({ stopId: Number(s.Id), routeId: Number(s.routeId), goBack: String(s.goBack) });
  }
  const all = [...locations.values()];
  if (!all.length) throw new Error('公車站牌資料為空');
  const destinations = new Map([...last].map(([k, v]) => [k, v.name]));
  return { locations: all, destinations, index: createGridIndex(all.length, (k) => all[k].lat, (k) => all[k].lng) };
};

const parseRouteNames = (xml) => {
  const names = new Map();
  for (const m of xml.matchAll(/<RouteFare>\s*<RouteID>(\d+)<\/RouteID>\s*<RouteName>\s*<Zh_tw>([^<]*)<\/Zh_tw>/g)) {
    names.set(Number(m[1]), m[2].trim());
  }
  if (!names.size) throw new Error('公車路線名稱資料為空');
  return names;
};

const parseEstimates = (body) => {
  const list = body?.BusInfo;
  if (!Array.isArray(list)) throw new Error('公車預估到站資料格式不符');
  const map = new Map();
  for (const e of list) map.set(`${e.RouteID}|${e.StopID}`, Number(e.EstimateTime));
  return { map, updatedAt: taipeiTime(body?.EssentialInfo?.UpdateTime) };
};

const stopsSource = createSource({
  name: DATASETS.busStops.title,
  ttlMs: DAY,
  retryMs: 10 * 60 * 1000,
  load: async () => ({ data: parseStops(parseJson(await fetchBuffer(DATASETS.busStops, { timeoutMs: 30000 }))) })
});

const routesSource = createSource({
  name: DATASETS.busRoutes.title,
  ttlMs: DAY,
  retryMs: 10 * 60 * 1000,
  load: async () => ({ data: parseRouteNames(decodeText(await fetchBuffer(DATASETS.busRoutes))) })
});

const estimatesSource = createSource({
  name: DATASETS.busEstimates.title,
  ttlMs: 30 * 1000,
  retryMs: 30 * 1000,
  load: async () => {
    const data = parseEstimates(parseJson(await fetchBuffer(DATASETS.busEstimates)));
    return { data, updatedAt: data.updatedAt ?? new Date() };
  }
});

// 預估到站秒數；負值為狀態碼：-1 尚未發車、-2 交管不停靠、-3 末班車已過、-4 今日未營運。
const STATUS_OF_CODE = { '-1': 'not_departed', '-2': 'not_stopping', '-3': 'last_passed', '-4': 'no_service' };
const ORDER = { arriving: 0, minutes: 1, not_departed: 2, unknown: 3, not_stopping: 4, last_passed: 5, no_service: 6 };

const arrival = (seconds) => {
  if (seconds === undefined || !Number.isFinite(seconds)) return { status: 'unknown', minutes: null };
  if (seconds >= 0) return seconds < 60 ? { status: 'arriving', minutes: 0 } : { status: 'minutes', minutes: Math.floor(seconds / 60) };
  return { status: STATUS_OF_CODE[String(seconds)] ?? 'unknown', minutes: null };
};

const byRouteName = (a, b) => a.name.localeCompare(b.name, 'zh-Hant', { numeric: true });

const nearby = async (lat, lng) => {
  const [stops, routes, estimates] = await Promise.all([stopsSource.get(), routesSource.get(), estimatesSource.get()]);
  if (!stops.data || !routes.data) return { status: 'unavailable', stops: [], updated_at: null, realtime_available: false };
  const eta = estimates.data?.map;

  const result = stops.data.index.within(lat, lng, RADIUS_M).slice(0, STOP_LIMIT).map(({ index, distance }) => {
    const loc = stops.data.locations[index];
    const seen = new Map();
    for (const e of loc.entries) {
      const name = routes.data.get(e.routeId);
      if (!name) continue;
      const direction = stops.data.destinations.get(`${e.routeId}|${e.goBack}`) ?? null;
      const item = { name, direction, ...arrival(eta?.get(`${e.routeId}|${e.stopId}`)) };
      const key = `${name}|${direction}`;
      const prev = seen.get(key);
      if (!prev || ORDER[item.status] < ORDER[prev.status] || (item.status === prev.status && (item.minutes ?? 0) < (prev.minutes ?? 0))) {
        seen.set(key, item);
      }
    }
    const list = [...seen.values()].sort((a, b) => ORDER[a.status] - ORDER[b.status] || (a.minutes ?? 0) - (b.minutes ?? 0) || byRouteName(a, b));
    return { name: loc.name, address: loc.address, latitude: loc.lat, longitude: loc.lng, distance_m: distance, routes: list };
  }).filter((s) => s.routes.length);

  return {
    status: 'ok',
    updated_at: estimates.data ? estimates.updatedAt : null,
    realtime_available: Boolean(estimates.data),
    stops: result
  };
};

const warm = () => Promise.all([stopsSource.get(), routesSource.get()]);

module.exports = { nearby, warm, parseStops, parseRouteNames, parseEstimates, arrival, RADIUS_M };
