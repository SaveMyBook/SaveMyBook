const express = require('express');
const authenticateToken = require('../middleware/auth');
const { requireVerification } = require('../middleware/verification');
const { rateLimit, byUser } = require('../middleware/rateLimit');
const { text } = require('../lib/validate');
const { badRequest } = require('../lib/errors');
const passkeys = require('../services/passkeys');

const router = express.Router();

router.use(authenticateToken);

const registerLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  key: byUser,
  message: '操作過於頻繁，請 15 分鐘後再試'
});

router.get('/', async (req, res) => {
  const data = await passkeys.list(req.user.userId);
  res.status(200).json({ success: true, data });
});

router.post('/options', registerLimiter, async (req, res) => {
  const options = await passkeys.registrationOptions(req.user.userId);
  res.status(200).json({ success: true, data: { options } });
});

router.post('/', registerLimiter, requireVerification('sensitive'), async (req, res) => {
  const label = text(req.body.device_label, { label: '裝置名稱', max: 50 }) || null;
  const data = await passkeys.register(req.user.userId, req.body.attestation, label);
  res.status(201).json({ success: true, message: '已新增通行密鑰', data });
});

router.patch('/:id', registerLimiter, async (req, res) => {
  const label = text(req.body.device_label, { label: '名稱', max: 50 });
  if (!label) throw badRequest('請輸入名稱');
  const data = await passkeys.rename(req.user.userId, req.params.id, label);
  res.status(200).json({ success: true, message: '已更新名稱', data });
});

router.delete('/:id', requireVerification('sensitive'), async (req, res) => {
  const data = await passkeys.remove(req.user.userId, req.params.id);
  res.status(200).json({ success: true, message: '已刪除通行密鑰', data });
});

module.exports = router;
