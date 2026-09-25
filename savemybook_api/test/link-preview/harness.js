// 連結預覽測試：以假的 node:dns 與 node:http(s) 取代對外連線，記錄每一次解析與實際連線的位址。
const dns = require('node:dns');
const http = require('node:http');
const https = require('node:https');
const net = require('node:net');
const { PassThrough } = require('node:stream');

const server = require('../lib/server');
const { registerModels } = require('../lib/fake-prisma');
const authToken = server.api('lib/auth-token');
const linkPreview = server.api('services/link-preview');

registerModels({ autoKeys: { books: 'book_id' } });

const dnsTable = new Map();
const dnsLog = [];

const realLookup = dns.lookup;
dns.lookup = (hostname, options, callback) => {
  if (net.isIP(hostname)) return realLookup(hostname, options, callback);
  const cb = typeof options === 'function' ? options : callback;
  dnsLog.push(hostname);
  const entry = dnsTable.get(hostname);
  if (!entry) return process.nextTick(() => cb(Object.assign(new Error(`ENOTFOUND ${hostname}`), { code: 'ENOTFOUND' })));
  const list = typeof entry === 'function' ? entry() : entry;
  const addresses = list.map((address) => ({ address, family: net.isIP(address) }));
  process.nextTick(() => cb(null, addresses));
};

const setDns = (hostname, addresses) => dnsTable.set(hostname, addresses);

const sites = new Map();
const connections = [];
const passthroughHosts = new Set();

const site = (url, handler) => sites.set(url, handler);

const html = (body, { status = 200, headers = {} } = {}) => ({
  status,
  headers: { 'content-type': 'text/html; charset=utf-8', ...headers },
  body
});

const fakeRequest = (secure, original) => (options, callback) => {
  if (passthroughHosts.has(options.hostname)) return original(options, callback);

  const req = new PassThrough();
  req.setTimeout = () => req;
  req.abort = () => req.destroy();
  const signal = options.signal;

  req.end = () => {
    const connect = (address) => {
      const url = `${secure ? 'https' : 'http'}://${net.isIP(options.hostname) === 6 ? `[${options.hostname}]` : options.hostname}${options.path}`;
      const record = { url, hostname: options.hostname, address, port: options.port, headers: options.headers, bytesSent: 0 };
      connections.push(record);
      const handler = sites.get(url);
      if (!handler) return req.emit('error', Object.assign(new Error('ECONNREFUSED'), { code: 'ECONNREFUSED' }));

      Promise.resolve(typeof handler === 'function' ? handler(record) : handler).then(async (spec) => {
        if (spec.delayMs) await new Promise((r) => setTimeout(r, spec.delayMs));
        if (signal?.aborted) return;
        const res = new PassThrough();
        res.statusCode = spec.status ?? 200;
        res.headers = Object.fromEntries(Object.entries(spec.headers ?? {}).map(([k, val]) => [k.toLowerCase(), val]));
        callback(res);
        const chunks = Array.isArray(spec.body) ? spec.body : [spec.body ?? ''];
        for (const chunk of chunks) {
          if (res.destroyed || signal?.aborted) return;
          const buf = Buffer.isBuffer(chunk) ? chunk : Buffer.from(String(chunk));
          record.bytesSent += buf.length;
          res.write(buf);
          await new Promise((r) => setImmediate(r));
          if (spec.chunkDelayMs) await new Promise((r) => setTimeout(r, spec.chunkDelayMs));
        }
        if (!res.destroyed) res.end();
      });
    };

    signal?.addEventListener('abort', () => req.emit('error', Object.assign(new Error('aborted'), { name: 'AbortError' })), { once: true });

    if (net.isIP(options.hostname)) return process.nextTick(() => connect(options.hostname));
    options.lookup(options.hostname, { all: true }, (err, list) => {
      if (err) return req.emit('error', err);
      connect(list[0].address);
    });
  };
  return req;
};

const realHttpRequest = http.request;
const realHttpsRequest = https.request;
http.request = fakeRequest(false, realHttpRequest);
https.request = fakeRequest(true, realHttpsRequest);

// 限流以使用者計數且跨測試保留，每個測試都要換新的使用者編號。
let userSeq = 0;
const addUser = () => {
  userSeq += 1;
  const userId = userSeq;
  const row = {
    user_id: userId, email: `user${userId}@example.com`, password_hash: 'hash', nickname: '測試使用者',
    role: 'buyer_seller', is_active: true, is_blacklisted: false, anonymized_at: null
  };
  server.prisma.rows('users').push(row);
  return { row, token: authToken.signToken(row) };
};

const addBook = (overrides = {}) => {
  const bookId = server.prisma.rows('books').length + 1;
  const row = {
    book_id: bookId,
    share_token: `${String(bookId).padStart(2, '0')}${'ab'.repeat(15)}`,
    title: '深入淺出統計學',
    author: '王大明',
    price: 350,
    status: 'on_sale',
    is_approved: true,
    condition_level: 'good',
    book_categories: { category_name: '教科書' },
    book_images: [{ image_url: '/uploads/books/cover.jpg' }],
    users: { nickname: '賣家', avatar_url: null, is_active: true, is_blacklisted: false, anonymized_at: null },
    ...overrides
  };
  server.prisma.rows('books').push(row);
  return row;
};

const DEFAULT_LIMITS = { ...linkPreview.LIMITS };

server.onReset(() => {
  dnsTable.clear();
  dnsLog.length = 0;
  sites.clear();
  connections.length = 0;
  passthroughHosts.clear();
  Object.assign(linkPreview.LIMITS, DEFAULT_LIMITS);
  linkPreview.resetCache();
});

server.setDefaultReset(() => server.reset({ tables: { users: [], books: [] } }));

const previewOf = async (token, url) => {
  const res = await server.request('GET', `/api/chat/link-preview?url=${encodeURIComponent(url)}`, { token });
  if (res.status !== 200) throw new Error(`預期 200，實際為 ${res.status}：${res.text}`);
  return res.body.data;
};

const signedTarget = (imageUrl) => linkPreview.verifyImage(new URL(imageUrl, 'http://placeholder').searchParams.get('u'));

module.exports = {
  ...server, dns, realLookup, setDns, dnsLog, site, html, sites, connections, passthroughHosts,
  realHttpRequest, addUser, addBook, linkPreview, previewOf, signedTarget
};
