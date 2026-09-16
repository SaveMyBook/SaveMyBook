const crypto = require('crypto');
const { env } = require('../config/env');

const ALPHABET = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
const LENGTH = 7;

let cachedKey = null;
const secretKey = () => {
  if (cachedKey) return cachedKey;
  const base = env.publicIdSecret || env.jwtSecret || 'savemybook';
  cachedKey = crypto.createHmac('sha256', base).update('public-id-v1').digest();
  return cachedKey;
};

const roundValue = (prefix, round, half) =>
  crypto.createHmac('sha256', secretKey()).update(`${prefix}:${round}:${half}`).digest().readUInt16BE(0);

const permute = (prefix, value) => {
  let left = value >>> 16;
  let right = value & 0xffff;
  for (let round = 0; round < 4; round += 1) {
    [left, right] = [right, left ^ roundValue(prefix, round, right)];
  }
  return ((left << 16) | right) >>> 0;
};

const unpermute = (prefix, value) => {
  let left = value >>> 16;
  let right = value & 0xffff;
  for (let round = 3; round >= 0; round -= 1) {
    [left, right] = [right ^ roundValue(prefix, round, left), left];
  }
  return ((left << 16) | right) >>> 0;
};

const toBase32 = (n) => {
  let out = '';
  let value = n;
  for (let i = 0; i < LENGTH; i += 1) {
    out = ALPHABET[value % 32] + out;
    value = Math.floor(value / 32);
  }
  return out;
};

const fromBase32 = (text) => {
  let value = 0;
  for (const ch of text) {
    const index = ALPHABET.indexOf(ch);
    if (index < 0) return null;
    value = value * 32 + index;
  }
  return value;
};

const PREFIX = {
  transaction: 'TX',
  log: 'LG',
  maintenance: 'MT',
  user: 'MB',
  member: 'MB',
  wallet: 'MB',
  password: 'MB',
  book: 'BK',
  order: 'OD',
  category: 'CT',
  book_category: 'CT',
  cabinet: 'CB',
  cabinet_slot: 'SL',
  report: 'RP',
  dispute: 'DP',
  ticket: 'TK',
  faq: 'FQ',
  legal: 'LD',
  announcement: 'AN',
  member_level: 'LV',
  level: 'LV',
  backup: 'BU',
  reservation: 'RS',
  transfer: 'TF',
  passkey: 'PK'
};

const prefixOf = (type) => PREFIX[type] ?? 'ID';

const encode = (type, id) => {
  const n = Number(id);
  if (!Number.isSafeInteger(n) || n < 0 || n > 0xffffffff) return null;
  const prefix = prefixOf(type);
  return `${prefix}${toBase32(permute(prefix, n))}`;
};

const decode = (type, code) => {
  const prefix = prefixOf(type);
  const text = String(code ?? '').trim().toUpperCase().replace(/[-\s]/g, '');
  if (!text.startsWith(prefix) || text.length !== prefix.length + LENGTH) return null;
  // 易混淆字元的正規化只能套用在前綴之後：LG、OD、LD、LV、SL 的前綴本身含 O／I／L，一起轉換會讓前綴永遠比對不到。
  const value = fromBase32(text.slice(prefix.length).replace(/O/g, '0').replace(/[IL]/g, '1'));
  if (value == null || value > 0xffffffff) return null;
  return unpermute(prefix, value);
};

const decodeAny = (code) => {
  const text = String(code ?? '').trim().toUpperCase();
  const prefix = text.slice(0, 2);
  const type = Object.keys(PREFIX).find((k) => PREFIX[k] === prefix);
  if (!type) return null;
  const id = decode(type, text);
  return id == null ? null : { type, prefix, id };
};

module.exports = { encode, decode, decodeAny, prefixOf };
