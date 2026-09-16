const express = require('express');
const authenticateToken = require('../../middleware/auth');
const requireAdmin = require('../../middleware/requireAdmin');
const { requireVerification } = require('../../middleware/verification');
const { rateLimit, byIp } = require('../../middleware/rateLimit');
const { id, text } = require('../../lib/validate');
const { actorOf } = require('../../lib/request-context');
const password = require('../../lib/password');
const { badRequest, forbidden } = require('../../lib/errors');
const users = require('../../services/users');
const { nickname, profileData } = require('./validators');

const router = express.Router();

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

const registerLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 30,
  key: byIp,
  message: '註冊次數過多，請稍後再試'
});

router.get('/', authenticateToken, requireAdmin('members'), async (req, res) => {
  res.status(200).json({ success: true, data: await users.listAll() });
});

router.get('/share/:token', authenticateToken, async (req, res) => {
  const data = await users.findByShareToken(String(req.params.token || '').toLowerCase());
  res.status(200).json({ success: true, data });
});

router.get('/:id', authenticateToken, async (req, res) => {
  const userId = id(req.params.id, '使用者編號');
  const includePrivate = userId === req.user.userId || req.user.role === 'admin';

  const user = await users.profileOf(userId, { includePrivate });
  res.status(200).json({ success: true, data: user });
});

router.post('/', registerLimiter, async (req, res) => {
  const email = text(req.body.email, { label: '電子郵件', max: 255 }).toLowerCase();
  const plain = req.body.password;
  const name = text(req.body.nickname, { label: '暱稱', max: 50 });

  if (!email || !plain || !name) throw badRequest('缺少必要欄位：email、password 或 nickname');
  if (!EMAIL_RE.test(email)) throw badRequest('電子郵件格式不正確');
  password.assertPolicy(plain);
  nickname(name);

  const newUser = await users.register({ email, plain, nickname: name, acceptLegal: req.body.accept_legal === true });
  res.status(201).json({ success: true, message: '使用者建立成功', data: newUser });
});

router.put('/:id', authenticateToken, async (req, res) => {
  const userId = id(req.params.id, '使用者編號');
  if (req.user.userId !== userId && req.user.role !== 'admin') {
    throw forbidden('存取被拒，您無權限修改他人的資料');
  }

  const updated = await users.updateProfile(userId, profileData(req.body));
  res.status(200).json({ success: true, message: '使用者資料更新成功', data: updated });
});

// 實體刪除僅限管理員，否則可繞過 /me/deletion「有進行中訂單不能刪」的檢查。
router.delete('/:id', authenticateToken, requireAdmin('members'), requireVerification('sensitive'), async (req, res) => {
  const userId = id(req.params.id, '使用者編號');
  await users.hardDelete(userId, actorOf(req));
  res.status(200).json({ success: true, message: '使用者已成功刪除' });
});

module.exports = router;
