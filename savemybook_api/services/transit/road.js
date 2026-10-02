const { DATASETS, fetchBuffer, decodeText, parseCsv } = require('./opendata');
const { createSource } = require('./source');
const { createGridIndex } = require('../../lib/geo');

const SPEED_RADIUS_M = 600;
const SPEED_LIMIT = 3;
const TAXI_RADIUS_M = 800;
const TAXI_LIMIT = 3;

// 交控中心說明文件：MOELevel -1 無資料、0 順暢、1 車多、2 壅塞。
const LEVELS = { 0: 'smooth', 1: 'busy', 2: 'congested' };

const tag = (block, name) => block.match(new RegExp(`<vd:${name}>([^<]*)</vd:${name}>`))?.[1]?.trim() ?? '';

// 路段名稱為「和平東路  羅斯福路-師大路」：路名與起訖點以空白分隔。
const splitName = (raw) => {
  const [road, ...rest] = raw.trim().split(/\s+/);
  return { road, between: rest.join(' ') };
};

const parseSpeeds = (xml) => {
  const sections = [];
  for (const m of xml.matchAll(/<vd:SectionData>([\s\S]*?)<\/vd:SectionData>/g)) {
    const block = m[1];
    const speed = Number(tag(block, 'AvgSpd'));
    const level = LEVELS[tag(block, 'MOELevel')];
    const coords = ['StartWgsY', 'StartWgsX', 'EndWgsY', 'EndWgsX'].map((t) => Number(tag(block, t)));
    if (!level || !(speed >= 0) || coords.some((n) => !Number.isFinite(n) || n === 0)) continue;
    sections.push({
      ...splitName(tag(block, 'SectionName')),
      speed: Math.round(speed),
      level,
      lat: (coords[0] + coords[2]) / 2,
      lng: (coords[1] + coords[3]) / 2
    });
  }
  if (!sections.length) throw new Error('道路速率資料為空');
  return { sections, index: createGridIndex(sections.length, (k) => sections[k].lat, (k) => sections[k].lng) };
};

const parseTaxiStands = (text) => {
  const [header, ...rows] = parseCsv(text);
  const col = (label) => header.findIndex((h) => h.includes(label));
  const [iLng, iLat, iPlace, iStreet, iSpaces, iHours] = ['經度', '緯度', '設置地點', '街道名稱', '排班格位', '排班時間'].map(col);
  if ([iLng, iLat, iPlace].some((i) => i < 0)) throw new Error('計程車招呼站欄位不符');
  const stands = [];
  for (const r of rows) {
    const lat = Number(r[iLat]);
    const lng = Number(r[iLng]);
    if (!Number.isFinite(lat) || !Number.isFinite(lng) || !r[iPlace]) continue;
    stands.push({
      name: r[iPlace],
      street: iStreet >= 0 ? r[iStreet] : '',
      spaces: iSpaces >= 0 ? Number(r[iSpaces]) || null : null,
      hours: iHours >= 0 ? r[iHours] : '',
      lat,
      lng
    });
  }
  if (!stands.length) throw new Error('計程車招呼站資料為空');
  return { stands, index: createGridIndex(stands.length, (k) => stands[k].lat, (k) => stands[k].lng) };
};

const speedSource = createSource({
  name: DATASETS.roadSpeed.title,
  ttlMs: 2 * 60 * 1000,
  load: async () => ({ data: parseSpeeds(decodeText(await fetchBuffer(DATASETS.roadSpeed))) })
});

const taxiSource = createSource({
  name: DATASETS.taxiStands.title,
  ttlMs: 24 * 60 * 60 * 1000,
  retryMs: 10 * 60 * 1000,
  load: async () => ({ data: parseTaxiStands(decodeText(await fetchBuffer(DATASETS.taxiStands))) })
});

const speeds = async (lat, lng) => {
  const { data, updatedAt } = await speedSource.get();
  if (!data) return { status: 'unavailable', sections: [], updated_at: null };
  const seen = new Set();
  const sections = [];
  for (const { index, distance } of data.index.within(lat, lng, SPEED_RADIUS_M)) {
    const s = data.sections[index];
    const key = `${s.road}|${s.between}`;
    if (seen.has(key)) continue;
    seen.add(key);
    sections.push({ road: s.road, between: s.between, speed_kph: s.speed, level: s.level, latitude: s.lat, longitude: s.lng, distance_m: distance });
    if (sections.length === SPEED_LIMIT) break;
  }
  return { status: 'ok', updated_at: updatedAt, sections };
};

const taxi = async (lat, lng) => {
  const { data, updatedAt } = await taxiSource.get();
  if (!data) return { status: 'unavailable', stands: [], updated_at: null };
  return {
    status: 'ok',
    updated_at: updatedAt,
    stands: data.index.within(lat, lng, TAXI_RADIUS_M).slice(0, TAXI_LIMIT).map(({ index, distance }) => {
      const s = data.stands[index];
      return { name: s.name, street: s.street, spaces: s.spaces, hours: s.hours, latitude: s.lat, longitude: s.lng, distance_m: distance };
    })
  };
};

const warm = () => taxiSource.get();

module.exports = { speeds, taxi, warm, parseSpeeds, parseTaxiStands, SPEED_RADIUS_M, TAXI_RADIUS_M };
