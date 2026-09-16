const express = require('express');
const v = require('../../lib/validate');
const { badRequest } = require('../../lib/errors');
const groups = require('../../services/chat/groups');
const { sendLimiter, CHAT_IMAGE_RE } = require('./limits');

const router = express.Router();

const nameOf = (value) => {
  const name = v.text(value, { label: '群組名稱', max: groups.MAX_NAME_LENGTH });
  if (!name) throw badRequest('請輸入群組名稱');
  return name;
};

const avatarOf = (value) => {
  if (value === undefined) return undefined;
  if (value === null || value === '') return null;
  const url = v.text(value, { label: '群組頭貼網址', max: 500 });
  if (!CHAT_IMAGE_RE.test(url)) throw badRequest('群組頭貼請先透過 /api/uploads/chat-image 上傳');
  return url;
};

const userIdsOf = (value) => {
  if (!Array.isArray(value) || value.length === 0) throw badRequest('請選擇成員');
  if (value.length > groups.MAX_INVITE) throw badRequest(`一次最多邀請 ${groups.MAX_INVITE} 人`);
  return [...new Set(value.map((id) => v.id(id, '成員編號')))];
};

router.post('/groups', sendLimiter, async (req, res) => {
  const name = nameOf(req.body.name);
  const memberIds = userIdsOf(req.body.member_ids);
  const avatarUrl = avatarOf(req.body.avatar_url) ?? null;

  const roomId = await groups.create(req.user.userId, { name, memberIds, avatarUrl });
  res.status(201).json({ success: true, message: '已建立群組', data: { room_id: roomId } });
});

router.patch('/groups/:roomId', async (req, res) => {
  const roomId = v.id(req.params.roomId, '聊天室編號');
  if (req.body.name === undefined && req.body.avatar_url === undefined) throw badRequest('請提供群組名稱或頭貼');
  const name = req.body.name === undefined ? undefined : nameOf(req.body.name);
  const avatarUrl = avatarOf(req.body.avatar_url);

  const data = await groups.update(roomId, req.user.userId, { name, avatarUrl });
  res.status(200).json({ success: true, message: '已更新群組資訊', data });
});

router.post('/groups/:roomId/members', sendLimiter, async (req, res) => {
  const roomId = v.id(req.params.roomId, '聊天室編號');
  const userIds = userIdsOf(req.body.user_ids);

  const data = await groups.invite(roomId, req.user.userId, userIds);
  res.status(200).json({
    success: true,
    message: data.added_user_ids.length ? '已邀請成員加入群組' : '所選成員皆已在群組中',
    data
  });
});

router.patch('/groups/:roomId/members/:userId', async (req, res) => {
  const roomId = v.id(req.params.roomId, '聊天室編號');
  const userId = v.id(req.params.userId, '使用者編號');
  const role = v.oneOf(req.body.role, ['owner', 'member'], '成員角色不正確');

  const data = await groups.setRole(roomId, req.user.userId, userId, role);
  res.status(200).json({ success: true, message: role === 'owner' ? '已設為管理員' : '已解除管理員身分', data });
});

router.delete('/groups/:roomId/members/:userId', async (req, res) => {
  const roomId = v.id(req.params.roomId, '聊天室編號');
  const userId = v.id(req.params.userId, '使用者編號');

  const data = await groups.removeMember(roomId, req.user.userId, userId);
  res.status(200).json({ success: true, message: '已將成員移出群組', data });
});

router.post('/groups/:roomId/leave', async (req, res) => {
  const roomId = v.id(req.params.roomId, '聊天室編號');
  const data = await groups.leave(roomId, req.user.userId);
  res.status(200).json({ success: true, message: '已退出群組', data });
});

module.exports = router;
