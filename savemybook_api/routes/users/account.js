const express = require('express');
const authenticateToken = require('../../middleware/auth');
const { requireVerification } = require('../../middleware/verification');
const { rateLimit, byUser } = require('../../middleware/rateLimit');
const { date } = require('../../lib/validate');
const password = require('../../lib/password');
const { imageUpload } = require('../../lib/upload');
const { publicBase } = require('../../lib/public-url');
const { badRequest } = require('../../lib/errors');
const { GENDERS } = require('../../constants/domain');
const users = require('../../services/users');
const account = require('../../services/account');
const identities = require('../../services/auth-identities');
const levels = require('../../services/levels');
const { avatarUrl, profileData } = require('./validators');

const router = express.Router();

const avatars = imageUpload({ folder: 'avatars', maxFileSize: 5 * 1024 * 1024 });

const passwordLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  key: byUser,
  message: '嘗試次數過多，請 15 分鐘後再試'
});

router.get('/me/stats', authenticateToken, async (req, res) => {
  res.status(200).json({ success: true, data: await users.stats(req.user.userId) });
});

router.get('/me/level', authenticateToken, async (req, res) => {
  res.status(200).json({ success: true, data: await levels.summaryFor(req.user.userId) });
});

router.put('/me', authenticateToken, async (req, res) => {
  const body = req.body;
  const data = profileData(body);
  if (body.avatar_url !== undefined) data.avatar_url = avatarUrl(body.avatar_url);
  if (body.gender !== undefined && GENDERS.includes(body.gender)) data.gender = body.gender;
  if (body.birthday !== undefined) {
    const birthday = date(body.birthday, '生日');
    if (birthday && (birthday > new Date() || birthday.getFullYear() < 1900)) {
      throw badRequest('生日不在合理範圍內');
    }
    data.birthday = birthday;
  }

  const updated = await users.updateSelf(req.user.userId, data);
  res.status(200).json({ success: true, message: '個人檔案已更新', data: updated });
});

router.post('/me/avatar', authenticateToken, ...avatars.single('avatar'), async (req, res) => {
  if (!req.file) throw badRequest('請選擇要上傳的圖片');

  const updated = await users.updateSelf(req.user.userId, { avatar_url: avatars.urlOf(req.file) });
  res.status(200).json({ success: true, message: '頭像已更新', data: updated });
});

router.put('/me/password', authenticateToken, passwordLimiter, async (req, res) => {
  const { current_password: current, new_password: next } = req.body;

  if (!current || !next) throw badRequest('請填寫目前密碼與新密碼');
  password.assertPolicy(next, '新密碼');
  if (!(await identities.hasPassword(req.user.userId))) {
    throw badRequest('此帳號尚未設定密碼，請改用設定密碼', 'PASSWORD_NOT_SET');
  }

  const token = await users.changePassword(req.user.userId, req.user.sid, current, next);
  res.status(200).json({
    success: true,
    message: '密碼已更新，其他裝置須重新登入',
    data: { token }
  });
});

router.get('/me/identities', authenticateToken, async (req, res) => {
  res.status(200).json({ success: true, data: await identities.listFor(req.user.userId) });
});

router.get('/me/qrcode', authenticateToken, async (req, res) => {
  const data = await users.profileQrCode(req.user.userId, publicBase(req));
  res.status(200).json({ success: true, data });
});

router.post('/me/share-token/rotate', authenticateToken, async (req, res) => {
  const qrData = await users.rotateShareLink(req.user.userId, publicBase(req));
  res.status(200).json({
    success: true,
    message: '已產生新連結，舊連結立即失效',
    data: { qr_data: qrData }
  });
});

router.get('/me/export', authenticateToken, requireVerification('sensitive'), async (req, res) => {
  const data = await account.exportData(req.user.userId);
  const stamp = new Date().toISOString().slice(0, 10);
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Content-Disposition', `attachment; filename="savemybook-${stamp}.json"`);
  res.setHeader('Cache-Control', 'no-store');
  res.status(200).send(JSON.stringify(data, null, 2));
});

router.get('/me/deletion', authenticateToken, async (req, res) => {
  res.status(200).json({ success: true, data: await account.deletionInfo(req.user.userId) });
});

router.post('/me/deletion', authenticateToken, passwordLimiter, async (req, res) => {
  const plain = typeof req.body.password === 'string' ? req.body.password : '';
  if (!plain) throw badRequest('請輸入密碼以確認身分');
  if (!(await identities.hasPassword(req.user.userId))) {
    throw badRequest('此帳號尚未設定密碼，請先設定密碼再申請刪除帳號', 'PASSWORD_NOT_SET');
  }

  const data = await account.requestDeletion(req.user.userId, plain);
  res.status(200).json({
    success: true,
    message: `已受理，${account.GRACE_DAYS} 天內重新登入即可取消`,
    data
  });
});

router.delete('/me/deletion', authenticateToken, async (req, res) => {
  await account.cancelDeletion(req.user.userId);
  res.status(200).json({ success: true, message: '已取消刪除帳號' });
});

module.exports = router;
