// WebAuthn 的低階工具：挑戰值、使用者代號、驗證器資料解析。簽章與 CBOR／COSE 驗證交給 @simplewebauthn/server。
const crypto = require('crypto');
const { isoBase64URL } = require('@simplewebauthn/server/helpers');
const { env } = require('../config/env');

const OPTIONS_TIMEOUT_MS = 5 * 60 * 1000;
// 須長於系統視窗的 timeout：使用者在視窗關閉前一刻完成驗證，加上網路往返仍要有效。
const CHALLENGE_TTL_MS = 10 * 60 * 1000;
const RANDOM_BYTES = 32;
const TAG_BYTES = 16;
const SUPPORTED_ALGORITHMS = [-7, -257];

const config = () => ({ rpId: env.passkeyRpId, rpName: env.passkeyRpName, origins: env.passkeyOrigins });

const isConfigured = () => Boolean(env.passkeyRpId) && env.passkeyOrigins.length > 0;

const keyFor = (label) => crypto.createHmac('sha256', env.jwtSecret || 'savemybook').update(label).digest();

// webauthn_challenges 沒有 scope 欄位：把用途、範圍與使用者簽進挑戰值本身，
// 驗證時重算，確保 sensitive 取得的挑戰值不能拿去換 admin 權杖。
const tagOf = (random, { purpose, scope = '', userId = '' }) =>
  crypto.createHmac('sha256', keyFor('webauthn-challenge-v1'))
    .update(`${purpose}|${scope}|${userId}|`)
    .update(random)
    .digest()
    .subarray(0, TAG_BYTES);

// 48 位元組經 base64url 編碼後恰為 64 字元，對應 CHAR(64)。
const createChallenge = (binding) => {
  const random = crypto.randomBytes(RANDOM_BYTES);
  const bytes = Buffer.concat([random, tagOf(random, binding)]);
  return { bytes: new Uint8Array(bytes), text: isoBase64URL.fromBuffer(new Uint8Array(bytes)) };
};

const challengeMatches = (text, binding) => {
  if (typeof text !== 'string' || text.length !== 64 || !isoBase64URL.isBase64URL(text)) return false;
  const bytes = Buffer.from(isoBase64URL.toBuffer(text));
  if (bytes.length !== RANDOM_BYTES + TAG_BYTES) return false;
  const expected = tagOf(bytes.subarray(0, RANDOM_BYTES), binding);
  return crypto.timingSafeEqual(bytes.subarray(RANDOM_BYTES), expected);
};

// 使用者代號不可用流水號：它會存進使用者的密碼管理器，且在探索式登入時原樣送回。
const userHandleFor = (userId) =>
  new Uint8Array(crypto.createHmac('sha256', keyFor('webauthn-user-handle-v1')).update(String(userId)).digest());

const userHandleText = (userId) => isoBase64URL.fromBuffer(userHandleFor(userId));

const fakeCredentialId = (email) => isoBase64URL.fromBuffer(new Uint8Array(
  crypto.createHmac('sha256', keyFor('webauthn-decoy-v1')).update(String(email).toLowerCase()).digest()
));

const clientDataOf = (response) => {
  try {
    const json = Buffer.from(isoBase64URL.toBuffer(response?.response?.clientDataJSON ?? '')).toString('utf8');
    const data = JSON.parse(json);
    return data && typeof data === 'object' ? data : null;
  } catch {
    return null;
  }
};

// 部分第三方密碼管理工具回傳帶 = 補位或標準 base64 的編號，比對與查詢前一律轉成無補位的 base64url。
const canonicalBase64URL = (value) => (typeof value === 'string'
  ? value.trim().replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
  : value);

const isBase64URL = (value, max = 4096) =>
  typeof value === 'string' && value.length > 0 && value.length <= max && isoBase64URL.isBase64URL(value);

module.exports = {
  OPTIONS_TIMEOUT_MS, CHALLENGE_TTL_MS, SUPPORTED_ALGORITHMS, config, isConfigured, createChallenge, challengeMatches,
  userHandleFor, userHandleText, fakeCredentialId, clientDataOf, canonicalBase64URL, isBase64URL
};
