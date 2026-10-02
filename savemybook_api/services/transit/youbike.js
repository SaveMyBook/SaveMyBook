const { DATASETS, fetchBuffer, parseJson, taipeiTime } = require('./opendata');
const { createSource } = require('./source');
const { createGridIndex } = require('../../lib/geo');

const RADIUS_M = 500;
const LIMIT = 5;

const parse = (list) => {
  if (!Array.isArray(list)) throw new Error('YouBike 資料格式不符');
  const stations = list
    .map((s) => ({
      name: String(s.sna ?? '').replace(/^YouBike2\.0_/, ''),
      area: s.sarea ?? '',
      address: s.ar ?? '',
      lat: Number(s.latitude),
      lng: Number(s.longitude),
      total: Number(s.Quantity ?? s.quantity ?? s.tot) || 0,
      rent: Number(s.available_rent_bikes) || 0,
      return: Number(s.available_return_bikes) || 0,
      active: String(s.act) === '1',
      updatedAt: taipeiTime(s.infoTime ?? s.mday)
    }))
    .filter((s) => s.name && Number.isFinite(s.lat) && Number.isFinite(s.lng));
  if (!stations.length) throw new Error('YouBike 資料為空');
  const latest = stations.reduce((t, s) => (s.updatedAt && (!t || s.updatedAt > t) ? s.updatedAt : t), null);
  return { stations, index: createGridIndex(stations.length, (k) => stations[k].lat, (k) => stations[k].lng), latest };
};

const source = createSource({
  name: DATASETS.youbike.title,
  ttlMs: 60 * 1000,
  load: async () => {
    const data = parse(parseJson(await fetchBuffer(DATASETS.youbike)));
    return { data, updatedAt: data.latest ?? new Date() };
  }
});

const nearby = async (lat, lng) => {
  const { data, updatedAt } = await source.get();
  if (!data) return { status: 'unavailable', stations: [], updated_at: null };
  return {
    status: 'ok',
    updated_at: updatedAt,
    stations: data.index.within(lat, lng, RADIUS_M).slice(0, LIMIT).map(({ index, distance }) => {
      const s = data.stations[index];
      return {
        name: s.name,
        address: s.address,
        latitude: s.lat,
        longitude: s.lng,
        distance_m: distance,
        available_rent: s.rent,
        available_return: s.return,
        total: s.total,
        is_active: s.active,
        updated_at: s.updatedAt
      };
    })
  };
};

module.exports = { nearby, parse, RADIUS_M };
