const express = require('express');
const v = require('../../lib/validate');
const { badRequest } = require('../../lib/errors');
const controls = require('../../services/chat/controls');
const aliases = require('../../services/chat/aliases');

const router = express.Router();

router.get('/blocks', async (req, res) => {
  res.status(200).json({ success: true, data: await controls.listBlocks(req.user.userId) });
});

router.put('/blocks/:userId', async (req, res) => {
  const targetId = v.id(req.params.userId, '使用者編號');
  await controls.block(req.user.userId, targetId);
  res.status(200).json({ success: true, message: '已封鎖此使用者', data: { user_id: targetId, blocked: true } });
});

router.delete('/blocks/:userId', async (req, res) => {
  const targetId = v.id(req.params.userId, '使用者編號');
  await controls.unblock(req.user.userId, targetId);
  res.status(200).json({ success: true, message: '已解除封鎖', data: { user_id: targetId, blocked: false } });
});

router.put('/aliases/:userId', async (req, res) => {
  const targetId = v.id(req.params.userId, '使用者編號');
  const { alias } = req.body;
  if (alias === undefined) throw badRequest('請提供 alias');
  if (alias !== null && typeof alias !== 'string') throw badRequest('alias 必須為字串');
  const value = v.text(alias ?? '', { label: '暱稱', max: aliases.MAX_ALIAS_LENGTH }) || null;

  const saved = await aliases.set(req.user.userId, targetId, value);
  res.status(200).json({
    success: true,
    message: saved ? '已設定暱稱' : '已移除暱稱',
    data: { user_id: targetId, alias: saved }
  });
});

module.exports = router;
