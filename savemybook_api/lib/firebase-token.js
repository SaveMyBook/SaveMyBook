const fs = require('fs');
const jwt = require('jsonwebtoken');
const { env } = require('../config/env');
const { HttpError } = require('./errors');

const CERT_URL = 'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com';
const FETCH_TIMEOUT_MS = 10 * 1000;
const FALLBACK_TTL_MS = 60 * 60 * 1000;

// Firebase 的 sign_in_provider 值與本站的 provider 代號不同名。
const SIGN_IN_PROVIDERS = { google: 'google.com', apple: 'apple.com', phone: 'phone' };

const invalidToken = () => new HttpError(401, '登入逾時，請重新操作', 'INVALID_ID_TOKEN');
const providerError = () => new HttpError(502, '目前無法完成第三方登入驗證，請稍後再試', 'AUTH_PROVIDER_ERROR');

let projectIdCache = null;

const readProjectId = () => {
  if (projectIdCache !== null) return projectIdCache;
  let value = '';
  if (env.fcmServiceAccountFile) {
    try {
      value = String(JSON.parse(fs.readFileSync(env.fcmServiceAccountFile, 'utf8')).project_id || '');
    } catch {
      value = '';
    }
  }
  projectIdCache = value || env.firebaseProjectId || '';
  return projectIdCache;
};

const isConfigured = () => Boolean(readProjectId());

let certs = { keys: null, expiresAt: 0, pending: null };

const parseMaxAge = (header) => {
  const match = /max-age\s*=\s*(\d+)/i.exec(String(header ?? ''));
  const seconds = match ? Number(match[1]) : 0;
  return seconds > 0 ? seconds * 1000 : FALLBACK_TTL_MS;
};

const fetchCerts = async () => {
  let response;
  try {
    response = await fetch(CERT_URL, { signal: AbortSignal.timeout(FETCH_TIMEOUT_MS) });
  } catch {
    throw providerError();
  }
  if (!response.ok) throw providerError();

  const body = await response.json().catch(() => null);
  if (!body || typeof body !== 'object' || Object.keys(body).length === 0) throw providerError();

  certs = { keys: body, expiresAt: Date.now() + parseMaxAge(response.headers.get('cache-control')), pending: null };
  return body;
};

const loadCerts = async ({ force = false } = {}) => {
  if (!force && certs.keys && Date.now() < certs.expiresAt) return certs.keys;
  if (!certs.pending) {
    certs.pending = fetchCerts().finally(() => { certs.pending = null; });
  }
  return certs.pending;
};

const resetCache = () => {
  certs = { keys: null, expiresAt: 0, pending: null };
  projectIdCache = null;
};

const nonEmpty = (value, max) => {
  const text = typeof value === 'string' ? value.trim() : '';
  return text ? text.slice(0, max) : null;
};

// provider 為本站代號（google／apple／phone）；不相符時交由呼叫端回 PROVIDER_MISMATCH。
const verifyIdToken = async (idToken, provider) => {
  const expected = SIGN_IN_PROVIDERS[provider];
  if (!expected) throw invalidToken();

  const projectId = readProjectId();
  if (!projectId) throw new HttpError(503, '此登入方式暫時無法使用，請稍後再試', 'AUTH_SOCIAL_UNAVAILABLE');
  if (typeof idToken !== 'string' || idToken.length < 20 || idToken.length > 8192) throw invalidToken();

  const decoded = jwt.decode(idToken, { complete: true });
  const kid = decoded?.header?.kid;
  if (!decoded || decoded.header.alg !== 'RS256' || typeof kid !== 'string') throw invalidToken();

  let keys = await loadCerts();
  // 金鑰輪替後舊快取查不到 kid，強制重新取得一次再判斷。
  if (!keys[kid]) keys = await loadCerts({ force: true });
  if (!keys[kid]) throw invalidToken();

  let claims;
  try {
    claims = jwt.verify(idToken, keys[kid], {
      algorithms: ['RS256'],
      audience: projectId,
      issuer: `https://securetoken.google.com/${projectId}`,
      clockTolerance: 5
    });
  } catch {
    throw invalidToken();
  }

  const subject = nonEmpty(claims.sub, 191);
  if (!subject) throw invalidToken();

  const authTime = Number(claims.auth_time);
  if (!Number.isFinite(authTime) || authTime > Math.floor(Date.now() / 1000) + 5) throw invalidToken();

  const signInProvider = claims.firebase?.sign_in_provider;
  return {
    subject,
    signInProvider,
    matchesProvider: signInProvider === expected,
    email: nonEmpty(claims.email, 255)?.toLowerCase() ?? null,
    emailVerified: claims.email_verified === true,
    phoneNumber: nonEmpty(claims.phone_number, 20),
    displayName: nonEmpty(claims.name, 100),
    pictureUrl: nonEmpty(claims.picture, 500)
  };
};

module.exports = { SIGN_IN_PROVIDERS, isConfigured, readProjectId, verifyIdToken, resetCache, invalidToken, providerError };
