const {
  generateRegistrationOptions, verifyRegistrationResponse,
  generateAuthenticationOptions, verifyAuthenticationResponse
} = require('@simplewebauthn/server');
const { isoBase64URL } = require('@simplewebauthn/server/helpers');
const prisma = require('../lib/prisma');
const webauthn = require('../lib/webauthn');
const publicId = require('../lib/public-id');
const { hasTables } = require('../lib/schema-check');
const { HttpError, badRequest, conflict, notFound } = require('../lib/errors');
const { notify } = require('./notify');
const authSettings = require('./auth-settings');
const identities = require('./auth-identities');

const TABLES = ['user_passkeys', 'webauthn_challenges'];
const MAX_PER_USER = 10;

const migrationReady = () => hasTables(TABLES);

const isAvailable = async () => webauthn.isConfigured() && (await migrationReady());

const assertAvailable = async () => {
  if (!(await isAvailable())) {
    throw new HttpError(503, '通行密鑰暫時無法使用，請改用其他方式', 'PASSKEY_UNAVAILABLE');
  }
};

const verificationFailed = () => badRequest('通行密鑰驗證失敗，請重新操作', 'PASSKEY_VERIFICATION_FAILED');
const challengeInvalid = () => badRequest('驗證要求已失效，請重新操作', 'PASSKEY_CHALLENGE_INVALID');

const passkeysOf = (userId) => prisma.$queryRaw`
  SELECT passkey_id, credential_id, transports, aaguid, device_label, created_at, last_used_at, backed_up
  FROM user_passkeys WHERE user_id = ${userId} ORDER BY created_at ASC`;

const countOf = async (userId) => {
  const [row] = await prisma.$queryRaw`SELECT COUNT(*) AS n FROM user_passkeys WHERE user_id = ${userId}`;
  return Number(row?.n ?? 0);
};

const hasPasskey = async (userId) => (await migrationReady()) && (await countOf(userId)) > 0;

const transportsOf = (row) => (row.transports ? String(row.transports).split(',').filter(Boolean) : undefined);

const AUTHENTICATORS = {
  'fbfc3007-154e-4ecc-8c0b-6e020557d7bd': 'icloud_keychain',
  'dd4ec289-e01d-41c9-bb89-70fa845d4bf2': 'icloud_keychain',
  'ea9b8d66-4d01-1d21-3ce4-b6b48cb575d4': 'google_password_manager',
  '53414d53-554e-4700-0000-000000000000': 'samsung_pass',
  'bada5566-a7aa-401f-bd96-45619a55120d': '1password',
  'd548826e-79b4-db40-a3d8-11116f7e8349': 'bitwarden',
  '531126d6-e717-415c-9320-3d9aa6981239': 'dashlane',
  'adce0002-35bc-c60a-648b-0b25f1f05503': 'chrome_mac',
  '08987058-cadc-4b81-b6e1-30de50dcbe96': 'windows_hello',
  '9ddd1817-af5a-4672-a2b9-3e3dd95000a9': 'windows_hello',
  '6028b017-b1d4-4c02-b4b3-afcdafc96bb2': 'windows_hello'
};

const authenticatorOf = (aaguid) => AUTHENTICATORS[String(aaguid ?? '').toLowerCase()] ?? null;

const shape = (row) => ({
  passkey_id: publicId.encode('passkey', row.passkey_id),
  device_label: row.device_label ?? null,
  authenticator: authenticatorOf(row.aaguid),
  created_at: row.created_at,
  last_used_at: row.last_used_at ?? null,
  backed_up: Boolean(Number(row.backed_up))
});

const list = async (userId) => {
  await assertAvailable();
  return (await passkeysOf(userId)).map(shape);
};

// ---------- 挑戰值 ----------

const storeChallenge = async (text, { purpose, userId = null }) => {
  await prisma.$executeRaw`
    INSERT INTO webauthn_challenges (challenge, user_id, purpose, created_at)
    VALUES (${text}, ${userId}, ${purpose}, ${new Date()})`;
};

// 先刪除再檢查：任何一次提交都會用掉挑戰值，失敗的嘗試不能留下可重送的機會。
const consumeChallenge = async (response, { purpose, scope = '', userId = null }) => {
  const challenge = webauthn.clientDataOf(response)?.challenge;
  if (typeof challenge !== 'string' || challenge.length !== 64) throw challengeInvalid();

  const rows = await prisma.$queryRaw`
    SELECT user_id, purpose, created_at FROM webauthn_challenges WHERE challenge = ${challenge}`;
  const row = rows[0];
  if (!row) throw challengeInvalid();
  const removed = await prisma.$executeRaw`DELETE FROM webauthn_challenges WHERE challenge = ${challenge}`;
  if (Number(removed) !== 1) throw challengeInvalid();

  const owner = row.user_id == null ? null : Number(row.user_id);
  if (row.purpose !== purpose || owner !== (userId == null ? null : Number(userId))) throw challengeInvalid();
  if (!webauthn.challengeMatches(challenge, { purpose, scope, userId: userId ?? '' })) throw challengeInvalid();
  if (Date.now() - new Date(row.created_at).getTime() > webauthn.CHALLENGE_TTL_MS) {
    throw badRequest('驗證要求已逾時，請重新操作', 'PASSKEY_CHALLENGE_EXPIRED');
  }
  return challenge;
};

const cleanupExpired = async () => {
  if (!(await migrationReady())) return 0;
  const cutoff = new Date(Date.now() - webauthn.CHALLENGE_TTL_MS);
  return prisma.$executeRaw`DELETE FROM webauthn_challenges WHERE created_at < ${cutoff}`;
};

// ---------- 註冊 ----------

const registrationOptions = async (userId) => {
  await assertAvailable();
  const [user, existing] = await Promise.all([
    prisma.users.findUnique({ where: { user_id: userId }, select: { email: true, nickname: true } }),
    passkeysOf(userId)
  ]);
  if (!user) throw notFound('找不到使用者');
  if (existing.length >= MAX_PER_USER) {
    throw badRequest(`每個帳號最多註冊 ${MAX_PER_USER} 組通行密鑰，請先刪除不再使用的裝置`, 'PASSKEY_LIMIT');
  }

  const { rpId, rpName } = webauthn.config();
  const challenge = webauthn.createChallenge({ purpose: 'register', userId });
  const options = await generateRegistrationOptions({
    rpName,
    rpID: rpId,
    userName: user.email,
    userDisplayName: user.nickname || user.email,
    userID: webauthn.userHandleFor(userId),
    challenge: challenge.bytes,
    timeout: webauthn.OPTIONS_TIMEOUT_MS,
    attestationType: 'none',
    excludeCredentials: existing.map((row) => ({ id: row.credential_id, transports: transportsOf(row) })),
    authenticatorSelection: { residentKey: 'required', requireResidentKey: true, userVerification: 'required' },
    supportedAlgorithmIDs: webauthn.SUPPORTED_ALGORITHMS
  });
  await storeChallenge(challenge.text, { purpose: 'register', userId });
  return options;
};

const normalizedResponse = (response, fields) => {
  const invalid = () => badRequest('通行密鑰資料格式不正確', 'PASSKEY_INVALID_RESPONSE');
  if (!response || typeof response !== 'object' || !response.response || typeof response.response !== 'object') throw invalid();

  const canonical = webauthn.canonicalBase64URL;
  const id = canonical(response.id);
  const rawId = response.rawId === undefined ? id : canonical(response.rawId);
  const inner = { ...response.response };
  for (const field of [...fields, 'userHandle']) {
    if (typeof inner[field] === 'string') inner[field] = canonical(inner[field]);
  }
  const ok = webauthn.isBase64URL(id, 1024)
    && rawId === id
    && fields.every((field) => webauthn.isBase64URL(inner[field], 16384));
  if (!ok) throw invalid();
  return { ...response, id, rawId: id, response: inner };
};

const isDuplicateKey = (err) => err?.code === 'P2002'
  || /Duplicate entry/i.test(err?.message ?? '')
  || String(err?.meta?.code ?? '') === '1062';

const TRANSPORTS = ['ble', 'cable', 'hybrid', 'internal', 'nfc', 'smart-card', 'usb'];

const register = async (userId, input, deviceLabel) => {
  await assertAvailable();
  const attestation = normalizedResponse(input, ['clientDataJSON', 'attestationObject']);
  const challenge = await consumeChallenge(attestation, { purpose: 'register', userId });

  if ((await countOf(userId)) >= MAX_PER_USER) {
    throw badRequest(`每個帳號最多註冊 ${MAX_PER_USER} 組通行密鑰，請先刪除不再使用的裝置`, 'PASSKEY_LIMIT');
  }

  const { rpId, origins } = webauthn.config();
  let result;
  try {
    result = await verifyRegistrationResponse({
      response: { ...attestation, rawId: attestation.id, type: 'public-key', clientExtensionResults: {} },
      expectedChallenge: challenge,
      expectedOrigin: origins,
      expectedRPID: rpId,
      requireUserVerification: true,
      supportedAlgorithmIDs: webauthn.SUPPORTED_ALGORITHMS
    });
  } catch {
    throw verificationFailed();
  }
  if (!result.verified) throw verificationFailed();

  const info = result.registrationInfo;
  const credentialId = info.credential.id;
  if (credentialId.length > 255) throw badRequest('此驗證器的憑證編號過長，無法註冊', 'PASSKEY_INVALID_RESPONSE');

  const transports = (Array.isArray(attestation.response.transports) ? attestation.response.transports : [])
    .filter((t) => TRANSPORTS.includes(t))
    .join(',')
    .slice(0, 100) || null;

  try {
    await prisma.$executeRaw`
      INSERT INTO user_passkeys
        (user_id, credential_id, public_key, sign_count, transports, aaguid, backed_up, device_label, created_at)
      VALUES
        (${userId}, ${credentialId}, ${isoBase64URL.fromBuffer(info.credential.publicKey)}, ${info.credential.counter},
         ${transports}, ${info.aaguid ?? null}, ${info.credentialBackedUp ? 1 : 0}, ${deviceLabel}, ${new Date()})`;
  } catch (err) {
    if (isDuplicateKey(err)) {
      throw conflict('此通行密鑰已經註冊', 'PASSKEY_ALREADY_REGISTERED');
    }
    throw err;
  }

  await notify(null, {
    userId,
    title: '已新增通行密鑰',
    content: `您的帳號已新增通行密鑰${deviceLabel ? `「${deviceLabel}」` : ''}。若非本人操作，請立即至「帳號安全」刪除並變更密碼。`,
    relatedType: 'security'
  }).catch(() => {});

  return list(userId);
};

// ---------- 刪除 ----------

const otherSignInMethods = async (userId) => {
  const [passwordSet, linked] = await Promise.all([
    identities.hasPassword(userId),
    authSettings.migrationReady().then((ready) => (ready ? identities.identitiesOf(userId) : []))
  ]);
  return (passwordSet ? 1 : 0) + linked.length;
};

const remove = async (userId, code) => {
  await assertAvailable();
  const passkeyId = publicId.decode('passkey', code);
  const rows = passkeyId == null ? [] : await prisma.$queryRaw`
    SELECT passkey_id, device_label FROM user_passkeys WHERE passkey_id = ${passkeyId} AND user_id = ${userId}`;
  if (rows.length === 0) throw notFound('找不到此通行密鑰，可能已經刪除');

  if ((await countOf(userId)) <= 1 && (await otherSignInMethods(userId)) === 0) {
    throw badRequest('這是此帳號唯一的登入方式，請先設定密碼或綁定其他登入方式', 'LAST_SIGN_IN_METHOD');
  }

  await prisma.$executeRaw`DELETE FROM user_passkeys WHERE passkey_id = ${passkeyId} AND user_id = ${userId}`;
  await notify(null, {
    userId,
    title: '已刪除通行密鑰',
    content: `您的帳號已刪除通行密鑰${rows[0].device_label ? `「${rows[0].device_label}」` : ''}。若非本人操作，請立即變更密碼。`,
    relatedType: 'security'
  }).catch(() => {});
  return list(userId);
};

const rename = async (userId, code, deviceLabel) => {
  await assertAvailable();
  const passkeyId = publicId.decode('passkey', code);
  const rows = passkeyId == null ? [] : await prisma.$queryRaw`
    SELECT passkey_id FROM user_passkeys WHERE passkey_id = ${passkeyId} AND user_id = ${userId}`;
  if (rows.length === 0) throw notFound('找不到此通行密鑰，可能已經刪除');

  await prisma.$executeRaw`
    UPDATE user_passkeys SET device_label = ${deviceLabel} WHERE passkey_id = ${passkeyId} AND user_id = ${userId}`;
  return list(userId);
};

// ---------- 驗證 ----------

const authenticationOptions = async ({ purpose, scope = '', userId = null, allowCredentials }) => {
  const challenge = webauthn.createChallenge({ purpose, scope, userId: userId ?? '' });
  const options = await generateAuthenticationOptions({
    rpID: webauthn.config().rpId,
    allowCredentials,
    challenge: challenge.bytes,
    timeout: webauthn.OPTIONS_TIMEOUT_MS,
    userVerification: 'required'
  });
  await storeChallenge(challenge.text, { purpose, userId });
  return options;
};

// 找不到帳號或帳號沒有通行密鑰時回傳以 Email 推導的固定假憑證，兩種情況與真帳號的回應形狀一致。
const loginOptions = async (email) => {
  await assertAvailable();
  let allowCredentials = [];
  if (email) {
    const user = await prisma.users.findUnique({ where: { email }, select: { user_id: true } });
    const rows = user ? await passkeysOf(user.user_id) : [];
    allowCredentials = rows.length
      ? rows.map((row) => ({ id: row.credential_id, transports: transportsOf(row) }))
      : [{ id: webauthn.fakeCredentialId(email), transports: ['internal', 'hybrid'] }];
  }
  return authenticationOptions({ purpose: 'login', allowCredentials });
};

const verifyOptions = async (userId, scope) => {
  await assertAvailable();
  const rows = await passkeysOf(userId);
  if (rows.length === 0) throw badRequest('此帳號尚未註冊通行密鑰', 'PASSKEY_NOT_REGISTERED');
  return authenticationOptions({
    purpose: 'verify',
    scope,
    userId,
    allowCredentials: rows.map((row) => ({ id: row.credential_id, transports: transportsOf(row) }))
  });
};

const counterRegressed = async (row, received) => {
  console.warn(`[通行密鑰簽章計數倒退] passkey_id=${row.passkey_id} user_id=${row.user_id} 已記錄=${row.sign_count} 收到=${received}`);
  await notify(null, {
    userId: Number(row.user_id),
    title: '通行密鑰驗證異常',
    content: '偵測到通行密鑰的使用紀錄異常，本次驗證已拒絕。若非本人操作，請至「帳號安全」刪除該通行密鑰並變更密碼。',
    relatedType: 'security'
  }).catch(() => {});
  return badRequest('此通行密鑰的驗證紀錄異常，已拒絕本次驗證', 'PASSKEY_COUNTER_REGRESSED');
};

// 回傳通過驗證的 user_id。userId 有值時憑證必須屬於該使用者。
const verifyAssertion = async (input, { purpose, scope = '', userId = null }) => {
  await assertAvailable();
  const assertion = normalizedResponse(input, ['clientDataJSON', 'authenticatorData', 'signature']);
  const challenge = await consumeChallenge(assertion, { purpose, scope, userId });

  const rows = await prisma.$queryRaw`
    SELECT passkey_id, user_id, credential_id, public_key, sign_count, transports
    FROM user_passkeys WHERE credential_id = ${assertion.id}`;
  const row = rows[0];
  if (!row || (userId != null && Number(row.user_id) !== Number(userId))) {
    throw badRequest('無法辨識此通行密鑰，可能已從帳號中刪除', 'PASSKEY_NOT_RECOGNIZED');
  }

  const handle = assertion.response.userHandle;
  if (handle && handle !== webauthn.userHandleText(row.user_id)) {
    throw badRequest('無法辨識此通行密鑰，可能已從帳號中刪除', 'PASSKEY_NOT_RECOGNIZED');
  }

  const { rpId, origins } = webauthn.config();
  let result;
  try {
    result = await verifyAuthenticationResponse({
      response: { ...assertion, rawId: assertion.id, type: 'public-key', clientExtensionResults: {} },
      expectedChallenge: challenge,
      expectedOrigin: origins,
      expectedRPID: rpId,
      requireUserVerification: true,
      credential: {
        id: row.credential_id,
        publicKey: isoBase64URL.toBuffer(row.public_key),
        // 計數由下方自行比對：先確認簽章有效，偽造的回應才不會觸發異常通知。
        counter: 0,
        transports: transportsOf(row)
      }
    });
  } catch {
    throw verificationFailed();
  }
  if (!result.verified) throw verificationFailed();

  const { newCounter, credentialBackedUp } = result.authenticationInfo;
  const stored = Number(row.sign_count ?? 0);
  if ((stored > 0 || newCounter > 0) && newCounter <= stored) throw await counterRegressed(row, newCounter);

  await prisma.$executeRaw`
    UPDATE user_passkeys SET sign_count = ${newCounter}, backed_up = ${credentialBackedUp ? 1 : 0}, last_used_at = ${new Date()}
    WHERE passkey_id = ${row.passkey_id}`;
  return Number(row.user_id);
};

const login = async (assertion, device) => {
  // 延後載入：services/auth → account 的載入鏈若在模組頂端引用會形成循環。
  const auth = require('./auth');
  const userId = await verifyAssertion(assertion, { purpose: 'login' });
  const user = await identities.loadLoginUser(userId);
  if (!user) throw badRequest('無法辨識此通行密鑰，可能已從帳號中刪除', 'PASSKEY_NOT_RECOGNIZED');
  auth.assertLoginAllowed(user);
  return auth.issueLogin(user, device, 'passkey');
};

module.exports = {
  MAX_PER_USER, migrationReady, isAvailable, assertAvailable, hasPasskey, list, registrationOptions, register,
  rename, remove, loginOptions, verifyOptions, verifyAssertion, login, cleanupExpired
};
