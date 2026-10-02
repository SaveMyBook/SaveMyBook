// 臺北市資料大平臺（data.taipei）的資料集與下載工具。
const zlib = require('zlib');

const USER_AGENT = 'SaveMyBook/1.0 (+https://savemybook.today)';
const PORTAL = 'https://data.taipei';

const DATASETS = {
  mrtFares: {
    title: '臺北捷運系統票價',
    dataset: '4acb4911-0360-4063-808d-fcee629508b3',
    resource: '893c2f2a-dcfd-407b-b871-394a14105532',
    format: 'CSV'
  },
  mrtExits: {
    title: '臺北捷運車站出入口座標',
    dataset: 'cfa4778c-62c1-497b-b704-756231de348b',
    resource: '307a7f61-e302-4108-a817-877ccbfca7c1',
    format: 'CSV'
  },
  mrtAccessibility: {
    title: '臺北捷運車站出入口無障礙電梯、無障礙坡道GPS座標',
    dataset: '0a3bb422-9eb5-459b-a9d4-138456516183',
    resource: '61792c82-6609-41b2-9775-3a346934826d',
    format: 'CSV'
  },
  // 站牌、預估到站與路線名稱的資料集只附「介接網址」說明檔，實際資料在交通局的檔案伺服器（gzip）。
  busStops: {
    title: '臺北市站牌',
    dataset: '62bc76da-6e6b-46ee-8976-c1945092d504',
    url: 'https://tcgbusfs.blob.core.windows.net/blobbus/GetStop.gz'
  },
  busEstimates: {
    title: '臺北市預估到站時間(公車)',
    dataset: 'f11a5af0-7b37-48ef-98cc-f6f102ed43c6',
    url: 'https://tcgbusfs.blob.core.windows.net/blobbus/GetEstimateTime.gz'
  },
  busRoutes: {
    title: '臺北市公車結構性票價資訊',
    dataset: '651f6f05-074c-4f7a-a9cf-a367c32aa60b',
    url: 'https://tcgbusfs.blob.core.windows.net/blobbus/GetBusRouteFareList.gz'
  },
  roadSpeed: {
    title: '臺北市道路速率',
    dataset: 'b5aaf33a-a6dc-4836-bce6-09986241fe11',
    url: 'https://tcgbusfs.blob.core.windows.net/blobtisv/GetVD.xml.gz'
  },
  taxiStands: {
    title: '計程車招呼站',
    dataset: 'a0cf5e08-2b46-46be-aaa6-ac894b439156',
    resource: '2e57ee8c-ce7a-42b3-9993-f9171b7c3228',
    format: 'CSV'
  },
  youbike: {
    title: 'YouBike2.0臺北市公共自行車即時資訊',
    dataset: 'c6bc8aed-557d-41d5-bfb1-8da24f78f2fb',
    url: 'https://tcgbusfs.blob.core.windows.net/dotapp/youbike/v2/youbike_immediate.json'
  },
  parkingLots: {
    title: '臺北市停車場資訊',
    dataset: 'd5c0656b-5250-4179-a491-c94daa56ef2c',
    url: 'https://tcgbusfs.blob.core.windows.net/blobtcmsv/TCMSV_alldesc.json'
  },
  parkingAvailability: {
    title: '臺北市停車場資訊（剩餘停車位數）',
    dataset: 'd5c0656b-5250-4179-a491-c94daa56ef2c',
    url: 'https://tcgbusfs.blob.core.windows.net/blobtcmsv/TCMSV_allavailable.json'
  },
  roadsideUsage: {
    title: '臺北市路邊停車格位使用情形',
    dataset: '434638ca-8770-42c1-940d-0386a74f6eb9',
    url: 'https://tcgbusfs.blob.core.windows.net/blobtcmsv/TCMSV_roadquery.xml'
  },
  roadsideSpaces: {
    title: '臺北市路邊停車格位',
    dataset: '5a911ea5-1694-4301-808e-e1780d971611',
    resource: '7e2f32a0-9201-4666-a0ed-11034e6c2b66',
    format: 'SHP'
  }
};

const downloadUrl = ({ dataset, resource }) => `${PORTAL}/api/dataset/${dataset}/resource/${resource}/download`;

// 機關上傳新版檔案時資源編號可能改變，舊編號失效就從資料集的資源清單找同格式的檔案。
const resolveResource = async (spec) => {
  const res = await fetch(`${PORTAL}/api/frontstage/tpeod/dataset.view?id=${spec.dataset}`, {
    headers: { 'user-agent': USER_AGENT, accept: 'application/json' },
    signal: AbortSignal.timeout(15000)
  });
  if (!res.ok) throw new Error(`${spec.title} 資料集資訊 HTTP ${res.status}`);
  const body = await res.json();
  const found = (body?.payload?.resources ?? []).find((r) => String(r.file_format).toUpperCase() === spec.format);
  if (!found?.rid) throw new Error(`${spec.title} 找不到 ${spec.format} 資源`);
  return { ...spec, resource: found.rid };
};

const request = (url, timeoutMs) => fetch(url, { headers: { 'user-agent': USER_AGENT }, signal: AbortSignal.timeout(timeoutMs) });

const fetchResponse = async (spec, { timeoutMs = 20000 } = {}) => {
  let res = await request(spec.url ?? downloadUrl(spec), timeoutMs);
  if (!spec.url && res.status === 404) res = await request(downloadUrl(await resolveResource(spec)), timeoutMs);
  if (!res.ok) throw new Error(`${spec.title} HTTP ${res.status}`);
  return res;
};

const isGzip = (buffer) => buffer.length > 2 && buffer[0] === 0x1f && buffer[1] === 0x8b;

const fetchBuffer = async (spec, opts) => {
  const buffer = Buffer.from(await (await fetchResponse(spec, opts)).arrayBuffer());
  return isGzip(buffer) ? zlib.gunzipSync(buffer) : buffer;
};

// 捷運的 CSV 目前是 Big5，日後改成 UTF-8 也要能讀。
const decodeText = (buffer) => {
  try {
    return new TextDecoder('utf-8', { fatal: true }).decode(buffer).replace(/^﻿/, '');
  } catch {
    return new TextDecoder('big5').decode(buffer);
  }
};

const parseJson = (buffer) => JSON.parse(decodeText(buffer));

const parseCsv = (text) => {
  const rows = [];
  let row = [];
  let field = '';
  let quoted = false;
  for (let i = 0; i < text.length; i += 1) {
    const ch = text[i];
    if (quoted) {
      if (ch === '"' && text[i + 1] === '"') { field += '"'; i += 1; } else if (ch === '"') quoted = false;
      else field += ch;
    } else if (ch === '"') quoted = true;
    else if (ch === ',') { row.push(field); field = ''; } else if (ch === '\n' || ch === '\r') {
      if (ch === '\r' && text[i + 1] === '\n') i += 1;
      row.push(field);
      if (row.some((f) => f.trim() !== '')) rows.push(row.map((f) => f.trim()));
      row = [];
      field = '';
    } else field += ch;
  }
  row.push(field);
  if (row.some((f) => f.trim() !== '')) rows.push(row.map((f) => f.trim()));
  return rows;
};

// 停車場資料的時間是「Fri Oct 02 19:47:00 CST 2026」，YouBike 是「2026-10-02 19:50:52」，公車是「2026/10/02 20:54:10」，皆為臺北時間。
const MONTHS = { Jan: 1, Feb: 2, Mar: 3, Apr: 4, May: 5, Jun: 6, Jul: 7, Aug: 8, Sep: 9, Oct: 10, Nov: 11, Dec: 12 };
const taipeiTime = (value) => {
  if (typeof value !== 'string') return null;
  let m = value.match(/^(\d{4})[-/](\d{2})[-/](\d{2})[ T](\d{2}):(\d{2})(?::(\d{2}))?/);
  if (m) return new Date(`${m[1]}-${m[2]}-${m[3]}T${m[4]}:${m[5]}:${m[6] ?? '00'}+08:00`);
  m = value.match(/^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})$/);
  if (m) return new Date(`${m[1]}-${m[2]}-${m[3]}T${m[4]}:${m[5]}:${m[6]}+08:00`);
  m = value.match(/^\w{3} (\w{3}) (\d{1,2}) (\d{2}):(\d{2}):(\d{2}) \w+ (\d{4})$/);
  if (m && MONTHS[m[1]]) {
    const pad = (n) => String(n).padStart(2, '0');
    return new Date(`${m[6]}-${pad(MONTHS[m[1]])}-${pad(m[2])}T${m[3]}:${m[4]}:${m[5]}+08:00`);
  }
  return null;
};

module.exports = { DATASETS, USER_AGENT, fetchBuffer, fetchResponse, decodeText, parseJson, parseCsv, taipeiTime };
