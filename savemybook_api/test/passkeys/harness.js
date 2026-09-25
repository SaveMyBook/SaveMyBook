// 通行密鑰測試的共用設定：沿用 test/lib 的假 Prisma 與 Express 應用，
// 另以 node:crypto 模擬真實的驗證器（P-256 金鑰、CBOR 編碼的 attestationObject、ECDSA 簽章）。
const crypto = require('crypto');

process.env.PASSKEY_RP_ID = 'savemybook.today';
process.env.LINE_CHANNEL_ID = 'line-channel-id';
process.env.LINE_CHANNEL_SECRET = 'line-channel-secret';
process.env.PASSKEY_ORIGINS = 'https://savemybook.today,android:apk-key-hash:47DEQpj8HBSa-_TImW-5JCeuQeRkm5NMpJWZG3hSuFU';

const server = require('../lib/server');
const { registerModels } = require('../lib/fake-prisma');

const { prisma, api, request, runSuite, runFolder, onReset } = server;

registerModels({
  autoKeys: { user_passkeys: 'passkey_id', user_sessions: 'session_id' },
  uniqueKeys: {
    user_passkeys: [['credential_id']],
    webauthn_challenges: [['challenge']],
    user_security: [['user_id']]
  }
});

const { isoCBOR, isoBase64URL } = require('@simplewebauthn/server/helpers');
const authToken = api('lib/auth-token');
const bcrypt = api('node_modules/bcrypt');
const authSettings = api('services/auth-settings');

const RP_ID = 'savemybook.today';
const ORIGIN = 'https://savemybook.today';
const ANDROID_ORIGIN = 'android:apk-key-hash:47DEQpj8HBSa-_TImW-5JCeuQeRkm5NMpJWZG3hSuFU';

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

const reset = ({ tables = {} } = {}) => {
  server.reset({
    tables: {
      users: [], login_logs: [], user_sessions: [], user_security: [], user_identities: [], auth_settings: [],
      user_passkeys: [], webauthn_challenges: [], notifications: [], admin_permissions: [], admin_operation_logs: [],
      push_devices: [], oauth_states: [], oauth_results: [], ...tables
    }
  });
};

server.setDefaultReset(() => reset());

onReset(() => {
  authSettings.clearCache();
});

// ---------- 使用者 ----------

let userSeq = 0;

const addUser = ({ email, role = 'buyer_seller', password = 'Passw0rd123', passwordSet = 1, isActive = true } = {}) => {
  userSeq += 1;
  const row = {
    user_id: userSeq,
    email: email ?? `member${userSeq}@example.com`,
    password_hash: bcrypt.hashSync(password, 4),
    nickname: `會員${userSeq}`,
    role,
    is_active: isActive,
    is_blacklisted: false,
    phone: null,
    deletion_requested_at: null,
    anonymized_at: null,
    password_set: passwordSet,
    created_at: new Date(),
    updated_at: new Date()
  };
  prisma.rows('users').push(row);
  return row;
};

const addSession = (user) => {
  const row = {
    session_id: prisma.nextId('user_sessions'),
    user_id: user.user_id,
    sid: crypto.randomBytes(16).toString('hex'),
    device_id: null,
    device_name: 'iPhone 17',
    platform: 'ios',
    created_at: new Date(),
    last_seen_at: new Date(),
    revoked_at: null,
    pay_key_hash: null
  };
  prisma.rows('user_sessions').push(row);
  return row;
};

const signedIn = (options) => {
  const user = addUser(options);
  const session = addSession(user);
  return { user, session, token: authToken.signToken(user, session.sid) };
};

const verifyTokenFor = ({ user, sid, scope = 'sensitive', method = 'password' }) =>
  authToken.sign({ typ: 'verify', uid: user.user_id, sid, scope, method, jti: crypto.randomBytes(12).toString('hex') }, 300);

const sensitive = (ctx) => ({ 'x-verify-token': verifyTokenFor({ user: ctx.user, sid: ctx.session.sid }) });

// ---------- 模擬驗證器 ----------

const b64url = (bytes) => isoBase64URL.fromBuffer(new Uint8Array(bytes));
const sha256 = (data) => crypto.createHash('sha256').update(data).digest();

const FLAG_UP = 0x01;
const FLAG_UV = 0x04;
const FLAG_BE = 0x08;
const FLAG_BS = 0x10;
const FLAG_AT = 0x40;

class Authenticator {
  constructor({ rpId = RP_ID, origin = ORIGIN, backedUp = true, aaguid = null } = {}) {
    this.aaguid = aaguid ? Buffer.from(aaguid.replace(/-/g, ''), 'hex') : Buffer.alloc(16);
    const { privateKey, publicKey } = crypto.generateKeyPairSync('ec', { namedCurve: 'P-256' });
    this.privateKey = privateKey;
    this.publicJwk = publicKey.export({ format: 'jwk' });
    this.credentialId = crypto.randomBytes(32);
    this.id = b64url(this.credentialId);
    this.rpId = rpId;
    this.origin = origin;
    this.backedUp = backedUp;
    this.counter = 0;
    this.userHandle = null;
  }

  flags({ userVerified = true, attested = false } = {}) {
    return FLAG_UP | (userVerified ? FLAG_UV : 0) | (this.backedUp ? FLAG_BE | FLAG_BS : 0) | (attested ? FLAG_AT : 0);
  }

  coseKey() {
    return isoCBOR.encode(new Map([
      [1, 2],
      [3, -7],
      [-1, 1],
      [-2, new Uint8Array(Buffer.from(this.publicJwk.x, 'base64url'))],
      [-3, new Uint8Array(Buffer.from(this.publicJwk.y, 'base64url'))]
    ]));
  }

  authData({ rpId = this.rpId, counter = this.counter, userVerified = true, attested = false } = {}) {
    const count = Buffer.alloc(4);
    count.writeUInt32BE(counter);
    const parts = [sha256(rpId), Buffer.from([this.flags({ userVerified, attested })]), count];
    if (attested) {
      const idLength = Buffer.alloc(2);
      idLength.writeUInt16BE(this.credentialId.length);
      parts.push(this.aaguid, idLength, this.credentialId, Buffer.from(this.coseKey()));
    }
    return Buffer.concat(parts);
  }

  clientData(type, challenge, origin = this.origin) {
    return Buffer.from(JSON.stringify({ type, challenge, origin, crossOrigin: false }));
  }

  // options 為伺服器回傳的 PublicKeyCredentialCreationOptionsJSON。
  create(options, { origin, rpId, userVerified = true } = {}) {
    this.userHandle = options.user.id;
    const attestationObject = isoCBOR.encode(new Map([
      ['fmt', 'none'],
      ['attStmt', new Map()],
      ['authData', new Uint8Array(this.authData({ rpId, counter: 0, userVerified, attested: true }))]
    ]));
    return {
      id: this.id,
      rawId: this.id,
      type: 'public-key',
      response: {
        clientDataJSON: b64url(this.clientData('webauthn.create', options.challenge, origin)),
        attestationObject: b64url(attestationObject),
        transports: ['internal', 'hybrid']
      },
      clientExtensionResults: {}
    };
  }

  // options 為伺服器回傳的 PublicKeyCredentialRequestOptionsJSON；counter 不給時自動遞增。
  get(options, { origin, rpId, counter, userVerified = true, userHandle = this.userHandle, signWith } = {}) {
    this.counter = counter ?? this.counter + 1;
    const authData = this.authData({ rpId, counter: this.counter, userVerified });
    const clientData = this.clientData('webauthn.get', options.challenge, origin);
    const signature = crypto.sign('sha256', Buffer.concat([authData, sha256(clientData)]), signWith ?? this.privateKey);
    return {
      id: this.id,
      rawId: this.id,
      type: 'public-key',
      response: {
        clientDataJSON: b64url(clientData),
        authenticatorData: b64url(authData),
        signature: b64url(signature),
        ...(userHandle && { userHandle })
      },
      clientExtensionResults: {}
    };
  }
}

// 走完整的 API 流程註冊一組通行密鑰，回傳驗證器。
const registerPasskey = async (ctx, { label = 'iPhone 17', authenticator = new Authenticator() } = {}) => {
  const options = await request('POST', '/api/users/me/passkeys/options', { token: ctx.token });
  if (options.status !== 200) throw new Error(`取得註冊 options 失敗：${options.status} ${options.text}`);
  const created = await request('POST', '/api/users/me/passkeys', {
    token: ctx.token,
    headers: sensitive(ctx),
    body: { attestation: authenticator.create(options.body.data.options), device_label: label }
  });
  if (created.status !== 201) throw new Error(`註冊失敗：${created.status} ${created.text}`);
  return authenticator;
};

module.exports = {
  api, prisma, request, runSuite, runFolder, reset, addUser, addSession, signedIn,
  verifyTokenFor, sensitive, Authenticator, registerPasskey, RP_ID, ORIGIN, ANDROID_ORIGIN, authToken
};
