const dns = require('node:dns');
const http = require('node:http');
const https = require('node:https');
const net = require('node:net');
const zlib = require('node:zlib');

const MAX_REDIRECTS = 3;
const REDIRECT_STATUSES = new Set([301, 302, 303, 307, 308]);
const ALLOWED_PORTS = new Set(['', '80', '443']);

class FetchError extends Error {
  constructor(reason) {
    super(reason);
    this.reason = reason;
  }
}

const fail = (reason) => new FetchError(reason);

const ipv4ToInt = (text) => {
  const parts = text.split('.');
  if (parts.length !== 4) return null;
  let value = 0;
  for (const part of parts) {
    if (!/^\d{1,3}$/.test(part) || Number(part) > 255) return null;
    value = value * 256 + Number(part);
  }
  return value;
};

const V4_BLOCKED = [
  ['0.0.0.0', 8],
  ['10.0.0.0', 8],
  ['100.64.0.0', 10],
  ['127.0.0.0', 8],
  ['169.254.0.0', 16],
  ['172.16.0.0', 12],
  ['192.0.0.0', 24],
  ['192.0.2.0', 24],
  ['192.88.99.0', 24],
  ['192.168.0.0', 16],
  ['198.18.0.0', 15],
  ['198.51.100.0', 24],
  ['203.0.113.0', 24],
  ['224.0.0.0', 4],
  ['240.0.0.0', 4]
].map(([base, prefix]) => ({ base: ipv4ToInt(base), prefix }));

const inV4 = (value, { base, prefix }) => {
  const size = 2 ** (32 - prefix);
  return Math.floor(value / size) === Math.floor(base / size);
};

const isBlockedV4 = (value) => value === null || V4_BLOCKED.some((range) => inV4(value, range));

const ipv6ToBigInt = (text) => {
  let addr = String(text).split('%')[0];
  const lastColon = addr.lastIndexOf(':');
  if (lastColon === -1) return null;
  const tail = addr.slice(lastColon + 1);
  if (tail.includes('.')) {
    const v4 = ipv4ToInt(tail);
    if (v4 === null) return null;
    addr = `${addr.slice(0, lastColon + 1)}${Math.floor(v4 / 65536).toString(16)}:${(v4 % 65536).toString(16)}`;
  }
  const halves = addr.split('::');
  if (halves.length > 2) return null;
  const head = halves[0] ? halves[0].split(':') : [];
  const rest = halves.length === 2 ? (halves[1] ? halves[1].split(':') : []) : null;
  const groups = rest === null ? head : [...head, ...Array(8 - head.length - rest.length).fill('0'), ...rest];
  if (groups.length !== 8 || groups.some((g) => !/^[0-9a-f]{1,4}$/i.test(g))) return null;
  return groups.reduce((acc, g) => (acc << 16n) | BigInt(parseInt(g, 16)), 0n);
};

const v6Range = (base, prefix) => ({ base: ipv6ToBigInt(base), prefix: BigInt(prefix) });

const inV6 = (value, { base, prefix }) => {
  const shift = 128n - prefix;
  return value >> shift === base >> shift;
};

const V6_MAPPED = v6Range('::ffff:0:0', 96);
const V6_NAT64 = v6Range('64:ff9b::', 96);
const V6_GLOBAL = v6Range('2000::', 3);

const V6_BLOCKED = [
  v6Range('fc00::', 7),
  v6Range('fe80::', 10),
  v6Range('fec0::', 10),
  v6Range('ff00::', 8),
  v6Range('fd00:ec2::254', 128),
  v6Range('2001::', 23),
  v6Range('2001:db8::', 32),
  v6Range('2002::', 16),
  v6Range('3fff::', 20)
];

const isBlockedAddress = (address) => {
  const family = net.isIP(address);
  if (family === 4) return isBlockedV4(ipv4ToInt(address));
  if (family !== 6) return true;

  const value = ipv6ToBigInt(address);
  if (value === null) return true;
  // IPv4-mapped 與 NAT64 位址實際連到內嵌的 IPv4，必須以 IPv4 規則判斷。
  if (inV6(value, V6_MAPPED) || inV6(value, V6_NAT64)) return isBlockedV4(Number(value & 0xffffffffn));
  if (value >> 32n === 0n) return true;
  if (V6_BLOCKED.some((range) => inV6(value, range))) return true;
  return !inV6(value, V6_GLOBAL);
};

const hostnameOf = (url) => url.hostname.replace(/^\[|\]$/g, '').toLowerCase();

const parseTarget = (raw) => {
  let url;
  try {
    url = new URL(raw);
  } catch {
    throw fail('invalid_url');
  }
  if (url.protocol !== 'http:' && url.protocol !== 'https:') throw fail('scheme');
  if (url.username || url.password) throw fail('credentials');
  if (!ALLOWED_PORTS.has(url.port)) throw fail('port');

  const hostname = hostnameOf(url);
  if (!hostname) throw fail('host');
  if (!net.isIP(hostname)) {
    if (!hostname.includes('.') || hostname === 'localhost' || hostname.endsWith('.localhost')) throw fail('host');
  }
  return url;
};

const lookupAll = (hostname) => new Promise((resolve, reject) => {
  dns.lookup(hostname, { all: true, verbatim: true }, (err, addresses) => {
    if (err) return reject(fail('dns'));
    resolve(addresses);
  });
});

const untilAbort = (promise, signal) => new Promise((resolve, reject) => {
  if (signal.aborted) return reject(fail('timeout'));
  const onAbort = () => reject(fail('timeout'));
  signal.addEventListener('abort', onAbort, { once: true });
  promise.then(resolve, reject).finally(() => signal.removeEventListener('abort', onAbort));
});

const resolveTarget = async (url, signal) => {
  const hostname = hostnameOf(url);
  const family = net.isIP(hostname);
  const addresses = family ? [{ address: hostname, family }] : await untilAbort(lookupAll(hostname), signal);
  if (!Array.isArray(addresses) || addresses.length === 0) throw fail('dns');
  if (addresses.some((entry) => isBlockedAddress(entry.address))) throw fail('blocked_address');
  const [first] = addresses;
  return { address: first.address, family: net.isIP(first.address) };
};

// 連線只能使用已檢查過的位址；若交給系統再解析一次，DNS rebinding 可在檢查後換成內部位址。
const pinnedLookup = ({ address, family }) => (_hostname, options, callback) => {
  if (options && options.all) return callback(null, [{ address, family }]);
  callback(null, address, family);
};

const openRequest = (url, target, { headers, signal }) => new Promise((resolve, reject) => {
  const secure = url.protocol === 'https:';
  const hostname = hostnameOf(url);
  const client = secure ? https : http;
  const req = client.request({
    protocol: url.protocol,
    hostname,
    port: url.port || (secure ? 443 : 80),
    path: `${url.pathname}${url.search}`,
    method: 'GET',
    headers,
    agent: false,
    signal,
    lookup: pinnedLookup(target),
    ...(secure && !net.isIP(hostname) && { servername: hostname })
  }, (res) => {
    res.on('error', () => {});
    resolve(res);
  });
  req.on('error', () => reject(fail(signal.aborted ? 'timeout' : 'connect')));
  req.end();
});

const DECODERS = {
  gzip: () => zlib.createGunzip(),
  'x-gzip': () => zlib.createGunzip(),
  deflate: () => zlib.createInflate(),
  br: () => zlib.createBrotliDecompress()
};

const readBody = (res, { maxBytes, overflow, signal }) => new Promise((resolve, reject) => {
  const encoding = String(res.headers['content-encoding'] ?? '').trim().toLowerCase();
  const declared = Number(res.headers['content-length']);
  if (overflow === 'reject' && Number.isFinite(declared) && declared > maxBytes) {
    res.destroy();
    return reject(fail('too_large'));
  }

  let stream = res;
  if (encoding && encoding !== 'identity') {
    const decoder = DECODERS[encoding];
    if (!decoder) {
      res.destroy();
      return reject(fail('encoding'));
    }
    stream = res.pipe(decoder());
  }

  const chunks = [];
  let size = 0;
  let settled = false;

  const finish = (err, value) => {
    if (settled) return;
    settled = true;
    signal.removeEventListener('abort', onAbort);
    if (stream !== res) stream.destroy();
    res.destroy();
    if (err) reject(err);
    else resolve(value);
  };
  const onAbort = () => finish(fail('timeout'));
  signal.addEventListener('abort', onAbort, { once: true });

  stream.on('data', (chunk) => {
    if (settled) return;
    const room = maxBytes - size;
    if (chunk.length > room) {
      if (overflow === 'reject') return finish(fail('too_large'));
      chunks.push(chunk.subarray(0, room));
      size = maxBytes;
      return finish(null, Buffer.concat(chunks));
    }
    chunks.push(chunk);
    size += chunk.length;
  });
  stream.on('end', () => finish(null, Buffer.concat(chunks)));
  stream.on('error', () => finish(fail(signal.aborted ? 'timeout' : 'read')));
  if (stream !== res) res.on('error', () => finish(fail(signal.aborted ? 'timeout' : 'read')));
});

const fetchSafely = async (raw, { maxBytes, overflow = 'reject', accept, headers = {}, timeoutMs }) => {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  const { signal } = controller;
  try {
    let url = parseTarget(raw);
    for (let hop = 0; ; hop += 1) {
      const target = await resolveTarget(url, signal);
      const res = await untilAbort(openRequest(url, target, { headers, signal }), signal);

      if (REDIRECT_STATUSES.has(res.statusCode)) {
        res.destroy();
        const location = res.headers.location;
        if (!location || hop >= MAX_REDIRECTS) throw fail('redirect');
        let next;
        try {
          next = new URL(location, url).href;
        } catch {
          throw fail('redirect');
        }
        url = parseTarget(next);
        continue;
      }

      if (res.statusCode < 200 || res.statusCode >= 300) {
        res.destroy();
        throw fail('status');
      }
      const contentType = String(res.headers['content-type'] ?? '').toLowerCase();
      if (!accept(contentType)) {
        res.destroy();
        throw fail('content_type');
      }
      const body = await readBody(res, { maxBytes, overflow, signal });
      return { url: url.href, contentType, body };
    }
  } finally {
    clearTimeout(timer);
  }
};

module.exports = {
  MAX_REDIRECTS, FetchError, isBlockedAddress, parseTarget, pinnedLookup, openRequest, fetchSafely
};
