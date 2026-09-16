// 測試共用底層：以假的 Prisma Client 與假的對外 fetch 直接驅動本專案的 Express 路由。
// 每個測試組（test/<組名>）是獨立行程，因此這裡的狀態不會跨組互相影響。
const http = require('http');
const path = require('path');
const Module = require('module');
const { FakePrisma } = require('./fake-prisma');

const API_ROOT = path.join(__dirname, '..', '..');

process.env.NODE_ENV = 'test';
process.env.DATABASE_URL ||= 'mysql://test:test@127.0.0.1:3306/savemybook_test';
process.env.JWT_SECRET = 'test-secret-0123456789012345678901234567890123';
process.env.PUBLIC_ID_SECRET ||= 'test-public-id-secret';
process.env.PUBLIC_WEB_URL ||= 'https://example.test';
process.env.PUSH_ENABLED = 'false';
process.env.BACKUP_ENABLED = 'false';
delete process.env.FCM_SERVICE_ACCOUNT_FILE;
delete process.env.GOOGLE_APPLICATION_CREDENTIALS;

const prisma = new FakePrisma();

// 必須在載入任何 API 模組之前替換掉 Prisma，否則 lib/prisma.js 會嘗試真的連線。
const originalLoad = Module._load;
Module._load = function patched(request, parent, isMain) {
  if (request === '@prisma/client') {
    return { PrismaClient: function PrismaClient() { return prisma; }, $Enums: {} };
  }
  if (request === '@prisma/adapter-mariadb') {
    return { PrismaMariaDb: function PrismaMariaDb() { return {}; } };
  }
  return originalLoad.call(this, request, parent, isMain);
};

const api = (relative) => require(path.join(API_ROOT, relative));

// ---------- 對外 fetch ----------

// 測試自己送出的 HTTP 請求要用真正的 fetch，必須在覆寫前先留下來。
const realFetch = global.fetch;
const fetchRoutes = [];
const fetchLog = [];

const onFetch = (matcher, handler) => fetchRoutes.push({ matcher, handler });

const jsonResponse = (body, { status = 200, headers = {} } = {}) => new Response(JSON.stringify(body), {
  status,
  headers: { 'content-type': 'application/json', ...headers }
});

global.fetch = async (input, init = {}) => {
  // 部分模組以 URL 物件呼叫 fetch（例如 lib/google-books），一律先轉成字串再比對。
  const url = typeof input === 'string' ? input : input instanceof URL ? input.href : input.url;
  fetchLog.push({ url, init });
  for (const route of fetchRoutes) {
    if (typeof route.matcher === 'string' ? url.startsWith(route.matcher) : route.matcher.test(url)) {
      return route.handler(url, init);
    }
  }
  throw new Error(`測試未攔截的對外請求：${url}`);
};

// ---------- 重設 ----------

const resetHooks = [];

// 測試組以 onReset() 登記自己要清掉的快取（schema-check、各服務的設定快取等）。
const onReset = (fn) => resetHooks.push(fn);

let clientIpSeq = 0;
let clientIp = '10.0.0.1';

const reset = ({ schema, tables = {} } = {}) => {
  prisma.store = { ...tables };
  if (schema) prisma.schema = schema;
  prisma.sqlLog = [];
  fetchLog.length = 0;
  // 限流以來源 IP 計數，每個測試換一組 IP 才不會互相干擾（trust proxy 為 loopback）。
  clientIpSeq += 1;
  clientIp = `10.${Math.floor(clientIpSeq / 65536) % 256}.${Math.floor(clientIpSeq / 256) % 256}.${clientIpSeq % 256}`;
  for (const hook of resetHooks) hook();
};

// 測試組可用 setDefaultReset() 指定「每個測試前要做的重設」，runSuite 會改呼叫它。
let defaultReset = reset;
const setDefaultReset = (fn) => { defaultReset = fn; };

// ---------- HTTP ----------

const express = api('node_modules/express');
const { registerRoutes } = api('routes');
const { ensureBody } = api('middleware/security');
const { notFound, errorHandler } = api('middleware/errorHandler');

const app = express();
app.set('trust proxy', 'loopback');
app.use(express.json({ limit: '1mb' }));
app.use(ensureBody);
registerRoutes(app);
app.use(notFound);
app.use(errorHandler);

const server = http.createServer(app);
let baseUrl = null;

const listen = () => new Promise((resolve) => {
  server.listen(0, '127.0.0.1', () => {
    baseUrl = `http://127.0.0.1:${server.address().port}`;
    resolve();
  });
});

const close = () => new Promise((resolve) => server.close(resolve));

const request = async (method, url, { body, token, headers = {}, raw } = {}) => {
  const isForm = raw instanceof FormData;
  const response = await realFetch(`${baseUrl}${url}`, {
    method,
    redirect: 'manual',
    headers: {
      ...(body ? { 'content-type': 'application/json' } : {}),
      ...(token ? { authorization: `Bearer ${token}` } : {}),
      'x-forwarded-for': clientIp,
      ...headers
    },
    ...(isForm ? { body: raw } : body ? { body: JSON.stringify(body) } : {})
  });
  const text = await response.text();
  let json = null;
  try {
    json = JSON.parse(text);
  } catch {
    json = null;
  }
  return { status: response.status, body: json, text, headers: response.headers };
};

// ---------- 測試執行 ----------

// tests 是 [標題, 函式] 的陣列；每個測試前會自動 reset()。
const runSuite = async (name, tests, { before } = {}) => {
  if (!baseUrl) await listen();
  let passed = 0;
  const failures = [];
  console.log(`\n=== ${name} ===`);
  for (const [label, fn] of tests) {
    try {
      defaultReset();
      if (before) await before();
      await fn();
      passed += 1;
      console.log(`  ✅ ${label}`);
    } catch (err) {
      failures.push(`${name} › ${label}：${err.message}`);
      console.log(`  ❌ ${label}\n     ${err.stack?.split('\n').slice(0, 4).join('\n     ')}`);
    }
  }
  console.log(`  ${passed}/${tests.length} 通過`);
  return { passed, total: tests.length, failures };
};

// 逐一執行資料夾內所有 *.js 測試檔（除了 harness 與 run-all），回報總計並設定 exit code。
const runFolder = async (dir, { skip = [] } = {}) => {
  const fs = require('fs');
  const ignored = new Set(['harness.js', 'fake-prisma.js', 'run-all.js', ...skip]);
  const files = fs.readdirSync(dir).filter((f) => f.endsWith('.js') && !ignored.has(f)).sort();
  const failures = [];
  let passed = 0;
  let total = 0;

  for (const file of files) {
    const suite = require(path.join(dir, file));
    if (!suite?.tests) continue;
    const result = await runSuite(suite.name ?? file, suite.tests, { before: suite.before });
    passed += result.passed;
    total += result.total;
    failures.push(...result.failures);
  }

  await close();
  console.log(`\n總計 ${passed}/${total} 通過`);
  if (failures.length) {
    console.log('\n未通過：');
    for (const item of failures) console.log(`  - ${item}`);
  }
  process.exit(failures.length ? 1 : 0);
};

module.exports = {
  API_ROOT, prisma, api, reset, onReset, setDefaultReset, onFetch, jsonResponse, fetchLog, realFetch,
  request, listen, close, runSuite, runFolder, clientIp: () => clientIp
};
