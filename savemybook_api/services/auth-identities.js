const crypto = require('crypto');
const prisma = require('../lib/prisma');
const passwordLib = require('../lib/password');
const { signToken } = require('../lib/auth-token');
const { HttpError, badRequest, conflict, forbidden, notFound } = require('../lib/errors');
const settings = require('./auth-settings');
const auth = require('./auth');
const sessions = require('./sessions');
const push = require('./push');
const legal = require('./legal');

const LOGIN_USER_SELECT = {
  user_id: true, email: true, role: true, password_hash: true,
  is_active: true, is_blacklisted: true, phone: true, deletion_requested_at: true
};

const emailHint = (email) => (email ? { provider_email: email } : undefined);

const linkRequired = (email) => new HttpError(
  409,
  '此電子郵件已註冊，請登入該帳號以綁定此登入方式',
  'ACCOUNT_EXISTS_LINK_REQUIRED',
  emailHint(email)
);

const noAccountForProvider = (provider, email = null) => new HttpError(
  404,
  `此 ${settings.PROVIDER_LABELS[provider] ?? provider} 帳號尚未綁定任何帳號`,
  'NO_ACCOUNT_FOR_PROVIDER',
  emailHint(email)
);

const maskEmail = (email) => {
  const [local, domain] = String(email ?? '').split('@');
  if (!local || !domain) return null;
  return `${local.slice(0, 2)}***@${domain}`;
};

const maskPhone = (phone) => {
  const digits = String(phone ?? '').replace(/\D/g, '');
  if (digits.length < 3) return null;
  return `${/^(09|8869)/.test(digits) ? '09**' : '***'}-***-${digits.slice(-3)}`;
};

const randomNickname = () => `使用者${String(crypto.randomInt(0, 10000)).padStart(4, '0')}`;

const findIdentity = async (provider, subject) => {
  const rows = await prisma.$queryRaw`
    SELECT identity_id, user_id FROM user_identities
    WHERE provider = ${provider} AND subject = ${subject}`;
  return rows[0] ?? null;
};

const identitiesOf = (userId) => prisma.$queryRaw`
  SELECT provider, email, phone, display_name, created_at, last_login_at
  FROM user_identities WHERE user_id = ${userId} ORDER BY created_at ASC`;

const passwordSetOf = async (userId) => {
  const rows = await prisma.$queryRaw`SELECT password_set FROM users WHERE user_id = ${userId}`;
  return Number(rows[0]?.password_set ?? 1) === 1;
};

const hasPassword = passwordSetOf;

const listFor = async (userId) => {
  const [rows, passwordSet, user] = await Promise.all([
    identitiesOf(userId),
    passwordSetOf(userId),
    prisma.users.findUnique({ where: { user_id: userId }, select: { phone: true } })
  ]);

  return {
    password_set: passwordSet,
    identities: rows.map((row) => ({
      provider: row.provider,
      display_name: row.display_name,
      masked_email: maskEmail(row.email),
      masked_phone: maskPhone(row.phone ?? (row.provider === 'phone' ? user?.phone : null)),
      created_at: row.created_at,
      last_login_at: row.last_login_at
    }))
  };
};

const loadLoginUser = (userId) =>
  prisma.users.findUnique({ where: { user_id: userId }, select: LOGIN_USER_SELECT });

const touchIdentity = (provider, subject, info) => prisma.$executeRaw`
  UPDATE user_identities
  SET last_login_at = ${new Date()},
      email = COALESCE(${info.email ?? null}, email),
      phone = COALESCE(${info.phoneNumber ?? null}, phone),
      display_name = COALESCE(${info.displayName ?? null}, display_name)
  WHERE provider = ${provider} AND subject = ${subject}`;

// 手機號碼只在使用者尚未填寫時補上，不覆寫本人自行維護的資料。
const fillPhone = (userId, phoneNumber) => (phoneNumber
  ? prisma.$executeRaw`
      UPDATE users SET phone = ${phoneNumber.slice(0, 20)}, updated_at = ${new Date()}
      WHERE user_id = ${userId} AND (phone IS NULL OR phone = '')`
  : Promise.resolve(0));

const createAccount = async ({ provider, info, email, nickname, acceptLegal }) => {
  const now = new Date();
  const user = await prisma.$transaction(async (tx) => {
    const created = await tx.users.create({
      data: {
        email,
        // 未設定密碼的帳號存入無法比對成功的隨機值，並以 password_set = 0 標記。
        password_hash: crypto.randomBytes(32).toString('hex'),
        nickname,
        role: 'buyer_seller',
        ...(provider === 'phone' && info.phoneNumber ? { phone: info.phoneNumber.slice(0, 20) } : {})
      },
      select: LOGIN_USER_SELECT
    });
    await tx.$executeRaw`UPDATE users SET password_set = 0 WHERE user_id = ${created.user_id}`;
    await tx.$executeRaw`
      INSERT INTO user_identities (user_id, provider, subject, email, phone, display_name, created_at, last_login_at)
      VALUES (${created.user_id}, ${provider}, ${info.subject}, ${info.email ?? null},
              ${info.phoneNumber ?? null}, ${info.displayName ?? null}, ${now}, ${now})`;
    return created;
  });

  if (acceptLegal) {
    await legal.acceptAllCurrent(user.user_id).catch((err) => console.error('[記錄註冊同意失敗]:', err.message));
  }
  return user;
};

// 依 identity 決定登入既有帳號或建立新帳號；回傳可直接簽發 Token 的使用者資料。
// create 為 false 時絕不建立帳號：使用者必須自己決定要綁定既有帳號還是註冊新帳號。
const resolveSignIn = async ({
  provider, info, email: fallbackEmail = null, nickname: fallbackNickname = null,
  acceptLegal = false, create = false
}) => {
  const existingIdentity = await findIdentity(provider, info.subject);
  if (existingIdentity) {
    const user = await loadLoginUser(Number(existingIdentity.user_id));
    if (!user) throw notFound('帳號不存在，請重新登入', 'ACCOUNT_NOT_FOUND');
    auth.assertLoginAllowed(user);
    await touchIdentity(provider, info.subject, info);
    if (provider === 'phone') await fillPhone(user.user_id, info.phoneNumber);
    return { user, created: false };
  }

  if (!create) throw noAccountForProvider(provider, info.email ?? null);

  const verifiedEmail = info.emailVerified ? info.email : null;
  if (verifiedEmail && (await prisma.users.findUnique({ where: { email: verifiedEmail }, select: { user_id: true } }))) {
    throw linkRequired(verifiedEmail);
  }

  const channel = await settings.channelOf(provider);
  if (!channel.signup) throw forbidden('此登入方式僅供既有帳號使用', 'SIGNUP_NOT_ALLOWED');

  let email = verifiedEmail;
  if (!email) {
    if (!fallbackEmail) throw badRequest('請提供電子郵件以建立帳號', 'EMAIL_REQUIRED');
    email = fallbackEmail;
    if (await prisma.users.findUnique({ where: { email }, select: { user_id: true } })) throw linkRequired(email);
  }

  const nickname = info.displayName || fallbackNickname || randomNickname();
  try {
    const user = await createAccount({ provider, info, email, nickname, acceptLegal });
    return { user, created: true };
  } catch (err) {
    // 同一個 Email 或同一組 identity 併發建立時，改回請使用者以既有方式登入。
    if (err?.code === 'P2002') throw linkRequired(email);
    throw err;
  }
};

const signIn = async ({ provider, info, device, email, nickname, acceptLegal, create }) => {
  const { user } = await resolveSignIn({ provider, info, email, nickname, acceptLegal, create });
  return auth.issueLogin(user, device, provider);
};

const link = async (userId, provider, info) => {
  const existing = await findIdentity(provider, info.subject);
  if (existing) {
    throw Number(existing.user_id) === Number(userId)
      ? conflict('此帳號已綁定此登入方式', 'ALREADY_LINKED')
      : conflict('此登入方式已綁定其他帳號', 'IDENTITY_TAKEN');
  }

  const rows = await identitiesOf(userId);
  if (rows.some((row) => row.provider === provider)) throw conflict('此帳號已綁定此登入方式', 'ALREADY_LINKED');

  const now = new Date();
  await prisma.$executeRaw`
    INSERT INTO user_identities (user_id, provider, subject, email, phone, display_name, created_at, last_login_at)
    VALUES (${userId}, ${provider}, ${info.subject}, ${info.email ?? null},
            ${info.phoneNumber ?? null}, ${info.displayName ?? null}, ${now}, ${now})`;
  if (provider === 'phone') await fillPhone(userId, info.phoneNumber);

  return listFor(userId);
};

// 不可引用 services/passkeys：該模組引用本檔，會形成循環載入。
const passkeyCountOf = async (userId) => {
  const [row] = await prisma.$queryRaw`SELECT COUNT(*) AS n FROM user_passkeys WHERE user_id = ${userId}`;
  return Number(row?.n ?? 0);
};

const unlink = async (userId, provider) => {
  const [rows, passwordSet] = await Promise.all([identitiesOf(userId), passwordSetOf(userId)]);
  if (!rows.some((row) => row.provider === provider)) throw notFound('此帳號未綁定此登入方式');
  if (!passwordSet && rows.length <= 1 && (await passkeyCountOf(userId)) === 0) {
    throw badRequest('這是此帳號唯一的登入方式，請先設定密碼或綁定其他登入方式', 'LAST_SIGN_IN_METHOD');
  }

  await prisma.$executeRaw`DELETE FROM user_identities WHERE user_id = ${userId} AND provider = ${provider}`;
  return listFor(userId);
};

const setPassword = async (userId, sid, plain) => {
  if (await passwordSetOf(userId)) throw badRequest('此帳號已設定密碼，請改用變更密碼', 'PASSWORD_ALREADY_SET');

  const updated = await prisma.users.update({
    where: { user_id: userId },
    data: { password_hash: await passwordLib.hash(plain), updated_at: new Date() },
    select: { user_id: true, email: true, role: true, password_hash: true }
  });
  await prisma.$executeRaw`UPDATE users SET password_set = 1 WHERE user_id = ${userId}`;

  // 密碼版本改變會讓所有既有 Token 失效，必須換發目前裝置的 Token。
  await push.removeUserDevices(userId);
  await sessions.revokeAll(userId, { exceptSid: sid });
  return signToken(updated, sid);
};

module.exports = {
  maskEmail, maskPhone, findIdentity, identitiesOf, passwordSetOf, hasPassword, listFor,
  resolveSignIn, signIn, link, unlink, setPassword, loadLoginUser, noAccountForProvider
};
