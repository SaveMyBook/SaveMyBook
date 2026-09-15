const { clip } = require('../../lib/text');

const isUnsafeChar = (code) => (code < 32 && code !== 9 && code !== 10 && code !== 13) || code === 127
  || (code >= 0x200b && code <= 0x200f) || (code >= 0x202a && code <= 0x202e) || (code >= 0x2066 && code <= 0x2069);

const stripControls = (s) => Array.from(s).filter((ch) => !isUnsafeChar(ch.codePointAt(0))).join('');

// 模型輸出一律視為不可信任：移除控制字元與 HTML 標籤後再截斷。
const sanitizeText = (value, max) => {
  if (typeof value !== 'string' && typeof value !== 'number') return '';
  const s = stripControls(String(value))
    .replace(/<\/?[a-zA-Z][^>]*>/g, '')
    .replace(/\r\n?/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
  return max ? clip(s, max) : s;
};

const sanitizeLine = (value, max) => {
  const s = sanitizeText(value).replace(/\s+/g, ' ').trim();
  return max ? clip(s, max) : s;
};

const stringList = (value, { max = 5, maxLength = 80 } = {}) => {
  if (!Array.isArray(value)) return [];
  const out = [];
  for (const item of value) {
    const s = sanitizeLine(item, maxLength);
    if (s && !out.includes(s)) out.push(s);
    if (out.length >= max) break;
  }
  return out;
};

const clamp01 = (value) => {
  const n = Number(value);
  if (!Number.isFinite(n)) return 0;
  return Math.round(Math.min(1, Math.max(0, n)) * 100) / 100;
};

const safeUrl = (value) => {
  if (typeof value !== 'string' || value.length > 500) return null;
  try {
    const url = new URL(value.trim());
    return ['http:', 'https:'].includes(url.protocol) ? url.toString() : null;
  } catch {
    return null;
  }
};

module.exports = { sanitizeText, sanitizeLine, stringList, clamp01, safeUrl };
