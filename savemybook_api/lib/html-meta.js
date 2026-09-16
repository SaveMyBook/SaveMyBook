const NAMED_ENTITIES = {
  amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ', ndash: '–', mdash: '—', hellip: '…',
  lsquo: '‘', rsquo: '’', ldquo: '“', rdquo: '”', middot: '·', bull: '•', copy: '©', reg: '®', trade: '™',
  laquo: '«', raquo: '»', times: '×', yen: '¥', euro: '€', pound: '£'
};

const RAW_TEXT = new Set(['script', 'style', 'title', 'textarea', 'noscript', 'template']);
const RAW_VALUE_LIMIT = 4000;

const decodeEntities = (text) => text.replace(/&(#x[0-9a-f]{1,6}|#\d{1,7}|[a-z][a-z0-9]{1,31});?/gi, (match, name) => {
  if (name[0] === '#') {
    const code = name[1] === 'x' || name[1] === 'X' ? parseInt(name.slice(2), 16) : parseInt(name.slice(1), 10);
    const valid = code > 0 && code <= 0x10ffff && !(code >= 0xd800 && code <= 0xdfff);
    return valid ? String.fromCodePoint(code) : '';
  }
  return NAMED_ENTITIES[name.toLowerCase()] ?? match;
});

const clipChars = (text, max) => {
  const chars = Array.from(text);
  return chars.length > max ? `${chars.slice(0, max - 1).join('').trimEnd()}…` : text;
};

const cleanText = (value, max) => {
  if (typeof value !== 'string') return '';
  const decoded = decodeEntities(value.slice(0, RAW_VALUE_LIMIT))
    .replace(/<[^<>]*>/g, ' ')
    .replace(/[\u0000-\u001f\u007f-\u009f\u00ad\u200b-\u200f\u2028-\u202e\u2060-\u206f\ufeff\ufff9-\ufffb]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  return clipChars(decoded, max);
};

const parseAttributes = (source) => {
  const attrs = {};
  const re = /([^\s"'<>/=]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+)))?/g;
  let m;
  while ((m = re.exec(source)) !== null) {
    const name = m[1].toLowerCase();
    if (!(name in attrs)) attrs[name] = m[2] ?? m[3] ?? m[4] ?? '';
  }
  return attrs;
};

// 屬性值內可能含有 >，須略過引號內的字元；找不到結尾時回傳 -1，呼叫端立即停止以維持線性時間。
const findTagEnd = (html, from) => {
  let quote = null;
  let afterEquals = false;
  for (let i = from; i < html.length; i += 1) {
    const ch = html[i];
    if (quote) {
      if (ch === quote) quote = null;
      continue;
    }
    if (ch === '>') return i;
    if ((ch === '"' || ch === "'") && afterEquals) {
      quote = ch;
      afterEquals = false;
      continue;
    }
    if (ch === '=') afterEquals = true;
    else if (!/\s/.test(ch)) afterEquals = false;
  }
  return -1;
};

const scan = (html) => {
  const lower = html.replace(/[A-Z]+/g, (s) => s.toLowerCase());
  const metas = [];
  let title = null;
  let i = 0;

  while ((i = lower.indexOf('<', i)) !== -1) {
    if (lower.startsWith('<!--', i)) {
      const end = lower.indexOf('-->', i + 4);
      if (end === -1) break;
      i = end + 3;
      continue;
    }
    const tag = /^<(\/?)([a-z][a-z0-9-]*)/.exec(lower.slice(i, i + 40));
    if (!tag) {
      i += 1;
      continue;
    }
    const [head, closing, name] = tag;
    const end = findTagEnd(html, i + head.length);
    if (end === -1) break;

    if (closing) {
      if (name === 'head') break;
      i = end + 1;
      continue;
    }
    if (name === 'body') break;
    if (RAW_TEXT.has(name)) {
      const close = lower.indexOf(`</${name}`, end + 1);
      if (close === -1) break;
      if (name === 'title' && title === null) title = html.slice(end + 1, close);
      i = close;
      continue;
    }
    if (name === 'meta') metas.push(parseAttributes(html.slice(i + head.length, end)));
    i = end + 1;
  }
  return { metas, title };
};

const extract = (html) => {
  const { metas, title } = scan(String(html ?? ''));
  const values = new Map();
  for (const attrs of metas) {
    const key = String(attrs.property ?? attrs.name ?? attrs.itemprop ?? '').trim().toLowerCase();
    if (!key || typeof attrs.content !== 'string' || values.has(key)) continue;
    if (attrs.content.trim()) values.set(key, attrs.content);
  }
  const first = (keys, max) => {
    for (const key of keys) {
      const text = cleanText(values.get(key), max);
      if (text) return text;
    }
    return '';
  };
  const firstRaw = (keys) => {
    for (const key of keys) {
      const value = decodeEntities(String(values.get(key) ?? '').slice(0, RAW_VALUE_LIMIT)).trim();
      if (value) return value;
    }
    return '';
  };

  return {
    title: first(['og:title', 'twitter:title'], 120) || cleanText(title ?? '', 120),
    description: first(['og:description', 'twitter:description', 'description'], 200),
    siteName: first(['og:site_name', 'application-name'], 60),
    image: firstRaw(['og:image', 'og:image:url', 'og:image:secure_url', 'twitter:image', 'twitter:image:src'])
  };
};

module.exports = { extract, cleanText, decodeEntities };
