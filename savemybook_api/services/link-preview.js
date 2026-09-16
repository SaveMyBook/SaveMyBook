const crypto = require('crypto');
const { env } = require('../config/env');
const { forbidden, notFound } = require('../lib/errors');
const safeFetch = require('../lib/safe-fetch');
const htmlMeta = require('../lib/html-meta');
const share = require('./share');

const SITE_NAME = '救「舊」我的書';
const MAX_URL_LENGTH = 2048;
const IMAGE_PATH = '/api/chat/link-preview/image';
const BOOK_PATH_RE = /^\/b\/([0-9a-f]{32})\/?$/i;

const LIMITS = {
  timeoutMs: 5000,
  htmlMaxBytes: 1024 * 1024,
  imageMaxBytes: 3 * 1024 * 1024,
  cacheSize: 500,
  hitTtlMs: 24 * 60 * 60 * 1000,
  missTtlMs: 10 * 60 * 1000
};

const USER_AGENT = 'SaveMyBookLinkPreview/1.0 (+https://savemybook.today)';

const HTML_HEADERS = {
  'user-agent': USER_AGENT,
  accept: 'text/html,application/xhtml+xml;q=0.9,*/*;q=0.1',
  'accept-language': 'zh-TW,zh;q=0.9,en;q=0.8',
  'accept-encoding': 'gzip, deflate, br'
};

const IMAGE_HEADERS = {
  'user-agent': USER_AGENT,
  accept: 'image/avif,image/webp,image/png,image/jpeg,image/gif;q=0.9,*/*;q=0.1',
  'accept-encoding': 'identity'
};

const isHtml = (contentType) => /^text\/html(\s*;|$)/.test(contentType);
const isImage = (contentType) => contentType.startsWith('image/') && !contentType.startsWith('image/svg');

const cache = new Map();
const inflight = new Map();

const cacheGet = (key) => {
  const entry = cache.get(key);
  if (!entry) return undefined;
  cache.delete(key);
  if (entry.expiresAt <= Date.now()) return undefined;
  cache.set(key, entry);
  return entry.value;
};

const cacheSet = (key, value) => {
  cache.delete(key);
  cache.set(key, { value, expiresAt: Date.now() + (value ? LIMITS.hitTtlMs : LIMITS.missTtlMs) });
  while (cache.size > LIMITS.cacheSize) cache.delete(cache.keys().next().value);
};

const resetCache = () => {
  cache.clear();
  inflight.clear();
};

let signingKey = null;
const keyOf = () => {
  signingKey ??= crypto.createHmac('sha256', env.jwtSecret || 'savemybook').update('link-preview-image-v1').digest();
  return signingKey;
};

const macOf = (payload) => crypto.createHmac('sha256', keyOf()).update(payload).digest('base64url');

const signImage = (url) => {
  const payload = Buffer.from(url, 'utf8').toString('base64url');
  return `${payload}.${macOf(payload)}`;
};

const verifyImage = (token) => {
  if (typeof token !== 'string' || token.length > MAX_URL_LENGTH * 2) return null;
  const parts = token.split('.');
  if (parts.length !== 2 || !parts[0] || !parts[1]) return null;
  const given = Buffer.from(parts[1]);
  const expected = Buffer.from(macOf(parts[0]));
  if (given.length !== expected.length || !crypto.timingSafeEqual(given, expected)) return null;
  return Buffer.from(parts[0], 'base64url').toString('utf8');
};

const imageUrlFor = (url) => `${IMAGE_PATH}?u=${signImage(url)}`;

const normalize = (raw) => {
  const text = String(raw ?? '').trim();
  if (!text || text.length > MAX_URL_LENGTH) return null;
  try {
    const url = new URL(text);
    if (url.protocol !== 'http:' && url.protocol !== 'https:') return null;
    url.hash = '';
    return url;
  } catch {
    return null;
  }
};

const isInternal = (url) => {
  if (!env.publicWebUrl) return false;
  try {
    return new URL(env.publicWebUrl).hostname.toLowerCase() === url.hostname.toLowerCase();
  } catch {
    return false;
  }
};

const bookPreview = async (url) => {
  const match = BOOK_PATH_RE.exec(url.pathname);
  if (!match) return null;
  const book = await share.publicBookByToken(match[1].toLowerCase());
  if (!book) return null;
  return {
    url: url.href,
    site_name: SITE_NAME,
    title: htmlMeta.cleanText(book.title, 120),
    description: htmlMeta.cleanText(book.author ?? '', 200) || null,
    image_url: book.book_images?.[0]?.image_url ?? null,
    kind: 'book',
    price: Number(book.price)
  };
};

const decodeHtml = (body, contentType) => {
  const declared = /charset\s*=\s*["']?([\w.:-]+)/i.exec(contentType)?.[1]
    ?? /<meta[^>]{0,200}charset\s*=\s*["']?([\w.:-]+)/i.exec(body.subarray(0, 4096).toString('latin1'))?.[1]
    ?? 'utf-8';
  try {
    return new TextDecoder(declared).decode(body);
  } catch {
    return new TextDecoder('utf-8').decode(body);
  }
};

const absoluteImage = (raw, base) => {
  if (!raw) return null;
  try {
    const url = new URL(raw, base);
    if (url.protocol !== 'http:' && url.protocol !== 'https:') return null;
    if (url.username || url.password || url.href.length > MAX_URL_LENGTH) return null;
    return url.href;
  } catch {
    return null;
  }
};

const webPreview = async (href) => {
  const result = await safeFetch.fetchSafely(href, {
    maxBytes: LIMITS.htmlMaxBytes,
    overflow: 'truncate',
    accept: isHtml,
    headers: HTML_HEADERS,
    timeoutMs: LIMITS.timeoutMs
  });
  const meta = htmlMeta.extract(decodeHtml(result.body, result.contentType));
  if (!meta.title) return null;

  const finalUrl = new URL(result.url);
  const image = absoluteImage(meta.image, finalUrl);
  return {
    url: href,
    site_name: meta.siteName || finalUrl.hostname.replace(/^www\./, ''),
    title: meta.title,
    description: meta.description || null,
    image_url: image ? imageUrlFor(image) : null,
    kind: 'web'
  };
};

const preview = async (raw) => {
  const url = normalize(raw);
  if (!url) return null;
  if (isInternal(url)) return bookPreview(url);

  const key = url.href;
  const hit = cacheGet(key);
  if (hit !== undefined) return hit;
  if (inflight.has(key)) return inflight.get(key);

  const task = webPreview(key)
    .catch((err) => {
      if (!(err instanceof safeFetch.FetchError)) console.error('[連結預覽失敗]:', err);
      return null;
    })
    .then((value) => {
      cacheSet(key, value);
      inflight.delete(key);
      return value;
    });
  inflight.set(key, task);
  return task;
};

const sniffImage = (buf) => {
  if (buf.length < 12) return null;
  if (buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return 'image/jpeg';
  if (buf.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) return 'image/png';
  if (buf.toString('latin1', 0, 6) === 'GIF87a' || buf.toString('latin1', 0, 6) === 'GIF89a') return 'image/gif';
  if (buf.toString('latin1', 0, 4) === 'RIFF' && buf.toString('latin1', 8, 12) === 'WEBP') return 'image/webp';
  if (buf.toString('latin1', 4, 8) === 'ftyp' && /^(avif|avis)$/.test(buf.toString('latin1', 8, 12))) return 'image/avif';
  if (buf[0] === 0x42 && buf[1] === 0x4d) return 'image/bmp';
  if (buf[0] === 0 && buf[1] === 0 && buf[2] === 1 && buf[3] === 0) return 'image/x-icon';
  return null;
};

const image = async (token) => {
  const target = verifyImage(token);
  if (!target) throw forbidden('圖片連結無效');

  let result;
  try {
    result = await safeFetch.fetchSafely(target, {
      maxBytes: LIMITS.imageMaxBytes,
      overflow: 'reject',
      accept: isImage,
      headers: IMAGE_HEADERS,
      timeoutMs: LIMITS.timeoutMs
    });
  } catch (err) {
    if (!(err instanceof safeFetch.FetchError)) console.error('[連結預覽圖片失敗]:', err);
    throw notFound('無法載入圖片');
  }
  const contentType = sniffImage(result.body);
  if (!contentType) throw notFound('無法載入圖片');
  return { contentType, body: result.body };
};

module.exports = { MAX_URL_LENGTH, LIMITS, preview, image, signImage, verifyImage, resetCache };
