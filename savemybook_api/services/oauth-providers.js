const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const prisma = require('../lib/prisma');
const { env } = require('../config/env');
const { badRequest, HttpError } = require('../lib/errors');
const settings = require('./auth-settings');
const identities = require('./auth-identities');
const auth = require('./auth');

const STATE_TTL_MS = 10 * 60 * 1000;
const RESULT_TTL_MS = 5 * 60 * 1000;
const TIMEOUT_MS = 10 * 1000;

const PROVIDERS = Object.freeze({
  line: {
    authorizeUrl: 'https://access.line.me/oauth2/v2.1/authorize',
    tokenUrl: 'https://api.line.me/oauth2/v2.1/token',
    profileUrl: 'https://api.line.me/v2/profile',
    scope: 'profile openid email'
  },
  discord: {
    authorizeUrl: 'https://discord.com/oauth2/authorize',
    tokenUrl: 'https://discord.com/api/oauth2/token',
    profileUrl: 'https://discord.com/api/users/@me',
    scope: 'identify email'
  }
});

const credentialsOf = (provider) => (provider === 'line'
  ? { clientId: env.lineChannelId, clientSecret: env.lineChannelSecret }
  : { clientId: env.discordClientId, clientSecret: env.discordClientSecret });

const providerError = () => new HttpError(502, '第三方登入服務目前無法使用，請稍後再試', 'AUTH_PROVIDER_ERROR');

const stateInvalid = () => badRequest('登入連結已失效，請重新操作', 'OAUTH_STATE_INVALID');

const codeInvalid = () => badRequest('登入逾時，請重新操作', 'OAUTH_CODE_INVALID');

const redirectUri = (provider) => `${env.oauthRedirectBase}/api/auth/oauth/${provider}/callback`;

const randomKey = () => crypto.randomBytes(16).toString('hex');

const clip = (value, max) => {
  const text = typeof value === 'string' ? value.trim() : '';
  return text ? text.slice(0, max) : null;
};

const start = async (provider, mode, userId) => {
  await settings.assertEnabled(provider);
  if (!env.oauthRedirectBase) throw settings.disabled(provider);

  const state = randomKey();
  await prisma.$executeRaw`
    INSERT INTO oauth_states (state, provider, mode, user_id, created_at)
    VALUES (${state}, ${provider}, ${mode}, ${userId ?? null}, ${new Date()})`;

  const { clientId } = credentialsOf(provider);
  const params = new URLSearchParams({
    response_type: 'code',
    client_id: clientId,
    redirect_uri: redirectUri(provider),
    state,
    scope: PROVIDERS[provider].scope
  });
  return { url: `${PROVIDERS[provider].authorizeUrl}?${params.toString()}`, state };
};

const takeState = async (provider, state) => {
  if (typeof state !== 'string' || !/^[0-9a-f]{32}$/.test(state)) throw stateInvalid();

  const rows = await prisma.$queryRaw`
    SELECT state, provider, mode, user_id, created_at FROM oauth_states WHERE state = ${state}`;
  const row = rows[0];
  // 一次性：不論後續是否成功都先刪除，避免重放。
  await prisma.$executeRaw`DELETE FROM oauth_states WHERE state = ${state}`;

  if (!row || row.provider !== provider) throw stateInvalid();
  if (Date.now() - new Date(row.created_at).getTime() > STATE_TTL_MS) throw stateInvalid();
  return row;
};

const postForm = async (url, body) => {
  let response;
  try {
    response = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams(body),
      signal: AbortSignal.timeout(TIMEOUT_MS)
    });
  } catch {
    throw providerError();
  }
  const data = await response.json().catch(() => null);
  if (!response.ok || !data) throw providerError();
  return data;
};

const getJson = async (url, accessToken) => {
  let response;
  try {
    response = await fetch(url, {
      headers: { Authorization: `Bearer ${accessToken}` },
      signal: AbortSignal.timeout(TIMEOUT_MS)
    });
  } catch {
    throw providerError();
  }
  const data = await response.json().catch(() => null);
  if (!response.ok || !data) throw providerError();
  return data;
};

const exchangeCode = (provider, code) => {
  const { clientId, clientSecret } = credentialsOf(provider);
  return postForm(PROVIDERS[provider].tokenUrl, {
    grant_type: 'authorization_code',
    code,
    redirect_uri: redirectUri(provider),
    client_id: clientId,
    client_secret: clientSecret
  });
};

// LINE 的電子郵件只放在 id_token 內，且以 channel secret 做 HS256 簽章。
const lineIdTokenClaims = (idToken) => {
  if (typeof idToken !== 'string' || !idToken) return {};
  try {
    return jwt.verify(idToken, env.lineChannelSecret, {
      algorithms: ['HS256'],
      audience: env.lineChannelId,
      issuer: 'https://access.line.me',
      clockTolerance: 5
    });
  } catch {
    return {};
  }
};

const profileOf = async (provider, tokens) => {
  if (provider === 'line') {
    const [profile, claims] = await Promise.all([
      getJson(PROVIDERS.line.profileUrl, tokens.access_token),
      Promise.resolve(lineIdTokenClaims(tokens.id_token))
    ]);
    const subject = clip(profile.userId ?? claims.sub, 191);
    if (!subject) throw providerError();
    const email = clip(claims.email, 255)?.toLowerCase() ?? null;
    return {
      subject,
      email,
      // LINE 只在使用者完成信箱驗證後才提供 email。
      emailVerified: Boolean(email),
      phoneNumber: null,
      displayName: clip(profile.displayName ?? claims.name, 100)
    };
  }

  const me = await getJson(PROVIDERS.discord.profileUrl, tokens.access_token);
  const subject = clip(me.id, 191);
  if (!subject) throw providerError();
  return {
    subject,
    email: clip(me.email, 255)?.toLowerCase() ?? null,
    emailVerified: me.verified === true && Boolean(me.email),
    phoneNumber: null,
    displayName: clip(me.global_name ?? me.username, 100)
  };
};

const saveResult = async (payload) => {
  const code = randomKey();
  await prisma.$executeRaw`
    INSERT INTO oauth_results (code, payload, created_at)
    VALUES (${code}, ${JSON.stringify(payload)}, ${new Date()})`;
  return code;
};

// 回呼階段只完成身分判定，Token 於 App 呼叫 exchange 時才簽發，資料庫不保存任何 Token。
// 尚未綁定任何帳號時只把第三方資料暫存下來，是否建立帳號由使用者在 App 決定。
const handleCallback = async (provider, code, state) => {
  await settings.assertEnabled(provider);
  if (typeof code !== 'string' || !code || code.length > 512) throw stateInvalid();

  const row = await takeState(provider, state);
  const tokens = await exchangeCode(provider, code);
  const info = await profileOf(provider, tokens);

  if (row.mode === 'link') {
    const userId = Number(row.user_id);
    if (!userId) throw stateInvalid();
    await identities.link(userId, provider, info);
    return saveResult({ kind: 'link', provider, user_id: userId });
  }

  if (!(await identities.findIdentity(provider, info.subject))) {
    return saveResult({ kind: 'signup', provider, info });
  }

  const { user } = await identities.resolveSignIn({ provider, info });
  return saveResult({ kind: 'login', provider, user_id: user.user_id });
};

const dropResult = (code) => prisma.$executeRaw`DELETE FROM oauth_results WHERE code = ${code}`;

const readResult = async (code) => {
  if (typeof code !== 'string' || !/^[0-9a-f]{32}$/.test(code)) throw codeInvalid();

  const rows = await prisma.$queryRaw`SELECT payload, created_at FROM oauth_results WHERE code = ${code}`;
  const row = rows[0];
  if (!row) throw codeInvalid();
  if (Date.now() - new Date(row.created_at).getTime() > RESULT_TTL_MS) {
    await dropResult(code);
    throw codeInvalid();
  }

  try {
    return JSON.parse(String(row.payload));
  } catch {
    await dropResult(code);
    throw codeInvalid();
  }
};

// 這些結果代表還要問使用者（建立帳號、補電子郵件、登入既有帳號並綁定），一次性碼必須留到下一次呼叫。
const RETRYABLE_CODES = new Set(['NO_ACCOUNT_FOR_PROVIDER', 'EMAIL_REQUIRED', 'ACCOUNT_EXISTS_LINK_REQUIRED']);

const exchangeResult = async (code, device, { create = false, email = null, nickname = null, acceptLegal = false } = {}) => {
  const payload = await readResult(code);
  try {
    if (payload.kind === 'link') {
      await dropResult(code);
      return { linked: true, provider: payload.provider };
    }

    if (payload.kind === 'signup') {
      const { user } = await identities.resolveSignIn({
        provider: payload.provider, info: payload.info, email, nickname, acceptLegal, create
      });
      await dropResult(code);
      return auth.issueLogin(user, device, payload.provider);
    }

    const user = await identities.loadLoginUser(Number(payload.user_id));
    if (!user) throw codeInvalid();
    auth.assertLoginAllowed(user);
    await dropResult(code);
    return auth.issueLogin(user, device, payload.provider);
  } catch (err) {
    if (!RETRYABLE_CODES.has(err?.code)) await dropResult(code);
    throw err;
  }
};

const cleanupExpired = async () => {
  await prisma.$executeRaw`DELETE FROM oauth_states WHERE created_at < ${new Date(Date.now() - STATE_TTL_MS)}`;
  await prisma.$executeRaw`DELETE FROM oauth_results WHERE created_at < ${new Date(Date.now() - RESULT_TTL_MS)}`;
};

module.exports = {
  PROVIDERS, STATE_TTL_MS, RESULT_TTL_MS, redirectUri,
  start, handleCallback, exchangeResult, readResult, dropResult, cleanupExpired, providerError, stateInvalid, codeInvalid
};
