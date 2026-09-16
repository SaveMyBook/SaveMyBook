const express = require('express');
const requireAdmin = require('../../middleware/requireAdmin');
const { requireVerification } = require('../../middleware/verification');
const v = require('../../lib/validate');
const { actorOf } = require('../../lib/request-context');
const { badRequest } = require('../../lib/errors');
const { USER_ROLES } = require('../../constants/domain');
const members = require('../../services/members');

const router = express.Router();
const canManage = requireAdmin('members');

const assertNotSelf = (req, userId, message) => {
  if (userId === req.user.userId) throw badRequest(message);
};

router.get('/members', canManage, async (req, res) => {
  const keyword = v.text(req.query.keyword, { label: '關鍵字', max: 100 });
  const { page, limit, skip } = v.pagination(req.query);

  const { members: data, total } = await members.list({ keyword, status: req.query.status, skip, limit });
  res.status(200).json({ success: true, pagination: v.pageMeta(total, { page, limit }), data });
});

router.get('/members/:id', canManage, async (req, res) => {
  const data = await members.detail(v.id(req.params.id, '會員編號'), req.user.userId);
  res.status(200).json({ success: true, data });
});

router.post('/members/:id/reset-password', canManage, requireVerification('admin'), async (req, res) => {
  const userId = v.id(req.params.id, '會員編號');
  assertNotSelf(req, userId, '無法重設自己的密碼，請使用「更改密碼」');

  const temp = await members.resetPassword(userId, actorOf(req));

  res.set('Cache-Control', 'no-store');
  res.status(200).json({
    success: true,
    message: '已重設，請將臨時密碼提供給使用者',
    data: { temp_password: temp }
  });
});

router.patch('/members/:id', canManage, async (req, res) => {
  const userId = v.id(req.params.id, '會員編號');
  assertNotSelf(req, userId, '無法變更自己的帳號狀態');

  const { is_active: isActive, is_blacklisted: isBlacklisted, role } = req.body;
  const data = {
    ...(isActive !== undefined && { is_active: v.bool(isActive) }),
    ...(isBlacklisted !== undefined && { is_blacklisted: v.bool(isBlacklisted) }),
    ...(role !== undefined && { role: v.oneOf(role, USER_ROLES, '不支援的身分') })
  };
  if (Object.keys(data).length === 0) throw badRequest('沒有需要變更的欄位');

  const updated = await members.updateStatus(userId, data, actorOf(req));
  res.status(200).json({ success: true, message: '會員狀態已更新', data: updated });
});

router.patch('/members/:id/level', canManage, async (req, res) => {
  const userId = v.id(req.params.id, '會員編號');
  const { level_id: levelId, reset, delta } = req.body;

  const data = await members.adjustLevel(userId, { reset, delta, levelId }, actorOf(req));
  res.status(200).json({ success: true, message: '已調整等級', data });
});

router.put('/members/:id/permissions', canManage, requireVerification('admin'), async (req, res) => {
  const userId = v.id(req.params.id, '會員編號');
  assertNotSelf(req, userId, '無法變更自己的權限');

  const data = {};
  for (const key of members.PERMISSION_COLUMNS) {
    if (req.body[key] !== undefined) data[key] = v.bool(req.body[key]);
  }
  if (Object.keys(data).length === 0) throw badRequest('沒有需要更新的權限');

  await members.setPermissions(userId, data, actorOf(req));
  res.status(200).json({ success: true, message: '已更新權限' });
});

module.exports = router;
