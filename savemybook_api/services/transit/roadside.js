const fs = require('fs');
const path = require('path');
const { pipeline } = require('stream/promises');
const { Readable } = require('stream');
const yauzl = require('yauzl');
const { env } = require('../../config/env');
const { DATASETS, fetchResponse, decodeText, taipeiTime } = require('./opendata');
const { createSource } = require('./source');
const { createGridIndex } = require('../../lib/geo');
const { toWgs84 } = require('../../lib/twd97');

const RADIUS_M = 300;
const UNNAMED = '路名未標示';
const LIMIT = 5;
const LAYER_MAX_AGE_MS = 30 * 24 * 60 * 60 * 1000;
const INDEX_VERSION = 1;

// 格位圖層 pktype（交通局說明）：只計入一般民眾可停的格位；警車、計程車、裝卸、公務車與說明中沒有的代碼不計。
const KIND = { car: 1, carAccessible: 2, motor: 3, motorAccessible: 4, motorArea: 5 };
const KIND_OF_TYPE = {
  '01': KIND.car, '09': KIND.car, '15': KIND.car, '22': KIND.car, '23': KIND.car,
  '03': KIND.carAccessible,
  '02': KIND.motor, '20': KIND.motor,
  '04': KIND.motorAccessible,
  '11': KIND.motorArea, '18': KIND.motorArea
};

const dataDir = () => env.transitDataDir || path.join(__dirname, '..', '..', 'storage', 'transit');
const indexFile = () => path.join(dataDir(), 'roadside-spaces.json');

// ---------- 即時使用情形（XML，約 9MB） ----------

const tag = (block, name) => {
  const m = block.match(new RegExp(`<${name}>([^<]*)</${name}>`, 'i'));
  return m ? m[1].trim() : '';
};

// 路段名稱偶爾帶有「1003046(04192) 」前綴。
const cleanName = (name) => name.replace(/^[0-9A-Z]+\(\d+\)\s*/, '').trim();

const parseUsage = (xml) => {
  const segments = new Map();
  let latest = null;
  for (const m of xml.matchAll(/<ROAD>([\s\S]*?)<\/ROAD>/g)) {
    const block = m[1].replace(/<cellStatusList>[\s\S]*?<\/cellStatusList>/, '');
    const id = tag(block, 'roadSegID');
    if (!id) continue;
    const total = Number(tag(block, 'roadSegTotalValue'));
    const avail = Number(tag(block, 'roadSegAvail'));
    const updatedAt = taipeiTime(tag(block, 'roadSegUpdatetime'));
    if (updatedAt && (!latest || updatedAt > latest)) latest = updatedAt;
    segments.set(id, {
      name: cleanName(tag(block, 'roadSegName')),
      total: Number.isFinite(total) && total >= 0 ? total : null,
      available: Number.isFinite(avail) && avail >= 0 ? avail : null,
      fee: tag(block, 'roadSegFee'),
      start: tag(block, 'roadSegtimeStart'),
      end: tag(block, 'roadSegtimeEnd'),
      updatedAt
    });
  }
  if (!segments.size) throw new Error('路邊停車使用情形資料為空');
  return { segments, latest };
};

const usageSource = createSource({
  name: DATASETS.roadsideUsage.title,
  ttlMs: 5 * 60 * 1000,
  load: async () => {
    const res = await fetchResponse(DATASETS.roadsideUsage, { timeoutMs: 30000 });
    const data = parseUsage(decodeText(Buffer.from(await res.arrayBuffer())));
    return { data, updatedAt: data.latest ?? new Date() };
  }
});

// ---------- 格位圖層（SHP，每月） ----------

// 逐塊累積串流資料，湊滿指定長度才交給解析，避免整個檔案載入記憶體（DBF 解壓後近 500MB）。
const byteReader = (stream) => {
  const iterator = stream[Symbol.asyncIterator]();
  let buffer = Buffer.alloc(0);
  let done = false;
  return async (n) => {
    while (buffer.length < n && !done) {
      const next = await iterator.next();
      if (next.done) done = true;
      else buffer = buffer.length ? Buffer.concat([buffer, next.value]) : next.value;
    }
    if (buffer.length < n) return null;
    const out = buffer.subarray(0, n);
    buffer = buffer.subarray(n);
    return out;
  };
};

const readShapes = async (stream) => {
  const read = byteReader(stream);
  const header = await read(100);
  if (!header || header.readInt32BE(0) !== 9994) throw new Error('SHP 檔頭不正確');
  const points = [];
  for (;;) {
    const recHeader = await read(8);
    if (!recHeader) break;
    const content = await read(recHeader.readInt32BE(4) * 2);
    if (!content) throw new Error('SHP 資料不完整');
    if (content.readInt32LE(0) === 0) {
      points.push(null);
      continue;
    }
    const x = (content.readDoubleLE(4) + content.readDoubleLE(20)) / 2;
    const y = (content.readDoubleLE(12) + content.readDoubleLE(28)) / 2;
    points.push(toWgs84(x, y));
  }
  return points;
};

const DBF_FIELDS = ['pktype', 'rdcode', 'roadname', 'pkroad'];

const readRecords = async (stream, onRecord) => {
  const read = byteReader(stream);
  const head = await read(32);
  if (!head) throw new Error('DBF 檔頭不正確');
  const count = head.readUInt32LE(4);
  const headerLength = head.readUInt16LE(8);
  const recordLength = head.readUInt16LE(10);
  const descriptors = await read(headerLength - 32);
  const fields = {};
  let offset = 1;
  for (let p = 0; p + 32 <= descriptors.length && descriptors[p] !== 0x0d; p += 32) {
    const name = descriptors.subarray(p, p + 11).toString('latin1').replace(/\0.*$/, '');
    const length = descriptors[p + 16];
    if (DBF_FIELDS.includes(name)) fields[name] = [offset, length];
    offset += length;
  }
  if (!fields.pktype || !fields.rdcode) throw new Error('DBF 缺少格位類型或路段編號欄位');
  const text = (rec, name) => (fields[name] ? rec.toString('utf8', fields[name][0], fields[name][0] + fields[name][1]).trim() : '');
  for (let i = 0; i < count; i += 1) {
    const rec = await read(recordLength);
    if (!rec) throw new Error('DBF 資料不完整');
    if (rec[0] === 0x2a) {
      onRecord(i, null);
      continue;
    }
    onRecord(i, { pktype: text(rec, 'pktype'), rdcode: text(rec, 'rdcode'), roadname: text(rec, 'roadname') || text(rec, 'pkroad') });
  }
};

const kindOf = (pktype) => KIND_OF_TYPE[pktype.padStart(2, '0')] ?? 0;

const round6 = (n) => Math.round(n * 1e6) / 1e6;

const ADOPT_RADIUS_M = 60;

// 約 8% 的格位沒有填路名（多為機車格），歸到 60 公尺內最近有路名的格位所屬路段，否則留在未標示路名的群組。
const adoptNearestRoad = (segments, spaces) => {
  const named = [];
  for (let k = 0; k < spaces.seg.length; k += 1) if (segments[spaces.seg[k]][1]) named.push(k);
  const index = createGridIndex(named.length, (i) => spaces.lat[named[i]], (i) => spaces.lng[named[i]], 0.001);
  for (let k = 0; k < spaces.seg.length; k += 1) {
    if (segments[spaces.seg[k]][1]) continue;
    const [hit] = index.within(spaces.lat[k], spaces.lng[k], ADOPT_RADIUS_M);
    if (hit) spaces.seg[k] = spaces.seg[named[hit.index]];
  }
};

const buildIndexFromZip = async (zipPath) => {
  const zip = await yauzl.openPromise(zipPath, { lazyEntries: true, autoClose: false });
  try {
    const entries = {};
    for await (const entry of zip.eachEntry()) {
      const ext = path.extname(entry.fileName).toLowerCase();
      if (['.shp', '.dbf'].includes(ext)) entries[ext] = entry;
    }
    if (!entries['.shp'] || !entries['.dbf']) throw new Error('格位圖層壓縮檔缺少 SHP 或 DBF');

    const points = await readShapes(await zip.openReadStreamPromise(entries['.shp']));
    const segments = [];
    const segmentOf = new Map();
    const spaces = { lat: [], lng: [], kind: [], seg: [] };
    await readRecords(await zip.openReadStreamPromise(entries['.dbf']), (i, rec) => {
      const point = points[i];
      if (!rec || !point) return;
      const kind = kindOf(rec.pktype);
      if (!kind) return;
      const key = rec.rdcode || `name:${rec.roadname}`;
      let seg = segmentOf.get(key);
      if (seg === undefined) {
        seg = segments.length;
        segments.push([rec.rdcode || null, rec.roadname]);
        segmentOf.set(key, seg);
      }
      spaces.lat.push(round6(point.lat));
      spaces.lng.push(round6(point.lng));
      spaces.kind.push(kind);
      spaces.seg.push(seg);
    });
    if (!spaces.kind.length) throw new Error('格位圖層沒有可用的格位');
    adoptNearestRoad(segments, spaces);

    // 壓縮檔內的檔名帶有圖層產製時間，例如 park01_202608271732.shp。
    const stamp = entries['.shp'].fileName.match(/(\d{8})(\d{4})?/);
    const layerDate = stamp ? taipeiTime(`${stamp[1].slice(0, 4)}-${stamp[1].slice(4, 6)}-${stamp[1].slice(6, 8)} ${stamp[2] ? `${stamp[2].slice(0, 2)}:${stamp[2].slice(2)}` : '00:00'}`) : null;
    return { version: INDEX_VERSION, built_at: new Date().toISOString(), layer_date: layerDate?.toISOString() ?? null, segments, spaces };
  } finally {
    zip.close();
  }
};

let layer = null;
let building = null;

const activate = (raw) => {
  const { spaces } = raw;
  layer = {
    builtAt: new Date(raw.built_at),
    layerDate: raw.layer_date ? new Date(raw.layer_date) : null,
    segments: raw.segments,
    spaces,
    index: createGridIndex(spaces.kind.length, (k) => spaces.lat[k], (k) => spaces.lng[k])
  };
  return layer;
};

const loadFromDisk = () => {
  try {
    const raw = JSON.parse(fs.readFileSync(indexFile(), 'utf8'));
    if (raw.version !== INDEX_VERSION) return null;
    return activate(raw);
  } catch {
    return null;
  }
};

const currentLayer = () => layer ?? loadFromDisk();

const rebuildLayer = () => {
  building ??= (async () => {
    const dir = dataDir();
    fs.mkdirSync(dir, { recursive: true });
    const zipPath = path.join(dir, `roadside-spaces-${process.pid}.zip`);
    try {
      const res = await fetchResponse(DATASETS.roadsideSpaces, { timeoutMs: 10 * 60 * 1000 });
      await pipeline(Readable.fromWeb(res.body), fs.createWriteStream(zipPath));
      const raw = await buildIndexFromZip(zipPath);
      const tmp = `${indexFile()}.${process.pid}.tmp`;
      fs.writeFileSync(tmp, JSON.stringify(raw));
      fs.renameSync(tmp, indexFile());
      activate(raw);
      return raw.spaces.kind.length;
    } finally {
      fs.rmSync(zipPath, { force: true });
      building = null;
    }
  })();
  return building;
};

// 排程每天呼叫：索引不存在或超過 30 天才重新下載。
const refreshLayerIfDue = async () => {
  const current = currentLayer();
  if (current && Date.now() - current.builtAt.getTime() < LAYER_MAX_AGE_MS) return 0;
  return rebuildLayer();
};

const nearby = async (lat, lng) => {
  const current = currentLayer();
  if (!current) return { status: 'unavailable', car: [], motorcycle: [], layer_updated_at: null, updated_at: null };
  const usage = await usageSource.get();
  const live = usage.data?.segments ?? new Map();

  const nameOf = (seg) => {
    const [segmentId, layerName] = current.segments[seg];
    return (segmentId && live.get(segmentId)?.name) || layerName || UNNAMED;
  };

  // 汽車格依路段編號分組（才能對上即時空位）；機車格大多沒有路段編號，依路名分組。
  const carGroups = new Map();
  const motorGroups = new Map();
  const touch = (groups, key, init) => {
    let g = groups.get(key);
    if (!g) groups.set(key, (g = init()));
    return g;
  };
  for (const { index, distance } of current.index.within(lat, lng, RADIUS_M)) {
    const seg = current.spaces.seg[index];
    const kind = current.spaces.kind[index];
    const at = { distance, lat: current.spaces.lat[index], lng: current.spaces.lng[index] };
    if (kind === KIND.car || kind === KIND.carAccessible) {
      const g = touch(carGroups, seg, () => ({ seg, ...at, spaces: 0, accessible: 0 }));
      g.spaces += 1;
      if (kind === KIND.carAccessible) g.accessible += 1;
    } else {
      const name = nameOf(seg);
      const g = touch(motorGroups, name, () => ({ name, ...at, spaces: 0, accessible: 0, area: false }));
      if (kind === KIND.motorArea) g.area = true;
      else g.spaces += 1;
      if (kind === KIND.motorAccessible) g.accessible += 1;
    }
  }

  const car = [...carGroups.values()].slice(0, LIMIT).map((g) => {
    const segmentId = current.segments[g.seg][0];
    const seg = segmentId ? live.get(segmentId) : null;
    return {
      name: nameOf(g.seg),
      segment_id: segmentId,
      distance_m: g.distance,
      latitude: g.lat,
      longitude: g.lng,
      spaces_nearby: g.spaces,
      accessible_nearby: g.accessible,
      live: seg
        ? { total: seg.total, available: seg.available, fee: seg.fee || null, start: seg.start || null, end: seg.end || null, updated_at: seg.updatedAt }
        : null
    };
  });

  const motorcycle = [...motorGroups.values()].slice(0, LIMIT).map((g) => ({
    name: g.name,
    distance_m: g.distance,
    latitude: g.lat,
    longitude: g.lng,
    spaces_nearby: g.spaces,
    accessible_nearby: g.accessible,
    has_parking_area: g.area
  }));

  return {
    status: 'ok',
    radius_m: RADIUS_M,
    layer_updated_at: current.layerDate ?? current.builtAt,
    updated_at: usage.data ? usage.updatedAt : null,
    car,
    motorcycle
  };
};

const resetLayer = () => {
  layer = null;
  building = null;
};

module.exports = { nearby, currentLayer, refreshLayerIfDue, rebuildLayer, buildIndexFromZip, parseUsage, resetLayer, RADIUS_M };
