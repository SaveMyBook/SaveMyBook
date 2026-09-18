const firebase = require('../lib/firebase-token');
const { badRequest, conflict } = require('../lib/errors');
const settings = require('./auth-settings');
const identities = require('./auth-identities');
const auth = require('./auth');
const passkeys = require('./passkeys');
const oauth = require('./oauth-providers');
const { notify } = require('./notify');

const pendingIdentity = async ({ provider, idToken, code }) => {
  if (code) {
    const payload = await oauth.readResult(code);
    if (payload.kind !== 'signup' || !payload.info?.subject) {
      await oauth.dropResult(code);
      throw oauth.codeInvalid();
    }
    if (provider && provider !== payload.provider) throw badRequest('登入失敗，請重新操作', 'PROVIDER_MISMATCH');
    await settings.assertEnabled(payload.provider);
    return { provider: payload.provider, info: payload.info };
  }

  await settings.assertEnabled(provider);
  const info = await firebase.verifyIdToken(idToken, provider);
  if (!info.matchesProvider) throw badRequest('登入失敗，請重新操作', 'PROVIDER_MISMATCH');
  return { provider, info };
};

const authenticate = async ({ email, password, assertion }) => {
  if (assertion) {
    const userId = await passkeys.verifyAssertion(assertion, { purpose: 'login' });
    const user = await identities.loadLoginUser(userId);
    if (!user) throw badRequest('無法辨識此通行密鑰，可能已從帳號中刪除', 'PASSKEY_NOT_RECOGNIZED');
    auth.assertLoginAllowed(user);
    return { user, method: 'passkey' };
  }
  if (!email || !password) throw badRequest('請提供 Email 與密碼');
  return { user: await auth.verifyPassword(email, password), method: 'password' };
};

const linkAndSignIn = async ({ provider, idToken, code, email, password, assertion, device }) => {
  if (!(await settings.migrationReady())) throw settings.unavailable();

  const pending = await pendingIdentity({ provider, idToken, code });
  const { user, method } = await authenticate({ email, password, assertion });

  const existing = await identities.findIdentity(pending.provider, pending.info.subject);
  if (existing && Number(existing.user_id) !== Number(user.user_id)) {
    throw conflict('此登入方式已綁定其他帳號', 'IDENTITY_TAKEN');
  }
  if (!existing) {
    try {
      await identities.link(user.user_id, pending.provider, pending.info);
    } catch (err) {
      if (err?.code === 'P2002') throw conflict('此登入方式已綁定其他帳號', 'IDENTITY_TAKEN');
      throw err;
    }
    const label = settings.PROVIDER_LABELS[pending.provider] ?? pending.provider;
    await notify(null, {
      userId: user.user_id,
      title: '已綁定登入方式',
      content: `您的帳號已綁定 ${label} 登入。若非本人操作，請立即變更密碼並至「帳號安全」解除綁定。`,
      relatedType: 'security'
    }).catch(() => {});
  }

  if (code) await oauth.dropResult(code);
  return auth.issueLogin(user, device, method);
};

module.exports = { linkAndSignIn };
