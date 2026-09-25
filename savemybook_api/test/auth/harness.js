// 登入相關測試的共用設定：沿用 test/lib 的假 Prisma 與假 fetch，另外提供 Firebase 權杖與帳號資料的產生器。
const crypto = require('crypto');
const path = require('path');
const fs = require('fs');
const os = require('os');
const { execFileSync } = require('child_process');

process.env.FIREBASE_PROJECT_ID = 'savemybook-test';
process.env.LINE_CHANNEL_ID = 'line-channel-id';
process.env.LINE_CHANNEL_SECRET = 'line-channel-secret';
process.env.DISCORD_CLIENT_ID = 'discord-client-id';
process.env.DISCORD_CLIENT_SECRET = 'discord-client-secret';
process.env.OAUTH_REDIRECT_BASE = 'https://api.example.test';

const server = require('../lib/server');
const { registerModels } = require('../lib/fake-prisma');

const { prisma, api, onFetch, jsonResponse, fetchLog, request, listen, close, runSuite, onReset } = server;

registerModels({
  autoKeys: { user_identities: 'identity_id', user_sessions: 'session_id' },
  uniqueKeys: {
    user_security: [['user_id']],
    user_identities: [['provider', 'subject']],
    auth_settings: [['id']],
    oauth_states: [['state']],
    oauth_results: [['code']]
  },
  defaults: { users: { password_set: 1 } }
});

// ---------- 測試用 RSA 金鑰與 x509 憑證 ----------

const certDir = fs.mkdtempSync(path.join(os.tmpdir(), 'smb-cert-'));
const keyFile = path.join(certDir, 'key.pem');
const certFile = path.join(certDir, 'cert.pem');
execFileSync('openssl', [
  'req', '-x509', '-newkey', 'rsa:2048', '-keyout', keyFile, '-out', certFile,
  '-days', '2', '-nodes', '-subj', '/CN=securetoken.test'
], { stdio: 'ignore' });

const otherKeyFile = path.join(certDir, 'other-key.pem');
const otherCertFile = path.join(certDir, 'other-cert.pem');
execFileSync('openssl', [
  'req', '-x509', '-newkey', 'rsa:2048', '-keyout', otherKeyFile, '-out', otherCertFile,
  '-days', '2', '-nodes', '-subj', '/CN=attacker.test'
], { stdio: 'ignore' });

const signingKey = fs.readFileSync(keyFile, 'utf8');
const signingCert = fs.readFileSync(certFile, 'utf8');
const wrongKey = fs.readFileSync(otherKeyFile, 'utf8');
const CERT_KID = 'test-kid-1';
const CERT_URL = 'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com';

let certRequests = 0;
onFetch(CERT_URL, () => {
  certRequests += 1;
  return jsonResponse({ [CERT_KID]: signingCert }, { headers: { 'cache-control': 'public, max-age=3600' } });
});

const jwt = api('node_modules/jsonwebtoken');

const PROJECT_ID = process.env.FIREBASE_PROJECT_ID;

const SIGN_IN_PROVIDERS = { google: 'google.com', apple: 'apple.com', phone: 'phone' };

const firebaseToken = ({
  provider = 'google',
  sub = 'uid-1',
  email,
  emailVerified = true,
  name,
  phoneNumber,
  audience = PROJECT_ID,
  issuer = `https://securetoken.google.com/${PROJECT_ID}`,
  expiresIn = 3600,
  key = signingKey,
  kid = CERT_KID,
  authTime = Math.floor(Date.now() / 1000) - 10
} = {}) => {
  const payload = {
    iss: issuer,
    aud: audience,
    sub,
    auth_time: authTime,
    user_id: sub,
    firebase: { sign_in_provider: SIGN_IN_PROVIDERS[provider] ?? provider, identities: {} }
  };
  if (email !== undefined) payload.email = email;
  if (email !== undefined) payload.email_verified = emailVerified;
  if (name !== undefined) payload.name = name;
  if (phoneNumber !== undefined) payload.phone_number = phoneNumber;
  return jwt.sign(payload, key, { algorithm: 'RS256', expiresIn, keyid: kid });
};

// ---------- 迷你 SQL 直譯器不支援的查詢 ----------

const time = (value) => new Date(value).getTime();

prisma.onSql(/LEFT JOIN user_sessions s ON s\.sid/, (sql, [sid, userId]) => {
  const session = prisma.rows('user_sessions').find((s) => s.sid === sid) ?? null;
  const security = prisma.rows('user_security').find((s) => Number(s.user_id) === Number(userId)) ?? null;
  return [{
    session_user: session ? session.user_id : null,
    revoked_at: session?.revoked_at ?? null,
    tokens_valid_after: security?.tokens_valid_after ?? null
  }];
});

prisma.onSql(/SELECT session_id, user_id, sid, pay_key_hash, last_seen_at FROM user_sessions/, (sql, [sid, cutoff]) =>
  prisma.rows('user_sessions').filter((s) => s.sid === sid && s.revoked_at == null && time(s.last_seen_at) >= time(cutoff)));

// ---------- 資料庫狀態 ----------

const authSettings = api('services/auth-settings');
const firebase = api('lib/firebase-token');
const authToken = api('lib/auth-token');
const bcrypt = api('node_modules/bcrypt');

const reset = ({ tables = {} } = {}) => {
  server.reset({
    tables: {
      users: [], login_logs: [], user_identities: [], auth_settings: [], oauth_states: [],
      oauth_results: [], admin_permissions: [], admin_operation_logs: [], push_devices: [],
      notifications: [], user_sessions: [], user_security: [], ...tables
    }
  });
};

server.setDefaultReset(() => reset());

onReset(() => {
  authSettings.clearCache();
  firebase.resetCache();
});

let userSeq = 0;

const addUser = ({
  email, nickname = '測試使用者', role = 'buyer_seller', password = null,
  passwordSet = 1, isActive = true, isBlacklisted = false, phone = null
} = {}) => {
  userSeq += 1;
  const row = {
    user_id: userSeq,
    email: email ?? `user${userSeq}@example.com`,
    password_hash: password ? bcrypt.hashSync(password, 4) : 'not-a-bcrypt-hash',
    nickname,
    avatar_url: null,
    bio: null,
    phone,
    birthday: null,
    gender: 'undisclosed',
    role,
    is_active: isActive,
    is_blacklisted: isBlacklisted,
    bonus_points: 0,
    deletion_requested_at: null,
    anonymized_at: null,
    share_token: null,
    password_set: passwordSet,
    created_at: new Date(),
    updated_at: new Date()
  };
  prisma.rows('users').push(row);
  return row;
};

const addIdentity = ({ userId, provider, subject, email = null, phone = null, displayName = null }) => {
  const row = {
    identity_id: prisma.nextId('user_identities'),
    user_id: userId,
    provider,
    subject,
    email,
    phone,
    display_name: displayName,
    created_at: new Date(),
    last_login_at: null
  };
  prisma.rows('user_identities').push(row);
  return row;
};

const setAuthSettings = (config) => {
  prisma.store.auth_settings = [{ id: 1, config: JSON.stringify(config), updated_by: null, updated_at: new Date() }];
  authSettings.clearCache();
};

const tokenFor = (user) => authToken.signToken(user, undefined);

// 驗證權杖由 services/security 簽發，測試需要時直接以同樣的內容簽一份。
const verifyHeaders = (user, scope = 'sensitive') => ({
  'x-verify-token': authToken.sign(
    { typ: 'verify', uid: user.user_id, sid: null, scope, method: 'password', jti: crypto.randomBytes(12).toString('hex') },
    300
  )
});

module.exports = {
  runSuite, listen, close, request,
  prisma, api, reset, addUser, addIdentity, setAuthSettings, tokenFor, verifyHeaders, request, listen, close,
  firebaseToken, signingKey, signingCert, wrongKey, CERT_KID, CERT_URL, PROJECT_ID,
  onFetch, jsonResponse, fetchLog, certRequests: () => certRequests,
  authSettings, jwt, bcrypt
};
