const express = require('express');
const authenticateToken = require('../middleware/auth');
const { requireVerification } = require('../middleware/verification');
const { rateLimit, byIp, byUser } = require('../middleware/rateLimit');
const { text, oneOf } = require('../lib/validate');
const { readToken } = require('../lib/auth-token');
const password = require('../lib/password');
const firebase = require('../lib/firebase-token');
const { badRequest, unauthorized } = require('../lib/errors');
const auth = require('../services/auth');
const security = require('../services/security');
const sessions = require('../services/sessions');
const authSettings = require('../services/auth-settings');
const identities = require('../services/auth-identities');
const oauth = require('../services/oauth-providers');

const router = express.Router();

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const OAUTH_DEEP_LINK = 'savemybook://auth/oauth';

// 以 IP + Email 計數：只看 IP 會連坐 NAT 後的使用者，只看 Email 則任何人都能鎖住他人帳號。
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  key: (req) => `${byIp(req)}|${text(req.body?.email).toLowerCase()}`,
  message: '登入嘗試次數過多，請 15 分鐘後再試'
});

const loginBurstLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  key: byIp,
  message: '登入嘗試次數過多，請稍後再試'
});

const refreshLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 60,
  key: byIp,
  message: '操作過於頻繁，請稍後再試'
});

const socialLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 30,
  key: byIp,
  message: '登入嘗試次數過多，請 15 分鐘後再試'
});

const linkLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  key: byUser,
  message: '嘗試次數過多，請 15 分鐘後再試'
});

const deviceFrom = (req) => ({
  deviceId: req.body.device_id,
  deviceName: req.body.device_name,
  platform: req.body.platform,
  appVersion: req.body.app_version,
  ip: req.ip
});

const idTokenOf = (body) => {
  const token = typeof body.id_token === 'string' ? body.id_token.trim() : '';
  if (!token) throw badRequest('請提供 id_token');
  return token;
};

const firebaseProvider = (value) =>
  oneOf(value, authSettings.FIREBASE_PROVIDERS, `provider 僅接受：${authSettings.FIREBASE_PROVIDERS.join(', ')}`);

const verifiedInfo = async (provider, idToken) => {
  const info = await firebase.verifyIdToken(idToken, provider);
  if (!info.matchesProvider) throw badRequest('登入憑證與所選的登入方式不符', 'PROVIDER_MISMATCH');
  return info;
};

// mode 為 link 時才需要登入與敏感操作驗證，login 是未登入狀態下的流程。
const whenLinkMode = (middleware) => (req, res, next) =>
  (req.body?.mode === 'link' ? middleware(req, res, next) : next());

const linkModeAuth = whenLinkMode(authenticateToken);
const linkModeVerify = whenLinkMode(requireVerification('sensitive'));

// 未設定密碼的帳號無法通過 sensitive 驗證（登入密碼比對必定失敗），只有已設定交易密碼時才要求，
// 否則社群登入的使用者永遠無法設定第一組密碼。
const sensitiveWhenAvailable = (req, res, next) => {
  security.status(req.user.userId, req.user.sid)
    .then((state) => (state.available && state.has_payment_pin
      ? requireVerification('sensitive')(req, res, next)
      : next()))
    .catch(next);
};

router.post('/login', loginBurstLimiter, loginLimiter, async (req, res) => {
  const email = text(req.body.email, { max: 255 });
  const plain = typeof req.body.password === 'string' ? req.body.password : '';

  if (!email || !plain) throw badRequest('請提供 Email 與密碼');

  const { token, deletion } = await auth.login(email, plain, deviceFrom(req));

  res.status(200).json({
    success: true,
    message: '登入成功',
    data: { token, ...(deletion && { pending_deletion: deletion }) }
  });
});

router.post('/refresh', refreshLimiter, async (req, res) => {
  const raw = readToken(req);
  if (!raw) throw unauthorized('存取被拒，未提供 Token');

  const token = await auth.refresh(raw, req.ip);
  res.status(200).json({ success: true, data: { token } });
});

router.post('/logout', authenticateToken, async (req, res) => {
  await sessions.revokeBySid(req.user.sid);
  res.status(200).json({ success: true, message: '已登出' });
});

router.get('/me', authenticateToken, async (req, res) => {
  const user = await auth.currentUser(req.user.userId);
  res.status(200).json({ success: true, data: user });
});

router.get('/providers', async (req, res) => {
  res.status(200).json({ success: true, data: await authSettings.publicPayload() });
});

router.post('/social', socialLimiter, async (req, res) => {
  const provider = firebaseProvider(req.body.provider);
  const idToken = idTokenOf(req.body);

  const email = text(req.body.email, { label: 'Email', max: 255 }).toLowerCase();
  if (email && !EMAIL_RE.test(email)) throw badRequest('Email 格式不正確');
  const nickname = text(req.body.nickname, { label: '暱稱', max: 50 });
  if (nickname && nickname.length < 2) throw badRequest('暱稱至少需 2 個字');

  await authSettings.assertEnabled(provider);
  const info = await verifiedInfo(provider, idToken);

  const { token, deletion } = await identities.signIn({
    provider,
    info,
    device: deviceFrom(req),
    email: email || null,
    nickname: nickname || null,
    acceptLegal: req.body.accept_legal === true
  });

  res.status(200).json({
    success: true,
    message: '登入成功',
    data: { token, ...(deletion && { pending_deletion: deletion }) }
  });
});

router.post('/link', authenticateToken, linkLimiter, requireVerification('sensitive'), async (req, res) => {
  const provider = firebaseProvider(req.body.provider);
  const idToken = idTokenOf(req.body);

  await authSettings.assertEnabled(provider);
  const info = await verifiedInfo(provider, idToken);

  const data = await identities.link(req.user.userId, provider, info);
  res.status(200).json({ success: true, message: '已綁定此登入方式', data });
});

router.delete('/link/:provider', authenticateToken, requireVerification('sensitive'), async (req, res) => {
  const provider = oneOf(
    req.params.provider,
    authSettings.PROVIDER_IDS,
    `provider 僅接受：${authSettings.PROVIDER_IDS.join(', ')}`
  );

  const data = await identities.unlink(req.user.userId, provider);
  res.status(200).json({ success: true, message: '已解除綁定', data });
});

router.post('/password/set', authenticateToken, linkLimiter, sensitiveWhenAvailable, async (req, res) => {
  const plain = typeof req.body.password === 'string' ? req.body.password : '';
  password.assertPolicy(plain);

  const token = await identities.setPassword(req.user.userId, req.user.sid, plain);
  res.status(200).json({ success: true, message: '密碼已設定，其他裝置須重新登入', data: { token } });
});

router.post('/oauth/exchange', socialLimiter, async (req, res) => {
  const code = typeof req.body.code === 'string' ? req.body.code.trim() : '';
  if (!code) throw badRequest('請提供 code');

  const result = await oauth.exchangeResult(code, deviceFrom(req));
  if (result.linked) {
    return res.status(200).json({ success: true, message: '已綁定此登入方式', data: result });
  }
  res.status(200).json({
    success: true,
    message: '登入成功',
    data: { token: result.token, ...(result.deletion && { pending_deletion: result.deletion }) }
  });
});

router.post('/oauth/:provider/start', socialLimiter, linkModeAuth, linkModeVerify, async (req, res) => {
  const provider = oneOf(
    req.params.provider,
    authSettings.OAUTH_PROVIDERS,
    `provider 僅接受：${authSettings.OAUTH_PROVIDERS.join(', ')}`
  );
  const mode = oneOf(req.body.mode ?? 'login', ['login', 'link'], 'mode 僅接受：login, link');

  const data = await oauth.start(provider, mode, mode === 'link' ? req.user.userId : null);
  res.status(200).json({ success: true, data });
});

router.get('/oauth/:provider/callback', async (req, res) => {
  const finish = (query) => {
    res.setHeader('Cache-Control', 'no-store');
    res.status(302)
      .location(`${OAUTH_DEEP_LINK}?${new URLSearchParams(query).toString()}`)
      .type('text/plain')
      .send('請返回 SaveMyBook 應用程式繼續操作。');
  };

  try {
    const provider = oneOf(req.params.provider, authSettings.OAUTH_PROVIDERS, 'provider 不正確');
    const code = await oauth.handleCallback(provider, req.query.code, req.query.state);
    finish({ code });
  } catch (err) {
    // 回呼頁面不揭露細節，只帶錯誤代碼讓 App 顯示對應訊息。
    finish({ error: err?.code || 'OAUTH_FAILED' });
  }
});

module.exports = router;
