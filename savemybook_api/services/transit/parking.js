const { DATASETS, fetchBuffer, parseJson, taipeiTime } = require('./opendata');
const { createSource } = require('./source');
const { createGridIndex, distanceMeters } = require('../../lib/geo');
const { toWgs84 } = require('../../lib/twd97');

const RADIUS_M = 800;
const LIMIT = 5;
// 部分停車場的入口座標與 TWD97 位置相差數公里（資料登錄錯誤），差太多時導航改用停車場位置。
const ENTRANCE_TRUST_M = 300;

const count = (v) => {
  const n = Number(v);
  return Number.isFinite(n) && n >= 0 ? n : null;
};

const parseLots = (body) => {
  const list = body?.data?.park;
  if (!Array.isArray(list)) throw new Error('停車場資料格式不符');
  const lots = [];
  for (const p of list) {
    const x = Number(p.tw97x);
    const y = Number(p.tw97y);
    const entrance = (p.EntranceCoord?.EntrancecoordInfo ?? [])
      .map((e) => ({ lat: Number(e.Xcod), lng: Number(e.Ycod) }))
      .find((e) => Number.isFinite(e.lat) && Number.isFinite(e.lng) && e.lat > 20 && e.lng > 118);
    let pos = x > 0 && y > 0 ? toWgs84(x, y) : null;
    if (!pos && entrance) pos = entrance;
    if (!pos || !p.name) continue;
    const nav = entrance && distanceMeters(pos.lat, pos.lng, entrance.lat, entrance.lng) <= ENTRANCE_TRUST_M ? entrance : pos;
    lots.push({
      id: String(p.id),
      name: String(p.name).trim(),
      address: String(p.address ?? '').trim(),
      tel: String(p.tel ?? '').trim(),
      fee: String(p.payex ?? '').trim(),
      hours: String(p.serviceTime ?? '').trim(),
      realtime: String(p.type) === '1',
      totalCar: count(p.totalcar) ?? 0,
      totalMotor: count(p.totalmotor) ?? 0,
      lat: pos.lat,
      lng: pos.lng,
      navLat: nav.lat,
      navLng: nav.lng
    });
  }
  if (!lots.length) throw new Error('停車場資料為空');
  return { lots, index: createGridIndex(lots.length, (k) => lots[k].lat, (k) => lots[k].lng), updatedAt: taipeiTime(body.data.UPDATETIME) };
};

const parseAvailability = (body) => {
  const list = body?.data?.park;
  if (!Array.isArray(list)) throw new Error('剩餘車位資料格式不符');
  const map = new Map();
  for (const a of list) map.set(String(a.id), { car: count(a.availablecar), motor: count(a.availablemotor) });
  return { map, updatedAt: taipeiTime(body.data.UPDATETIME) };
};

const lotsSource = createSource({
  name: DATASETS.parkingLots.title,
  ttlMs: 24 * 60 * 60 * 1000,
  retryMs: 10 * 60 * 1000,
  load: async () => {
    const data = parseLots(parseJson(await fetchBuffer(DATASETS.parkingLots, { timeoutMs: 30000 })));
    return { data, updatedAt: data.updatedAt ?? new Date() };
  }
});

const availabilitySource = createSource({
  name: DATASETS.parkingAvailability.title,
  ttlMs: 2 * 60 * 1000,
  load: async () => {
    const data = parseAvailability(parseJson(await fetchBuffer(DATASETS.parkingAvailability)));
    return { data, updatedAt: data.updatedAt ?? new Date() };
  }
});

const nearby = async (lat, lng) => {
  const [lots, live] = await Promise.all([lotsSource.get(), availabilitySource.get()]);
  if (!lots.data) return { status: 'unavailable', lots: [], updated_at: null };
  const liveMap = live.data?.map ?? new Map();
  return {
    status: 'ok',
    updated_at: live.data ? live.updatedAt : lots.updatedAt,
    realtime_available: Boolean(live.data),
    lots: lots.data.index.within(lat, lng, RADIUS_M).slice(0, LIMIT).map(({ index, distance }) => {
      const p = lots.data.lots[index];
      const avail = p.realtime ? liveMap.get(p.id) : null;
      return {
        name: p.name,
        address: p.address,
        tel: p.tel,
        fee: p.fee,
        hours: p.hours,
        latitude: p.navLat,
        longitude: p.navLng,
        distance_m: distance,
        car: { total: p.totalCar, available: avail?.car ?? null },
        motorcycle: { total: p.totalMotor, available: avail?.motor ?? null }
      };
    })
  };
};

const warm = () => lotsSource.get();

module.exports = { nearby, warm, parseLots, parseAvailability, RADIUS_M };
